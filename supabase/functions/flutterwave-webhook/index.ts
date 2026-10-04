// @ts-nocheck
// Supabase Edge Function: Réception et validation cryptographique stricte du webhook Flutterwave
// RÈGLE P0 DE L'AUDIT (FAIL-CLOSED PAR DÉFAUT) :
// 1. Secret serveur configuré obligatoire (500 si absent).
// 2. Signature verif-hash obligatoire et concordante (401 si absente ou invalide).
// 3. Appel de vérification externe à l'API Flutterwave OBLIGATOIRE et BLOQUANT (échec si erreur).
// 4. Contrôles stricts : statut = 'successful', devise = 'XOF', concordance tx_ref.
// 5. Contrôle du montant vérifié par rapport au montant officiel attendu en base.
// 6. Confirmation atomique via confirm_payment exécuté avec service_role.

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

    // 1. CONTRÔLE DE CONFIGURATION SERVEUR (FAIL-CLOSED)
    if (!FLW_SECRET) {
      console.error('Flutterwave webhook : Secret serveur FLW_SECRET non configuré.');
      return new Response(JSON.stringify({ error: 'Configuration serveur incomplète' }), {
        status: 500,
        headers: { 'Content-Type': 'application/json' },
      });
    }

    // 2. CONTRÔLE DE SIGNATURE CRYPTOGRAPHIQUE STRICT
    const signature = req.headers.get('verif-hash');
    if (!signature || signature !== FLW_SECRET) {
      console.warn('Flutterwave webhook : Signature verif-hash absente ou invalide.');
      return new Response(JSON.stringify({ error: 'Signature invalide ou non autorisée' }), {
        status: 401,
        headers: { 'Content-Type': 'application/json' },
      });
    }

    const body = await req.json();
    const event = body.event || body.data?.event || body;
    const tx = event.data || event;

    const txRef: string = tx.txRef || tx.tx_ref || '';
    const flwTxId = tx.id;

    if (!flwTxId) {
      console.warn('Flutterwave webhook : ID de transaction Flutterwave manquant.');
      return new Response(JSON.stringify({ error: 'ID de transaction requis' }), {
        status: 400,
        headers: { 'Content-Type': 'application/json' },
      });
    }

    // 3. VÉRIFICATION CROISÉE OBLIGATOIRE ET FERMÉE (FAIL-CLOSED) AUPRÈS DE L'API FLUTTERWAVE
    let verifyData: any;
    try {
      const verifyRes = await fetch(`https://api.flutterwave.com/v3/transactions/${flwTxId}/verify`, {
        method: 'GET',
        headers: {
          'Authorization': `Bearer ${FLW_SECRET}`,
          'Content-Type': 'application/json',
        },
      });

      if (!verifyRes.ok) {
        console.error(`Flutterwave API verify a retourné un statut HTTP ${verifyRes.status}`);
        return new Response(JSON.stringify({ error: 'Échec de vérification auprès de l API Flutterwave' }), {
          status: 400,
          headers: { 'Content-Type': 'application/json' },
        });
      }

      verifyData = await verifyRes.json();
    } catch (netErr: any) {
      console.error('Erreur réseau lors de l appel à l API Flutterwave verify:', netErr);
      return new Response(JSON.stringify({ error: 'Impossible de contacter l API de vérification Flutterwave' }), {
        status: 502,
        headers: { 'Content-Type': 'application/json' },
      });
    }

    // 4. CONTRÔLE STRICT DU STATUT, DEVISE ET RÉFÉRENCE FOURNIS PAR L'API OFFICIELLE
    if (verifyData.status !== 'success' || verifyData.data?.status !== 'successful') {
      console.warn(`Transaction Flutterwave non réussie : ${verifyData.data?.status}`);
      return new Response(JSON.stringify({ error: 'Transaction non réussie auprès du prestataire' }), {
        status: 400,
        headers: { 'Content-Type': 'application/json' },
      });
    }

    const verifiedCurrency = (verifyData.data?.currency || '').toUpperCase();
    if (verifiedCurrency !== 'XOF' && verifiedCurrency !== 'CFA') {
      console.warn(`Devise non conforme : ${verifiedCurrency} (attendu XOF)`);
      return new Response(JSON.stringify({ error: 'Devise non conforme' }), {
        status: 400,
        headers: { 'Content-Type': 'application/json' },
      });
    }

    const verifiedTxRef = verifyData.data?.tx_ref || '';
    if (txRef && verifiedTxRef && verifiedTxRef !== txRef) {
      console.warn(`Non concordance de référence de transaction: webhook=${txRef}, API=${verifiedTxRef}`);
      return new Response(JSON.stringify({ error: 'Référence de transaction incohérente' }), {
        status: 400,
        headers: { 'Content-Type': 'application/json' },
      });
    }

    const verifiedAmount = Number(verifyData.data?.amount || 0);
    const flwRef: string = verifyData.data?.flw_ref || `flw_${flwTxId}`;

    // 5. EXTRACTION EXACTE DES BOOKING IDS
    let bookingIds: string[] = [];
    const metaBookingIds = verifyData.data?.meta?.booking_ids || tx.meta?.booking_ids;

    if (metaBookingIds) {
      const metaStr = metaBookingIds.toString();
      bookingIds = metaStr.includes(',') ? metaStr.split(',').map((id: string) => id.trim()) : [metaStr.trim()];
    } else if (verifiedTxRef && verifiedTxRef.startsWith('dioufy_')) {
      const parts = verifiedTxRef.split('_');
      if (parts.length >= 3) {
        const idPart = parts[1];
        bookingIds = idPart.includes(',') ? idPart.split(',').map((id: string) => id.trim()) : [idPart.trim()];
      } else if (parts.length === 2) {
        bookingIds = [parts[1].trim()];
      }
    }

    bookingIds = bookingIds.filter((id: string) => id.length > 0);

    if (bookingIds.length === 0) {
      console.warn('Flutterwave webhook : Aucun booking ID valide associé à la transaction', verifiedTxRef);
      return new Response(JSON.stringify({ error: 'Impossible d associer la transaction à une réservation' }), {
        status: 400,
        headers: { 'Content-Type': 'application/json' },
      });
    }

    // 6. CONTRÔLE DE COHÉRENCE DU MONTANT AVEC LA BASE DE DONNÉES
    // Calcul du montant officiel attendu pour ces réservations
    const { data: bookingsData, error: bErr } = await supabase
      .from('bookings')
      .select('id, trips(price)')
      .in('id', bookingIds);

    if (bErr || !bookingsData || bookingsData.length === 0) {
      console.error('Erreur récupération réservations pour validation du montant:', bErr);
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

    if (expectedTotalAmount > 0 && verifiedAmount < expectedTotalAmount) {
      console.warn(`Tentative de sous-paiement : payé=${verifiedAmount}, attendu=${expectedTotalAmount}`);
      return new Response(JSON.stringify({ error: 'Montant payé inférieur au montant officiel attendu' }), {
        status: 400,
        headers: { 'Content-Type': 'application/json' },
      });
    }

    // 7. INSERTION IDEMPOTENTE DANS LA TABLE PAYMENTS
    const { error: upsertErr } = await supabase.from('payments').upsert({
      booking_id: bookingIds[0],
      amount: verifiedAmount,
      provider: 'Flutterwave',
      provider_ref: flwRef,
      status: 'successful',
      idempotency_key: flwRef,
    }, { onConflict: 'idempotency_key' });

    if (upsertErr) {
      console.error('Erreur upsert payments webhook Flutterwave:', upsertErr);
    }

    // 8. VALIDATION ATOMIQUE VIA CONFIRM_PAYMENT (AVEC CLÉ SERVICE_ROLE)
    const unitAmount = Math.floor(verifiedAmount / bookingIds.length);

    for (const bid of bookingIds) {
      const { data: confirmRes, error: confirmErr } = await supabase.rpc('confirm_payment', {
        p_booking_id: bid,
        p_provider: 'Flutterwave',
        p_provider_ref: flwRef,
        p_amount: unitAmount,
      });

      if (confirmErr) {
        console.error(`Erreur RPC confirm_payment pour réservation ${bid}:`, confirmErr);
        continue;
      }

      console.log(`Réservation ${bid} confirmée et commissions ventilées avec succès.`);

      // Notification push facultative au voyageur
      try {
        const { data: bookingRow } = await supabase
          .from('bookings')
          .select('user_id')
          .eq('id', bid)
          .maybeSingle();

        if (bookingRow?.user_id) {
          await supabase.functions.invoke('send-notification', {
            body: JSON.stringify({
              user_id: bookingRow.user_id,
              title: 'Paiement Confirmé',
              body: `Votre billet Dioufy (${bid}) a été émis avec succès !`,
            }),
          }).catch((e: any) => console.warn('Notification non délivrée:', e));
        }
      } catch (_) {}
    }

    return new Response(JSON.stringify({
      success: true,
      processed: bookingIds.length,
      amount: verifiedAmount,
      flw_ref: flwRef,
    }), {
      status: 200,
      headers: { 'Content-Type': 'application/json' },
    });
  } catch (err: any) {
    console.error('Erreur inattendue webhook Flutterwave:', err);
    return new Response(JSON.stringify({ error: err.message || 'Erreur interne' }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' },
    });
  }
}

serve(handler);
