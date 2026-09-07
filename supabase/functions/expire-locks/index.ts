import { serve } from 'https://deno.land/std@0.201.0/http/server.ts';
import { createClient } from 'https://cdn.jsdelivr.net/npm/@supabase/supabase-js/+esm';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL') || '';
const SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') || '';

const supabase = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
  auth: { persistSession: false },
});

// This function can be scheduled (e.g. every minute) to clear expired locks.
serve(async (req) => {
  try {
    // optionally protect with a secret header
    const header = req.headers.get('x-invoke-secret');
    const expected = Deno.env.get('EXPIRE_LOCKS_SECRET');
    if (expected && header !== expected) {
      return new Response('Forbidden', { status: 403 });
    }

    const rpc = await supabase.rpc('expire_locks');
    if (rpc.error) {
      return new Response(JSON.stringify({ error: rpc.error.message }), { status: 500 });
    }
    return new Response(JSON.stringify({ success: true }), { headers: { 'Content-Type': 'application/json' } });
  } catch (err: any) {
    console.error('expire-locks error', err);
    return new Response(JSON.stringify({ error: err?.message || 'internal' }), { status: 500 });
  }
});