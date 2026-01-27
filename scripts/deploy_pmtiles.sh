#!/usr/bin/env bash
set -euo pipefail

TILES_DIR="${TILES_DIR:-/srv/tiles}"
BUILD_DIR="${BUILD_DIR:-/srv/build}"

DEFAULT_TARGETS=(
  "osm:at-plus.pmtiles"
  "basemap-at:basemap-at.pmtiles"
  "overlays:basemap-at-contours.pmtiles"
)

if [[ -n "${PMTILES_TARGETS:-}" ]]; then
  mapfile -t TARGETS <<<"${PMTILES_TARGETS}"
else
  TARGETS=("${DEFAULT_TARGETS[@]}")
fi

missing=0

for target in "${TARGETS[@]}"; do
  if [[ "$target" != *:* ]]; then
    echo "❌ Ungültiger Eintrag in PMTILES_TARGETS: '$target' (erwartet: tileset:datei.pmtiles)"
    missing=1
    continue
  fi

  tileset="${target%%:*}"
  filename="${target#*:}"
  src="$BUILD_DIR/$tileset/tmp/$filename"
  dest_dir="$TILES_DIR/$tileset/pmtiles"
  dest="$dest_dir/$filename"

  if [[ ! -f "$src" ]]; then
    echo "❌ Quelle fehlt: $src"
    missing=1
    continue
  fi

  mkdir -p "$dest_dir"
  if [[ -f "$dest" ]]; then
    echo "🗑️ Entferne alte PMTiles: $dest"
    rm -f "$dest"
  fi

  echo "📦 Deploye $src -> $dest"
  cp -f "$src" "$dest"
  chmod 644 "$dest"
  echo "✅ OK: $dest"

done

if [[ "$missing" -ne 0 ]]; then
  echo "❌ Deployment fehlgeschlagen: fehlende Quellen oder ungültige Targets."
  exit 1
fi

echo "✅ PMTiles Deployment abgeschlossen."
