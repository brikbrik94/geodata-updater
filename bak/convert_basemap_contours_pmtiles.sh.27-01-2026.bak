#!/usr/bin/env bash
set -euo pipefail

echo "== basemap.at contours VTPK -> PMTiles (vtpk2mbtiles) =="

# -------------------------------------------------------------------
# Pfade
# -------------------------------------------------------------------
BASE="${BASE:-/srv/build/basemap-at-contours}"
SRC="${SRC:-$BASE/src}"
TMP="${TMP:-$BASE/tmp}"

VTPK="${VTPK:-$SRC/bmapvhl_vtpk_3857.vtpk}"
RAW_DIR="${RAW_DIR:-$TMP/vtpk_extract}"

OUT_PMTILES="${OUT_PMTILES:-$TMP/basemap-at-contours.pmtiles}"
OUT_MBTILES="${OUT_MBTILES:-$TMP/basemap-at-contours.mbtiles}"
OUT_META_DIR="${OUT_META_DIR:-$TMP}"
INFO_JSON="${INFO_JSON:-$TMP/basemap-at-contours.json}"
MAXZOOM="${MAXZOOM:-}"
ATTRIBUTION="${ATTRIBUTION:-© basemap.at}"

CLEANUP="${CLEANUP:-1}"
TOOLS_DIR="${TOOLS_DIR:-$TMP/tools}"
VTPK2MBTILES_URL="${VTPK2MBTILES_URL:-https://github.com/BergWerkGIS/vtpk2mbtiles/releases/download/v0.0.0.2/vtpk2mbtiles-linux-x64-v0.0.0.2.zip}"
PMTILES_VERSION="${PMTILES_VERSION:-1.22.1}"
PMTILES_URL="${PMTILES_URL:-https://github.com/protomaps/go-pmtiles/releases/download/v${PMTILES_VERSION}/go-pmtiles_${PMTILES_VERSION}_Linux_x86_64.tar.gz}"

command -v unzip >/dev/null 2>&1 || { echo "❌ unzip fehlt"; exit 1; }

mkdir -p "$TMP"

# -------------------------------------------------------------------
# 1) Tools vorbereiten
# -------------------------------------------------------------------
export DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=1

mkdir -p "$TOOLS_DIR"

if [[ ! -x "$TOOLS_DIR/vtpk2mbtiles" ]]; then
  echo "⬇️ Lade vtpk2mbtiles"
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$VTPK2MBTILES_URL" -o "$TOOLS_DIR/vtpk2mbtiles.zip"
  else
    wget -q "$VTPK2MBTILES_URL" -O "$TOOLS_DIR/vtpk2mbtiles.zip"
  fi
  unzip -q "$TOOLS_DIR/vtpk2mbtiles.zip" -d "$TOOLS_DIR"
  rm -f "$TOOLS_DIR/vtpk2mbtiles.zip"
  chmod +x "$TOOLS_DIR/vtpk2mbtiles"
fi

if [[ ! -x "$TOOLS_DIR/pmtiles" ]]; then
  echo "⬇️ Lade pmtiles"
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$PMTILES_URL" -o "$TOOLS_DIR/pmtiles.tar.gz"
  else
    wget -q "$PMTILES_URL" -O "$TOOLS_DIR/pmtiles.tar.gz"
  fi
  tar -xzf "$TOOLS_DIR/pmtiles.tar.gz" -C "$TOOLS_DIR"
  rm -f "$TOOLS_DIR/pmtiles.tar.gz"
  if [[ -f "$TOOLS_DIR/go-pmtiles" ]]; then
    mv "$TOOLS_DIR/go-pmtiles" "$TOOLS_DIR/pmtiles"
  fi
  chmod +x "$TOOLS_DIR/pmtiles"
fi

# -------------------------------------------------------------------
# 2) VTPK entpacken
# -------------------------------------------------------------------
if [[ -d "$RAW_DIR" ]]; then
  echo "✅ VTPK bereits entpackt: $RAW_DIR"
else
  echo "📦 Entpacke VTPK -> $RAW_DIR"
  if [[ ! -f "$VTPK" ]]; then
    echo "❌ VTPK nicht gefunden: $VTPK"
    exit 2
  fi
  rm -rf "$RAW_DIR"
  mkdir -p "$RAW_DIR"
  unzip -q "$VTPK" -d "$RAW_DIR"
fi

# -------------------------------------------------------------------
# 3) VTPK -> MBTiles -> PMTiles
# -------------------------------------------------------------------
echo "🧾 Kopiere VTPK Metadaten"
mkdir -p "$OUT_META_DIR"
if [[ -f "$RAW_DIR/p12/resources/styles/root.json" ]]; then
  mkdir -p "$OUT_META_DIR/styles"
  cp -f "$RAW_DIR/p12/resources/styles/root.json" "$OUT_META_DIR/styles/root.json"
fi
if [[ -d "$RAW_DIR/p12/resources/styles" ]]; then
  mkdir -p "$OUT_META_DIR/styles"
  cp -a "$RAW_DIR/p12/resources/styles/." "$OUT_META_DIR/styles/"
fi
if [[ -f "$RAW_DIR/p12/esriinfo/iteminfo.xml" ]]; then
  cp -f "$RAW_DIR/p12/esriinfo/iteminfo.xml" "$OUT_META_DIR/iteminfo.xml"
fi
if [[ -d "$RAW_DIR/p12/resources/sprites" ]]; then
  for sprite_file in sprite.json sprite.png sprite@2x.json sprite@2x.png; do
    if [[ -f "$RAW_DIR/p12/resources/sprites/$sprite_file" ]]; then
      mkdir -p "$TMP/sprites"
      cp -f "$RAW_DIR/p12/resources/sprites/$sprite_file" "$TMP/sprites/$sprite_file"
    fi
  done
fi

if [[ ! -f "$OUT_MBTILES" ]]; then
  echo "🧱 Erzeuge MBTiles"
  "$TOOLS_DIR/vtpk2mbtiles" "$RAW_DIR" "$OUT_MBTILES" false
else
  echo "ℹ️ MBTiles bereits vorhanden: $OUT_MBTILES"
fi

echo "🧠 Erzeuge PMTiles"
"$TOOLS_DIR/pmtiles" convert "$OUT_MBTILES" "$OUT_PMTILES"

if [[ ! -f "$OUT_PMTILES" ]]; then
  echo "❌ PMTiles Output fehlt"
  exit 5
fi

CURRENT_DATE=$(date +%Y-%m-%d)
FILE_SIZE=$(stat -c%s "$OUT_PMTILES")
HOST_NAME=$(hostname)
VTPK_FILENAME=$(basename "$VTPK")
PMTILES_FILENAME=$(basename "$OUT_PMTILES")
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
  "name": "basemap.at contours (PMTiles)",
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

echo "✅ Fertig"
echo " - PMTiles : $OUT_PMTILES"

if [[ "$CLEANUP" == "1" ]]; then
  echo "🧹 Räume temporäre Dateien auf"
  rm -rf "$RAW_DIR"
  rm -f "$OUT_MBTILES"
fi
