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

log_header "PHASE 1: DOWNLOAD DATEN"

# 2. OSM Download (Zwingend erforderlich)
if [ -f "$SCRIPT_DIR/download_osm.sh" ]; then
    "$SCRIPT_DIR/download_osm.sh"
else
    log_error "download_osm.sh nicht gefunden! Abbruch."
    exit 1
fi

# 3. Basemap Download (Optional / Standard)
if [ -f "$SCRIPT_DIR/download_basemap.sh" ]; then
    "$SCRIPT_DIR/download_basemap.sh"
else
    log_warn "download_basemap.sh nicht gefunden - überspringe."
fi

# 4. Contours Download (Optional / Overlay)
if [ -f "$SCRIPT_DIR/download_basemap_contours.sh" ]; then
    "$SCRIPT_DIR/download_basemap_contours.sh"
else
    log_warn "download_basemap_contours.sh nicht gefunden - überspringe."
fi

log_success "Phase 1 (Download) abgeschlossen."

# 5. OpenSkimap Download (Zusatz-Overlay)
if [ -f "$SCRIPT_DIR/download_openskimap.sh" ]; then
    bash "$SCRIPT_DIR/download_openskimap.sh"
else
    log_warn "download_openskimap.sh nicht gefunden - überspringe."
fi
