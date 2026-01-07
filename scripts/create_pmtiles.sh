#!/bin/bash
set -euo pipefail

# --- KONFIGURATION ---
INPUT_PBF="/srv/build/osm/merged/complete_map.osm.pbf"
INPUT_FILENAME="complete_map.osm.pbf"
TILESET_ID="${TILESET_ID:-osm}"
STYLE_ID="${STYLE_ID:-$TILESET_ID}"
BUILD_BASE="/srv/build/$TILESET_ID"
BUILD_DIR="$BUILD_BASE/tmp/out"
SOURCES_DIR="$BUILD_BASE/tmp/sources"
SERVE_DIR="/srv/tiles/$TILESET_ID/pmtiles"
STYLE_DIR="/srv/tiles/$TILESET_ID/styles/$STYLE_ID"
STYLE_FILE="$STYLE_DIR/style.json"
STATS_DIR="/srv/scripts/stats"
INFO_JSON="/srv/tiles/$TILESET_ID/tilejson/${TILESET_ID}.json"
FILENAME="at-plus.pmtiles"
DOCKER_IMAGE="ghcr.io/onthegomap/planetiler:latest"
DEBUG_LOG="/srv/scripts/planetiler_raw_debug.log"
USE_SUDO="${USE_SUDO:-0}"
DOCKER_BIN=""

# --- VORBEREITUNG ---
export STATS_DIR="$STATS_DIR"

DOCKER_BIN="$(command -v docker 2>/dev/null || true)"
if [ -z "$DOCKER_BIN" ]; then
    for candidate in /usr/bin/docker /usr/local/bin/docker /bin/docker; do
        if [ -x "$candidate" ]; then
            DOCKER_BIN="$candidate"
            break
        fi
    done
fi
if [ -z "$DOCKER_BIN" ]; then
    echo "❌ FEHLER: 'docker' Kommando nicht gefunden."
    echo "Bitte Docker installieren (z.B. docker.io) und sicherstellen, dass der Pfad (PATH) korrekt ist."
    echo "Aktueller PATH: $PATH"
    exit 1
fi
if ! systemctl is-active --quiet docker; then echo "❌ FEHLER: Docker läuft nicht."; exit 1; fi
if [ ! -f "$INPUT_PBF" ]; then echo "❌ FEHLER: Input-Datei $INPUT_PBF nicht gefunden."; exit 1; fi

mkdir -p "$BUILD_DIR" "$SOURCES_DIR" "$SERVE_DIR" "$STATS_DIR" "$STYLE_DIR" "$(dirname "$INFO_JSON")"
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
DOCKER_CMD="$DOCKER_BIN"
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
  "pmtiles_path": "$SERVE_DIR/$FILENAME",
  "pmtiles_size_bytes": $FILE_SIZE,
  "built_from_host": "$HOST_NAME",
  "attribution": "© OpenMapTiles © OpenStreetMap contributors"
}
EOF
chmod 644 "$INFO_JSON"

if [ ! -f "$STYLE_FILE" ]; then
    echo "❌ FEHLER: style.json nicht gefunden: $STYLE_FILE"
    echo "Lege die Datei dort ab (z.B. via install.sh, Quelle: styles/style.json)."
    exit 1
fi
