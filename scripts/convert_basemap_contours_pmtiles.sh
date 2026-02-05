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
WORK_DIR="${CONTOURS_BUILD_DIR:-$OVERLAYS_BUILD_DIR/contours}"
SRC_DIR="$WORK_DIR/src"
TMP_DIR="$WORK_DIR/tmp"
TMP_EXTRACT="$TMP_DIR/vtpk_extract"
TOOLS_DIR="$WORK_DIR/tools"

VTPK="$SRC_DIR/bmapvhl_vtpk_3857.vtpk"
OUT_PMTILES="$TMP_DIR/basemap-at-contours.pmtiles"
OUT_MBTILES="$TMP_DIR/temp_contours.mbtiles"
INFO_JSON="$TMP_DIR/basemap-at-contours.json"

MAXZOOM="${MAXZOOM:-}"
ATTRIBUTION="${ATTRIBUTION:-© basemap.at}"
CLEANUP="${CLEANUP:-1}"

VTPK2MBTILES_URL="https://github.com/BergWerkGIS/vtpk2mbtiles/releases/download/v0.0.0.2/vtpk2mbtiles-linux-x64-v0.0.0.2.zip"
PMTILES_VERSION="1.22.1"
PMTILES_URL="https://github.com/protomaps/go-pmtiles/releases/download/v${PMTILES_VERSION}/go-pmtiles_${PMTILES_VERSION}_Linux_x86_64.tar.gz"

mkdir -p "$SRC_DIR" "$TMP_DIR" "$TOOLS_DIR"

if [[ ! -f "$VTPK" ]]; then
    log_error "VTPK nicht gefunden: $VTPK"
    exit 2
fi

source_mtime=$(stat -c %Y "$VTPK")
REBUILD_REQUIRED=1
if [[ -f "$OUT_PMTILES" ]]; then
    pmtiles_mtime=$(stat -c %Y "$OUT_PMTILES")
    if (( pmtiles_mtime >= source_mtime )); then
        REBUILD_REQUIRED=0
        log_info "Contours-PMTiles ist aktueller oder gleich alt wie die Quelle."
    fi
fi

if (( REBUILD_REQUIRED == 0 )) && [[ -f "$INFO_JSON" ]]; then
    log_success "Konvertierung übersprungen (PMTiles aktuell): $OUT_PMTILES"
    exit 0
fi

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

if (( REBUILD_REQUIRED == 1 )); then
    # -------------------------------------------------------------------
    # 4. VTPK Verarbeitung
    # -------------------------------------------------------------------
    log_info "Entpacke VTPK..."
    rm -rf "$TMP_EXTRACT"
    mkdir -p "$TMP_EXTRACT"
    unzip -q "$VTPK" -d "$TMP_EXTRACT"

    # 4b. Stylesheet sichern
    if [[ -f "$TMP_EXTRACT/p12/resources/styles/root.json" ]]; then
        mkdir -p "$TMP_DIR/styles"
        cp -f "$TMP_EXTRACT/p12/resources/styles/root.json" "$TMP_DIR/styles/root.json"
    fi

    # 5. Konvertierung
    log_info "Erzeuge MBTiles..."
    "$TOOLS_DIR/vtpk2mbtiles" "$TMP_EXTRACT" "$OUT_MBTILES" false >/dev/null

    log_info "Konvertiere zu PMTiles: $OUT_PMTILES"
    "$TOOLS_DIR/pmtiles" convert "$OUT_MBTILES" "$OUT_PMTILES" >/dev/null
else
    log_info "Neuaufbau nicht nötig, aktualisiere nur Info-JSON falls notwendig."
fi

if [[ ! -f "$OUT_PMTILES" ]]; then
    log_error "Konvertierung fehlgeschlagen, $OUT_PMTILES wurde nicht erstellt."
    exit 5
fi

# -------------------------------------------------------------------
# 6. Metadaten & Info-JSON
# -------------------------------------------------------------------
if [[ -z "$MAXZOOM" && -f "$TMP_EXTRACT/p12/resources/styles/root.json" ]]; then
    MAXZOOM=$(TMP_EXTRACT="$TMP_EXTRACT" python3 - <<'PY'
import json
import os
from pathlib import Path

root = Path(os.environ["TMP_EXTRACT"]) / "p12" / "resources" / "styles" / "root.json"
try:
    print(json.loads(root.read_text(encoding="utf-8")).get("maxzoom", 14))
except Exception:
    print(14)
PY
)
fi
MAXZOOM="${MAXZOOM:-14}"

cat <<JSON > "$INFO_JSON"
{
  "name": "basemap.at contours",
  "source": "$(basename "$VTPK")",
  "updated": "$(date +%Y-%m-%d)",
  "maxzoom": $MAXZOOM,
  "file": "$(basename "$OUT_PMTILES")",
  "size_bytes": $(stat -c%s "$OUT_PMTILES"),
  "attribution": "$ATTRIBUTION"
}
JSON

log_success "Contours PMTiles erfolgreich erstellt: $(basename "$OUT_PMTILES")"

if [[ "$CLEANUP" == "1" ]]; then
    log_info "Räume temporäre Daten auf..."
    rm -rf "$TMP_EXTRACT"
    rm -f "$OUT_MBTILES"
fi
