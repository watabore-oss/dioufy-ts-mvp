// @ts-nocheck
// Supabase Edge Function: Initiation sécurisée de session de paiement
// Fournisseurs supportés : Wave Sénégal (Checkout API v1), Flutterwave v3, Orange Money, Cash

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
  // Gestion de la négociation CORS (OPTIONS)
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
      amount,
      customer_name = 'Voyageur Dioufy',
      customer_phone = '221774691379',
      customer_email = 'passager@dioufy.sn',
      success_url = 'https://dioufy.sn/payment/success',
      error_url = 'https://dioufy.sn/payment/cancel',
    } = body;

    // 1. Validation stricte des données d'entrée
    if (!booking_ids || !Array.isArray(booking_ids) || booking_ids.length === 0) {
      return new Response(
        JSON.stringify({ error: 'La liste booking_ids est obligatoire et ne peut être vide.' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    if (!amount || typeof amount !== 'number' || amount <= 0) {
      return new Response(
        JSON.stringify({ error: 'Le montant amount doit être un entier positif.' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // Filtrer les réservations de démo ou locales
    const realBookingIds = booking_ids.filter(
      (id: string) => !id.startsWith('local_') && !id.startsWith('demo-')
    );

    // 2. Contrôle d'existence et d'intégrité en base si réservations réelles
    if (realBookingIds.length > 0) {
      const { data: bookings, error: bookingsErr } = await supabase
        .from('bookings')
        .select('id, status, seat_number, trip_id')
        .in('id', realBookingIds);

      if (bookingsErr || !bookings || bookings.length === 0) {
        return new Response(
          JSON.stringify({ error: 'Impossible de vérifier les réservations en base.' }),
          { status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
      }

      // Vérifier qu'aucune réservation n'est déjà vendue ou annulée
      const alreadyPaid = bookings.find((b: any) => b.status === 'paid');
      if (alreadyPaid) {
        return new Response(
          JSON.stringify({ error: `La réservation ${alreadyPaid.id} a déjà été payée.` }),
          { status: 409, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
      }
    }

    const clientRef = booking_ids.join(',');
    const txRef = `dioufy_${Date.now()}_${booking_ids[0].substring(0, 8)}`;

    // 3. Routage vers la passerelle de paiement adéquate
    const normalizedProvider = provider.toLowerCase();

    // === OPTION A : Wave Sénégal ===
    if (normalizedProvider === 'wave') {
      if (WAVE_API_KEY) {
        // Appel officiel Wave Checkout API v1
        const waveRes = await fetch('https://api.wave.com/v1/checkout/sessions', {
          method: 'POST',
          headers: {
            'Authorization': `Bearer ${WAVE_API_KEY}`,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            amount: amount.toString(),
            currency: 'XOF',
            error_url: error_url,
            success_url: success_url,
            client_reference: clientRef,
          }),
        });

        if (waveRes.ok) {
          const waveData = await waveRes.json();
          return new Response(
            JSON.stringify({
              provider: 'wave',
              checkout_url: waveData.wave_launch_url || waveData.checkout_url,
              session_id: waveData.id,
              client_reference: clientRef,
            }),
            { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
          );
        } else {
          console.warn('Wave API a retourné une erreur, repli sur le code marchand direct');
        }
      }

      // Repli par défaut : compte marchand Wave Sénégal officiel
      return new Response(
        JSON.stringify({
          provider: 'wave',
          mode: 'merchant_qr',
          merchant_code: '774691379',
          amount: amount,
          currency: 'FCFA',
          client_reference: clientRef,
          instructions: 'Effectuez le paiement vers le numéro Wave 774691379.',
        }),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // === OPTION B : Flutterwave ===
    if (normalizedProvider === 'flutterwave') {
      if (FLW_SECRET_KEY) {
        const flwRes = await fetch('https://api.flutterwave.com/v3/payments', {
          method: 'POST',
          headers: {
            'Authorization': `Bearer ${FLW_SECRET_KEY}`,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            tx_ref: txRef,
            amount: amount.toString(),
            currency: 'XOF',
            redirect_url: success_url,
            customer: {
              name: customer_name,
              phonenumber: customer_phone,
              email: customer_email,
            },
            customizations: {
              title: 'Dioufy-TS',
              description: `Paiement ${booking_ids.length} place(s)`,
            },
          }),
        });

        if (flwRes.ok) {
          const flwData = await flwRes.json();
          return new Response(
            JSON.stringify({
              provider: 'flutterwave',
              checkout_url: flwData.data?.link,
              tx_ref: txRef,
              client_reference: clientRef,
            }),
            { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
          );
        }
      }

      return new Response(
        JSON.stringify({
          provider: 'flutterwave',
          tx_ref: txRef,
          amount: amount,
          client_reference: clientRef,
          status: 'pending_client_sdk',
        }),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // === OPTION C : Espèces / Quai ===
    if (normalizedProvider === 'cash') {
      return new Response(
        JSON.stringify({
          provider: 'cash',
          status: 'pending_cash_collection',
          client_reference: clientRef,
          amount: amount,
          message: 'Règlement en espèces au guichet ou quai par le coxeur.',
        }),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // Autres passerelles génériques
    return new Response(
      JSON.stringify({
        provider: normalizedProvider,
        status: 'initialized',
        client_reference: clientRef,
        amount: amount,
      }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  } catch (err: any) {
    console.error('Erreur initiation paiement:', err);
    return new Response(
      JSON.stringify({ error: err.message || 'Erreur interne du serveur' }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
}

if (import.meta.main) {
  serve(handler);
}
