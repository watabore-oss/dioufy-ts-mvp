// Edge Function to dispatch push and SMS notifications.
// Expects JSON body: { user_id, title, body }

import { serve } from 'https://deno.land/std@0.201.0/http/server.ts';
import { createClient } from 'https://cdn.jsdelivr.net/npm/@supabase/supabase-js/+esm';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL') || '';
const SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') || '';
const FCM_KEY = Deno.env.get('FCM_SERVER_KEY') || '';
const TERMII_KEY = Deno.env.get('TERMII_API_KEY') || '';

const supabase = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
  auth: { persistSession: false },
});

serve(async (req) => {
  try {
    if (req.method !== 'POST') {
      return new Response('Method Not Allowed', { status: 405 });
    }
    const { user_id, title, body } = await req.json();
    if (!user_id || !title || !body) {
      return new Response(JSON.stringify({ error: 'user_id, title and body required' }), { status: 400 });
    }
    // lookup fcm token and phone
    const { data: userData, error } = await supabase.from('app_users').select('fcm_token,phone').eq('id', user_id).single();
    if (error || !userData) {
      return new Response(JSON.stringify({ error: 'user not found' }), { status: 404 });
    }
    const token = userData.fcm_token;
    const phone = userData.phone;
    // send push
    if (token && FCM_KEY) {
      await fetch('https://fcm.googleapis.com/fcm/send', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `key=${FCM_KEY}`,
        },
        body: JSON.stringify({
          to: token,
          notification: { title, body },
        }),
      });
    }
    // send sms via Termii
    if (phone && TERMII_KEY) {
      await fetch('https://api.ng.termii.com/api/sms/send', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', apiKey: TERMII_KEY },
        body: JSON.stringify({ to: phone, message: `${title}\n${body}`, from: 'DIoufy' }),
      });
    }
    return new Response(JSON.stringify({ success: true }), { status: 200 });
  } catch (err: any) {
    console.error('send-notification error', err);
    return new Response(JSON.stringify({ error: err.message }), { status: 500 });
  }
});