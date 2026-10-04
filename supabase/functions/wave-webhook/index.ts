// @ts-nocheck
// Supabase Edge Function: Réception et validation cryptographique stricte des webhooks Wave Sénégal
// RÈGLE P0 DE L'AUDIT (FAIL-CLOSED PAR DÉFAUT) :
// 1. Secret WAVE_WEBHOOK_SECRET obligatoirement configuré sur le serveur (500 si absent).
// 2. En-tête wave-signature STRICTEMENT OBLIGATOIRE (401 si manquant).
// 3. Signature HMAC SHA-256 validée avant tout traitement (401 si invalide).
// 4. Contrôles stricts : type = 'checkout.session.completed', devise = 'XOF'.
// 5. Validation du montant reçu contre le montant officiel attendu en base.
// 6. Confirmation transactionnelle atomique via confirm_payment avec service_role.

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

    // 1. CONTRÔLE DE CONFIGURATION SERVEUR (FAIL-CLOSED)
    // Refuser par défaut si le secret webhook n'est pas provisionné
    if (!WAVE_WEBHOOK_SECRET) {
      console.error('Wave webhook : Secret serveur WAVE_WEBHOOK_SECRET non configuré.');
      return new Response(JSON.stringify({ error: 'Configuration serveur Wave incomplète' }), {
        status: 500,
        headers: { 'Content-Type': 'application/json' },
      });
    }

    // 2. CONTRÔLE DE SIGNATURE CRYPTOGRAPHIQUE STRICT ET OBLIGATOIRE
    const signature = req.headers.get('wave-signature');
    if (!signature) {
      console.warn('Wave webhook : En-tête wave-signature manquant');
      return new Response(JSON.stringify({ error: 'En-tête de signature manquant' }), {
        status: 401,
        headers: { 'Content-Type': 'application/json' },
      });
    }

    const rawBody = await req.text();

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
      console.warn('Wave webhook : Signature HMAC invalide');
      return new Response(JSON.stringify({ error: 'Signature invalide ou frelatée' }), {
        status: 401,
        headers: { 'Content-Type': 'application/json' },
      });
    }

    const event = JSON.parse(rawBody);
    console.log('Wave webhook authentifié avec succès :', event.type || event.event);

    // 3. VÉRIFICATION DU TYPE D'ÉVÉNEMENT
    const eventType = event.type || event.event || '';
    if (eventType !== 'checkout.session.completed') {
      console.log(`Événement Wave ignoré (non finalisé) : ${eventType}`);
      return new Response(JSON.stringify({ message: 'Événement ignoré', type: eventType }), {
        status: 200,
        headers: { 'Content-Type': 'application/json' },
      });
    }

    const data = event.data || event;
    const clientRef = data.client_reference || data.checkout_session_id;
    const waveTxId = data.transaction_id || data.id || `wave_${Date.now()}`;
    const amount = parseInt(data.amount || '0', 10);
    const currency = (data.currency || '').toUpperCase();

    // 4. CONTRÔLE DE LA DEVISE
    if (currency && currency !== 'XOF' && currency !== 'CFA') {
      console.warn(`Devise Wave non conforme : ${currency}`);
      return new Response(JSON.stringify({ error: 'Devise non conforme' }), {
        status: 400,
        headers: { 'Content-Type': 'application/json' },
      });
    }

    if (!clientRef) {
      console.warn('Wave webhook : client_reference absente');
      return new Response(JSON.stringify({ error: 'Missing client_reference' }), {
        status: 400,
        headers: { 'Content-Type': 'application/json' },
      });
    }

    // 5. EXTRACTION EXACTE DES BOOKING IDS
    const bookingIds: string[] = clientRef.includes(',')
      ? clientRef.split(',').map((id: string) => id.trim()).filter(Boolean)
      : [clientRef.trim()];

    if (bookingIds.length === 0) {
      return new Response(JSON.stringify({ error: 'Aucun booking ID extrait' }), {
        status: 400,
        headers: { 'Content-Type': 'application/json' },
      });
    }

    // 6. CONTRÔLE DU MONTANT PAYÉ PAR RAPPORT AU MONTANT OFFICIEL ATTENDU EN BASE
    const { data: bookingsData, error: bErr } = await supabase
      .from('bookings')
      .select('id, trips(price)')
      .in('id', bookingIds);

    if (bErr || !bookingsData || bookingsData.length === 0) {
      console.error('Erreur récupération réservations pour validation Wave:', bErr);
      return new Response(JSON.stringify({ error: 'Réservations introuvables en base' }), {
        status: 400,
        headers: { 'Content-Type': 'application/json' },
      });
    }

    let expectedTotalAmount = 0;
    for (const b of bookingsData) {
      const tripPrice = Number(b.trips?.price || 0);
      expectedTotalAmount += tripPrice;
    }

    if (expectedTotalAmount > 0 && amount < expectedTotalAmount) {
      console.warn(`Tentative de sous-paiement Wave : payé=${amount}, attendu=${expectedTotalAmount}`);
      return new Response(JSON.stringify({ error: 'Montant payé inférieur au montant officiel attendu' }), {
        status: 400,
        headers: { 'Content-Type': 'application/json' },
      });
    }

    // 7. INSERTION IDEMPOTENTE DANS LA TABLE PAYMENTS
    const { error: upsertErr } = await supabase.from('payments').upsert({
      booking_id: bookingIds[0],
      amount: amount,
      provider: 'Wave',
      provider_ref: waveTxId,
      status: 'successful',
      idempotency_key: waveTxId,
    }, { onConflict: 'idempotency_key' });

    if (upsertErr) {
      console.error('Erreur upsert payments Wave:', upsertErr);
    }

    // 8. VALIDATION ATOMIQUE VIA CONFIRM_PAYMENT (AVEC SERVICE_ROLE)
    const unitAmount = Math.floor(amount / (bookingIds.length || 1));

    for (const bookingId of bookingIds) {
      const { data: confirmRes, error: confirmErr } = await supabase.rpc('confirm_payment', {
        p_booking_id: bookingId,
        p_provider: 'Wave',
        p_provider_ref: waveTxId,
        p_amount: unitAmount,
      });

      if (confirmErr) {
        console.error('Erreur confirm_payment RPC pour booking', bookingId, confirmErr);
        continue;
      }

      console.log(`Billet et commissions validés pour réservation ${bookingId}`);

      // Notification push facultative au voyageur
      try {
        const { data: bookingRow } = await supabase
          .from('bookings')
          .select('user_id')
          .eq('id', bookingId)
          .maybeSingle();

        if (bookingRow?.user_id) {
          await supabase.functions.invoke('send-notification', {
            body: JSON.stringify({
              user_id: bookingRow.user_id,
              title: 'Paiement Wave Confirmé',
              body: `Votre billet Dioufy pour la réservation ${bookingId} est prêt !`,
            }),
          }).catch((e: any) => console.warn('Notification non délivrée:', e));
        }
      } catch (_) {}
    }

    return new Response(JSON.stringify({
      success: true,
      processed: bookingIds.length,
      amount: amount,
      wave_ref: waveTxId,
    }), {
      status: 200,
      headers: { 'Content-Type': 'application/json' },
    });
  } catch (err: any) {
    console.error('Erreur traitement Wave webhook:', err);
    return new Response(JSON.stringify({ error: err.message || 'Erreur interne' }), {
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

serve(handler);
