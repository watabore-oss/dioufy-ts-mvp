# dioufy-ts-mvp
MVP Dioufy-TS – Gare Numérique Sénégal – Flutter + Supabase

## Setup rapide

1. **Environnement Supabase**
   - Crée un projet Supabase et récupère `SUPABASE_URL` et `SUPABASE_SERVICE_ROLE_KEY`.
   - Ajoute dans les variables d'environnement de l'éditeur ou `--dart-define` lors du build.
   - Applique le schéma SQL (`supabase db push` ou `psql < supabase/schema.sql`).

2. **Variables sensibles**
   - `TICKET_SECRET` : secret HMAC pour signer les tickets. Utile aussi côté Flutter.
   - `FLW_SECRET` : clé de vérification des webhooks Flutterwave.
   - `EXPIRE_LOCKS_SECRET` : facultatif, protège l'appel à la fonction `expire-locks`.
   - `FCM_SERVER_KEY` : clé serveur Firebase Cloud Messaging pour push.
   - `TERMII_API_KEY` : clé Termii pour l'envoi de SMS.

3. **Installer dépendances Flutter**

   ```bash
   flutter pub get
   ```

4. **Lancer l'application**

   ```bash
   flutter run -d <device>
   ```

5. **Tests**

   ```bash
   flutter test test/ticket_service_test.dart
   # run webhook Edge Function integration test (requires Deno)
   cd supabase/functions/flutterwave-webhook
   deno test --allow-net --allow-env test.ts
   ```

## Workflow CTO & Idempotence

**Idempotence garantie:** tous les appels critiques sont idempotents (exactly-once semantics).

### Verrouillage de siège (`lock-seat`)
```bash
POST /functions/v1/lock-seat
Authorization: Bearer <token>
Content-Type: application/json

{
  "trip_id": "...",
  "seat_number": "A1",
  "lock_minutes": 10,
  "request_id": "seat-lock-123"  # optional, auto-generated if missing
}
```
- La même `request_id` retourne toujours le même `booking_id`.
- Même en cas de re-tentative, pas de doublon.

### Libération de siège (`release-seat`)
```bash
POST /functions/v1/release-seat
Authorization: Bearer <token>

{
  "booking_id": "...",
  "request_id": "seat-release-456"
}
```
- Sûr à appeler plusieurs fois : le même `request_id` réentrant n'a aucun effet.

### Webhook Flutterwave (`flutterwave-webhook`)
- Utilise `provider_ref` (clé unique Flutterwave) pour l'idempotence.
- Même webhook dupliqué → pas de paiement/ticket dupliqué.
- Déclenche notification et génère QR signé.

### Ticket & vérification offline
- QR généré avec **signature HMAC** dans le payload.
- Chauffeur scanne → vérification locale sans réseau (voir `TicketService.verify()`).

### Prochains chantiers
- Notifications push/SMS (via `send-notification` Edge Function).
- Position chauffeurs (60s, Realtime).
- Flux bagages (photo, ID, stockage).
- Dashboard Next.js + isolation par agence.

## Bonne pratique

Toujours prévoir un bouton « retour » sur chaque écran mobile. Le code respecte déjà
cette règle (voir `AppBar` sur tous les écrans).
