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

log_section "DOWNLOAD: BASEMAP.AT (VTPK)"

# URL definieren (Standard: basemap.at)
BASEMAP_URL="${BASEMAP_URL:-https://cdn.basemap.at/offline/bmapv_vtpk_3857.vtpk}"

# Ziel-Verzeichnis (aus Config: BASEMAP_BUILD_DIR oder Fallback)
BASE_DIR="${BASEMAP_BUILD_DIR:-/srv/build/basemap-at}"
OUTPUT_DIR="$BASE_DIR/src"

mkdir -p "$OUTPUT_DIR"

FILENAME="$(basename "$BASEMAP_URL")"
DEST_PATH="$OUTPUT_DIR/$FILENAME"

# Alters-Prüfung (2 Jahre in Sekunden)
TWO_YEARS_SECONDS=$((60 * 60 * 24 * 365 * 2))
NOW_EPOCH=$(date +%s)
SHOULD_DOWNLOAD=1

if [ -f "$DEST_PATH" ]; then
    FILE_MTIME=$(stat -c %Y "$DEST_PATH")
    AGE_SECONDS=$((NOW_EPOCH - FILE_MTIME))
    
    if [ "$AGE_SECONDS" -lt "$TWO_YEARS_SECONDS" ]; then
        log_info "Datei ist aktuell (< 2 Jahre): $FILENAME"
        SHOULD_DOWNLOAD=0
    else
        log_warn "Datei ist veraltet (> 2 Jahre). Starte Update..."
    fi
fi

if [ "$SHOULD_DOWNLOAD" -eq 1 ]; then
    log_info "Starte Download von: $BASEMAP_URL"
    log_info "Ziel: $DEST_PATH"
    
    if ! command -v aria2c >/dev/null 2>&1; then
        log_error "aria2c nicht gefunden. Bitte installieren."
        exit 1
    fi

    if aria2c -x16 -s16 -c -d "$OUTPUT_DIR" -o "$FILENAME" "$BASEMAP_URL"; then
        log_success "Download erfolgreich."
    else
        log_error "Download fehlgeschlagen!"
        exit 1
    fi
else
    log_success "Download übersprungen (Datei aktuell)."
fi
