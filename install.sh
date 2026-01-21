#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SETUP_SCRIPT="$SCRIPT_DIR/scripts/setup.sh"
FONTS_SCRIPT="$SCRIPT_DIR/scripts/install_fonts.sh"

if [ -x "$SETUP_SCRIPT" ]; then
    "$SETUP_SCRIPT"
else
    echo "FEHLER: setup.sh wurde nicht gefunden oder ist nicht ausführbar: $SETUP_SCRIPT"
    exit 1
fi

if [ -x "$FONTS_SCRIPT" ]; then
    "$FONTS_SCRIPT"
else
    echo "FEHLER: install_fonts.sh wurde nicht gefunden oder ist nicht ausführbar: $FONTS_SCRIPT"
    exit 1
fi
