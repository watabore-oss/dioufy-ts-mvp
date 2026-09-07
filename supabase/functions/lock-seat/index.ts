// Supabase Edge Function: lock-seat
// Expects JSON body: { trip_id, seat_number, lock_minutes, request_id? }
// Calls DB RPC `lock_seat` to atomically create booking and lock a seat.
// 
// For idempotence, provide a unique `request_id` in the body or via header `X-Request-ID`.
// The same request_id will always return the same booking_id, even if called multiple times.

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

    // parse body
    const body = await req.json().catch(() => ({}));
    const { trip_id, seat_number, lock_minutes, request_id: bodyRequestId } = body as Record<string, any>;

    if (!trip_id || !seat_number) {
      return new Response(JSON.stringify({ error: 'trip_id and seat_number are required' }), { status: 400 });
    }

    // Authenticate request: require Authorization: Bearer <access_token>
    const authHeader = req.headers.get('authorization') || req.headers.get('Authorization');
    if (!authHeader || !authHeader.toLowerCase().startsWith('bearer ')) {
      return new Response(JSON.stringify({ error: 'Missing Authorization header' }), { status: 401 });
    }
    const token = authHeader.split(' ')[1];

    // Validate token via Supabase Auth (service role key allows verifying arbitrary tokens)
    const userRes = await supabase.auth.getUser(token);
    const user = (userRes && (userRes as any).data && (userRes as any).data.user) ? (userRes as any).data.user : null;
    if (!user) {
      return new Response(JSON.stringify({ error: 'Invalid or expired token' }), { status: 401 });
    }

    const user_id = user.id as string;
    const minutes = lock_minutes ? Number(lock_minutes) : 10;
    
    // Extract or generate request_id for idempotence
    const requestId = bodyRequestId || req.headers.get('X-Request-ID') || `lock-${user_id}-${Date.now()}`;

    const rpcRes = await supabase.rpc('lock_seat', {
      p_trip_id: trip_id,
      p_seat_number: seat_number,
      p_user_id: user_id,
      p_lock_minutes: minutes,
      p_request_id: requestId,
    });

    if (rpcRes.error) {
      // handle DB exception messages
      return new Response(JSON.stringify({ error: rpcRes.error.message }), { status: 400 });
    }

    const bookingId = rpcRes.data as string | null;
    return new Response(JSON.stringify({ booking_id: bookingId, request_id: requestId }), {
      status: 200,
      headers: { 'Content-Type': 'application/json' },
    });
  } catch (err: any) {
    console.error('lock-seat error', err);
    return new Response(JSON.stringify({ error: err?.message || 'internal' }), { status: 500 });
  }
});
