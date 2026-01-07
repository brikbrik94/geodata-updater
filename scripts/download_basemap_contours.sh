#!/bin/bash
set -euo pipefail

CONTOURS_URL="${CONTOURS_URL:-https://cdn.basemap.at/offline/bmapvhl_vtpk_3857.vtpk}"
CONTOURS_ID="${CONTOURS_ID:-basemap-at-contours}"
OUTPUT_DIR="${CONTOURS_OUTPUT_DIR:-/srv/build/$CONTOURS_ID}"
FORCE_DOWNLOAD="${FORCE_DOWNLOAD:-0}"

mkdir -p "$OUTPUT_DIR"

FILENAME="$(basename "$CONTOURS_URL")"
DEST_PATH="$OUTPUT_DIR/$FILENAME"

if [ -f "$DEST_PATH" ] && [ "$FORCE_DOWNLOAD" -ne 1 ]; then
    echo "Contours-Datei vorhanden, Download wird übersprungen: $DEST_PATH"
    exit 0
fi

echo "Lade Basemap-Contours herunter: $CONTOURS_URL"
wget -q --show-progress -O "$DEST_PATH" "$CONTOURS_URL"
echo "✓ Contours-Download OK: $DEST_PATH"
