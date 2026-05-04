#!/bin/bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

log_section "GENERIERUNG: MASTER ENDPOINTS INFO"

export ENDPOINTS_INFO_PATH="${ENDPOINTS_INFO_PATH:-/srv/info/endpoints_info.json}"
PYTHON_SCRIPT="$SCRIPT_DIR/generate_endpoints_info.py"

if [ -f "$PYTHON_SCRIPT" ]; then
    python3 "$PYTHON_SCRIPT"
else
    log_error "Skript nicht gefunden: $PYTHON_SCRIPT"
    exit 1
fi
