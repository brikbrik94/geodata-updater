#!/bin/bash
set -euo pipefail

# Utils laden (lädt automatisch config.env)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/utils.sh" ]; then source "$SCRIPT_DIR/utils.sh"; else source /dev/null; fi

# --- 1. Argumente & Interaktion ---
REBUILD_ORS=0

for arg in "$@"; do
    case "$arg" in
        --rebuild-ors|-o) REBUILD_ORS=1 ;;
        --help|-h) echo "Usage: $0 [--rebuild-ors|-o]"; exit 0 ;;
        *) log_error "Unbekannte Option: $arg"; exit 1 ;;
    esac
done

log_header "GEODATA PIPELINE START"

if [ "$REBUILD_ORS" -eq 0 ] && [ -t 0 ]; then
    echo "Soll der OpenRouteService (ORS) Graph nach dem Update neu gebaut werden?"
    read -r -p "ORS Rebuild starten? (y/N): " reply
    case "$reply" in
        [yY]|[yY][eE][sS]) REBUILD_ORS=1 ;;
    esac
fi

# --- 2. Die Pipeline (Run-Skripte) ---

# Phase 1: Download
"$SCRIPT_DIR/run_download.sh"

# Phase 2: Merge
"$SCRIPT_DIR/run_merge.sh"

# Phase 3: Konvertierung
"$SCRIPT_DIR/run_pmtiles.sh"

# Phase 4: Deployment (Neuer Name!)
"$SCRIPT_DIR/run_deploy.sh"

# Phase 5: ORS (Optional)
if [ "$REBUILD_ORS" -eq 1 ]; then
    "$SCRIPT_DIR/run_ors.sh"
else
    log_info "ORS Rebuild übersprungen."
fi

log_success "Gesamte Pipeline erfolgreich beendet."
