#!/bin/bash
set -euo pipefail

# Konfiguration
USER_NAME="${USER_NAME:-geo}"  # Dein User auf dem VPS
INSTALL_DIR="${INSTALL_DIR:-/srv/scripts}"
DATA_DIR="${DATA_DIR:-/srv/osm}"
TILE_DIR="${TILE_DIR:-/srv/pmtiles}"
ORS_DIR="${ORS_DIR:-/srv/ors}"

echo "=== OSM Geodata Pipeline Installer ==="

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
sudo apt-get install -y osmium-tool wget python3 docker.io acl

# 2. Ordnerstruktur erstellen
echo "[2] Erstelle Ordnerstruktur in /srv..."
sudo mkdir -p "$INSTALL_DIR/stats"
sudo mkdir -p "$DATA_DIR/parts"
sudo mkdir -p "$DATA_DIR/merged"
sudo mkdir -p "$TILE_DIR/build/out"
sudo mkdir -p "$TILE_DIR/build/sources"
sudo mkdir -p "$TILE_DIR/serve"
# ORS Struktur (damit es bereit ist für dein anderes Repo)
sudo mkdir -p "$ORS_DIR/emergency"
sudo mkdir -p "$ORS_DIR/graphs"
sudo mkdir -p "$ORS_DIR/logs"
sudo mkdir -p "$ORS_DIR/tmp"

# 3. Skripte kopieren
echo "[3] Kopiere Skripte & Config..."
sudo cp scripts/* "$INSTALL_DIR/"
sudo cp conf/links.txt "$INSTALL_DIR/"

# 4. Rechte setzen
echo "[4] Setze Berechtigungen..."
sudo chmod +x "$INSTALL_DIR/"*.sh
sudo chown -R $USER_NAME:$USER_NAME /srv/osm /srv/pmtiles /srv/scripts /srv/ors

# 5. Docker Rechte für User (damit sudo docker nicht nötig ist, optional)
# sudo usermod -aG docker $USER_NAME

echo "=== Installation fertig! ==="
echo "Die Skripte liegen unter $INSTALL_DIR"
echo "Du kannst jetzt starten mit: $INSTALL_DIR/update_map.sh"
