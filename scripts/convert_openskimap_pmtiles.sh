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

log_section "CONVERT: OPENSKIMAP -> PMTILES"

# 2. Pfade definieren
# Quelldatei aus dem Download-Schritt
INPUT_FILE="$SKIMAP_BUILD_DIR/openskidata.gpkg"
# Ziel im allgemeinen Build-Ordner (für das spätere Deployment)
OUTPUT_PMTILES="$BUILD_DIR/openskimap.pmtiles"

if [ ! -f "$INPUT_FILE" ]; then
    log_error "Eingabedatei nicht gefunden: $INPUT_FILE"
    exit 1
fi

# In den Arbeitsordner wechseln für temporäre Dateien
cd "$SKIMAP_BUILD_DIR"

# 3. Extraktion der Layer (GeoJSONSeq für Tippecanoe)
log_info "Extrahiere Layer aus GeoPackage..."
ogr2ogr -f GeoJSONSeq areas_p.jsonseq "$INPUT_FILE" ski_areas_point
ogr2ogr -f GeoJSONSeq areas_poly.jsonseq "$INPUT_FILE" ski_areas_multipolygon
ogr2ogr -f GeoJSONSeq lifts.jsonseq "$INPUT_FILE" lifts_linestring
ogr2ogr -f GeoJSONSeq runs_poly.jsonseq "$INPUT_FILE" runs_multipolygon
ogr2ogr -f GeoJSONSeq runs_line.jsonseq "$INPUT_FILE" runs_linestring

# 4. Konvertierung mit Tippecanoe
log_info "Erstelle PMTiles: $OUTPUT_PMTILES"
tippecanoe -o "$OUTPUT_PMTILES" --force \
  --minimum-zoom=0 --maximum-zoom=14 \
  --drop-densest-as-needed \
  --extend-zooms-if-still-dropping \
  --layer=areas_p areas_p.jsonseq \
  --layer=areas_poly areas_poly.jsonseq \
  --layer=lifts lifts.jsonseq \
  --layer=runs_poly runs_poly.jsonseq \
  --layer=runs_line runs_line.jsonseq

# 5. Aufräumen
log_info "Bereinige temporäre JSON-Dateien..."
rm -f *.jsonseq

log_success "OpenSkimap PMTiles erfolgreich erstellt."
