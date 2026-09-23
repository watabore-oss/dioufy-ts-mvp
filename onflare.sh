#!/usr/bin/env bash
# ==============================================================================
# Raccourci Bash pour le déploiement sur CLOUDFLARE
# ==============================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
"$SCRIPT_DIR/deploy/cloudflare/deploy-cloudflare.sh" "$@"
