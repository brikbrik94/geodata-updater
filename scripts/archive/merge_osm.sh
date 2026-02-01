#!/bin/bash
set -euo pipefail

# Utils laden
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

SRC_DIR="/srv/build/osm/src"
MERGE_DIR="/srv/build/osm/merged"

log_section "SCHRITT 2: OSM MERGE"

mkdir -p "$MERGE_DIR"

if ! command -v osmium &> /dev/null; then
    log_error "'osmium-tool' ist nicht installiert."
    exit 1
fi

# --- HAUPTSCHLEIFE ---
FOUND_ANY=0
for list_file in "$SRC_DIR"/*.list; do
    [ -e "$list_file" ] || continue
    FOUND_ANY=1
    
    MAP_NAME="$(basename "$list_file" .list)"
    OUTPUT_PBF="$MERGE_DIR/${MAP_NAME}.osm.pbf"
    
    log_header "Merge Region: $MAP_NAME"
    
    if [ ! -s "$list_file" ]; then
        log_warn "Liste ist leer, überspringe."
        continue
    fi
    
    FILE_COUNT=$(wc -l < "$list_file")
    log_info "Füge $FILE_COUNT Dateien zusammen..."
    
    # Osmium ausführen
    if xargs -a "$list_file" osmium merge -o "$OUTPUT_PBF" --overwrite 2>/dev/null; then
        FILE_SIZE=$(du -h "$OUTPUT_PBF" | cut -f1)
        log_success "Erstellt: ${MAP_NAME}.osm.pbf ($FILE_SIZE)"
    else
        log_error "Merge fehlgeschlagen für $MAP_NAME"
        exit 1
    fi
    echo ""
done

if [ "$FOUND_ANY" -eq 0 ]; then
    log_warn "Keine .list Dateien in $SRC_DIR gefunden."
    log_info "Hast du 'download_osm.sh' ausgeführt?"
fi
