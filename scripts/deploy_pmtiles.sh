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

log_section "PHASE 4: DEPLOYMENT (PMTILES & METADATA)"

# --- KONFIGURATION ---
TILES_DIR="$(realpath -m "${TILES_DIR:-/srv/tiles}")"

# Quellen (Synchronisiert mit config.env)
OSM_SRC="$(realpath -m "${OSM_BUILD_DIR:-/srv/build/osm}/tmp")"
BASEMAP_SRC="$(realpath -m "${BASEMAP_BUILD_DIR:-/srv/build/basemap-at}/tmp")"

log_info "Deployment Ziel: $TILES_DIR"

# --- FUNKTION: Deploy Tileset ---
deploy_tileset() {
    local src_dir="$1"
    local tileset_name="$2"  # z.B. "osm"

    local pmtiles_dest="$TILES_DIR/$tileset_name/pmtiles"
    local tilejson_dest="$TILES_DIR/$tileset_name/tilejson"

    if [ ! -d "$src_dir" ]; then 
        log_warn "Quellverzeichnis nicht gefunden: $src_dir"
        return
    fi

    # A) PMTiles kopieren
    shopt -s nullglob
    local pmtiles_files=("$src_dir"/*.pmtiles)
    shopt -u nullglob

    if [ ${#pmtiles_files[@]} -gt 0 ]; then
        log_info "📂 Verarbeite Tileset: $tileset_name"
        mkdir -p "$pmtiles_dest"

        for file in "${pmtiles_files[@]}"; do
            filename=$(basename "$file")
            target="$pmtiles_dest/$filename"

            cp -f "$file" "$target"
            chmod 644 "$target"
            echo "   📦 PMTiles: $filename"
        done

        # B) Metadaten (JSON) kopieren (z.B. at.json von Planetiler)
        shopt -s nullglob
        local json_files=("$src_dir"/*.json)
        shopt -u nullglob
        
        if [ ${#json_files[@]} -gt 0 ]; then
            mkdir -p "$tilejson_dest"
            for jfile in "${json_files[@]}"; do
                jname=$(basename "$jfile")
                cp -f "$jfile" "$tilejson_dest/$jname"
                chmod 644 "$tilejson_dest/$jname"
                echo "   📄 Info:    $jname"
            done
        fi
    fi
}

# --- HAUPTABLAUF ---

# 1. OSM & Basemap (Standard-Struktur)
deploy_tileset "$OSM_SRC" "osm"
deploy_tileset "$BASEMAP_SRC" "basemap-at"

# 2. OVERLAYS (Manuelle Pfade, da Dateien direkt im BUILD_DIR liegen)
log_info "📂 Verarbeite Overlays..."
mkdir -p "$TILES_DIR/overlays/pmtiles"
mkdir -p "$TILES_DIR/overlays/tilejson"

# Contours
if [ -f "$BUILD_DIR/basemap-at-contours.pmtiles" ]; then
    cp -f "$BUILD_DIR/basemap-at-contours.pmtiles" "$TILES_DIR/overlays/pmtiles/"
    chmod 644 "$TILES_DIR/overlays/pmtiles/basemap-at-contours.pmtiles"
    echo "   📦 PMTiles: basemap-at-contours.pmtiles"
    
    # Metadaten-JSON für Contours (falls generiert)
    CONTOURS_JSON="${CONTOURS_BUILD_DIR:-/srv/build/overlays/contours}/basemap-at-contours.json"
    if [ -f "$CONTOURS_JSON" ]; then
        cp -f "$CONTOURS_JSON" "$TILES_DIR/overlays/tilejson/"
        echo "   📄 Info:    basemap-at-contours.json"
    fi
fi

# OpenSkimap
if [ -f "$BUILD_DIR/openskimap.pmtiles" ]; then
    cp -f "$BUILD_DIR/openskimap.pmtiles" "$TILES_DIR/overlays/pmtiles/"
    chmod 644 "$TILES_DIR/overlays/pmtiles/openskimap.pmtiles"
    echo "   📦 PMTiles: openskimap.pmtiles"
fi

# 3. Abschluss: Inventar & Info-Generation
INFO_SCRIPT="$SCRIPT_DIR/generate_endpoints_info.sh"
if [ -f "$INFO_SCRIPT" ]; then
    echo ""
    log_info "Aktualisiere Karten-Inventar..."
    bash "$INFO_SCRIPT"
fi

echo ""
log_success "Deployment (Phase 4) abgeschlossen."
