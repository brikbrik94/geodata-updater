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

log_header "DOWNLOAD: OPENSKIMAP"

# 2. Verzeichnis sicherstellen
# Nutzt die neue Variable aus Schritt 1
mkdir -p "$SKIMAP_BUILD_DIR"
cd "$SKIMAP_BUILD_DIR"

# 3. Download mit wget (Timestamp-Prüfung)
URL="https://tiles.openskimap.org/openskidata.gpkg"
FILENAME="openskidata.gpkg"

log_info "Prüfe auf neue OpenSkimap-Daten..."

# -N sorgt dafür, dass nur geladen wird, wenn die Datei auf dem Server neuer ist
if wget -q -N "$URL"; then
    log_success "Download erfolgreich oder Datei bereits aktuell."
else
    log_error "Fehler beim Download von $URL"
    exit 1
fi

log_info "Speicherort: $SKIMAP_BUILD_DIR/$FILENAME"
