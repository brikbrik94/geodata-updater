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

log_section "SCHRITT 2: OSM MERGE (MULTI-MAP)"

# Config-Variablen
BASE_DIR="${OSM_BUILD_DIR:-/srv/build/osm}"
INPUT_DIR="$BASE_DIR/src"
# Wir speichern die gemergten Dateien in einem eigenen Ordner "merged"
OUTPUT_DIR="$BASE_DIR/merged"

mkdir -p "$OUTPUT_DIR"

# Tool Check
if ! command -v osmium &> /dev/null; then
    log_error "Osmium Tool ('osmium') nicht gefunden."
    exit 1
fi

# Wir suchen nach .list Dateien (die von download_osm.sh erstellt wurden)
# Jede .list entspricht einer geplanten Karte (z.B. at-plus.list -> at-plus.pmtiles)
mapfile -t LIST_FILES < <(find "$INPUT_DIR" -maxdepth 1 -name "*.list" | sort)

if [ ${#LIST_FILES[@]} -eq 0 ]; then
    log_error "Keine .list Dateien in $INPUT_DIR gefunden!"
    log_info "Bitte zuerst scripts/run_download.sh ausführen."
    exit 1
fi

log_info "Gefundene Karten-Definitionen: ${#LIST_FILES[@]}"

for list_file in "${LIST_FILES[@]}"; do
    # Name der Karte aus dem Dateinamen ableiten (at-plus.list -> at-plus)
    MAP_NAME="$(basename "$list_file" .list)"
    TARGET_FILE="$OUTPUT_DIR/${MAP_NAME}.osm.pbf"
    
    log_header "Verarbeite Karte: $MAP_NAME"
    
    # Pfade aus der Liste lesen (in Array einlesen)
    mapfile -t PBF_INPUTS < "$list_file"
    
    FILE_COUNT=${#PBF_INPUTS[@]}
    
    if [ "$FILE_COUNT" -eq 0 ]; then
        log_warn "Liste $list_file ist leer - überspringe."
        continue
    fi

    # Entscheidung: Mergen oder Kopieren?
    if [ "$FILE_COUNT" -eq 1 ]; then
        SINGLE_FILE="${PBF_INPUTS[0]}"
        log_info "Nur eine Datei: $SINGLE_FILE"
        log_info " -> Kopiere zu $TARGET_FILE"
        cp -f "$SINGLE_FILE" "$TARGET_FILE"
    else
        log_info "Merge $FILE_COUNT Dateien..."
        for f in "${PBF_INPUTS[@]}"; do
             log_info "  + $(basename "$f")"
        done
        
        # Merge ausführen
        if osmium merge "${PBF_INPUTS[@]}" -o "$TARGET_FILE" --overwrite; then
            log_success "Merge OK."
        else
            log_error "Fehler beim Mergen von $MAP_NAME"
            exit 1
        fi
    fi
    
    # Größen-Check zur Info
    if [ -f "$TARGET_FILE" ]; then
        SIZE=$(du -h "$TARGET_FILE" | cut -f1)
        log_success "Erstellt: $TARGET_FILE ($SIZE)"
    fi
done

log_success "Alle Merge-Vorgänge abgeschlossen."
