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

log_section "PHASE 5: DEPLOYMENT STYLESHEETS"

# --- KONFIGURATION ---
# Da wir alles nach /srv kopieren, definieren wir hier die Basis-Pfade
TILES_ROOT="$(realpath -m "${TILES_DIR:-/srv/tiles}")"
# Das Repo sollte laut Plan in /srv/scripts oder /srv/geodata-updater liegen
# Wir nutzen INSTALL_DIR aus der config.env als Ankerpunkt
REPO_BASE="$(dirname "$INSTALL_DIR")" 

# Quelldateien (liegen im styles-Ordner des Repos unter /srv)
OSM_STYLE_SRC="$REPO_BASE/styles/osm-style.json"
SKIMAP_STYLE_SRC="$REPO_BASE/styles/openskimap-style.json"

# Pfade zu den extrahierten Styles der VTPK-Dateien (liegen in den Build-Verzeichnissen)
# Diese werden von dort in die Tiles-Struktur kopiert
BASEMAP_STYLE_SRC="${BASEMAP_BUILD_DIR:-/srv/build/basemap-at}/tmp/styles/root.json"
CONTOURS_STYLE_SRC="${CONTOURS_BUILD_DIR:-/srv/build/overlays/contours}/styles/root.json"

log_info "Ziel-Verzeichnis: $TILES_ROOT"

# --- FUNKTION: Style-Kopie ---
deploy_style_copy() {
    local tileset_folder="$1" # z.B. "osm"
    local source_file="$2"
    local map_name="$3"       # z.B. "at"

    local target_dir="$TILES_ROOT/$tileset_folder/styles/$map_name"
    local target_file="$target_dir/style.json"

    if [ -f "$source_file" ]; then
        mkdir -p "$target_dir"
        cp -f "$source_file" "$target_file"
        chmod 644 "$target_file"
        echo "   📄 Style angelegt: $tileset_folder/styles/$map_name/style.json"
    else
        log_warn "⚠️  Quelldatei nicht gefunden: $source_file"
    fi
}

# --- HAUPTABLAUF ---

# 1. OSM: Style für jede Region kopieren
if [ -d "$TILES_ROOT/osm/pmtiles" ]; then
    for f in "$TILES_ROOT/osm/pmtiles"/*.pmtiles; do
        mapname=$(basename "$f" .pmtiles)
        deploy_style_copy "osm" "$OSM_STYLE_SRC" "$mapname"
    done
fi

# 2. Basemap.at
deploy_style_copy "basemap-at" "$BASEMAP_STYLE_SRC" "basemap-at"

# 3. Overlays: Contours
deploy_style_copy "overlays" "$CONTOURS_STYLE_SRC" "basemap-at-contours"

# 4. Overlays: OpenSkimap
deploy_style_copy "overlays" "$SKIMAP_STYLE_SRC" "openskimap"

log_success "Stylesheets erfolgreich verteilt."

# --- URL-UPDATE STARTEN (Python) ---
UPDATE_SCRIPT="$SCRIPT_DIR/update_stylesheets.sh"
if [ -f "$UPDATE_SCRIPT" ]; then
    export TILES_DIR="$TILES_ROOT"
    bash "$UPDATE_SCRIPT"
else
    log_error "update_stylesheets.sh nicht gefunden!"
    exit 1
fi
