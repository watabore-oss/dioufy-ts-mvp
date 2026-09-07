// @ts-nocheck
import { assertEquals } from "https://deno.land/std@0.201.0/testing/asserts.ts";
import { handler } from "./index.ts";
import { createClient } from "https://cdn.jsdelivr.net/npm/@supabase/supabase-js/+esm";

// Simple integration test for the flutterwave-webhook Edge Function.
// Requires the SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY env vars and network access.

Deno.test({
  name: "webhook marks booking paid and creates ticket",
  sanitizeResources: false,
  sanitizeOps: false,
}, async () => {
  const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
  const SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
  if (!SUPABASE_URL || !SERVICE_ROLE_KEY) {
    throw new Error('SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY must be set');
  }

  const supabase = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, { auth: { persistSession: false } });

  // prepare minimal data: agency, user, trip, seat, booking
  const { data: agency, error: agencyErr } = await supabase.from('agencies').insert({ name: 'test' }).select().single();
  if (agencyErr) throw new Error('agency insert failed: ' + agencyErr.message);
  if (!agency) throw new Error('agency row not returned');

  const { data: user, error: userErr } = await supabase.from('app_users').insert({ full_name: 'Tester' }).select().single();
  if (userErr) throw new Error('user insert failed: ' + userErr.message);
  if (!user) throw new Error('user row not returned');

  const { data: trip, error: tripErr } = await supabase.from('trips')
    .insert({
      agency_id: agency.id,
      from_loc: 'X',
      to_loc: 'Y',
      depart_at: new Date().toISOString(),
      price: 1000,
      seats_count: 2,
    })
    .select()
    .single();
  if (tripErr) throw new Error('trip insert failed: ' + tripErr.message);
  if (!trip) throw new Error('trip row not returned');
  const seatNumber = 'A1';
  await supabase.from('seats').insert({ trip_id: trip!.id, seat_number: seatNumber });
  const { data: booking } = await supabase.from('bookings')
    .insert({
      user_id: user!.id,
      trip_id: trip!.id,
      seats: [seatNumber],
      status: 'pending',
      lock_expires_at: new Date().toISOString(),
    })
    .select()
    .single();

  // craft a fake Flutterwave event
  // encode booking id directly; if multiple, separate with comma
  const txRef = `dioufy_${booking!.id}_987`; // booking ID encoded
  const body = {
    event: {
      data: {
        txRef,
        flwRef: 'FLW123',
        amount: 1000,
        status: 'successful',
      },
    },
  };

  // set ticket secret for signature generation
  if (!Deno.env.get('TICKET_SECRET')) {
    Deno.env.set('TICKET_SECRET', 'test-secret');
  }
  const req = new Request('https://example.com/webhook', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  });

  const resp = await handler(req);
  const text = await resp.text();
  if (resp.status !== 200) {
    console.error('handler response', resp.status, text);
  }
  assertEquals(resp.status, 200);

  // verify side effects
  const { data: payments } = await supabase
    .from('payments')
    .select('*')
    .eq('provider_ref', 'FLW123');
  assertEquals(payments?.length, 1);
  assertEquals(payments?.[0].status, 'successful');

  const { data: updatedBooking } = await supabase
    .from('bookings')
    .select('status')
    .eq('id', booking!.id)
    .single();
  assertEquals(updatedBooking?.status, 'paid');

  const { data: tickets } = await supabase
    .from('tickets')
    .select('*')
    .eq('booking_id', booking!.id);
  assertEquals(tickets?.length, 1);

  // cleanup inserted rows
  await supabase.from('tickets').delete().eq('booking_id', booking!.id);
  await supabase.from('payments').delete().eq('provider_ref', 'FLW123');
  await supabase.from('bookings').delete().eq('id', booking!.id);
  await supabase.from('seats').delete().eq('trip_id', trip!.id);
  await supabase.from('trips').delete().eq('id', trip!.id);
  await supabase.from('agencies').delete().eq('id', agency!.id);
  await supabase.from('app_users').delete().eq('id', user!.id);
});
