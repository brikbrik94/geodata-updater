kk#!/bin/bash
set -euo pipefail

# 1. Utils & Config laden
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/utils.sh" ]; then
    source "$SCRIPT_DIR/utils.sh"
else
    echo "❌ Fehler: utils.sh nicht gefunden!"
    exit 1
fi

log_section "PHASE 4: DEPLOYMENT (PMTILES & METADATA)"

# --- KONFIGURATION ---
TILES_DIR="$(realpath -m "${TILES_DIR:-/srv/tiles}")"

# Quellen
OSM_SRC="$(realpath -m "${OSM_BUILD_DIR:-/srv/build/osm}/tmp")"
BASEMAP_SRC="$(realpath -m "${BASEMAP_BUILD_DIR:-/srv/build/basemap}/tmp")"
OVERLAYS_SRC="$(realpath -m "${OVERLAYS_BUILD_DIR:-/srv/build/overlays}/tmp")"

log_info "Deployment Ziel: $TILES_DIR"

# --- FUNKTION: Deploy Tileset ---
deploy_tileset() {
    local src_dir="$1"
    local tileset_name="$2"  # z.B. "osm"
    
    local pmtiles_dest="$TILES_DIR/$tileset_name/pmtiles"
    local tilejson_dest="$TILES_DIR/$tileset_name/tilejson"

    if [ ! -d "$src_dir" ]; then return; fi

    # A) PMTiles kopieren
    shopt -s nullglob
    local pmtiles_files=("$src_dir"/*.pmtiles)
    shopt -u nullglob

    if [ ${#pmtiles_files[@]} -gt 0 ]; then
        log_info "📂 Tileset: $tileset_name"
        mkdir -p "$pmtiles_dest"
        
        for file in "${pmtiles_files[@]}"; do
            filename=$(basename "$file")
            target="$pmtiles_dest/$filename"
            
            # Kopieren
            cp -f "$file" "$target"
            chmod 644 "$target"
            echo "   📦 PMTiles: $filename"
        done
        
        # B) Metadaten (JSON) kopieren
        # Planetiler erstellt z.B. "at.json" passend zu "at.pmtiles"
        local json_files=("$src_dir"/*.json)
        if [ ${#json_files[@]} -gt 0 ]; then
            mkdir -p "$tilejson_dest"
            for jfile in "${json_files[@]}"; do
                jname=$(basename "$jfile")
                # Filtern: Wir wollen keine temp files, nur die map infos
                # Meistens heißen sie wie die Karte (at.json)
                cp -f "$jfile" "$tilejson_dest/$jname"
                chmod 644 "$tilejson_dest/$jname"
                echo "   📄 Info:    $jname"
            done
        fi
    else
        log_info "ℹ️  Keine Daten für '$tileset_name' in $src_dir"
    fi
}

# --- HAUPTABLAUF ---
deploy_tileset "$OSM_SRC" "osm"
deploy_tileset "$BASEMAP_SRC" "basemap-at"
deploy_tileset "$OVERLAYS_SRC" "overlays"

# Info Generator aufrufen
INFO_SCRIPT="$SCRIPT_DIR/generate_endpoints_info.sh"
if [ -f "$INFO_SCRIPT" ]; then
    echo ""
    log_info "Aktualisiere Karten-Inventar..."
    bash "$INFO_SCRIPT"
fi

echo ""
log_success "Deployment abgeschlossen."
