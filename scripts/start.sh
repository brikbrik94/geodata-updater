#!/bin/bash
set -euo pipefail

REBUILD_ORS=0
for arg in "$@"; do
    case "$arg" in
        --rebuild-ors|-o)
            REBUILD_ORS=1
            ;;
        --help|-h)
            echo "Usage: $0 [--rebuild-ors|-o]"
            exit 0
            ;;
        *)
            echo "Unbekannte Option: $arg"
            echo "Usage: $0 [--rebuild-ors|-o]"
            exit 1
            ;;
    esac
done

if [ "$REBUILD_ORS" -eq 0 ] && [ -t 0 ]; then
    read -r -p "ORS-Graphen neu bauen? (y/N): " reply
    case "$reply" in
        [yY]|[yY][eE][sS])
            REBUILD_ORS=1
            ;;
    esac
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

"$SCRIPT_DIR/run_download.sh"
"$SCRIPT_DIR/run_merge.sh"
"$SCRIPT_DIR/run_pmtiles.sh"

if [ "$REBUILD_ORS" -eq 1 ]; then
    "$SCRIPT_DIR/run_ors.sh"
fi
