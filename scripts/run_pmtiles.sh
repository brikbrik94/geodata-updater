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

log_section "KONVERTIERUNG: OSM -> PMTILES (Planetiler)"

# Config-Variablen
BASE_DIR="${OSM_BUILD_DIR:-/srv/build/osm}"
INPUT_DIR="$BASE_DIR/merged"
OUTPUT_DIR="$BASE_DIR/tmp"  # Hier sucht deploy_pmtiles.sh später
TOOLS_DIR="${BUILD_DIR:-/srv/build}/tools"
PLANETILER_JAR="$TOOLS_DIR/planetiler.jar"

# Planetiler Download URL (fest oder aus Config)
PLANETILER_URL="https://github.com/onthegomap/planetiler/releases/latest/download/planetiler.jar"

mkdir -p "$OUTPUT_DIR"
mkdir -p "$TOOLS_DIR"

# 1. Planetiler JAR prüfen/laden
if [ ! -f "$PLANETILER_JAR" ]; then
    log_info "Lade Planetiler herunter..."
    if wget -q -O "$PLANETILER_JAR" "$PLANETILER_URL"; then
        log_success "Planetiler installiert."
    else
        log_error "Download von Planetiler fehlgeschlagen."
        exit 1
    fi
fi

# 2. Input Dateien finden (aus dem Merge-Schritt)
mapfile -t PBF_FILES < <(find "$INPUT_DIR" -maxdepth 1 -name "*.osm.pbf" | sort)

if [ ${#PBF_FILES[@]} -eq 0 ]; then
    log_error "Keine gemergten PBF-Dateien in $INPUT_DIR gefunden."
    log_info "Bitte scripts/run_merge.sh ausführen."
    exit 1
fi

# 3. Schleife über alle Karten
for pbf_file in "${PBF_FILES[@]}"; do
    filename=$(basename "$pbf_file")          # z.B. at-plus.osm.pbf
    map_name="${filename%%.*}"                # z.B. at-plus
    output_file="$OUTPUT_DIR/${map_name}.pmtiles"
    
    log_header "Verarbeite Karte: $map_name"
    log_info "Input:  $pbf_file"
    log_info "Output: $output_file"
    
    # Speicher für Java berechnen (ca. 80% vom verfügbaren RAM oder fest 4G)
    # Hier simpel: wir lassen Java selbst entscheiden oder geben z.B. -Xmx4g mit wenn nötig.
    # Planetiler ist sehr effizient.
    
    # Ausführen
    # --force überschreibt existierende Dateien
    # --download-threads etc. werden automatisch gesetzt
    java -jar "$PLANETILER_JAR" \
        --osm-path "$pbf_file" \
        --output "$output_file" \
        --force \
        --nodemap-type array \
        --storage-type ram \
        > /dev/null # Output unterdrücken (Planetiler ist sehr gesprächig), ggf. in Logfile leiten
        
    # Check
    if [ -f "$output_file" ]; then
        SIZE=$(du -h "$output_file" | cut -f1)
        log_success "Erstellt: $output_file ($SIZE)"
    else
        log_error "Fehler bei der Konvertierung von $map_name"
        exit 1
    fi
done

log_success "Alle OSM-Karten konvertiert."
