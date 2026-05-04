#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/utils.sh" ]; then source "$SCRIPT_DIR/utils.sh"; else exit 1; fi

log_section "GENERIERUNG: TILES INVENTORY"

export TILES_DIR="${TILES_DIR:-/srv/tiles}"
export TILES_BASE_URL="${TILES_BASE_URL:-}"
# NEU: Eigener Pfad für das Teil-Inventory
export TILES_INVENTORY_PATH="${TILES_INVENTORY_PATH:-/srv/info/tiles_inventory.json}"

PYTHON_SCRIPT="$SCRIPT_DIR/generate_tiles_inventory.py"

if [ -f "$PYTHON_SCRIPT" ]; then
    python3 "$PYTHON_SCRIPT"
else
    log_error "Skript nicht gefunden: $PYTHON_SCRIPT"
    exit 1
fi
