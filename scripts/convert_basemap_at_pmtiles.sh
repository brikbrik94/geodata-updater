#!/usr/bin/env bash
set -euo pipefail

echo "== basemap.at VTPK -> PMTiles =="

# -------------------------------------------------------------------
# Pfade
# -------------------------------------------------------------------
BASE="${BASE:-/srv/build/basemap-at}"
SRC="${SRC:-$BASE/src}"
TMP="${TMP:-$BASE/tmp}"

VTPK="${VTPK:-$SRC/bmapv_vtpk_3857.vtpk}"
RAW_DIR="${RAW_DIR:-$SRC/vtpk_raw}"
P12_DIR="${P12_DIR:-$RAW_DIR/p12}"

OUT_PMTILES="${OUT_PMTILES:-$TMP/basemap-at.pmtiles}"
OUT_META="${OUT_META:-$TMP/metadaten.json}"

CLEANUP="${CLEANUP:-1}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

command -v unzip >/dev/null 2>&1 || { echo "❌ unzip fehlt"; exit 1; }
command -v python3 >/dev/null 2>&1 || { echo "❌ python3 fehlt"; exit 1; }

mkdir -p "$TMP"

# -------------------------------------------------------------------
# 0) VTPK entpacken (falls noch nicht passiert)
# -------------------------------------------------------------------
if [[ -d "$P12_DIR" && -f "$P12_DIR/root.json" && -d "$P12_DIR/tile" ]]; then
  echo "✅ VTPK bereits entpackt: $P12_DIR"
else
  echo "📦 Entpacke VTPK -> $RAW_DIR"
  if [[ ! -f "$VTPK" ]]; then
    echo "❌ VTPK nicht gefunden: $VTPK"
    exit 2
  fi
  rm -rf "$RAW_DIR"
  mkdir -p "$RAW_DIR"
  unzip -q "$VTPK" -d "$RAW_DIR"

  if [[ ! -d "$P12_DIR" ]]; then
    echo "❌ p12 Ordner nicht gefunden nach unzip"
    find "$RAW_DIR" -maxdepth 3 -type d
    exit 3
  fi
fi

# -------------------------------------------------------------------
# 1) Esri CompactV2 (.bundle) -> PMTiles (streaming)
# -------------------------------------------------------------------
echo "🧠 Extrahiere .bundle Tiles -> PMTiles"

python3 "$SCRIPT_DIR/vtpk_bundle_to_pmtiles.py" \
  --tiles "$P12_DIR/tile" \
  --output "$OUT_PMTILES"

# -------------------------------------------------------------------
# 2) metadata.json robust reparieren
# -------------------------------------------------------------------
echo "🧾 Erzeuge metadaten.json"

python3 "$SCRIPT_DIR/fix_metadata_json.py" \
  --input "$P12_DIR/metadata.json" \
  --output "$OUT_META"

if [[ ! -f "$OUT_PMTILES" ]]; then
  echo "❌ PMTiles Output fehlt"
  exit 5
fi

echo "✅ Fertig"
echo " - PMTiles : $OUT_PMTILES"
echo " - Metadata: $OUT_META"

if [[ "$CLEANUP" == "1" ]]; then
  echo "🧹 Räume temporäre Dateien auf"
  rm -rf "$RAW_DIR"
fi
