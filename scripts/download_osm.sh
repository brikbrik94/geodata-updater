#!/bin/bash
set -euo pipefail

# Utils laden
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

# --- KONFIGURATION ---
SOURCES_DIR="/srv/scripts/sources"
DOWNLOAD_BASE_DIR="/srv/build/osm/src"

log_section "SCHRITT 1: DOWNLOAD OSM DATEN"

if [ ! -d "$SOURCES_DIR" ]; then
    log_error "Quellen-Verzeichnis nicht gefunden: $SOURCES_DIR"
    exit 1
fi

mkdir -p "$DOWNLOAD_BASE_DIR"

# Zähler
COUNT=0

# --- HAUPTSCHLEIFE ---
for source_file in "$SOURCES_DIR"/*.txt; do
    [ -e "$source_file" ] || continue
    
    MAP_NAME="$(basename "$source_file" .txt)"
    LIST_FILE="$DOWNLOAD_BASE_DIR/${MAP_NAME}.list"
    
    log_header "Konfiguration: $MAP_NAME"
    
    # Liste leeren
    > "$LIST_FILE"
    
    mapfile -t URLS < <(grep -vE '^\s*($|#)' "$source_file")
    
    if [ ${#URLS[@]} -eq 0 ]; then
        log_warn "Keine URLs in $source_file gefunden."
        continue
    fi

    for LINK in "${URLS[@]}"; do
        FILENAME=$(basename "$LINK")
        FULL_PATH="$DOWNLOAD_BASE_DIR/$FILENAME"
        
        # Wir nutzen wget im Hintergrund-Modus für weniger Noise, außer es gibt Fehler
        # -N: Nur laden wenn neuer (Timestamping)
        log_info "Prüfe: $FILENAME"
        
        if wget -q -N -P "$DOWNLOAD_BASE_DIR" "$LINK"; then
            if [ -f "$FULL_PATH" ]; then
                echo "$FULL_PATH" >> "$LIST_FILE"
                COUNT=$((COUNT+1))
            else
                 log_error "Download scheinbar ok, aber Datei fehlt: $FILENAME"
            fi
        else
            log_error "Download fehlgeschlagen: $LINK"
        fi
    done
    
    if [ -s "$LIST_FILE" ]; then
        ENTRY_COUNT=$(wc -l < "$LIST_FILE")
        log_success "Liste erstellt ($ENTRY_COUNT Dateien)."
    fi
    echo "" # Leerzeile für Abstand
done

log_success "Download abgeschlossen. $COUNT Dateien bereit."
