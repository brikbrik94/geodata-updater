#!/bin/bash
set -euo pipefail

VTPK_PATH="${VTPK_PATH:-/srv/build/basemap-at-contours/src/bmapvhl_vtpk_3857.vtpk}"
OUTPUT_PM="${OUTPUT_PM:-/srv/tiles/basemap-at-contours/pmtiles/basemap-at-contours.pmtiles}"
TMP_DIR="${TMP_DIR:-/srv/build/basemap-at-contours/tmp}"
CONVERT_CMD="${CONVERT_CMD:-}"

mkdir -p "$TMP_DIR" "$(dirname "$OUTPUT_PM")"

if [ ! -f "$VTPK_PATH" ]; then
    echo "❌ FEHLER: VTPK-Datei nicht gefunden: $VTPK_PATH"
    exit 1
fi

if [ -z "$CONVERT_CMD" ]; then
    cat <<EOM
❌ FEHLER: Kein Konvertierungsbefehl definiert.

Setze CONVERT_CMD, um die VTPK→PMTiles-Konvertierung zu starten.
Beispiel:
  CONVERT_CMD='vtpk-to-pmtiles "$VTPK_PATH" "$OUTPUT_PM" --tmp "$TMP_DIR"'
EOM
    exit 1
fi

echo "Starte VTPK→PMTiles Konvertierung (basemap-at-contours)..."
bash -lc "$CONVERT_CMD"

echo "✓ PMTiles erstellt: $OUTPUT_PM"
