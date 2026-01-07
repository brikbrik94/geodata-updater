#!/bin/bash
set -euo pipefail

BASEMAP_URL="${BASEMAP_URL:-https://cdn.basemap.at/offline/bmapv_vtpk_3857.vtpk}"
BASEMAP_ID="${BASEMAP_ID:-basemap-at}"
OUTPUT_DIR="${BASEMAP_OUTPUT_DIR:-/srv/build/$BASEMAP_ID/src}"

mkdir -p "$OUTPUT_DIR"

FILENAME="$(basename "$BASEMAP_URL")"
DEST_PATH="$OUTPUT_DIR/$FILENAME"

TWO_YEARS_SECONDS=$((60 * 60 * 24 * 365 * 2))
NOW_EPOCH=$(date +%s)

if [ -f "$DEST_PATH" ]; then
    FILE_MTIME=$(stat -c %Y "$DEST_PATH")
    AGE_SECONDS=$((NOW_EPOCH - FILE_MTIME))
    if [ "$AGE_SECONDS" -lt "$TWO_YEARS_SECONDS" ]; then
        echo "Basemap-Datei ist jünger als 2 Jahre, Download wird übersprungen: $DEST_PATH"
        exit 0
    fi
fi

echo "Lade Basemap-Datei herunter: $BASEMAP_URL"
wget -q --show-progress -O "$DEST_PATH" "$BASEMAP_URL"
echo "✓ Basemap-Download OK: $DEST_PATH"
