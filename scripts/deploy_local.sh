#!/bin/bash
set -euo pipefail

# Verzeichnis dieses Skripts ermitteln
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

# Zielverzeichnis auf dem Server
TARGET_DIR="/srv/scripts"
CONF_TARGET="/srv/conf"
STYLE_TARGET="/srv/styles"

echo "========================================"
echo " DEPLOY: GIT -> LIVE SYSTEM"
echo "========================================"
echo "Repo Root: $REPO_ROOT"
echo "Ziel:      $TARGET_DIR"

# Zielordner erstellen
mkdir -p "$TARGET_DIR"
mkdir -p "$CONF_TARGET"
mkdir -p "$STYLE_TARGET"

# 1. Skripte kopieren (.sh AND .py)
echo "👉 Kopiere Skripte (.sh und .py)..."
cp "$REPO_ROOT/scripts/"*.sh "$TARGET_DIR/"
cp "$REPO_ROOT/scripts/"*.py "$TARGET_DIR/"

# 2. Config kopieren
if [ -f "$REPO_ROOT/scripts/config.env" ]; then
    echo "👉 Kopiere Config (.env)..."
    cp "$REPO_ROOT/scripts/config.env" "$TARGET_DIR/"
fi

# 3. Quellen-Listen kopieren (Listen für Downloads)
if [ -d "$REPO_ROOT/conf/sources" ]; then
    echo "👉 Kopiere Quellen-Listen aus conf/sources..."
    mkdir -p "$CONF_TARGET/sources"
    cp -r "$REPO_ROOT/conf/sources/"* "$CONF_TARGET/sources/"
fi

# 4. Styles kopieren (NEU)
# Kopiert osm-style.json und openskimap-style.json nach /srv/styles
if [ -d "$REPO_ROOT/styles" ]; then
    echo "👉 Kopiere Styles nach $STYLE_TARGET..."
    cp -r "$REPO_ROOT/styles/"* "$STYLE_TARGET/"
fi

# 5. Rechte setzen
echo "👉 Setze Ausführungsrechte..."
chmod +x "$TARGET_DIR/"*.sh
chmod +x "$TARGET_DIR/"*.py 2>/dev/null || true

echo "✅ Deployment erfolgreich."
