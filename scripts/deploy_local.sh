#!/bin/bash
set -euo pipefail

# Wo sind wir? (Git Repo)
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPTS_SRC="$REPO_DIR/scripts"
CONFIG_SRC="$SCRIPTS_SRC/config.env"

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
echo "Quelle: $SCRIPTS_SRC"
echo "Ziel:   $TARGET_DIR"

mkdir -p "$TARGET_DIR"

# 1. Skripte kopieren
echo "👉 Kopiere Skripte (.sh)..."
cp "$SCRIPTS_SRC"/*.sh "$TARGET_DIR/"

# 2. Config kopieren
echo "👉 Kopiere Config (.env)..."
cp "$SCRIPTS_SRC"/*.env "$TARGET_DIR/"

# 3. Sources kopieren (WICHTIG für download_osm.sh)
# Wir gehen davon aus, dass im Repo ein Ordner 'sources' existiert (z.B. in scripts/sources)
SOURCES_SRC="$SCRIPTS_SRC/sources"
SOURCES_DST="$TARGET_DIR/sources"

if [ -d "$SOURCES_SRC" ]; then
    echo "👉 Kopiere Quellen-Listen (.txt)..."
    mkdir -p "$SOURCES_DST"
    cp "$SOURCES_SRC"/*.txt "$SOURCES_DST/"
else
    echo "⚠️  Warnung: Kein 'sources' Ordner in $SCRIPTS_SRC gefunden."
fi

# 4. Rechte setzen
echo "👉 Setze Ausführungsrechte..."
chmod +x "$TARGET_DIR"/*.sh
chmod 644 "$TARGET_DIR"/*.env
chmod 644 "$TARGET_DIR"/sources/*.txt 2>/dev/null || true

echo "✅ Deployment erfolgreich."
echo "   Du kannst jetzt starten mit: $TARGET_DIR/start.sh"
