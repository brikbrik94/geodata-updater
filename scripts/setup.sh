#!/bin/bash
set -euo pipefail

# Konfiguration
USER_NAME="${USER_NAME:-geo}"  # Dein User auf dem VPS
INSTALL_DIR="${INSTALL_DIR:-/srv/scripts}"
OSM_BUILD_DIR="${OSM_BUILD_DIR:-/srv/build/osm}"
BASEMAP_BUILD_DIR="${BASEMAP_BUILD_DIR:-/srv/build/basemap-at}"
CONTOURS_BUILD_DIR="${CONTOURS_BUILD_DIR:-/srv/build/basemap-at-contours}"
OVERLAYS_BUILD_DIR="${OVERLAYS_BUILD_DIR:-/srv/build/overlays}"
TILESET_ID="${TILESET_ID:-osm}"
STYLE_ID="${STYLE_ID:-$TILESET_ID}"
TILES_DIR="${TILES_DIR:-/srv/tiles}"
ASSETS_DIR="${ASSETS_DIR:-/srv/assets}"
BUILD_DIR="${BUILD_DIR:-/srv/build}"
ORS_DIR="${ORS_DIR:-/srv/ors}"
STYLE_SOURCE="${STYLE_SOURCE:-styles/style.json}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

STYLE_SOURCE_PATH="$REPO_ROOT/$STYLE_SOURCE"

echo "=== OSM Geodata Pipeline Setup ==="

# 0. Benutzer prüfen/erstellen
if ! id -u "$USER_NAME" >/dev/null 2>&1; then
    echo "[0] Erstelle System-User '$USER_NAME'..."
    sudo useradd --system --create-home --shell /usr/sbin/nologin "$USER_NAME"
fi
if getent group docker >/dev/null 2>&1; then
    echo "[0] Füge '$USER_NAME' zur docker-Gruppe hinzu..."
    sudo usermod -aG docker "$USER_NAME"
    echo "[0] Hinweis: Bitte neu einloggen oder 'newgrp docker' ausführen, damit die Gruppenänderung wirkt."
else
    echo "[0] docker-Gruppe nicht gefunden. Überspringe Gruppen-Zuweisung."
fi

# 1. Abhängigkeiten prüfen/installieren
echo "[1] Installiere System-Pakete..."
sudo apt-get update
sudo apt-get install -y osmium-tool wget python3 docker.io docker-cli acl

# 2. Ordnerstruktur erstellen
echo "[2] Erstelle Ordnerstruktur in /srv..."
sudo mkdir -p "$INSTALL_DIR/stats"
sudo mkdir -p "$OSM_BUILD_DIR/src"
sudo mkdir -p "$OSM_BUILD_DIR/tmp"
sudo mkdir -p "$OSM_BUILD_DIR/merged"
sudo mkdir -p "$BASEMAP_BUILD_DIR/src" "$BASEMAP_BUILD_DIR/tmp"
sudo mkdir -p "$CONTOURS_BUILD_DIR/src" "$CONTOURS_BUILD_DIR/tmp"
sudo mkdir -p "$OVERLAYS_BUILD_DIR/src" "$OVERLAYS_BUILD_DIR/tmp"
sudo mkdir -p "$TILES_DIR/$TILESET_ID/pmtiles"
sudo mkdir -p "$TILES_DIR/$TILESET_ID/tilejson"
sudo mkdir -p "$TILES_DIR/$TILESET_ID/styles/$STYLE_ID"
sudo mkdir -p "$TILES_DIR/osm/styles/at"
sudo mkdir -p "$TILES_DIR/osm/styles/at-plus"
sudo mkdir -p "$TILES_DIR/basemap-at/pmtiles"
sudo mkdir -p "$TILES_DIR/basemap-at/tilejson"
sudo mkdir -p "$TILES_DIR/basemap-at/styles/basemap-at"
sudo mkdir -p "$TILES_DIR/basemap-at-contours/pmtiles"
sudo mkdir -p "$TILES_DIR/basemap-at-contours/tilejson"
sudo mkdir -p "$TILES_DIR/basemap-at-contours/styles/basemap-at-contours"
sudo mkdir -p "$TILES_DIR/overlays/pmtiles"
sudo mkdir -p "$TILES_DIR/overlays/tilejson"
sudo mkdir -p "$TILES_DIR/overlays/styles/overlay-xyz"
sudo mkdir -p "$ASSETS_DIR/fonts" "$ASSETS_DIR/sprites"
# ORS Struktur (damit es bereit ist für dein anderes Repo)
sudo mkdir -p "$ORS_DIR/emergency"
sudo mkdir -p "$ORS_DIR/graphs"
sudo mkdir -p "$ORS_DIR/logs"
sudo mkdir -p "$ORS_DIR/tmp"

# 3. Skripte kopieren
echo "[3] Kopiere Skripte & Config..."
sudo cp "$REPO_ROOT"/scripts/* "$INSTALL_DIR/"
sudo cp "$REPO_ROOT"/conf/links.txt "$INSTALL_DIR/"
if [ -f "$STYLE_SOURCE_PATH" ]; then
    sudo cp "$STYLE_SOURCE_PATH" "$TILES_DIR/$TILESET_ID/styles/$STYLE_ID/style.json"
else
    echo "[3] Hinweis: Kein $STYLE_SOURCE_PATH gefunden. Lege dort dein style.json ab, um es zu kopieren."
fi

# 4. Rechte setzen
echo "[4] Setze Berechtigungen..."
sudo chmod +x "$INSTALL_DIR/"*.sh
sudo chown -R $USER_NAME:$USER_NAME /srv/tiles /srv/assets /srv/build /srv/scripts /srv/ors

# 5. Docker Rechte für User (damit sudo docker nicht nötig ist, optional)
# sudo usermod -aG docker $USER_NAME

echo "=== Setup fertig! ==="
echo "Die Skripte liegen unter $INSTALL_DIR"
echo "Du kannst jetzt starten mit: $INSTALL_DIR/start.sh"
