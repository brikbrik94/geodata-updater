#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

"$SCRIPT_DIR/download_osm.sh"
"$SCRIPT_DIR/download_basemap.sh"
"$SCRIPT_DIR/download_basemap_contours.sh"
