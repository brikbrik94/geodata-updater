#!/bin/bash
set -euo pipefail

# Utils laden
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/utils.sh" ]; then source "$SCRIPT_DIR/utils.sh"; else source /dev/null; fi

log_section "SCHRITT 3: PMTILES KONVERTIERUNG (GESAMT)"

# 1. OSM Konvertierung (Planetiler)
# Ruft das existierende OSM-Skript auf
if [ -f "$SCRIPT_DIR/convert_osm_pmtiles.sh" ]; then
    "$SCRIPT_DIR/convert_osm_pmtiles.sh"
else
    log_error "convert_osm_pmtiles.sh nicht gefunden!"
fi

# 2. Basemap.at Konvertierung
if [ -f "$SCRIPT_DIR/convert_basemap_at_pmtiles.sh" ]; then
    "$SCRIPT_DIR/convert_basemap_at_pmtiles.sh"
fi

# 3. Contours (Overlays) Konvertierung
if [ -f "$SCRIPT_DIR/convert_basemap_contours_pmtiles.sh" ]; then
    "$SCRIPT_DIR/convert_basemap_contours_pmtiles.sh"
fi

log_success "Alle Konvertierungen abgeschlossen."
