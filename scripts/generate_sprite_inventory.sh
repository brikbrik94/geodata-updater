#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/utils.sh" ]; then
    source "$SCRIPT_DIR/utils.sh"
else
    echo "❌ Fehler: utils.sh nicht gefunden!"
    exit 1
fi

SPRITES_DIR="${SPRITES_DIR:-${ASSETS_DIR:-/srv/assets}/sprites}"
SPRITE_INVENTORY_PATH="${SPRITE_INVENTORY_PATH:-${INFO_DIR:-/srv/info}/${SPRITE_INVENTORY_FILE:-sprite_inventory.json}}"
PYTHON_SCRIPT="$SCRIPT_DIR/generate_sprite_inventory.py"

if [ ! -f "$PYTHON_SCRIPT" ]; then
    log_error "Python-Skript nicht gefunden: $PYTHON_SCRIPT"
    exit 1
fi

log_info "Generiere Sprite-Inventory..."
SPRITES_DIR="$SPRITES_DIR" SPRITE_INVENTORY_PATH="$SPRITE_INVENTORY_PATH" python3 "$PYTHON_SCRIPT"
