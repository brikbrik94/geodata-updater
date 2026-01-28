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

log_header "PHASE 5: OPEN ROUTE SERVICE (ORS)"

# Ruft das eigentliche Logik-Skript auf
if [ -f "$SCRIPT_DIR/rebuild_ors_graphs.sh" ]; then
    "$SCRIPT_DIR/rebuild_ors_graphs.sh"
else
    log_error "rebuild_ors_graphs.sh nicht gefunden!"
    exit 1
fi

log_success "ORS Phase abgeschlossen."
