#!/bin/bash
set -euo pipefail

# Utils laden
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/utils.sh" ]; then source "$SCRIPT_DIR/utils.sh"; else source /dev/null; fi

log_section "SCHRITT: KONVERTIERUNG BASEMAP.AT (STANDARD)"

# -------------------------------------------------------------------
# Pfade & Konfiguration
# -------------------------------------------------------------------
BASE="${BASE:-/srv/build/basemap-at}"
SRC="${SRC:-$BASE/src}"
TMP="${TMP:-$BASE/tmp}"

# Input
VTPK="${VTPK:-$SRC/bmapv_vtpk_3857.vtpk}"

# Output
OUT_PMTILES="${OUT_PMTILES:-$TMP/basemap-at.pmtiles}"
OUT_MBTILES="${OUT_MBTILES:-$TMP/basemap-at.mbtiles}"
INFO_JSON="${INFO_JSON:-$TMP/basemap-at.json}"
LOG_FILE="$TMP/vtpk2mbtiles.log"

# Tools
TOOLS_DIR="${TOOLS_DIR:-$TMP/tools}"
VTPK2MBTILES_URL="${VTPK2MBTILES_URL:-https://github.com/BergWerkGIS/vtpk2mbtiles/releases/download/v0.0.0.2/vtpk2mbtiles-linux-x64-v0.0.0.2.zip}"
PMTILES_URL="${PMTILES_URL:-https://github.com/protomaps/go-pmtiles/releases/download/v1.22.1/go-pmtiles_1.22.1_Linux_x86_64.tar.gz}"

# Einstellungen
MAXZOOM="${MAXZOOM:-}"
ATTRIBUTION="${ATTRIBUTION:-© basemap.at}"
CLEANUP="${CLEANUP:-1}"

# Check Unzip
command -v unzip >/dev/null 2>&1 || { log_error "unzip fehlt"; exit 1; }

mkdir -p "$TMP" "$TOOLS_DIR"

# -------------------------------------------------------------------
# 1. Tools vorbereiten
# -------------------------------------------------------------------
export DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=1

# vtpk2mbtiles
if [[ ! -x "$TOOLS_DIR/vtpk2mbtiles" ]]; then
  log_info "Lade vtpk2mbtiles..."
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$VTPK2MBTILES_URL" -o "$TOOLS_DIR/vtpk2mbtiles.zip"
  else
    wget -q "$VTPK2MBTILES_URL" -O "$TOOLS_DIR/vtpk2mbtiles.zip"
  fi
  unzip -q -o "$TOOLS_DIR/vtpk2mbtiles.zip" -d "$TOOLS_DIR"
  rm -f "$TOOLS_DIR/vtpk2mbtiles.zip"
  chmod +x "$TOOLS_DIR/vtpk2mbtiles"
fi

# pmtiles
if [[ ! -x "$TOOLS_DIR/pmtiles" ]]; then
  log_info "Lade pmtiles..."
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$PMTILES_URL" -o "$TOOLS_DIR/pmtiles.tar.gz"
  else
    wget -q "$PMTILES_URL" -O "$TOOLS_DIR/pmtiles.tar.gz"
  fi
  tar -xzf "$TOOLS_DIR/pmtiles.tar.gz" -C "$TOOLS_DIR"
  rm -f "$TOOLS_DIR/pmtiles.tar.gz"
  if [[ -f "$TOOLS_DIR/go-pmtiles" ]]; then mv "$TOOLS_DIR/go-pmtiles" "$TOOLS_DIR/pmtiles"; fi
  chmod +x "$TOOLS_DIR/pmtiles"
fi

# -------------------------------------------------------------------
# 2. VTPK entpacken
# -------------------------------------------------------------------
RAW_DIR="$TMP/vtpk_extract"

if [[ -d "$RAW_DIR" ]]; then
  log_info "VTPK bereits entpackt: $RAW_DIR"
else
  log_info "Entpacke VTPK..."
  if [[ ! -f "$VTPK" ]]; then
    log_error "VTPK nicht gefunden: $VTPK"
    exit 2
  fi
  rm -rf "$RAW_DIR"
  mkdir -p "$RAW_DIR"
  # -q = quiet (unterdrückt die Dateiliste beim Entpacken)
  unzip -q "$VTPK" -d "$RAW_DIR"
fi

# -------------------------------------------------------------------
# 3. Metadaten & Sprites sichern
# -------------------------------------------------------------------
log_info "Verarbeite Metadaten & Sprites..."
OUT_META_DIR="$TMP"
mkdir -p "$OUT_META_DIR"

# Style extraction
if [[ -f "$RAW_DIR/p12/resources/styles/root.json" ]]; then
  mkdir -p "$OUT_META_DIR/styles"
  cp -f "$RAW_DIR/p12/resources/styles/root.json" "$OUT_META_DIR/styles/root.json"
fi

# Sprite extraction
if [[ -d "$RAW_DIR/p12/resources/sprites" ]]; then
  mkdir -p "$TMP/sprites"
  for sprite_file in sprite.json sprite.png sprite@2x.json sprite@2x.png; do
    if [[ -f "$RAW_DIR/p12/resources/sprites/$sprite_file" ]]; then
      cp -f "$RAW_DIR/p12/resources/sprites/$sprite_file" "$TMP/sprites/$sprite_file"
    fi
  done
fi

# -------------------------------------------------------------------
# 4. Konvertierung MBTiles
# -------------------------------------------------------------------
if [[ ! -f "$OUT_MBTILES" ]]; then
  log_info "Erzeuge MBTiles (vtpk2mbtiles)..."
  log_info "Logs werden geschrieben nach: $LOG_FILE"
  
  # HIER IST DIE ÄNDERUNG: Output wird nach $LOG_FILE umgeleitet
  if "$TOOLS_DIR/vtpk2mbtiles" "$RAW_DIR" "$OUT_MBTILES" false > "$LOG_FILE" 2>&1; then
      log_success "MBTiles erstellt."
  else
      log_error "Fehler bei vtpk2mbtiles. Siehe Log: $LOG_FILE"
      tail -n 20 "$LOG_FILE"
      exit 1
  fi
else
  log_info "MBTiles bereits vorhanden."
fi

# -------------------------------------------------------------------
# 5. Konvertierung PMTiles
# -------------------------------------------------------------------
log_info "Erzeuge PMTiles..."
# pmtiles output lassen wir sichtbar, da der Progress-Bar nützlich ist
"$TOOLS_DIR/pmtiles" convert "$OUT_MBTILES" "$OUT_PMTILES"

if [[ ! -f "$OUT_PMTILES" ]]; then
  log_error "PMTiles Output fehlt."
  exit 5
fi

# -------------------------------------------------------------------
# 6. Metadaten JSON
# -------------------------------------------------------------------
CURRENT_DATE=$(date +%Y-%m-%d)
FILE_SIZE=$(stat -c%s "$OUT_PMTILES")
HOST_NAME=$(hostname)
VTPK_FILENAME=$(basename "$VTPK")
PMTILES_FILENAME=$(basename "$OUT_PMTILES")

# Auto-detect Maxzoom via Python snippet
if [[ -z "$MAXZOOM" && -f "$OUT_META_DIR/styles/root.json" ]]; then
  MAXZOOM=$(OUT_META_DIR="$OUT_META_DIR" python3 - <<'PY'
import json
import os
import pathlib
root = pathlib.Path(os.environ["OUT_META_DIR"]) / "styles" / "root.json"
try:
    data = json.loads(root.read_text(encoding="utf-8"))
    value = data.get("maxzoom")
    if isinstance(value, int):
        print(value)
except Exception:
    pass
PY
)
fi
MAXZOOM="${MAXZOOM:-14}"

cat <<EOF > "$INFO_JSON"
{
  "name": "basemap.at (PMTiles)",
  "source_vtpk": "$VTPK_FILENAME",
  "dataset_date": "$CURRENT_DATE",
  "maxzoom": $MAXZOOM,
  "pmtiles_file": "$PMTILES_FILENAME",
  "pmtiles_path": "$OUT_PMTILES",
  "pmtiles_size_bytes": $FILE_SIZE,
  "built_from_host": "$HOST_NAME",
  "attribution": "$ATTRIBUTION"
}
EOF
chmod 644 "$INFO_JSON"

log_success "Fertig: $OUT_PMTILES ($FILE_SIZE bytes)"

# -------------------------------------------------------------------
# 7. Cleanup
# -------------------------------------------------------------------
if [[ "$CLEANUP" == "1" ]]; then
  log_info "Räume temporäre Dateien auf..."
  rm -rf "$RAW_DIR"
  rm -f "$OUT_MBTILES"
fi
