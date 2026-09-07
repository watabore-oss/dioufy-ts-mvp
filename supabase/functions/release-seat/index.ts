// Edge Function: release-seat
// Expects JSON body: { booking_id, request_id? }
// Releases a locked seat and cancels the booking.
//
// For idempotence, provide a unique `request_id` in the body or via header `X-Request-ID`.

import { serve } from 'https://deno.land/std@0.201.0/http/server.ts';
import { createClient } from 'https://cdn.jsdelivr.net/npm/@supabase/supabase-js/+esm';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL') || '';
const SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') || '';

const supabase = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
  auth: { persistSession: false },
});

serve(async (req) => {
  try {
    if (req.method !== 'POST') {
      return new Response('Method Not Allowed', { status: 405 });
    }

    const authHeader = req.headers.get('authorization') || req.headers.get('Authorization');
    if (!authHeader || !authHeader.toLowerCase().startsWith('bearer ')) {
      return new Response(JSON.stringify({ error: 'Missing Authorization header' }), { status: 401 });
    }
    const token = authHeader.split(' ')[1];
    const userRes = await supabase.auth.getUser(token);
    const user = (userRes && (userRes as any).data && (userRes as any).data.user) ? (userRes as any).data.user : null;
    if (!user) {
      return new Response(JSON.stringify({ error: 'Invalid or expired token' }), { status: 401 });
    }

    const { booking_id, request_id: bodyRequestId } = await req.json().catch(() => ({}));
    if (!booking_id) {
      return new Response(JSON.stringify({ error: 'booking_id is required' }), { status: 400 });
    }

    const requestId = bodyRequestId || req.headers.get('X-Request-ID') || `release-${booking_id}-${Date.now()}`;

    const rpc = await supabase.rpc('release_seat', {
      p_booking_id: booking_id,
      p_request_id: requestId,
    });
    if (rpc.error) {
      return new Response(JSON.stringify({ error: rpc.error.message }), { status: 400 });
    }

    return new Response(JSON.stringify({ success: true, request_id: requestId }), {
      status: 200,
      headers: { 'Content-Type': 'application/json' },
    });
  } catch (err: any) {
    console.error('release-seat error', err);
    return new Response(JSON.stringify({ error: err?.message || 'internal' }), { status: 500 });
  }
});