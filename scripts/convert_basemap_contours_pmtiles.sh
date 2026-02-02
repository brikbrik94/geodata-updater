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

log_section "CONVERT: CONTOURS -> PMTILES"

# -------------------------------------------------------------------
# 2. Pfade (SYNCHRONISIERT MIT CONFIG.ENV & OVERLAY STRUKTUR)
# -------------------------------------------------------------------
# Wir nutzen die zentralen Variablen aus der config.env
WORK_DIR="${CONTOURS_BUILD_DIR:-$OVERLAYS_BUILD_DIR/contours}"
SRC_DIR="$WORK_DIR" # Die vtpk liegt direkt im Download-Ordner
TMP_EXTRACT="$WORK_DIR/vtpk_extract"
TOOLS_DIR="$WORK_DIR/tools"

# Eingabe-Datei (aus download_basemap_contours.sh)
VTPK="$SRC_DIR/bmapvhl_vtpk_3857.vtpk"

# AUSGABE: Direkt in den zentralen Build-Ordner für das Deployment
OUT_PMTILES="$BUILD_DIR/basemap-at-contours.pmtiles"

# Temporäre MBTiles (wird nach Abschluss gelöscht)
OUT_MBTILES="$WORK_DIR/temp_contours.mbtiles"
INFO_JSON="$WORK_DIR/basemap-at-contours.json"

# Einstellungen
MAXZOOM="${MAXZOOM:-}"
ATTRIBUTION="${ATTRIBUTION:-© basemap.at}"
CLEANUP="${CLEANUP:-1}"

# Tool URLs
VTPK2MBTILES_URL="https://github.com/BergWerkGIS/vtpk2mbtiles/releases/download/v0.0.0.2/vtpk2mbtiles-linux-x64-v0.0.0.2.zip"
PMTILES_VERSION="1.22.1"
PMTILES_URL="https://github.com/protomaps/go-pmtiles/releases/download/v${PMTILES_VERSION}/go-pmtiles_${PMTILES_VERSION}_Linux_x86_64.tar.gz"

mkdir -p "$WORK_DIR"
mkdir -p "$TOOLS_DIR"

# -------------------------------------------------------------------
# 3. Tools vorbereiten
# -------------------------------------------------------------------
export DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=1

if [[ ! -x "$TOOLS_DIR/vtpk2mbtiles" ]]; then
    log_info "Lade vtpk2mbtiles herunter..."
    wget -q "$VTPK2MBTILES_URL" -O "$TOOLS_DIR/vtpk2mbtiles.zip"
    unzip -q "$TOOLS_DIR/vtpk2mbtiles.zip" -d "$TOOLS_DIR"
    rm -f "$TOOLS_DIR/vtpk2mbtiles.zip"
    chmod +x "$TOOLS_DIR/vtpk2mbtiles"
fi

if [[ ! -x "$TOOLS_DIR/pmtiles" ]]; then
    log_info "Lade pmtiles herunter..."
    wget -q "$PMTILES_URL" -O "$TOOLS_DIR/pmtiles.tar.gz"
    tar -xzf "$TOOLS_DIR/pmtiles.tar.gz" -C "$TOOLS_DIR"
    rm -f "$TOOLS_DIR/pmtiles.tar.gz"
    [ -f "$TOOLS_DIR/go-pmtiles" ] && mv "$TOOLS_DIR/go-pmtiles" "$TOOLS_DIR/pmtiles"
    chmod +x "$TOOLS_DIR/pmtiles"
fi

# -------------------------------------------------------------------
# 4. VTPK Verarbeitung
# -------------------------------------------------------------------
if [[ ! -f "$VTPK" ]]; then
    log_error "VTPK nicht gefunden: $VTPK"
    exit 2
fi

log_info "Entpacke VTPK..."
rm -rf "$TMP_EXTRACT"
mkdir -p "$TMP_EXTRACT"
unzip -q "$VTPK" -d "$TMP_EXTRACT"

# -------------------------------------------------------------------
# 5. Konvertierung: VTPK -> MBTiles -> PMTiles
# -------------------------------------------------------------------
log_info "Erzeuge MBTiles..."
"$TOOLS_DIR/vtpk2mbtiles" "$TMP_EXTRACT" "$OUT_MBTILES" false >/dev/null

log_info "Konvertiere zu PMTiles: $OUT_PMTILES"
"$TOOLS_DIR/pmtiles" convert "$OUT_MBTILES" "$OUT_PMTILES" >/dev/null

if [[ ! -f "$OUT_PMTILES" ]]; then
    log_error "Konvertierung fehlgeschlagen, $OUT_PMTILES wurde nicht erstellt."
    exit 5
fi

# -------------------------------------------------------------------
# 6. Metadaten & Info-JSON
# -------------------------------------------------------------------
# Maxzoom aus root.json ermitteln falls vorhanden
if [[ -z "$MAXZOOM" && -f "$TMP_EXTRACT/p12/resources/styles/root.json" ]]; then
    MAXZOOM=$(python3 - <<'PY'
import json, os
try:
    with open('vtpk_extract/p12/resources/styles/root.json', 'r') as f:
        print(json.load(f).get('maxzoom', 14))
except: print(14)
PY
)
fi
MAXZOOM="${MAXZOOM:-14}"

# Info-Datei für die Pipeline-Statistik erstellen
cat <<EOF > "$INFO_JSON"
{
  "name": "basemap.at contours",
  "source": "$(basename "$VTPK")",
  "updated": "$(date +%Y-%m-%d)",
  "maxzoom": $MAXZOOM,
  "file": "$(basename "$OUT_PMTILES")",
  "size_bytes": $(stat -c%s "$OUT_PMTILES"),
  "attribution": "$ATTRIBUTION"
}
EOF

log_success "Contours PMTiles erfolgreich erstellt: $(basename "$OUT_PMTILES")"

# -------------------------------------------------------------------
# 7. Cleanup
# -------------------------------------------------------------------
if [[ "$CLEANUP" == "1" ]]; then
    log_info "Räume temporäre Daten auf..."
    rm -rf "$TMP_EXTRACT"
    rm -f "$OUT_MBTILES"
fi
