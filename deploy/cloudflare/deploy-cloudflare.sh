#!/usr/bin/env bash
# ==============================================================================
# Script de Déploiement Cloudflare (Bash / Linux / Git Bash)
# ==============================================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

echo "========================================================="
echo "  ⚡ DÉPLOIEMENT CLOUDFLARE (Bash) • Pages & Workers     "
echo "========================================================="

cd "$PROJECT_ROOT"

# 1. Compilation
echo "ℹ️  Compilation Flutter Web release..."
flutter build web --release --base-href=/ --web-renderer=auto --pwa-strategy=offline-first

# 2. Injection _redirects & _headers
echo "ℹ️  Injection _redirects et _headers..."
cp "$SCRIPT_DIR/_redirects" "$PROJECT_ROOT/build/web/_redirects"
cp "$SCRIPT_DIR/_headers" "$PROJECT_ROOT/build/web/_headers"

# 3. Déploiement Wrangler
echo "ℹ️  Déploiement sur Cloudflare Pages..."
npx --yes wrangler pages deploy "$PROJECT_ROOT/build/web" --project-name=dioufy-ts --branch=main --commit-dirty=true

echo "✅ Déploiement Cloudflare Pages terminé avec succès !"
