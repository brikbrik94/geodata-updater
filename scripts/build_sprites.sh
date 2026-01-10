#!/bin/bash
set -euo pipefail

MAP_ICONS_REF="${MAP_ICONS_REF:-master}"
MAP_ICONS_URL="${MAP_ICONS_URL:-https://github.com/openstreetmap/map-icons/archive/refs/heads/${MAP_ICONS_REF}.zip}"
SPRITE_NAME="${SPRITE_NAME:-classic.small}"
ASSETS_DIR="${ASSETS_DIR:-/srv/assets}"
ATTRIBUTION_DIR="${ATTRIBUTION_DIR:-/srv/info/attribution}"
SPRITES_DIR="$ASSETS_DIR/sprites"
ATTRIBUTION_TARGET="$ATTRIBUTION_DIR/map-icons"
SPRITEZERO_IMAGE="${SPRITEZERO_IMAGE:-docker.io/mapbox/spritezero:latest}"

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

if command -v spritezero >/dev/null 2>&1; then
  echo "[3/4] Erzeuge Sprite via spritezero..."
  spritezero --output "$SPRITE_PNG" --json "$SPRITE_JSON" "$SVG_DIR"
elif command -v docker >/dev/null 2>&1; then
  echo "[3/4] Erzeuge Sprite via Docker ($SPRITEZERO_IMAGE)..."
  if ! docker pull "$SPRITEZERO_IMAGE" >/dev/null 2>&1; then
    echo "❌ Docker-Image $SPRITEZERO_IMAGE konnte nicht geladen werden."
    echo "   Hinweis: Setze SPRITEZERO_IMAGE auf ein erreichbares Image"
    echo "   oder installiere spritezero-cli lokal."
    exit 1
  fi
  docker run --rm \
    -v "$SVG_DIR:/work/input:ro" \
    -v "$SPRITES_DIR:/work/output" \
    "$SPRITEZERO_IMAGE" \
    spritezero --output "/work/output/$SPRITE_NAME.png" --json "/work/output/$SPRITE_NAME.json" /work/input
else
  echo "❌ Weder 'spritezero' noch 'docker' gefunden. Bitte installiere spritezero-cli oder Docker."
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
echo "Attribution: $ATTRIBUTION_TARGET"
