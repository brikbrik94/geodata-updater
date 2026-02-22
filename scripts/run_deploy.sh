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

# 2. PMTiles & Metadata deployen (Kopiert von build -> tiles)
if [ -f "$SCRIPT_DIR/deploy_pmtiles.sh" ]; then
    "$SCRIPT_DIR/deploy_pmtiles.sh"
else
    log_error "deploy_pmtiles.sh nicht gefunden!"
    exit 1
fi

# 3. Stylesheets kopieren (Erstellt style.json in tiles)
# Hinweis: Das URL-Update kann hier noch fehlschlagen, da endpoints_info.json noch fehlt.
# Das ist okay, wir machen am Ende ein fixes Update.
if [ -f "$SCRIPT_DIR/deploy_stylesheets.sh" ]; then
    "$SCRIPT_DIR/deploy_stylesheets.sh"
else
    log_error "deploy_stylesheets.sh nicht gefunden!"
    exit 1
fi

# 4. Inventare erstellen (Tiles Inventory)
# (Sprites und Fonts Inventory existieren bereits durch Setup/Assets)
if [ -f "$SCRIPT_DIR/generate_tiles_inventory.sh" ]; then
    log_info "Generiere Tiles Inventory..."
    "$SCRIPT_DIR/generate_tiles_inventory.sh"
fi


# 4b. Sprite-Inventory erstellen (einmalig am Ende der Pipeline)
if [ -f "$SCRIPT_DIR/generate_sprite_inventory.sh" ]; then
    log_info "Generiere Sprite Inventory..."
    "$SCRIPT_DIR/generate_sprite_inventory.sh"
fi

# 5. Master Info generieren (Aggregiert alles)
if [ -f "$SCRIPT_DIR/generate_endpoints_info.sh" ]; then
    log_info "Generiere Endpunkt-Informationen (Master JSON)..."
    "$SCRIPT_DIR/generate_endpoints_info.sh"
fi

# 6. Stylesheets finalisieren (URLs setzen)
# Jetzt, wo endpoints_info.json da ist, können wir die Links sauber setzen.
if [ -f "$SCRIPT_DIR/update_stylesheets.sh" ]; then
    log_info "Finalisiere Stylesheets (Links setzen)..."
    "$SCRIPT_DIR/update_stylesheets.sh"
fi

log_success "Deployment vollständig abgeschlossen."
