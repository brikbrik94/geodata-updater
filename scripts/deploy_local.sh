#!/bin/bash
set -euo pipefail

# Verzeichnis dieses Skripts ermitteln
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

# Zielverzeichnisse auf dem Server
TARGET_BASE="/srv"
TARGET_DIR="$TARGET_BASE/scripts"
CONF_TARGET="$TARGET_BASE/conf"
STYLE_TARGET="$TARGET_BASE/styles"
DOCS_TARGET="$TARGET_BASE/docs"

copy_dir_contents() {
    local src_dir="$1"
    local dst_dir="$2"

    if [ ! -d "$src_dir" ]; then
        echo "⚠️  Verzeichnis fehlt, überspringe: $src_dir"
        return
    fi

    mkdir -p "$dst_dir"

    # Alles kopieren, inkl. Unterordnern, ohne von einem externen Repo-Pfad abhängig zu sein
    # (dotfiles werden hier bewusst nicht benötigt)
    cp -a "$src_dir/." "$dst_dir/"
}

echo "========================================"
echo " DEPLOY: GIT -> LIVE SYSTEM"
echo "========================================"
echo "Repo Root:   $REPO_ROOT"
echo "Ziel-Basis:  $TARGET_BASE"

# Zielordner erstellen
mkdir -p "$TARGET_DIR" "$CONF_TARGET" "$STYLE_TARGET" "$DOCS_TARGET"

# 1. Scripts komplett kopieren (inkl. Unterordner wie scripts/archive)
echo "👉 Kopiere scripts/ nach $TARGET_DIR ..."
copy_dir_contents "$REPO_ROOT/scripts" "$TARGET_DIR"

# 2. Config komplett kopieren (inkl. sprite_mapping.json, sources, etc.)
echo "👉 Kopiere conf/ nach $CONF_TARGET ..."
copy_dir_contents "$REPO_ROOT/conf" "$CONF_TARGET"

# 3. Styles komplett kopieren
echo "👉 Kopiere styles/ nach $STYLE_TARGET ..."
copy_dir_contents "$REPO_ROOT/styles" "$STYLE_TARGET"

# 4. (Optional) Doku nach /srv/docs
if [ -d "$REPO_ROOT/docs" ]; then
    echo "👉 Kopiere docs/ nach $DOCS_TARGET ..."
    copy_dir_contents "$REPO_ROOT/docs" "$DOCS_TARGET"
fi

# 5. Nicht gewünschte Cache-Artefakte entfernen
find "$TARGET_DIR" -type d -name '__pycache__' -prune -exec rm -rf {} +

# 6. Rechte setzen
if compgen -G "$TARGET_DIR/*.sh" >/dev/null; then
    chmod +x "$TARGET_DIR"/*.sh
fi
if compgen -G "$TARGET_DIR/*.py" >/dev/null; then
    chmod +x "$TARGET_DIR"/*.py
fi

echo "✅ Deployment erfolgreich."
