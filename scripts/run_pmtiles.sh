#!/bin/bash
set -euo pipefail

# 1. Utils laden
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/utils.sh" ]; then
    source "$SCRIPT_DIR/utils.sh"
else
    echo "❌ Fehler: utils.sh nicht gefunden!"
    exit 1
fi

log_section "PHASE 3: PMTILES KONVERTIERUNG (Orchestrator)"

# ---------------------------------------------------------
# 1. OSM KARTEN KONVERTIEREN
# ---------------------------------------------------------
# Ruft das Docker-Skript auf, das wir gerade repariert haben
if [ -f "$SCRIPT_DIR/convert_osm_pmtiles.sh" ]; then
    # Wir rufen es explizit mit bash auf, damit Environment sauber bleibt
    bash "$SCRIPT_DIR/convert_osm_pmtiles.sh"
else
    log_error "Skript nicht gefunden: convert_osm_pmtiles.sh"
    exit 1
fi

# ---------------------------------------------------------
# 2. BASEMAP.AT (Raster/Vektor) KONVERTIEREN
# ---------------------------------------------------------
# Falls du auch die Basemap Konvertierung hast
if [ -f "$SCRIPT_DIR/convert_basemap_at_pmtiles.sh" ]; then
    bash "$SCRIPT_DIR/convert_basemap_at_pmtiles.sh"
else
    log_info "Kein Basemap-Skript gefunden, überspringe..."
fi

# ---------------------------------------------------------
# 3. HÖHENLINIEN (CONTOURS) KONVERTIEREN
# ---------------------------------------------------------
# Falls du das Contours-Skript hast
if [ -f "$SCRIPT_DIR/convert_basemap_contours_pmtiles.sh" ]; then
    bash "$SCRIPT_DIR/convert_basemap_contours_pmtiles.sh"
fi

log_success "Alle Konvertierungs-Schritte abgeschlossen."

# ---------------------------------------------------------
# 4. OPENSKIMAP KONVERTIEREN
# ---------------------------------------------------------
if [ -f "$SCRIPT_DIR/convert_openskimap_pmtiles.sh" ]; then
    bash "$SCRIPT_DIR/convert_openskimap_pmtiles.sh"
else
    log_warn "convert_openskimap_pmtiles.sh nicht gefunden - überspringe."
fi
