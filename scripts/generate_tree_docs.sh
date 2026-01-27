#!/bin/bash
set -euo pipefail

# --- KONFIGURATION ---
DOC_FILE="/srv/docs/FOLDER_STRUCTURE.md"
ROOT_DIR="/srv"

# Utils laden
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/utils.sh" ]; then
    source "$SCRIPT_DIR/utils.sh"
else
    # Fallback
    log_section() { echo "=== $1 ==="; }
    log_info() { echo "INFO: $1"; }
    log_error() { echo "ERROR: $1"; }
    log_success() { echo "SUCCESS: $1"; }
fi

log_section "DOKUMENTATION UPDATE: FOLDER STRUCTURE"

if ! command -v tree &> /dev/null; then
    log_error "'tree' ist nicht installiert. Bitte 'sudo apt-get install tree' ausführen."
    exit 1
fi

log_info "Analysiere Dateistruktur in $ROOT_DIR..."

# Header schreiben
cat <<EODOC > "$DOC_FILE"
# Detaillierte Ordnerstruktur

Dies ist die aktuelle Struktur auf dem Server ($ROOT_DIR), automatisch generiert am $(date +%Y-%m-%d).

EODOC

# Tree Befehl ausführen
# Änderungen:
# - Entfernt: --prune (Damit Font-Ordner sichtbar bleiben, auch wenn ihr Inhalt ausgeblendet ist)
# - Beibehalten: -I (Filtert die Font-Dateien selbst weg)
{
    echo '```'
    tree "$ROOT_DIR" \
        -L 4 \
        --dirsfirst \
        -I 'node_modules|venv|.git|__pycache__|src|tmp|merged|.list|[0-9]*-[0-9]*.pbf' \
        -P "*.sh|*.json|*.txt|*.pmtiles|*.pbf|*.md|*.html" \
        --ignore-case \
        --matchdirs \
        --filelimit 15
    echo '```'
} >> "$DOC_FILE"

# Erklärung anhängen
cat <<EODOC >> "$DOC_FILE"

## Legende

- **scripts/**: Enthält die Pipeline-Logik.
- **tiles/**: Der öffentliche Web-Ordner (Nginx Root).
- **build/**: Arbeitsverzeichnis (Downloads & Zwischenschritte).
- **assets/**: Fonts und Sprites.
- **conf/sources/**: Konfigurationen der einzelnen Karten.
EODOC

log_success "Dokumentation aktualisiert: $DOC_FILE"
