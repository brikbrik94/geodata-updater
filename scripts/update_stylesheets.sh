#!/bin/bash
set -euo pipefail

# 1. Utils & Config laden
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/utils.sh" ]; then
    source "$SCRIPT_DIR/utils.sh"
else
    echo "❌ Fehler: utils.sh nicht gefunden!"
    exit 1
fi

log_section "PHASE 5b: STYLESHEET UPDATE (Python)"

# --- UMGEBUNG VORBEREITEN ---

# Config-Variablen exportieren, damit Python sie lesen kann
export TILES_DIR="${TILES_DIR:-/srv/tiles}"
export TILES_BASE_URL="${TILES_BASE_URL:-}"
export ASSETS_BASE_URL="${ASSETS_BASE_URL:-$TILES_BASE_URL}"
export ENDPOINTS_INFO_PATH="${ENDPOINTS_INFO_PATH:-/srv/info/endpoints_info.json}"

# Templates (falls in config.env gesetzt)
export SPRITE_URL_TEMPLATE="${SPRITE_URL_TEMPLATE:-}"
export GLYPHS_URL_TEMPLATE="${GLYPHS_URL_TEMPLATE:-}"

# Falls du manuelle Mappings hast
export PMTILES_FILE_MAP="${PMTILES_FILE_MAP:-}"
export PMTILES_FILE="${PMTILES_FILE:-}"

# Python Skript Pfad
PYTHON_SCRIPT="$SCRIPT_DIR/update_stylesheets.py"

# --- AUSFÜHREN ---
if [ -f "$PYTHON_SCRIPT" ]; then
    python3 "$PYTHON_SCRIPT"
else
    log_error "Python-Worker nicht gefunden: $PYTHON_SCRIPT"
    exit 1
fi

log_success "Stylesheet Updates abgeschlossen."
