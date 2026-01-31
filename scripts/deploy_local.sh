#!/bin/bash
set -euo pipefail

# Wo sind wir? (Git Repo Root ermitteln)
# Wenn dieses Skript in .../geodata-updater/scripts liegt, ist REPO_DIR .../geodata-updater
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

SCRIPTS_SRC="$REPO_DIR/scripts"
CONFIG_SRC="$SCRIPTS_SRC/config.env"

# KORREKTUR: Die Quellen liegen in conf/sources
SOURCES_SRC="$REPO_DIR/conf/sources"

# Wir laden die Config TEMPORÄR, um das Zielverzeichnis (INSTALL_DIR) zu kennen
if [ -f "$CONFIG_SRC" ]; then
    source "$CONFIG_SRC"
else
    echo "❌ Fehler: scripts/config.env im Repo nicht gefunden!"
    exit 1
fi

# Standardfall, falls in Config nicht gesetzt
TARGET_DIR="${INSTALL_DIR:-/srv/scripts}"

echo "========================================"
echo " DEPLOY: GIT -> LIVE SYSTEM"
echo "========================================"
echo "Repo Root: $REPO_DIR"
echo "Ziel:      $TARGET_DIR"

mkdir -p "$TARGET_DIR"

# 1. Skripte kopieren
echo "👉 Kopiere Skripte (.sh)..."
cp "$SCRIPTS_SRC"/*.sh "$TARGET_DIR/"

# 2. Config kopieren
echo "👉 Kopiere Config (.env)..."
cp "$SCRIPTS_SRC"/*.env "$TARGET_DIR/"

# 3. Sources kopieren
# Ziel ist weiterhin /srv/scripts/sources (damit download_osm.sh sie findet)
SOURCES_DST="$TARGET_DIR/sources"

if [ -d "$SOURCES_SRC" ]; then
    echo "👉 Kopiere Quellen-Listen aus conf/sources..."
    mkdir -p "$SOURCES_DST"
    # Kopiere nur .txt Dateien
    cp "$SOURCES_SRC"/*.txt "$SOURCES_DST/" 2>/dev/null || echo "   (Keine .txt Dateien in conf/sources gefunden)"
else
    echo "⚠️  Warnung: Ordner nicht gefunden: $SOURCES_SRC"
fi

# 4. Rechte setzen
echo "👉 Setze Ausführungsrechte..."
chmod +x "$TARGET_DIR"/*.sh
chmod 644 "$TARGET_DIR"/*.env
if [ -d "$SOURCES_DST" ]; then
    chmod 644 "$SOURCES_DST"/*.txt 2>/dev/null || true
fi

echo "✅ Deployment erfolgreich."
