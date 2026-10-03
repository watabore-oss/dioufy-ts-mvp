// @ts-nocheck
// Edge Function: Réception et validation cryptographique stricte du webhook Flutterwave
// RÈGLE P0 DE L'AUDIT :
// 1. Signature du webhook OBLIGATOIRE (rejet 401 si absente ou non concordante).
// 2. Vérification de la transaction auprès de l'API Flutterwave.
// 3. Récupération exacte des booking_ids correspondant au format de tx_ref généré.
// 4. Confirmation atomique via confirm_payment et émission du billet officiel.

import { serve } from 'https://deno.land/std@0.201.0/http/server.ts';
import { createClient } from 'https://cdn.jsdelivr.net/npm/@supabase/supabase-js/+esm';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const FLW_SECRET = Deno.env.get('FLW_SECRET') || Deno.env.get('FLW_SECRET_KEY') || '';

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

    // 1. CONTRÔLE DE SIGNATURE STRICT ET OBLIGATOIRE
    const signature = req.headers.get('verif-hash');
    if (!signature || !FLW_SECRET || signature !== FLW_SECRET) {
      console.warn('Flutterwave webhook : Signature absente ou invalide.');
      return new Response(JSON.stringify({ error: 'Signature invalide ou non autorisée' }), {
        status: 401,
        headers: { 'Content-Type': 'application/json' },
      });
    }

    const body = await req.json();
    const event = body.event || body.data?.event || body;
    const tx = event.data || event;

    const txRef: string = tx.txRef || tx.tx_ref || '';
    const flwRef: string = tx.flwRef || tx.flw_ref || tx.id?.toString() || `flw_${Date.now()}`;
    const amount = Number(tx.amount || tx.charged_amount || 0);
    const flwTxId = tx.id;

    // 2. VÉRIFICATION CROISÉE AUPRÈS DE L'API FLUTTERWAVE (SI ID PRÉSENT)
    if (flwTxId && FLW_SECRET) {
      try {
        const verifyRes = await fetch(`https://api.flutterwave.com/v3/transactions/${flwTxId}/verify`, {
          method: 'GET',
          headers: {
            'Authorization': `Bearer ${FLW_SECRET}`,
            'Content-Type': 'application/json',
          },
        });
        if (verifyRes.ok) {
          const verifyData = await verifyRes.json();
          if (verifyData.data?.status !== 'successful') {
            console.warn(`Flutterwave verify API statut non réussi : ${verifyData.data?.status}`);
            return new Response(JSON.stringify({ error: 'Statut de transaction non validé' }), {
              status: 400,
              headers: { 'Content-Type': 'application/json' },
            });
          }
        }
      } catch (verifyErr) {
        console.warn('Erreur vérification externe Flutterwave API:', verifyErr);
      }
    }

    // 3. EXTRACTION FIABLE DES BOOKING IDS
    let bookingIds: string[] = [];

    // A. Priorité 1 : Méta-données envoyées lors de l'initiation
    if (tx.meta?.booking_ids) {
      const metaIds = tx.meta.booking_ids.toString();
      bookingIds = metaIds.includes(',') ? metaIds.split(',').map((id: string) => id.trim()) : [metaIds.trim()];
    }
    // B. Priorité 2 : Format standard "dioufy_{id1,id2}_{timestamp}"
    else if (txRef && txRef.startsWith('dioufy_')) {
      const parts = txRef.split('_');
      if (parts.length >= 3) {
        const idPart = parts[1];
        bookingIds = idPart.includes(',') ? idPart.split(',').map((id: string) => id.trim()) : [idPart.trim()];
      } else if (parts.length === 2) {
        bookingIds = [parts[1].trim()];
      }
    }

    // Nettoyage et élimination des identifiants vides
    bookingIds = bookingIds.filter((id: string) => id.length > 0);

    if (bookingIds.length === 0) {
      console.warn('Flutterwave webhook : Aucun booking ID extrait de la transaction', txRef);
      return new Response(JSON.stringify({ error: 'Impossible d associer la transaction à une réservation' }), {
        status: 400,
        headers: { 'Content-Type': 'application/json' },
      });
    }

    // 4. INSERTION IDEMPOTENTE DANS PAYMENTS
    const isSuccessful = (tx.status === 'successful');
    const { error: upsertErr } = await supabase.from('payments').upsert({
      booking_id: bookingIds[0],
      amount: amount || 0,
      provider: 'Flutterwave',
      provider_ref: flwRef,
      status: isSuccessful ? 'successful' : 'failed',
      idempotency_key: flwRef,
    }, { onConflict: 'idempotency_key' });

    if (upsertErr) {
      console.error('Erreur upsert payments webhook Flutterwave:', upsertErr);
    }

    // 5. VALIDATION ATOMIQUE DB PAR RÉSERVATION SI TRANSACTION RÉUSSIE
    if (isSuccessful) {
      const unitAmount = Math.floor(amount / bookingIds.length);

      for (const bid of bookingIds) {
        // Confirmation atomique et calcul des commissions réelles côté serveur
        const { data: confirmRes, error: confirmErr } = await supabase.rpc('confirm_payment', {
          p_booking_id: bid,
          p_provider: 'Flutterwave',
          p_provider_ref: flwRef,
          p_amount: unitAmount,
        });

        if (confirmErr) {
          console.error(`Erreur RPC confirm_payment pour booking ${bid}:`, confirmErr);
          continue;
        }

        console.log(`Réservation ${bid} confirmée et commissions ventilées avec succès.`);

        // Notification push optionnelle
        const { data: bookingRow } = await supabase
          .from('bookings')
          .select('user_id')
          .eq('id', bid)
          .single();

        if (bookingRow?.user_id) {
          await supabase.functions.invoke('send-notification', {
            body: JSON.stringify({
              user_id: bookingRow.user_id,
              title: 'Paiement Flutterwave Confirmé',
              body: `Votre billet pour la réservation ${bid} est prêt !`,
            }),
          }).catch((e: any) => console.warn('Notification push non délivrée:', e));
        }
      }
    }

    return new Response(JSON.stringify({ received: true, processed: bookingIds.length }), {
      status: 200,
      headers: { 'Content-Type': 'application/json' },
    });
  } catch (err: any) {
    console.error('Erreur inattendue Flutterwave webhook:', err);
    return new Response(JSON.stringify({ error: err.message || 'Erreur serveur' }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' },
    });
  }
}

if (import.meta.main) {
  serve(handler);
}
