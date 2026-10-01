// @ts-nocheck
// Supabase Edge Function: Réception et validation cryptographique des webhooks Wave Sénégal
// Référentiels : Wave Checkout API v1, OWASP ASVS

import { serve } from 'https://deno.land/std@0.201.0/http/server.ts';
import { createClient } from 'https://cdn.jsdelivr.net/npm/@supabase/supabase-js/+esm';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const WAVE_WEBHOOK_SECRET = Deno.env.get('WAVE_WEBHOOK_SECRET') || '';

const supabase = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
  auth: { persistSession: false },
});

export async function handler(req: Request): Promise<Response> {
  try {
    if (req.method !== 'POST') {
      return new Response(JSON.stringify({ error: 'Method Not Allowed' }), {
        status: 405,
        headers: { 'Content-Type': 'application/json' },
      });
    }

    const rawBody = await req.text();
    const signature = req.headers.get('wave-signature');

    // Vérification de la signature cryptographique Wave si le secret est configuré
    if (WAVE_WEBHOOK_SECRET && signature) {
      const encoder = new TextEncoder();
      const keyData = encoder.encode(WAVE_WEBHOOK_SECRET);
      const key = await crypto.subtle.importKey(
        'raw',
        keyData,
        { name: 'HMAC', hash: 'SHA-256' },
        false,
        ['verify']
      );

      const isValid = await crypto.subtle.verify(
        'HMAC',
        key,
        hexToBytes(signature),
        encoder.encode(rawBody)
      );

      if (!isValid) {
        console.warn('Wave webhook: Signature invalide');
        return new Response(JSON.stringify({ error: 'Signature invalide' }), {
          status: 401,
          headers: { 'Content-Type': 'application/json' },
        });
      }
    }

    const event = JSON.parse(rawBody);
    console.log('Wave webhook reçu:', event.type || event.event);

    const data = event.data || event;
    const clientRef = data.client_reference || data.checkout_session_id;
    const waveTxId = data.transaction_id || data.id || `wave_${Date.now()}`;
    const amount = parseInt(data.amount || '0', 10);

    if (!clientRef) {
      console.warn('Wave webhook: Référence client absente');
      return new Response(JSON.stringify({ error: 'Missing client_reference' }), {
        status: 400,
        headers: { 'Content-Type': 'application/json' },
      });
    }

    // Extraction des booking_ids (supporte identifiant unique ou liste séparée par virgule)
    const bookingIds: string[] = clientRef.includes(',')
      ? clientRef.split(',').map((id: string) => id.trim())
      : [clientRef.trim()];

    for (const bookingId of bookingIds) {
      // 1. Confirmation atomique du paiement et passage des sièges à 'sold'
      const { data: confirmRes, error: confirmErr } = await supabase.rpc('confirm_payment', {
        p_booking_id: bookingId,
        p_provider: 'Wave',
        p_provider_ref: waveTxId,
        p_amount: Math.floor(amount / (bookingIds.length || 1)),
      });

      if (confirmErr) {
        console.error('Erreur confirm_payment RPC pour booking', bookingId, confirmErr);
        continue;
      }

      // 2. Émission officielle du billet cryptographiquement certifié par le serveur
      const { data: ticketRes, error: ticketErr } = await supabase.rpc('issue_ticket', {
        p_booking_id: bookingId,
      });

      if (ticketErr) {
        console.error('Erreur issue_ticket RPC pour booking', bookingId, ticketErr);
      } else {
        console.log('Billet officiel émis avec succès:', ticketRes?.ticket_number);
      }

      // 3. Notification push optionnelle
      const { data: bookingRow } = await supabase
        .from('bookings')
        .select('user_id')
        .eq('id', bookingId)
        .single();

      if (bookingRow?.user_id) {
        await supabase.functions.invoke('send-notification', {
          body: JSON.stringify({
            user_id: bookingRow.user_id,
            title: 'Paiement Wave Confirmé',
            body: `Votre billet Dioufy pour la réservation ${bookingId} est prêt !`,
          }),
        }).catch((e: any) => console.warn('Notification non délivrée:', e));
      }
    }

    return new Response(JSON.stringify({ success: true, processed: bookingIds.length }), {
      status: 200,
      headers: { 'Content-Type': 'application/json' },
    });
  } catch (err: any) {
    console.error('Erreur traitement Wave webhook:', err);
    return new Response(JSON.stringify({ error: err.message }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' },
    });
  }
}

function hexToBytes(hex: string): Uint8Array {
  const cleanHex = hex.trim().replace(/^0x/, '');
  const bytes = new Uint8Array(cleanHex.length / 2);
  for (let i = 0; i < cleanHex.length; i += 2) {
    bytes[i / 2] = parseInt(cleanHex.substring(i, i + 2), 16);
  }
  return bytes;
}

if (import.meta.main) {
  serve(handler);
}
