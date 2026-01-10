#!/bin/bash
set -euo pipefail

MAP_ICONS_REF="${MAP_ICONS_REF:-master}"
MAP_ICONS_URL="${MAP_ICONS_URL:-https://github.com/openstreetmap/map-icons/archive/refs/heads/${MAP_ICONS_REF}.zip}"
SPRITE_NAME="${SPRITE_NAME:-classic.small}"
ASSETS_DIR="${ASSETS_DIR:-/srv/assets}"
ATTRIBUTION_DIR="${ATTRIBUTION_DIR:-/srv/info/attribution}"
SPRITES_DIR="$ASSETS_DIR/sprites"
ATTRIBUTION_TARGET="$ATTRIBUTION_DIR/map-icons"
SPREET_IMAGE="${SPREET_IMAGE:-ghcr.io/flother/spreet:latest}"
TMP_DIR="$(mktemp -d)"
cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

mkdir -p "$SPRITES_DIR" "$ATTRIBUTION_TARGET"

ZIP_PATH="$TMP_DIR/map-icons.zip"

echo "[1/4] Lade map-icons von $MAP_ICONS_URL herunter..."
curl -fsSL "$MAP_ICONS_URL" -o "$ZIP_PATH"

echo "[2/4] Entpacke Archiv..."
unzip -q "$ZIP_PATH" -d "$TMP_DIR"

ICONS_ROOT="$(find "$TMP_DIR" -maxdepth 1 -type d -name 'map-icons-*' | head -n 1)"
if [[ -z "$ICONS_ROOT" ]]; then
  echo "❌ Konnte map-icons Ordner nicht finden."
  exit 1
fi

SVG_DIR="$ICONS_ROOT/$SPRITE_NAME"
if [[ ! -d "$SVG_DIR" ]]; then
  echo "❌ SVG-Ordner nicht gefunden: $SVG_DIR"
  exit 1
fi

SPRITE_PNG="$SPRITES_DIR/$SPRITE_NAME.png"
SPRITE_JSON="$SPRITES_DIR/$SPRITE_NAME.json"
SPRITE_PNG_2X="$SPRITES_DIR/$SPRITE_NAME@2x.png"
SPRITE_JSON_2X="$SPRITES_DIR/$SPRITE_NAME@2x.json"

if ! command -v docker >/dev/null 2>&1; then
  echo "❌ Docker nicht gefunden. Bitte installiere Docker."
  exit 1
fi

SPREET_INPUT_DIR="/work/input"
SPREET_OUTPUT_DIR="/work/output"

run_spreet() {
  docker run --rm \
    -v "$SVG_DIR:$SPREET_INPUT_DIR:ro" \
    -v "$SPRITES_DIR:$SPREET_OUTPUT_DIR" \
    "$SPREET_IMAGE" \
    spreet "$@"
}

echo "[3/4] Erzeuge Sprite via spreet..."
SPREET_HELP="$(run_spreet --help 2>&1 || true)"
if echo "$SPREET_HELP" | grep -q -- "--data"; then
  if echo "$SPREET_HELP" | grep -q -- "--ratio"; then
    run_spreet --data "$SPREET_OUTPUT_DIR/$SPRITE_NAME.json" --sheet "$SPREET_OUTPUT_DIR/$SPRITE_NAME.png" --ratio 1 "$SPREET_INPUT_DIR"
    run_spreet --data "$SPREET_OUTPUT_DIR/$SPRITE_NAME@2x.json" --sheet "$SPREET_OUTPUT_DIR/$SPRITE_NAME@2x.png" --ratio 2 "$SPREET_INPUT_DIR"
  else
    run_spreet --data "$SPREET_OUTPUT_DIR/$SPRITE_NAME.json" --sheet "$SPREET_OUTPUT_DIR/$SPRITE_NAME.png" "$SPREET_INPUT_DIR"
    run_spreet --data "$SPREET_OUTPUT_DIR/$SPRITE_NAME@2x.json" --sheet "$SPREET_OUTPUT_DIR/$SPRITE_NAME@2x.png" --retina "$SPREET_INPUT_DIR"
  fi
elif echo "$SPREET_HELP" | grep -q -- "--output"; then
  if echo "$SPREET_HELP" | grep -q -- "--ratio"; then
    run_spreet --output "$SPREET_OUTPUT_DIR/$SPRITE_NAME" --ratio 1 "$SPREET_INPUT_DIR"
    run_spreet --output "$SPREET_OUTPUT_DIR/$SPRITE_NAME@2x" --ratio 2 "$SPREET_INPUT_DIR"
  else
    run_spreet --output "$SPREET_OUTPUT_DIR/$SPRITE_NAME" "$SPREET_INPUT_DIR"
    run_spreet --output "$SPREET_OUTPUT_DIR/$SPRITE_NAME@2x" --retina "$SPREET_INPUT_DIR"
  fi
else
  echo "❌ Unbekannte spreet-CLI. Bitte prüfe 'spreet --help'."
  exit 1
fi

for file in LICENSE LICENSE.txt COPYING README README.md; do
  if [[ -f "$ICONS_ROOT/$file" ]]; then
    cp -f "$ICONS_ROOT/$file" "$ATTRIBUTION_TARGET/"
  fi
done

cat > "$ATTRIBUTION_TARGET/SOURCE.txt" <<SOURCE
Source: https://github.com/openstreetmap/map-icons
Ref: $MAP_ICONS_REF
Archive: $MAP_ICONS_URL
Sprite: $SPRITE_NAME
Downloaded: $(date -u +"%Y-%m-%dT%H:%M:%SZ")
SOURCE

echo "[4/4] Fertig. Sprite: $SPRITE_PNG / $SPRITE_JSON"
echo "[4/4] Fertig. Sprite (@2x): $SPRITE_PNG_2X / $SPRITE_JSON_2X"
echo "Attribution: $ATTRIBUTION_TARGET"
