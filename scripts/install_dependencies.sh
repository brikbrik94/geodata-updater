#!/bin/bash
set -euo pipefail

echo "========================================"
echo " SYSTEM-DEPENDENCIES INSTALLIEREN"
echo "========================================"

if [ "$EUID" -ne 0 ]; then
  echo "❌ Bitte als root ausführen."
  exit 1
fi

# 1. System updaten
echo "👉 Update Paketlisten..."
apt-get update

# 2. Pakete installieren
# Wir installieren nur noch das Nötigste für Assets (Fonts/Sprites) und Python.
# osmium-tool, aria2 und golang wurden in die externen Repos ausgelagert.
echo "👉 Installiere Pakete..."
apt-get install -y \
    wget \
    curl \
    git \
    unzip \
    tree \
    acl \
    python3 \
    python3-venv \
    docker.io \
    docker-cli \
    nodejs \
    npm

echo "✅ Abhängigkeiten installiert."
