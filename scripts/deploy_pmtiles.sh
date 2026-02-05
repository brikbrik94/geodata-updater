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

copy_if_newer() {
    local src="$1"
    local dst="$2"
    local label="$3"

    if [ ! -f "$src" ]; then
        return
    fi

    if [ -f "$dst" ]; then
        local src_mtime dst_mtime
        src_mtime=$(stat -c %Y "$src")
        dst_mtime=$(stat -c %Y "$dst")

        if [ "$src_mtime" -le "$dst_mtime" ]; then
            echo "   ⏭️  $label unverändert: $(basename "$src")"
            return
        fi
    fi

    mkdir -p "$(dirname "$dst")"
    cp -f "$src" "$dst"
    chmod 644 "$dst"
    echo "   📦 $label aktualisiert: $(basename "$src")"
}


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
            target="$pmtiles_dest/$(basename "$file")"

            copy_if_newer "$file" "$target" "PMTiles"
        done

        # B) Metadaten (JSON) kopieren (z.B. at.json von Planetiler)
        shopt -s nullglob
        local json_files=("$src_dir"/*.json)
        shopt -u nullglob
        
        if [ ${#json_files[@]} -gt 0 ]; then
            mkdir -p "$tilejson_dest"
            for jfile in "${json_files[@]}"; do
                copy_if_newer "$jfile" "$tilejson_dest/$(basename "$jfile")" "Info"
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
CONTOURS_TMP="${CONTOURS_BUILD_DIR:-/srv/build/overlays/contours}/tmp"
if [ -f "$CONTOURS_TMP/basemap-at-contours.pmtiles" ]; then
    copy_if_newer "$CONTOURS_TMP/basemap-at-contours.pmtiles" "$TILES_DIR/overlays/pmtiles/basemap-at-contours.pmtiles" "PMTiles"

    # Metadaten-JSON für Contours (falls generiert)
    CONTOURS_JSON="$CONTOURS_TMP/basemap-at-contours.json"
    if [ -f "$CONTOURS_JSON" ]; then
        copy_if_newer "$CONTOURS_JSON" "$TILES_DIR/overlays/tilejson/basemap-at-contours.json" "Info"
    fi
fi

# OpenSkimap
SKIMAP_TMP="${SKIMAP_BUILD_DIR:-/srv/build/overlays/openskimap}/tmp"
if [ -f "$SKIMAP_TMP/openskimap.pmtiles" ]; then
    copy_if_newer "$SKIMAP_TMP/openskimap.pmtiles" "$TILES_DIR/overlays/pmtiles/openskimap.pmtiles" "PMTiles"
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
