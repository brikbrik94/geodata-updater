#!/bin/bash
set -euo pipefail

# 1. Utils & Config laden
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/utils.sh" ]; then 
    source "$SCRIPT_DIR/utils.sh"
else 
    echo "❌ Fehler: utils.sh nicht gefunden!"
    exit 1
fi

log_header "PHASE 4: DEPLOYMENT (Tiles, Styles, Info)"

# Parameter --force abfangen
FORCE_ARG=""
[[ "$*" == *"--force"* ]] && FORCE_ARG="--force"

# 3b. EXTERNES DEPLOYMENT (Plugins)
if [ -f "$SCRIPT_DIR/deploy_external.sh" ]; then
    "$SCRIPT_DIR/deploy_external.sh"
fi

# 4. Inventare & Master-Info generieren
# Ruft tiles, sprites, fonts und aggregate in der richtigen Reihenfolge auf.
if [ -f "$SCRIPT_DIR/run_inventory.py" ]; then
    python3 "$SCRIPT_DIR/run_inventory.py" $FORCE_ARG
else
    log_error "run_inventory.py nicht gefunden!"
    exit 1
fi

# 6. Stylesheets finalisieren (URLs setzen)
# Jetzt, wo endpoints_info.json da ist, können wir die Links sauber setzen.
if [ -f "$SCRIPT_DIR/update_stylesheets.sh" ]; then
    log_info "Finalisiere Stylesheets (Links setzen)..."
    # Der Wrapper update_stylesheets.sh ruft das .py auf
    bash "$SCRIPT_DIR/update_stylesheets.sh" $FORCE_ARG
fi

log_success "Deployment vollständig abgeschlossen."
