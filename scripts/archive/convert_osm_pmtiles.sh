#!/bin/bash
set -euo pipefail

# Utils laden
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

# --- KONFIGURATION ---
# Pfade dynamisch aus der config.env (via utils.sh geladen)
MERGE_DIR="${OSM_BUILD_DIR:-/srv/build/osm}/merged"
TILESET_ID="${TILESET_ID:-osm}"
# BUILD_BASE wird durch OSM_BUILD_DIR ersetzt/abgedeckt
BUILD_TMP="${OSM_BUILD_DIR:-/srv/build/osm}/tmp"
STATS_DIR="${INSTALL_DIR:-/srv/scripts}/stats"

DOCKER_IMAGE="ghcr.io/onthegomap/planetiler:latest"
USE_SUDO="${USE_SUDO:-0}"

log_section "SCHRITT 3: PMTILES KONVERTIERUNG (Planetiler)"

# Docker Check
DOCKER_BIN="$(command -v docker 2>/dev/null || true)"
if [ -z "$DOCKER_BIN" ]; then
    log_error "Docker nicht gefunden."
    exit 1
fi
DOCKER_CMD="$DOCKER_BIN"
[ "$USE_SUDO" -eq 1 ] && DOCKER_CMD="sudo docker"

mkdir -p "$BUILD_TMP" "$STATS_DIR"

# --- HAUPTSCHLEIFE ---
FOUND_ANY=0
for pbf_file in "$MERGE_DIR"/*.osm.pbf; do
    [ -e "$pbf_file" ] || continue
    FOUND_ANY=1
    
    MAP_NAME="$(basename "$pbf_file" .osm.pbf)"
    PMTILES_NAME="${MAP_NAME}.pmtiles"
    INFO_JSON="$BUILD_TMP/${MAP_NAME}.json"
    LOG_FILE="$STATS_DIR/${MAP_NAME}_build.log"
    
    log_header "Konvertiere: $MAP_NAME"
    log_info "Input:  $(basename "$pbf_file")"
    log_info "Output: $PMTILES_NAME"
    log_info "Log:    $LOG_FILE"
    
    # Logfile leeren
    > "$LOG_FILE"
    
    # 1. Planetiler starten (Hintergrund)
    $DOCKER_CMD run --rm \
      -v "$MERGE_DIR":/in:ro \
      -v "$BUILD_TMP":/out \
      "$DOCKER_IMAGE" \
      --osm-path="/in/$(basename "$pbf_file")" \
      --output="/out/$PMTILES_NAME" \
      --force \
      --download=true \
      > "$LOG_FILE" 2>&1 &
      
    PID=$!
    
    # 2. Progress anzeigen
    if [ -f "$SCRIPT_DIR/planetiler_follow.py" ]; then
        # Python Skript übernimmt die "Live"-Anzeige
        python3 -u "$SCRIPT_DIR/planetiler_follow.py" "$LOG_FILE" "$PID"
    else
        log_info "Warte auf Docker Prozess (PID $PID)..."
        wait $PID
    fi
    EXIT_CODE=$?
    
    # 3. Ergebnis prüfen
    if [ $EXIT_CODE -eq 0 ] && [ -f "$BUILD_TMP/$PMTILES_NAME" ]; then
        SIZE=$(stat -c%s "$BUILD_TMP/$PMTILES_NAME")
        SIZE_H=$(du -h "$BUILD_TMP/$PMTILES_NAME" | cut -f1)
        DATE=$(date +%Y-%m-%d)
        
        # Metadaten JSON schreiben
        cat <<EOF > "$INFO_JSON"
{
  "name": "OSM $MAP_NAME",
  "dataset_date": "$DATE",
  "pmtiles_file": "$PMTILES_NAME",
  "size_bytes": $SIZE,
  "attribution": "© OpenMapTiles © OpenStreetMap contributors"
}
EOF
        log_success "Fertig! Datei: $PMTILES_NAME ($SIZE_H)"
    else
        log_error "Konvertierung fehlgeschlagen (Exit Code: $EXIT_CODE). Details siehe Log."
        exit 1
    fi
    echo ""
done

if [ "$FOUND_ANY" -eq 0 ]; then
    log_warn "Keine .osm.pbf Dateien in $MERGE_DIR gefunden."
fi
