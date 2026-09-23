/**
 * Cloudflare Worker : Reverse Proxy & Personnalisation de Domaine Supabase Auth
 * Domaine cible : auth.dioufy-ts.sn -> yrarlatdoulyfyjpqzlp.supabase.co
 * 
 * Ce script permet de :
 * 1. Masquer l'URL technique Supabase (yrarlatdoulyfyjpqzlp.supabase.co).
 * 2. Diffuser des liens de confirmation/réinitialisation de marque souveraine (auth.dioufy-ts.sn).
 * 3. Gérer les headers CORS et la sécurité SSL de bout en bout via le réseau Cloudflare.
 */

const SUPABASE_HOSTNAME = 'yrarlatdoulyfyjpqzlp.supabase.co';

export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);

    // Gérer les requêtes préliminaires CORS OPTIONS
    if (request.method === 'OPTIONS') {
      return new Response(null, {
        status: 204,
        headers: {
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Methods': 'GET, POST, PUT, PATCH, DELETE, OPTIONS',
          'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
          'Access-Control-Max-Age': '86400',
        },
      });
    }

    // Réécrire l'hôte vers Supabase
    url.hostname = SUPABASE_HOSTNAME;

    // Dupliquer les en-têtes en préservant apikey et authorization
    const forwardHeaders = new Headers(request.headers);
    forwardHeaders.set('Host', SUPABASE_HOSTNAME);
    forwardHeaders.set('X-Forwarded-Host', request.headers.get('Host') || 'auth.dioufy-ts.sn');
    forwardHeaders.set('X-Forwarded-Proto', 'https');

    const newRequest = new Request(url.toString(), {
      method: request.method,
      headers: forwardHeaders,
      body: request.body,
      redirect: 'manual', // Préserver les redirections 302 vers l'application mobile
    });

    try {
      const response = await fetch(newRequest);

      // Réécrire les en-têtes de redirection (Location) si Supabase renvoie son propre domaine
      const responseHeaders = new Headers(response.headers);
      responseHeaders.set('Access-Control-Allow-Origin', '*');

      const location = responseHeaders.get('Location');
      if (location && location.includes(SUPABASE_HOSTNAME)) {
        responseHeaders.set(
          'Location',
          location.replace(SUPABASE_HOSTNAME, request.headers.get('Host') || 'auth.dioufy-ts.sn')
        );
      }

      return new Response(response.body, {
        status: response.status,
        statusText: response.statusText,
        headers: responseHeaders,
      });
    } catch (err) {
      return new Response(JSON.stringify({ error: 'Échec de passerelle proxy Supabase', details: err.message }), {
        status: 502,
        headers: { 'Content-Type': 'application/json' },
      });
    }
  },
};
