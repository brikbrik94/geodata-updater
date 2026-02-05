#!/bin/bash
set -euo pipefail

# Konfiguration
USER_NAME="${USER_NAME:-geo}"
INSTALL_DIR="${INSTALL_DIR:-/srv/scripts}"

# OSM
OSM_BUILD_DIR="${OSM_BUILD_DIR:-/srv/build/osm}"
TILESET_ID="${TILESET_ID:-osm}"
if [ "$TILESET_ID" == "osm" ]; then
    STYLE_ID="${STYLE_ID:-at-plus}"
else
    STYLE_ID="${STYLE_ID:-$TILESET_ID}"
fi

# Basemap (Standard)
BASEMAP_BUILD_DIR="${BASEMAP_BUILD_DIR:-/srv/build/basemap-at}"

# Overlays (NEU: Hier landen jetzt auch die Contours)
OVERLAYS_BUILD_DIR="${OVERLAYS_BUILD_DIR:-/srv/build/overlays}"

TILES_DIR="${TILES_DIR:-/srv/tiles}"
ASSETS_DIR="${ASSETS_DIR:-/srv/assets}"
ORS_DIR="${ORS_DIR:-/srv/ors}"
STYLE_SOURCE="${STYLE_SOURCE:-styles/style.json}"
SPREET_IMAGE="${SPREET_IMAGE:-ghcr.io/flother/spreet:latest}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
STYLE_SOURCE_PATH="$REPO_ROOT/$STYLE_SOURCE"

echo "=== OSM Geodata Pipeline Setup ==="

# 0. Benutzer & Gruppe
if ! id -u "$USER_NAME" >/dev/null 2>&1; then
    echo "[0] Erstelle System-User '$USER_NAME'..."
    sudo useradd --system --create-home --shell /usr/sbin/nologin "$USER_NAME"
fi
if getent group docker >/dev/null 2>&1; then
    sudo usermod -aG docker "$USER_NAME"
fi

# 1. Pakete
echo "[1] Installiere System-Pakete..."
sudo apt-get update
sudo apt-get install -y aria2 osmium-tool wget python3 python3-venv docker.io docker-cli acl unzip nodejs npm golang librsvg2-bin tree
VENV_DIR="${VENV_DIR:-/srv/scripts/venv}"
if [ ! -d "$VENV_DIR" ]; then
    sudo python3 -m venv "$VENV_DIR"
fi
sudo "$VENV_DIR/bin/pip" install --upgrade pip pmtiles

if command -v docker >/dev/null 2>&1; then
    if ! sudo docker pull "$SPREET_IMAGE"; then
        echo "WARNUNG: spreet Image konnte nicht geladen werden."
    fi
fi

# 2. Ordnerstruktur
echo "[2] Erstelle Ordnerstruktur in /srv..."
sudo mkdir -p "$INSTALL_DIR/stats" "$INSTALL_DIR/sources"

# OSM
sudo mkdir -p "$OSM_BUILD_DIR/src" "$OSM_BUILD_DIR/tmp" "$OSM_BUILD_DIR/merged"
sudo mkdir -p "$TILES_DIR/$TILESET_ID/pmtiles" "$TILES_DIR/$TILESET_ID/tilejson" "$TILES_DIR/$TILESET_ID/styles/$STYLE_ID"

# Basemap
sudo mkdir -p "$BASEMAP_BUILD_DIR/src" "$BASEMAP_BUILD_DIR/tmp"
sudo mkdir -p "$TILES_DIR/basemap-at/pmtiles" "$TILES_DIR/basemap-at/tilejson" "$TILES_DIR/basemap-at/styles/basemap-at"

# Overlays (NEU: Ersetzt den alten Contours-Block)
sudo mkdir -p "$OVERLAYS_BUILD_DIR/contours/src" "$OVERLAYS_BUILD_DIR/contours/tmp"
sudo mkdir -p "$OVERLAYS_BUILD_DIR/openskimap/src" "$OVERLAYS_BUILD_DIR/openskimap/tmp"
sudo mkdir -p "$TILES_DIR/overlays/pmtiles" "$TILES_DIR/overlays/tilejson" "$TILES_DIR/overlays/styles"

# Elevation / Terrain (DEM)
# Enthält reine Höhendaten (z. B. terrain-rgb.pmtiles) ohne eigenes Style.
sudo mkdir -p "$TILES_DIR/elevation/pmtiles" "$TILES_DIR/elevation/tilejson"

# Assets & ORS
sudo mkdir -p "$ASSETS_DIR/fonts" "$ASSETS_DIR/sprites" /srv/info/attribution
sudo mkdir -p "$ORS_DIR/emergency" "$ORS_DIR/graphs" "$ORS_DIR/logs" "$ORS_DIR/tmp"
sudo mkdir -p /srv/styles /srv/docs

# 3. Kopieren
echo "[3] Kopiere Dateien..."
sudo cp "$REPO_ROOT"/scripts/* "$INSTALL_DIR/"

if [ -d "$REPO_ROOT/conf/sources" ]; then
    sudo cp "$REPO_ROOT"/conf/sources/*.txt "$INSTALL_DIR/sources/"
fi

if [ -d "$REPO_ROOT/styles" ]; then
    sudo cp -r "$REPO_ROOT"/styles/* /srv/styles/
fi

if [ -d "$REPO_ROOT/docs" ]; then
    sudo cp "$REPO_ROOT"/docs/*.md /srv/docs/
fi

if [ -f "$STYLE_SOURCE_PATH" ]; then
    sudo cp "$STYLE_SOURCE_PATH" "$TILES_DIR/$TILESET_ID/styles/$STYLE_ID/style.json"
fi

# --- ASSETS VORBEREITEN ---
log_section "Assets Vorbereitung"
if [ -f "$SCRIPT_DIR/run_assets.sh" ]; then
    "$SCRIPT_DIR/run_assets.sh"
else
    log_warn "run_assets.sh nicht gefunden. Bitte Fonts und Sprites manuell prüfen."
fi

log_success "Setup vollständig abgeschlossen! Du kannst nun 'start.sh' ausführen."


# 4. Rechte
echo "[4] Setze Berechtigungen..."
sudo chmod +x "$INSTALL_DIR/"*.sh
sudo chown -R $USER_NAME:$USER_NAME /srv/tiles /srv/assets /srv/build /srv/scripts /srv/ors /srv/docs /srv/styles

echo "=== Setup fertig! ==="
