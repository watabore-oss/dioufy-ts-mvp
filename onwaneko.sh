#!/usr/bin/env bash
# ==============================================================================
# Raccourci Bash pour le déploiement sur WANECO
# ==============================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
"$SCRIPT_DIR/deploy/waneko/deploy-waneko.sh" "$@"
