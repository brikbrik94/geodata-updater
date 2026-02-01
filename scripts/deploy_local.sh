#!/bin/bash
set -euo pipefail

# Verzeichnis dieses Skripts ermitteln
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

# Zielverzeichnis auf dem Server
TARGET_DIR="/srv/scripts"
CONF_TARGET="/srv/conf"

echo "========================================"
echo " DEPLOY: GIT -> LIVE SYSTEM"
echo "========================================"
echo "Repo Root: $REPO_ROOT"
echo "Ziel:      $TARGET_DIR"

# Zielordner erstellen
mkdir -p "$TARGET_DIR"
mkdir -p "$CONF_TARGET"

# 1. Skripte kopieren (.sh AND .py)
echo "👉 Kopiere Skripte (.sh und .py)..."
# Wir kopieren Shell-Skripte und Python-Dateien
cp "$REPO_ROOT/scripts/"*.sh "$TARGET_DIR/"
cp "$REPO_ROOT/scripts/"*.py "$TARGET_DIR/"

# 2. Config kopieren
if [ -f "$REPO_ROOT/scripts/config.env" ]; then
    echo "👉 Kopiere Config (.env)..."
    cp "$REPO_ROOT/scripts/config.env" "$TARGET_DIR/"
fi

# 3. Quellen-Listen kopieren (Listen für Downloads)
# Wir kopieren alles aus conf/sources nach /srv/conf/sources
if [ -d "$REPO_ROOT/conf/sources" ]; then
    echo "👉 Kopiere Quellen-Listen aus conf/sources..."
    mkdir -p "$CONF_TARGET/sources"
    cp -r "$REPO_ROOT/conf/sources/"* "$CONF_TARGET/sources/"
fi

# 4. Styles kopieren (Optional, falls du Styles im Repo hast)
# Wir kopieren den styles ordner nach /srv/styles (oder wo du ihn brauchst)
# Das deployment script für Styles greift ja auf das Repo zu, 
# aber es schadet nicht, die Struktur sauber zu halten.
# (Optional, falls gewünscht - ich lasse es hier mal simpel beim Scripts ordner)

# 5. Rechte setzen
echo "👉 Setze Ausführungsrechte..."
chmod +x "$TARGET_DIR/"*.sh
# Python Skripte müssen nicht zwingend +x haben, wenn man sie mit "python script.py" ruft, 
# aber schaden tut es nicht.
chmod +x "$TARGET_DIR/"*.py 2>/dev/null || true

echo "✅ Deployment erfolgreich."
