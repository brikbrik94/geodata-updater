#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

"$SCRIPT_DIR/convert_osm_pmtiles.sh"
"$SCRIPT_DIR/convert_basemap_at_pmtiles.sh"
