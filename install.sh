#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SETUP_SCRIPT="$SCRIPT_DIR/scripts/setup.sh"

if [ -x "$SETUP_SCRIPT" ]; then
    "$SETUP_SCRIPT"
else
    echo "FEHLER: setup.sh wurde nicht gefunden oder ist nicht ausführbar: $SETUP_SCRIPT"
    exit 1
fi
