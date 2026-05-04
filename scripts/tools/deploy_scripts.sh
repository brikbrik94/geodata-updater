#!/bin/bash
set -euo pipefail

# Verzeichnis dieses Skripts ermitteln
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Da das Skript nun in scripts/tools/ liegt, müssen wir zwei Ebenen nach oben
REPO_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"

# Zielverzeichnisse auf dem Server (Standard: /srv)
TARGET_BASE="${TARGET_BASE:-/srv}"
TARGET_DIR="$TARGET_BASE/scripts"
CONF_TARGET="$TARGET_BASE/conf"
STYLE_TARGET="$TARGET_BASE/styles"
DOCS_TARGET="$TARGET_BASE/docs"

# Tool-Check
if ! command -v rsync &> /dev/null; then
    echo "❌ Fehler: rsync ist nicht installiert. Bitte mit 'apt install rsync' nachholen."
    exit 1
fi

sync_dir() {
    local src_dir="$1"
    local dst_dir="$2"
    local label="$3"

    if [ ! -d "$src_dir" ]; then
        echo "⚠️  Quelle fehlt, überspringe: $src_dir"
        return
    fi

    mkdir -p "$dst_dir"
    echo "👉 Synchronisiere $label -> $dst_dir ..."
    
    # rsync: -a (archive), -v (verbose), --delete (entfernt Dateien im Ziel, die in Quelle fehlen)
    # --exclude: Schützt Git-Daten und Python Caches
    rsync -av --delete \
        --exclude ".git/" \
        --exclude "__pycache__/" \
        --exclude "*.bak" \
        "$src_dir/" "$dst_dir/"
}

echo "========================================"
echo " DEPLOY: GIT -> LIVE SYSTEM (RSYNC)"
echo "========================================"
echo "Repo Root:   $REPO_ROOT"
echo "Ziel-Basis:  $TARGET_BASE"

# 1. Scripts
sync_dir "$REPO_ROOT/scripts" "$TARGET_DIR" "Scripts"

# 2. Config
sync_dir "$REPO_ROOT/conf" "$CONF_TARGET" "Config"

# 3. Styles
sync_dir "$REPO_ROOT/styles" "$STYLE_TARGET" "Styles"

# 4. Dokumentation
sync_dir "$REPO_ROOT/docs" "$DOCS_TARGET" "Docs"

# 5. Rechte setzen (Sicherheitshalber für Skripte)
echo "🔧 Setze Ausführungsrechte..."
find "$TARGET_DIR" -type f -name "*.sh" -exec chmod +x {} +
find "$TARGET_DIR" -type f -name "*.py" -exec chmod +x {} +

echo ""
echo "✅ Synchronisation erfolgreich abgeschlossen."
