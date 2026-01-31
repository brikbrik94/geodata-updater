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

log_section "PHASE 4: DEPLOYMENT (PMTILES)"

# --- KONFIGURATION ---
# Ziel-Verzeichnis (aus Config oder Standard)
TILES_DIR="$(realpath -m "${TILES_DIR:-/srv/tiles}")"

# Quell-Verzeichnisse (Mapping der Build-Ordner auf Tileset-Namen)
# Format: QUELLE|TILESET_NAME (wie im Ordner-Baum gewünscht)

# 1. OSM
OSM_SRC="$(realpath -m "${OSM_BUILD_DIR:-/srv/build/osm}/tmp")"
# 2. Basemap (Falls vorhanden)
BASEMAP_SRC="$(realpath -m "${BASEMAP_BUILD_DIR:-/srv/build/basemap}/tmp")"
# 3. Overlays (Falls vorhanden)
OVERLAYS_SRC="$(realpath -m "${OVERLAYS_BUILD_DIR:-/srv/build/overlays}/tmp")"

log_info "Deployment Ziel: $TILES_DIR"

# --- FUNKTION: Deploy in die Tileset-Struktur ---
deploy_tileset() {
    local src_dir="$1"
    local tileset_name="$2"  # z.B. "osm", "basemap-at", "overlays"
    
    # Zielstruktur gemäß deinem Tree: tiles/TILESET/pmtiles/
    local dest_dir="$TILES_DIR/$tileset_name/pmtiles"

    if [ ! -d "$src_dir" ]; then
        return
    fi

    # Suche nach ALLEN .pmtiles Dateien (dynamisch statt statischer Liste)
    shopt -s nullglob
    local files=("$src_dir"/*.pmtiles)
    shopt -u nullglob

    if [ ${#files[@]} -gt 0 ]; then
        log_info "📂 Tileset: $tileset_name"
        
        mkdir -p "$dest_dir"

        for file in "${files[@]}"; do
            filename=$(basename "$file")
            target="$dest_dir/$filename"
            
            # Prüfen ob Update nötig oder Datei schon existiert
            if [[ -f "$target" ]]; then
                echo "   🗑️  Überschreibe alt: $filename"
            fi
            
            echo "   📦 Deploye $file -> $target"
            cp -f "$file" "$target"
            chmod 644 "$target"
            echo "   ✅ OK: $target"
        done
    else
        # Nur Info, kein Fehler (vielleicht wurde Basemap diesmal nicht gebaut)
        log_info "ℹ️  Keine PMTiles für '$tileset_name' gefunden in $src_dir"
    fi
}

# --- HAUPTABLAUF ---

# 1. OSM Deployen (Zielordner: osm)
deploy_tileset "$OSM_SRC" "osm"

# 2. Basemap Deployen (Zielordner: basemap-at, wie in deinem Tree)
deploy_tileset "$BASEMAP_SRC" "basemap-at"

# 3. Overlays Deployen (Zielordner: overlays)
deploy_tileset "$OVERLAYS_SRC" "overlays"

# 4. Info Generator (falls vorhanden)
# Aktualisiert die endpoints_info.json basierend auf dem neuen Inhalt
INFO_SCRIPT="$SCRIPT_DIR/generate_endpoints_info.sh"
if [ -f "$INFO_SCRIPT" ]; then
    echo ""
    log_info "Aktualisiere Karten-Inventar..."
    bash "$INFO_SCRIPT"
fi

echo ""
log_success "PMTiles Deployment abgeschlossen."
