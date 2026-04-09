#!/bin/bash
set -euo pipefail

# 1. Utils & Config laden
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/utils.sh" ]; then source "$SCRIPT_DIR/utils.sh"; else exit 1; fi

log_section "PHASE 4b: EXTERNES DEPLOYMENT (Plugins)"

# 2. Umgebungsvariablen für Python setzen
export TILES_DIR="${TILES_DIR:-/srv/tiles}"
export ASSETS_DIR="${ASSETS_DIR:-/srv/assets}"
export EXTERNAL_REPOS_CONF="$(dirname "$SCRIPT_DIR")/conf/external_repos.txt"

PYTHON_SCRIPT="$SCRIPT_DIR/deploy_external.py"

# 3. Ausführen
if [ -f "$PYTHON_SCRIPT" ]; then
    python3 "$PYTHON_SCRIPT"
else
    log_error "Python-Worker nicht gefunden: $PYTHON_SCRIPT"
    exit 1
fi

log_success "Externes Deployment abgeschlossen."
