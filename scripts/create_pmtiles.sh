#!/bin/bash
set -euo pipefail

# --- KONFIGURATION ---
INPUT_PBF="/srv/osm/merged/complete_map.osm.pbf"
INPUT_FILENAME="complete_map.osm.pbf"
BUILD_DIR="/srv/pmtiles/build/out"
SOURCES_DIR="/srv/pmtiles/build/sources"
SERVE_DIR="/srv/pmtiles/serve"
STATS_DIR="/srv/scripts/stats"
INFO_JSON="$SERVE_DIR/info.json"
FILENAME="at-plus.pmtiles"
DOCKER_IMAGE="ghcr.io/onthegomap/planetiler:latest"
DEBUG_LOG="/srv/scripts/planetiler_raw_debug.log"
USE_SUDO="${USE_SUDO:-0}"

# --- VORBEREITUNG ---
export STATS_DIR="$STATS_DIR"

if ! systemctl is-active --quiet docker; then echo "❌ FEHLER: Docker läuft nicht."; exit 1; fi
if [ ! -f "$INPUT_PBF" ]; then echo "❌ FEHLER: Input-Datei $INPUT_PBF nicht gefunden."; exit 1; fi

mkdir -p "$BUILD_DIR" "$SOURCES_DIR" "$SERVE_DIR" "$STATS_DIR"
if ! groups | grep -qw docker && [ "$USE_SUDO" -ne 1 ]; then
    echo "❌ FEHLER: Benutzer ist nicht in der docker-Gruppe. Setze USE_SUDO=1 oder füge den User zur docker-Gruppe hinzu."
    exit 1
fi
# Logfile leeren
> "$DEBUG_LOG"

# --- RUN PLANETILER (HINTERGRUND) ---
echo "Starte Docker im Hintergrund..."

# WICHTIG: Docker läuft im Hintergrund (&) und schreibt in die Datei.
# Python läuft im Vordergrund und liest die Datei. Keine Pipe, kein Deadlock.
DOCKER_CMD="docker"
if [ "$USE_SUDO" -eq 1 ]; then
    DOCKER_CMD="sudo docker"
fi

$DOCKER_CMD run --rm \
  -v /srv/osm/merged:/in:ro \
  -v "$BUILD_DIR":/out \
  -v "$SOURCES_DIR":/data/sources \
  "$DOCKER_IMAGE" \
  --download=true \
  --osm-path="/in/$INPUT_FILENAME" \
  --output="/out/$FILENAME" \
  --force \
  --color=true \
  > "$DEBUG_LOG" 2>&1 &

DOCKER_PID=$!

# --- PYTHON FOLLOWER STARTEN ---
# Wir übergeben den Pfad zum Log und die PID von Docker
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
python3 -u "$SCRIPT_DIR/planetiler_follow.py" "$DEBUG_LOG" "$DOCKER_PID"

# Warten bis Docker wirklich fertig ist (für den Exit Code)
wait $DOCKER_PID
EXIT_CODE=$?

if [ $EXIT_CODE -ne 0 ]; then
    echo "❌ FEHLER: Planetiler ist fehlgeschlagen (Exit Code: $EXIT_CODE)."
    echo "Details im Log: $DEBUG_LOG"
    exit 1
fi

# --- DEPLOYMENT ---
mv "$BUILD_DIR/$FILENAME" "$SERVE_DIR/$FILENAME"
chmod 644 "$SERVE_DIR/$FILENAME"

# --- INFO.JSON UPDATE ---
CURRENT_DATE=$(date +%Y-%m-%d)
FILE_SIZE=$(stat -c%s "$SERVE_DIR/$FILENAME")
HOST_NAME=$(hostname)

cat <<EOF > "$INFO_JSON"
{
  "name": "AT+ OpenMapTiles (PMTiles)",
  "source_pbf": "$INPUT_FILENAME",
  "dataset_date": "$CURRENT_DATE",
  "maxzoom": 14,
  "pmtiles_file": "$FILENAME",
  "pmtiles_size_bytes": $FILE_SIZE,
  "built_from_host": "$HOST_NAME",
  "attribution": "© OpenMapTiles © OpenStreetMap contributors"
}
EOF
chmod 644 "$INFO_JSON"
