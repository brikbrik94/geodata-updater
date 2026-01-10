#!/bin/bash
set -euo pipefail

ASSETS_DIR="${ASSETS_DIR:-/srv/assets}"
FONTS_DIR="$ASSETS_DIR/fonts"
FONTS_REPO_URL="${FONTS_REPO_URL:-https://github.com/openmaptiles/fonts/archive/refs/heads/master.zip}"

TMP_DIR="$(mktemp -d)"
cleanup() {
    rm -rf "$TMP_DIR"
}
trap cleanup EXIT

echo "[fonts] Lade Fonts von $FONTS_REPO_URL..."
wget -q -O "$TMP_DIR/fonts.zip" "$FONTS_REPO_URL"
unzip -q "$TMP_DIR/fonts.zip" -d "$TMP_DIR"

SOURCE_DIR="$(find "$TMP_DIR" -maxdepth 1 -type d -name 'fonts-*' -print -quit)"
if [ -z "$SOURCE_DIR" ]; then
    echo "FEHLER: Entpacktes Fonts-Verzeichnis nicht gefunden."
    exit 1
fi

sudo mkdir -p "$FONTS_DIR"
sudo rm -rf "$FONTS_DIR"/*
sudo cp -R "$SOURCE_DIR"/* "$FONTS_DIR"/

echo "[fonts] Fonts installiert nach $FONTS_DIR"
