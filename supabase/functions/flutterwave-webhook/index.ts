// @ts-nocheck
// Edge Function to handle Flutterwave webhook events and update bookings/payments.
// For MVP we parse txRef to recover booking IDs and mark them paid.

import { serve } from 'https://deno.land/std@0.201.0/http/server.ts';
import { createClient } from 'https://cdn.jsdelivr.net/npm/@supabase/supabase-js/+esm';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const FLW_SECRET = Deno.env.get('FLW_SECRET') || ''; // used for signature verification

const supabase = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
  auth: { persistSession: false },
});

export async function handler(req: Request): Promise<Response> {
  try {
    if (req.method !== 'POST') {
      return new Response('Method Not Allowed', { status: 405 });
    }
    
    const body = await req.json();
    // optionally verify signature
    const signature = req.headers.get('verif-hash');
    if (signature && FLW_SECRET) {
      // compute hash of body with secret and compare
      const encoder = new TextEncoder();
      const data = encoder.encode(FLW_SECRET + JSON.stringify(body));
      const hashBuffer = await crypto.subtle.digest('SHA-512', data);
      const hashArray = Array.from(new Uint8Array(hashBuffer));
      const computed = hashArray.map(b => b.toString(16).padStart(2, '0')).join('');
      if (computed !== signature) {
        console.warn('flutterwave signature mismatch');
        return new Response(JSON.stringify({ error: 'Invalid signature' }), { status: 400 });
      }
    }

    const event = body.event || body.data?.event || body;
    // determine success
    const tx = event.data || event;
    const txRef: string = tx.txRef || tx.data?.txRef;
    const flwRef: string = tx.flwRef || tx.data?.flwRef;
    const amount = tx.amount || tx.data?.amount;

    // parse booking IDs encoded in txRef; expectation: 'dioufy_{booking1}-{booking2}_timestamp'
    let bookingIds: string[] = [];
    if (txRef) {
      const parts = txRef.split('_');
      if (parts.length >= 2) {
        const idPart = parts[1];
        // allow comma-separated list of ids; do not split on hyphen because UUIDs contain them
        bookingIds = idPart.includes(',') ? idPart.split(',') : [idPart];
      }
    }

    // Insert payment record if not exists (idempotency by provider_ref)
    const { error: insertErr } = await supabase.from('payments').upsert({
      booking_id: bookingIds[0] || null,
      amount: amount || null,
      provider: 'flutterwave',
      provider_ref: flwRef,
      status: tx.status === 'successful' ? 'successful' : 'failed',
      idempotency_key: flwRef,
    }, { onConflict: ['provider_ref'] });

    if (insertErr) {
      console.error('payment upsert error', insertErr);
    }

    if (tx.status === 'successful') {
      // mark bookings as paid
      for (const bid of bookingIds) {
        await supabase.from('bookings').update({ status: 'paid' }).eq('id', bid);
        // generate ticket
        const ticketPayload = { booking_id: bid, issued: new Date().toISOString() };
        const signature = await generateTicketSignature(ticketPayload);
        await supabase.from('tickets').insert({ booking_id: bid, payload: ticketPayload, signature });
        // fire notification to customer
        // retrieve user_id from booking row
        const { data: bookingRow } = await supabase
          .from('bookings')
          .select('user_id')
          .eq('id', bid)
          .single();
        const userId = bookingRow?.user_id;
        if (userId) {
          await supabase.functions.invoke('send-notification', {
            body: JSON.stringify({
              user_id: userId,
              title: 'Paiement reçu',
              body: `Votre réservation ${bid} est confirmée`,
            }),
          });
        }
      }
    }

    return new Response(JSON.stringify({ received: true }), { status: 200 });
  } catch (err: any) {
    console.error('webhook error', err);
    return new Response(JSON.stringify({ error: err.message }), { status: 500 });
  }
}

// start server if run directly
if (import.meta.main) {
  serve(handler);
}

// helper to create simple HMAC signature for ticket payload
async function generateTicketSignature(payload: any): Promise<string> {
  const secret = Deno.env.get('TICKET_SECRET') || '';
  if (!secret) {
    throw new Error('TICKET_SECRET not configured');
  }
  const msg = new TextEncoder().encode(JSON.stringify(payload));
  const key = await crypto.subtle.importKey('raw', new TextEncoder().encode(secret), { name: 'HMAC', hash: 'SHA-256' }, false, ['sign']);
  const sig = await crypto.subtle.sign('HMAC', key, msg);
  const arr = Array.from(new Uint8Array(sig));
  return arr.map(b => b.toString(16).padStart(2, '0')).join('');
}
