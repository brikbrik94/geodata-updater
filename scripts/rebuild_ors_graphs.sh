#!/bin/bash
set -euo pipefail

ORS_DIR="${ORS_DIR:-/srv/ors}"
REBUILD_CMD="${ORS_REBUILD_CMD:-}"

if [ -n "$REBUILD_CMD" ]; then
    echo "Starte ORS-Graphenbuild mit ORS_REBUILD_CMD..."
    bash -lc "$REBUILD_CMD"
    exit 0
fi

if [ -x "$ORS_DIR/rebuild_graphs.sh" ]; then
    echo "Starte ORS-Graphenbuild via $ORS_DIR/rebuild_graphs.sh..."
    "$ORS_DIR/rebuild_graphs.sh"
    exit 0
fi

cat <<EOM
❌ FEHLER: Keine ORS-Graphenbuild-Definition gefunden.

Lege ein ausführbares Skript unter $ORS_DIR/rebuild_graphs.sh an
oder setze die Umgebungsvariable ORS_REBUILD_CMD auf den gewünschten Befehl.
EOM
exit 1
