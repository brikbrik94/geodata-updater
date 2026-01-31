#!/bin/bash
set -euo pipefail

# 1. Utils laden
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/utils.sh" ]; then
    source "$SCRIPT_DIR/utils.sh"
else
    echo "❌ Fehler: utils.sh nicht gefunden!"
    exit 1
fi

log_section "PHASE 5: DEPLOYMENT STYLESHEETS (Copy Only)"

# --- KONFIGURATION ---
TILES_ROOT="$(realpath -m "${TILES_DIR:-/srv/tiles}")"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

# Pfade zu den Build-Ordnern
BASEMAP_BUILD="$(realpath -m "${BASEMAP_BUILD_DIR:-/srv/build/basemap}")"
OVERLAYS_BUILD="$(realpath -m "${OVERLAYS_BUILD_DIR:-/srv/build/overlays}")"

# --- QUELLEN DEFINIEREN ---

# 1. OSM: Template aus dem Git-Repo
# KORREKTUR: Pfad angepasst auf styles/style.json (statt conf/styles/...)
STYLE_SRC_OSM="${STYLE_TEMPLATE:-$REPO_ROOT/styles/style.json}"

# 2. BASEMAP: root.json aus dem Build-Ordner
STYLE_SRC_BASEMAP="$BASEMAP_BUILD/tmp/styles/root.json"

# 3. OVERLAYS: root.json aus dem Build-Ordner
# Wir suchen dynamisch nach der ersten root.json im tmp-Ordner
STYLE_SRC_OVERLAYS=$(find "$OVERLAYS_BUILD/tmp" -name "root.json" | head -n 1)

log_info "Ziel Basis: $TILES_ROOT"

# --- FUNKTION ---
deploy_style_copy() {
    local tileset_name="$1"   # z.B. "osm"
    local source_style="$2"   # Pfad zur Quell-Datei

    local pmtiles_dir="$TILES_ROOT/$tileset_name/pmtiles"
    local styles_root="$TILES_ROOT/$tileset_name/styles"

    # Validierung
    if [ -z "$source_style" ] || [ ! -f "$source_style" ]; then
        if [ -d "$pmtiles_dir" ] && [ "$(ls -A "$pmtiles_dir" 2>/dev/null)" ]; then
            log_warn "⚠️  Kein Style-Template für '$tileset_name' gefunden."
            log_info "   (Gesucht: $source_style)"
        fi
        return
    fi

    if [ ! -d "$pmtiles_dir" ]; then return; fi

    # Alle deployten PMTiles finden
    shopt -s nullglob
    local files=("$pmtiles_dir"/*.pmtiles)
    shopt -u nullglob

    if [ ${#files[@]} -gt 0 ]; then
        log_info "Verarbeite Tileset: $tileset_name"
        log_info "   Quelle: $source_style"
        
        for pmtiles_path in "${files[@]}"; do
            filename=$(basename "$pmtiles_path")       # z.B. "at-plus.pmtiles"
            mapname="${filename%.*}"                   # z.B. "at-plus"
            
            target_dir="$styles_root/$mapname"
            target_file="$target_dir/style.json"
            
            # 1. Ordner erstellen
            mkdir -p "$target_dir"
            
            # 2. Kopieren (Überschreiben)
            cp -f "$source_style" "$target_file"
            chmod 644 "$target_file"
            
            echo "   📄 Style angelegt: $tileset_name/styles/$mapname/style.json"
        done
    else
        log_info "ℹ️  Keine PMTiles in '$tileset_name' gefunden."
    fi
}

# --- HAUPTABLAUF ---

# 1. OSM
deploy_style_copy "osm" "$STYLE_SRC_OSM"

# 2. Basemap
deploy_style_copy "basemap-at" "$STYLE_SRC_BASEMAP"

# 3. Overlays
deploy_style_copy "overlays" "$STYLE_SRC_OVERLAYS"

log_success "Stylesheets kopiert."
log_info "Starte nun update_stylesheets.sh für URL-Anpassungen..."

# --- LINK-UPDATE STARTEN ---
UPDATE_SCRIPT="$SCRIPT_DIR/update_stylesheets.sh"
if [ -f "$UPDATE_SCRIPT" ]; then
    # Wir übergeben TILES_DIR explizit, falls es im Env fehlt
    export TILES_DIR="$TILES_ROOT"
    
    # NEU: Wir helfen dem Python-Skript bei Mehrdeutigkeiten (at vs at-plus)
    # Das Mapping hilft, wenn mehrere PMTiles im Ordner liegen.
    # Wir bauen das dynamisch auf für OSM:
    # "osm:at.pmtiles osm:at-plus.pmtiles" <- Das Python Skript scheint das Format tileset:file zu erwarten
    # Aber das Python Skript ist global. Wir lassen es erstmal laufen.
    
    bash "$UPDATE_SCRIPT"
else
    log_error "update_stylesheets.sh nicht gefunden!"
    exit 1
fi
