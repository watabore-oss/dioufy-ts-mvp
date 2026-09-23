#!/usr/bin/env bash
# ==============================================================================
# Script de Déploiement Wanekoo (Bash / Linux / Git Bash)
# ==============================================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

echo "========================================================="
echo "  🌍 DÉPLOIEMENT WANEKOO (Bash) • https://dioufy-ts.sn/  "
echo "========================================================="

cd "$PROJECT_ROOT"

# 1. Compilation
echo "ℹ️  Compilation Flutter Web release..."
flutter build web --release --base-href=/ --web-renderer=auto --pwa-strategy=offline-first

# 2. Injection .htaccess
echo "ℹ️  Injection .htaccess..."
cp "$SCRIPT_DIR/.htaccess" "$PROJECT_ROOT/build/web/.htaccess"

# 3. Création de l'archive
echo "ℹ️  Création de l'archive dioufy-ts-production.zip..."
cd "$PROJECT_ROOT/build/web"
zip -r -q "$PROJECT_ROOT/dioufy-ts-production.zip" .
cd "$PROJECT_ROOT"

echo "✅ Archive prête : $PROJECT_ROOT/dioufy-ts-production.zip"
echo "👉 Déposez cette archive dans /public_html/ sur cPanel Wanekoo et extrayez-la."
