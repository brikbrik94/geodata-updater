#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

TILES_DIR="${TILES_DIR:-/srv/tiles}"
TILESET_ID="${TILESET_ID:-osm}"
STYLE_ID="${STYLE_ID:-$TILESET_ID}"
STYLES_SOURCE_DIR="${STYLES_SOURCE_DIR:-$REPO_ROOT/styles}"
TMP_DIR="${TMP_DIR:-/srv/build/$TILESET_ID/tmp}"
METADATA_DIR="${METADATA_DIR:-$TMP_DIR/metadata}"

if [[ -d "$METADATA_DIR/styles" ]]; then
  STYLES_SOURCE_DIR="$METADATA_DIR/styles"
  echo "ℹ️ Verwende Stylesheets aus $STYLES_SOURCE_DIR"
elif [[ -d "$METADATA_DIR" ]]; then
  STYLES_SOURCE_DIR="$METADATA_DIR"
  echo "ℹ️ Verwende Stylesheets aus $STYLES_SOURCE_DIR"
fi

if [[ ! -d "$STYLES_SOURCE_DIR" ]]; then
  echo "❌ Stylesheet-Verzeichnis nicht gefunden: $STYLES_SOURCE_DIR"
  exit 1
fi

copied=0

if [[ -f "$STYLES_SOURCE_DIR/style.json" ]]; then
  dest_dir="$TILES_DIR/$TILESET_ID/styles/$STYLE_ID"
  mkdir -p "$dest_dir"
  echo "📦 Deploye $STYLES_SOURCE_DIR/style.json -> $dest_dir/style.json"
  cp -f "$STYLES_SOURCE_DIR/style.json" "$dest_dir/style.json"
  chmod 644 "$dest_dir/style.json"
  copied=$((copied + 1))
fi

if [[ -f "$STYLES_SOURCE_DIR/root.json" ]]; then
  dest_dir="$TILES_DIR/$TILESET_ID/styles/$STYLE_ID"
  mkdir -p "$dest_dir"
  echo "📦 Deploye $STYLES_SOURCE_DIR/root.json -> $dest_dir/style.json"
  cp -f "$STYLES_SOURCE_DIR/root.json" "$dest_dir/style.json"
  chmod 644 "$dest_dir/style.json"
  copied=$((copied + 1))
fi

mapfile -t style_files < <(find "$STYLES_SOURCE_DIR" -mindepth 3 -maxdepth 3 -name style.json)
for style_file in "${style_files[@]}"; do
  rel_path="${style_file#$STYLES_SOURCE_DIR/}"
  tileset="${rel_path%%/*}"
  remainder="${rel_path#*/}"
  style_name="${remainder%%/*}"

  if [[ -z "$tileset" || -z "$style_name" || "$tileset" == "$style_name" ]]; then
    echo "⚠️ Überspringe unerwarteten Pfad: $style_file"
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
  echo "❌ Keine Stylesheets gefunden. Lege style.json in $STYLES_SOURCE_DIR oder unter $STYLES_SOURCE_DIR/<tileset>/<style-id>/style.json ab."
  exit 1
fi

echo "✅ Stylesheet Deployment abgeschlossen ($copied Datei(en))."
