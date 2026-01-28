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

# 2. PMTiles deployen (Kopiert von build -> tiles)
if [ -f "$SCRIPT_DIR/deploy_pmtiles.sh" ]; then
    "$SCRIPT_DIR/deploy_pmtiles.sh"
else
    log_error "deploy_pmtiles.sh nicht gefunden!"
    exit 1
fi

# 3. Stylesheets generieren (Erstellt style.json in tiles)
if [ -f "$SCRIPT_DIR/deploy_stylesheets.sh" ]; then
    "$SCRIPT_DIR/deploy_stylesheets.sh"
else
    log_error "deploy_stylesheets.sh nicht gefunden!"
    exit 1
fi

# 4. Endpunkt-Infos generieren (Erstellt endpoints_info.json)
if [ -f "$SCRIPT_DIR/generate_endpoints_info.sh" ]; then
    log_info "Generiere Endpunkt-Informationen..."
    "$SCRIPT_DIR/generate_endpoints_info.sh"
else
    log_warn "generate_endpoints_info.sh nicht gefunden - überspringe Info-Generierung."
fi

log_success "Deployment vollständig abgeschlossen."
