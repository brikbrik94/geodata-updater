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

# --- KONFIGURATION ---
# Wir nutzen OVERLAYS_BUILD_DIR aus der Config (Standard: /srv/build/overlays)
# Das /src hängen wir hier an, wie in deinem Original
BASE_DIR="${OVERLAYS_BUILD_DIR:-/srv/build/overlays}"
OUTPUT_DIR="$BASE_DIR/src"

VTPK_URL="${CONTOURS_URL:-https://cdn.basemap.at/offline/bmapvhl_vtpk_3857.vtpk}"
FILENAME="$(basename "$VTPK_URL")"
FULL_PATH="$OUTPUT_DIR/$FILENAME"
FORCE_DOWNLOAD="${FORCE_DOWNLOAD:-0}"

log_section "DOWNLOAD: CONTOURS (OVERLAY)"

mkdir -p "$OUTPUT_DIR"

if [ -f "$FULL_PATH" ] && [ "$FORCE_DOWNLOAD" -eq 0 ]; then
    log_info "Datei existiert bereits: $FULL_PATH"
    log_info "Nutze FORCE_DOWNLOAD=1 zum Überschreiben."
else
    log_info "Starte Download von basemap.at..."
    log_info "URL: $VTPK_URL"
    log_info "Ziel: $FULL_PATH"
    
    if wget -q --show-progress -O "$FULL_PATH" "$VTPK_URL"; then
        log_success "Download erfolgreich."
    else
        log_error "Download fehlgeschlagen."
        exit 1
    fi
fi
