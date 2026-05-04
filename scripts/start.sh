#!/bin/bash
set -euo pipefail

# Utils laden (lädt automatisch config.env)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/utils.sh" ]; then source "$SCRIPT_DIR/utils.sh"; else source /dev/null; fi

# --- 1. Argumente ---
for arg in "$@"; do
    case "$arg" in
        --help|-h) echo "Usage: $0"; exit 0 ;;
        *) log_error "Unbekannte Option: $arg"; exit 1 ;;
    esac
done

log_header "GEODATA PIPELINE START"

# --- 2. Die Pipeline (Run-Skripte) ---

# Phase 1: Externe Plugins aktualisieren (Downloads & Konvertierung ausgelagert)
if [ -f "$SCRIPT_DIR/run_external_updates.sh" ]; then
    "$SCRIPT_DIR/run_external_updates.sh"
fi

# Phase 2: Deployment (Tiles, Styles, Info)
"$SCRIPT_DIR/run_deploy.sh"

log_success "Gesamte Pipeline erfolgreich beendet."
