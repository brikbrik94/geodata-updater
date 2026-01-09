#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

TILES_DIR="${TILES_DIR:-/srv/tiles}"
BUILD_DIR="${BUILD_DIR:-/srv/build}"
STYLE_ID="${STYLE_ID:-}"
STYLES_FALLBACK_DIR="${STYLES_SOURCE_DIR:-$REPO_ROOT/styles}"

deploy_stylesheets() {
  local tileset_id="$1"
  local styles_source_dir="$2"
  local style_id="${3:-$tileset_id}"
  local copied=0

  if [[ ! -d "$styles_source_dir" ]]; then
    echo "❌ Stylesheet-Verzeichnis nicht gefunden: $styles_source_dir"
    return 1
  fi

  if [[ -f "$styles_source_dir/style.json" ]]; then
    local dest_dir="$TILES_DIR/$tileset_id/styles/$style_id"
    mkdir -p "$dest_dir"
    echo "📦 Deploye $styles_source_dir/style.json -> $dest_dir/style.json"
    cp -f "$styles_source_dir/style.json" "$dest_dir/style.json"
    chmod 644 "$dest_dir/style.json"
    copied=$((copied + 1))
  fi

  if [[ -f "$styles_source_dir/root.json" ]]; then
    local dest_dir="$TILES_DIR/$tileset_id/styles/$style_id"
    mkdir -p "$dest_dir"
    echo "📦 Deploye $styles_source_dir/root.json -> $dest_dir/style.json"
    cp -f "$styles_source_dir/root.json" "$dest_dir/style.json"
    chmod 644 "$dest_dir/style.json"
    copied=$((copied + 1))
  fi

  mapfile -t style_files < <(find "$styles_source_dir" -mindepth 3 -maxdepth 3 -name style.json)
  for style_file in "${style_files[@]}"; do
    rel_path="${style_file#$styles_source_dir/}"
    tileset="${rel_path%%/*}"
    remainder="${rel_path#*/}"
    style_name="${remainder%%/*}"

    if [[ -z "$tileset" || -z "$style_name" || "$tileset" == "$style_name" ]]; then
      echo "⚠️ Überspringe unerwarteten Pfad: $style_file"
      continue
    fi

    if [[ "$tileset" != "$tileset_id" ]]; then
      continue
    fi

    dest_dir="$TILES_DIR/$tileset/styles/$style_name"
    mkdir -p "$dest_dir"
    echo "📦 Deploye $style_file -> $dest_dir/style.json"
    cp -f "$style_file" "$dest_dir/style.json"
    chmod 644 "$dest_dir/style.json"
    copied=$((copied + 1))

  done

  if [[ "$copied" -eq 0 ]]; then
    echo "❌ Keine Stylesheets gefunden. Lege style.json in $styles_source_dir oder unter $styles_source_dir/<tileset>/<style-id>/style.json ab."
    return 1
  fi

  echo "✅ Stylesheet Deployment abgeschlossen ($copied Datei(en)) für Tileset $tileset_id."
}

copied_total=0
found_tilesets=0

while IFS= read -r -d '' tmp_dir; do
  tileset_id="$(basename "$(dirname "$tmp_dir")")"
  metadata_dir="$tmp_dir/metadata"

  if [[ -d "$metadata_dir/styles" ]]; then
    styles_source_dir="$metadata_dir/styles"
    echo "ℹ️ Verwende Stylesheets aus $styles_source_dir (Tileset $tileset_id)"
  elif [[ -d "$metadata_dir" ]]; then
    styles_source_dir="$metadata_dir"
    echo "ℹ️ Verwende Stylesheets aus $styles_source_dir (Tileset $tileset_id)"
  else
    styles_source_dir="$STYLES_FALLBACK_DIR"
    echo "ℹ️ Kein Metadata-Ordner für Tileset $tileset_id gefunden, verwende Fallback $styles_source_dir"
  fi

  deploy_stylesheets "$tileset_id" "$styles_source_dir" "$STYLE_ID"
  copied_total=$((copied_total + 1))
  found_tilesets=1
done < <(find "$BUILD_DIR" -mindepth 2 -maxdepth 2 -type d -name tmp -print0)

if [[ "$found_tilesets" -eq 0 ]]; then
  echo "❌ Keine Tileset-TMP-Ordner unter $BUILD_DIR gefunden."
  exit 1
fi

echo "✅ Stylesheet Deployment abgeschlossen für $copied_total Tileset(s)."
