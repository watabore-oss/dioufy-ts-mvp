// @ts-nocheck
// Supabase Edge Function: Initiation sécurisée de session de paiement
// Fournisseurs supportés : Wave Sénégal (Checkout API v1), Flutterwave v3
// RÈGLE P0 DE L'AUDIT : Le montant est obligatoirement validé et calculé côté serveur
// depuis la base de données centrale. Aucun montant arbitraire client n'est accepté.
// Aucun faux repli simulant un paiement réussi.

import { serve } from 'https://deno.land/std@0.201.0/http/server.ts';
import { createClient } from 'https://cdn.jsdelivr.net/npm/@supabase/supabase-js/+esm';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

const WAVE_API_KEY = Deno.env.get('WAVE_API_KEY') || '';
const FLW_SECRET_KEY = Deno.env.get('FLW_SECRET') || Deno.env.get('FLW_SECRET_KEY') || '';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

const supabase = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
  auth: { persistSession: false },
});

export async function handler(req: Request): Promise<Response> {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  if (req.method !== 'POST') {
    return new Response(JSON.stringify({ error: 'Méthode non autorisée' }), {
      status: 405,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }

  try {
    const body = await req.json();
    const {
      booking_ids,
      provider = 'wave',
      customer_name = 'Voyageur Dioufy',
      customer_phone = '221774691379',
      customer_email = 'passager@dioufy.sn',
      success_url = 'https://dioufy.sn/payment/success',
      error_url = 'https://dioufy.sn/payment/cancel',
    } = body;

    // 1. Validation stricte des réservations
    if (!booking_ids || !Array.isArray(booking_ids) || booking_ids.length === 0) {
      return new Response(
        JSON.stringify({ error: 'La liste booking_ids est obligatoire et ne peut être vide.' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // Interdire tout ID local ou de démo en production
    const invalidIds = booking_ids.filter(
      (id: string) => typeof id !== 'string' || id.startsWith('local_') || id.startsWith('demo-')
    );
    if (invalidIds.length > 0) {
      return new Response(
        JSON.stringify({ error: 'Identifiants de réservation non valides. Seules les réservations réelles sont acceptées.' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // 2. Contrôle d'existence et calcul souverain du montant côté serveur
    const { data: bookings, error: bookingsErr } = await supabase
      .from('bookings')
      .select('id, status, trip_id, trips(price)')
      .in('id', booking_ids);

    if (bookingsErr || !bookings || bookings.length !== booking_ids.length) {
      return new Response(
        JSON.stringify({ error: 'Impossible de vérifier l ensemble des réservations en base.' }),
        { status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // Vérifier qu'aucune réservation n'est déjà payée ou annulée
    for (const b of bookings) {
      if (b.status === 'paid') {
        return new Response(
          JSON.stringify({ error: `La réservation ${b.id} a déjà été payée.` }),
          { status: 409, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
      }
      if (b.status === 'cancelled') {
        return new Response(
          JSON.stringify({ error: `La réservation ${b.id} a été annulée.` }),
          { status: 410, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
      }
    }

    // Calcul du montant exact en FCFA à partir des prix des trajets officiels
    let serverCalculatedAmount = 0;
    for (const b of bookings) {
      const tripPrice = b.trips?.price;
      if (typeof tripPrice !== 'number' || tripPrice <= 0) {
        return new Response(
          JSON.stringify({ error: `Tarif du trajet introuvable pour la réservation ${b.id}.` }),
          { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
      }
      serverCalculatedAmount += tripPrice;
    }

    if (serverCalculatedAmount <= 0) {
      return new Response(
        JSON.stringify({ error: 'Montant total invalide calculé par le serveur.' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // Encodage standard sans ambiguïté des booking IDs (séparateur virgule)
    const clientRef = booking_ids.join(',');
    const timestamp = Date.now();
    const txRef = `dioufy_${clientRef}_${timestamp}`;

    const normalizedProvider = provider.toLowerCase();

    // === OPTION A : Wave Sénégal (Checkout API v1) ===
    if (normalizedProvider === 'wave') {
      if (!WAVE_API_KEY) {
        return new Response(
          JSON.stringify({
            error: 'Passerelle Wave non configurée sur le serveur. Veuillez contacter le support ou choisir un autre moyen.',
          }),
          { status: 503, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
      }

      const waveRes = await fetch('https://api.wave.com/v1/checkout/sessions', {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${WAVE_API_KEY}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          amount: serverCalculatedAmount.toString(),
          currency: 'XOF',
          error_url: error_url,
          success_url: success_url,
          client_reference: clientRef,
        }),
      });

      if (!waveRes.ok) {
        const errorText = await waveRes.text();
        console.error('Erreur Wave Checkout API:', errorText);
        return new Response(
          JSON.stringify({ error: 'La passerelle Wave est momentanément indisponible.' }),
          { status: 502, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
      }

      const waveData = await waveRes.json();
      return new Response(
        JSON.stringify({
          provider: 'wave',
          checkout_url: waveData.wave_launch_url || waveData.checkout_url,
          session_id: waveData.id,
          client_reference: clientRef,
          amount: serverCalculatedAmount,
          currency: 'FCFA',
        }),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // === OPTION B : Flutterwave v3 ===
    if (normalizedProvider === 'flutterwave') {
      if (!FLW_SECRET_KEY) {
        return new Response(
          JSON.stringify({
            error: 'Passerelle Flutterwave non configurée sur le serveur.',
          }),
          { status: 503, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
      }

      const flwRes = await fetch('https://api.flutterwave.com/v3/payments', {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${FLW_SECRET_KEY}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          tx_ref: txRef,
          amount: serverCalculatedAmount.toString(),
          currency: 'XOF',
          redirect_url: success_url,
          customer: {
            name: customer_name,
            phonenumber: customer_phone,
            email: customer_email,
          },
          meta: {
            booking_ids: clientRef,
          },
          customizations: {
            title: 'Dioufy-TS',
            description: `Paiement ${booking_ids.length} place(s)`,
          },
        }),
      });

      if (!flwRes.ok) {
        const errorText = await flwRes.text();
        console.error('Erreur Flutterwave API:', errorText);
        return new Response(
          JSON.stringify({ error: 'La passerelle Flutterwave est momentanément indisponible.' }),
          { status: 502, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
      }

      const flwData = await flwRes.json();
      return new Response(
        JSON.stringify({
          provider: 'flutterwave',
          checkout_url: flwData.data?.link,
          tx_ref: txRef,
          client_reference: clientRef,
          amount: serverCalculatedAmount,
          currency: 'FCFA',
        }),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    return new Response(
      JSON.stringify({ error: `Moyen de paiement non pris en charge : ${provider}` }),
      { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  } catch (err: any) {
    console.error('Erreur interne initiation paiement:', err);
    return new Response(
      JSON.stringify({ error: err.message || 'Erreur interne du serveur' }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
}

if (import.meta.main) {
  serve(handler);
}
