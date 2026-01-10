#!/bin/bash
set -euo pipefail

ASSETS_DIR="${ASSETS_DIR:-/srv/assets}"
FONTS_DIR="$ASSETS_DIR/fonts"
FONTS_REPO_URL="${FONTS_REPO_URL:-https://github.com/openmaptiles/fonts.git}"

TMP_DIR="$(mktemp -d)"
cleanup() {
    rm -rf "$TMP_DIR"
}
trap cleanup EXIT

echo "[fonts] Klone Fonts-Repository von $FONTS_REPO_URL..."
git clone --depth 1 "$FONTS_REPO_URL" "$TMP_DIR/fonts"

pushd "$TMP_DIR/fonts" >/dev/null
echo "[fonts] Installiere npm-Abhängigkeiten..."
npm install
echo "[fonts] Generiere Fonts..."
node ./generate.js
popd >/dev/null

SOURCE_DIR="$TMP_DIR/fonts/_output"
if [ ! -d "$SOURCE_DIR" ]; then
    echo "FEHLER: _output-Verzeichnis nicht gefunden."
    exit 1
fi

sudo mkdir -p "$FONTS_DIR"
sudo rm -rf "$FONTS_DIR"/*
sudo cp -R "$SOURCE_DIR"/* "$FONTS_DIR"/

echo "[fonts] Fonts installiert nach $FONTS_DIR"
