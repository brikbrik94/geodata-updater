#!/bin/bash
set -euo pipefail

# =================================================================
# ZENTRALE SETUP-ROUTINE (setup.sh)
# =================================================================
# Initialisiert das System für die neue Plugin-Architektur.

# Konfiguration (Standardwerte)
USER_NAME="${USER_NAME:-geo}"
INSTALL_DIR="${INSTALL_DIR:-/srv/scripts}"
TILES_DIR="${TILES_DIR:-/srv/tiles}"
ASSETS_DIR="${ASSETS_DIR:-/srv/assets}"
INFO_DIR="${INFO_DIR:-/srv/info}"
ORS_DIR="${ORS_DIR:-/srv/ors}"
DOCS_DIR="${DOCS_DIR:-/srv/docs}"
STYLES_DIR="${STYLES_DIR:-/srv/styles}"

SPREET_IMAGE="${SPREET_IMAGE:-ghcr.io/flother/spreet:latest}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "🚀 Starte Geodata Pipeline Setup (Plugin-Architektur)..."

# --- 0. Benutzer & Gruppe ---
if ! id -u "$USER_NAME" >/dev/null 2>&1; then
    echo "[0] Erstelle System-User '$USER_NAME'..."
    sudo useradd --system --create-home --shell /usr/sbin/nologin "$USER_NAME"
fi
if getent group docker >/dev/null 2>&1; then
    sudo usermod -aG docker "$USER_NAME"
fi

# --- 1. Pakete ---
echo "[1] Installiere System-Pakete..."
sudo apt-get update
sudo apt-get install -y wget python3 python3-venv docker.io docker-cli acl unzip nodejs npm tree git curl rsync

# Python Virtual Environment
VENV_DIR="$INSTALL_DIR/venv"
if [ ! -d "$VENV_DIR" ]; then
    echo "    📦 Erstelle Python Venv..."
    sudo mkdir -p "$INSTALL_DIR"
    sudo python3 -m venv "$VENV_DIR"
fi
sudo "$VENV_DIR/bin/pip" install --upgrade pip

# Docker Images
if command -v docker >/dev/null 2>&1; then
    echo "    🐳 Lade Docker Images..."
    if ! sudo docker pull "$SPREET_IMAGE"; then
        echo "    ⚠️  Warnung: spreet Image konnte nicht geladen werden."
    fi
fi

# --- 2. Ordnerstruktur ---
echo "[2] Erstelle Verzeichnisstruktur in /srv..."

# Basis-Verzeichnisse
sudo mkdir -p "$INSTALL_DIR" "$INFO_DIR/attribution" "$DOCS_DIR" "$STYLES_DIR"

# Tiles-Struktur (Kategorien basierend auf Plugin-Standard)
for cat in "basemaps" "overlays" "elevation"; do
    sudo mkdir -p "$TILES_DIR/$cat/pmtiles"
    sudo mkdir -p "$TILES_DIR/$cat/tilejson"
    sudo mkdir -p "$TILES_DIR/$cat/styles"
done

# Assets
sudo mkdir -p "$ASSETS_DIR/fonts" "$ASSETS_DIR/sprites"

# ORS (Optional/Manuell)
sudo mkdir -p "$ORS_DIR/graphs" "$ORS_DIR/logs" "$ORS_DIR/tmp"

# --- 3. Dateien kopieren ---
echo "[3] Kopiere Skripte und Konfiguration..."

# Skripte (inkl. Unterordner tools, inventory, ors)
sudo rsync -av --delete "$REPO_ROOT/scripts/" "$INSTALL_DIR/"

# Konfiguration
if [ -d "$REPO_ROOT/conf" ]; then
    sudo mkdir -p /srv/conf
    sudo cp -r "$REPO_ROOT/conf/"* /srv/conf/
fi

# Styles (Vorlagen)
if [ -d "$REPO_ROOT/styles" ]; then
    sudo cp -r "$REPO_ROOT/styles/"* "$STYLES_DIR/"
fi

# Dokumentation
if [ -d "$REPO_ROOT/docs" ]; then
    sudo cp -r "$REPO_ROOT/docs/"* "$DOCS_DIR/"
fi

# --- 4. Assets vorbereiten ---
if [ -f "$INSTALL_DIR/run_assets.sh" ]; then
    echo "[4] Starte initiale Asset-Generierung (Fonts/Sprites)..."
    # Wir führen es als geo user aus, falls möglich
    sudo -u "$USER_NAME" bash "$INSTALL_DIR/run_assets.sh"
fi

# --- 5. Rechte setzen ---
echo "[5] Setze Berechtigungen..."
sudo chmod +x "$INSTALL_DIR/"*.sh "$INSTALL_DIR/"*.py
sudo chmod +x "$INSTALL_DIR/tools/"*.sh 2>/dev/null || true
sudo chmod +x "$INSTALL_DIR/inventory/"*.py 2>/dev/null || true
sudo chmod +x "$INSTALL_DIR/inventory/"*.sh 2>/dev/null || true
sudo chmod +x "$INSTALL_DIR/ors/"*.sh 2>/dev/null || true

sudo chown -R "$USER_NAME":"$USER_NAME" /srv/tiles /srv/assets /srv/scripts /srv/ors /srv/docs /srv/styles /srv/conf /srv/info

echo "✅ Setup vollständig abgeschlossen!"
