# Dioufy-TS MVP

MVP Flutter de **gare numérique au Sénégal** : recherche de trajets interurbains, comparaison d'opérateurs, pré-réservation avec QR code et base Supabase prête à connecter.

## Fonctionnalités livrées

- Écran d'accueil avec recherche départ/destination et carte du Sénégal.
- Résultats de trajets filtrés sur des données de démonstration locales.
- Cartes trajet avec opérateur, horaires, durée, gare, type de véhicule, places et prix.
- Parcours de pré-réservation générant une référence et un QR code.
- Configuration Supabase par `--dart-define` sans secrets codés en dur.
- Schéma SQL MVP pour profils, trajets, sièges et réservations.

## Configuration Supabase

Le projet Supabase de développement est configuré sur :

- URL publique : `https://orfgrbxltlycjtmtrsvl.supabase.co`
- Région effective : `eu-central-1`

Copie `.env.example` vers `.env.local` ou passe les valeurs avec `--dart-define`. Ne commit jamais le mot de passe Postgres, la `secret key` Supabase ou une clé de service.

## Lancer l'application

```bash
flutter pub get
flutter run \
  --dart-define=SUPABASE_URL=https://orfgrbxltlycjtmtrsvl.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<anon-or-publishable-key>
```

Les variables Supabase sont optionnelles en développement : sans valeurs réelles, l'application démarre en mode données locales.

## Structure

```text
lib/
  core/                 # thème et configuration
  data/                 # modèles + données de démonstration
  features/
    home/               # recherche initiale
    search/             # liste des trajets
    booking/            # confirmation + QR code
supabase/schema.sql     # schéma MVP
```

## Prochaines étapes

1. Brancher `searchTrips` sur Supabase avec pagination et filtres de date.
2. Ajouter authentification passager et espace opérateur.
3. Intégrer Mobile Money via Flutterwave et webhook serveur.
4. Remplacer le QR code local par une réservation persistée et vérifiable.
