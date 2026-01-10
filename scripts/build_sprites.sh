#!/bin/bash
set -euo pipefail

MAP_ICONS_REF="${MAP_ICONS_REF:-master}"
MAP_ICONS_URL="https://github.com/openstreetmap/map-icons/archive/refs/heads/${MAP_ICONS_REF}.zip"
SPRITE_NAME="classic.small"
ASSETS_DIR="${ASSETS_DIR:-/srv/assets}"
SPRITES_DIR="$ASSETS_DIR/sprite"
SPREET_IMAGE="${SPREET_IMAGE:-ghcr.io/flother/spreet:latest}"

TMP_DIR="$(mktemp -d)"
cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

mkdir -p "$SPRITES_DIR"

ZIP_PATH="$TMP_DIR/map-icons.zip"
curl -fsSL "$MAP_ICONS_URL" -o "$ZIP_PATH"
unzip -q "$ZIP_PATH" -d "$TMP_DIR"

ICONS_ROOT="$(find "$TMP_DIR" -maxdepth 1 -type d -name 'map-icons-*' | head -n 1)"
if [[ -z "$ICONS_ROOT" ]]; then
  echo "map-icons Ordner nicht gefunden."
  exit 1
fi

SVG_DIR="$ICONS_ROOT/$SPRITE_NAME"
if [[ ! -d "$SVG_DIR" ]]; then
  echo "SVG-Ordner nicht gefunden: $SVG_DIR"
  exit 1
fi

docker run --rm \
  -v "$SVG_DIR:/work/input:ro" \
  -v "$SPRITES_DIR:/work/output" \
  "$SPREET_IMAGE" \
  spreet "/work/input" "/work/output/$SPRITE_NAME" --retina
