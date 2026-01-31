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
# Liste basiert auf deinem ursprünglichen Setup
# osmium-tool: Für den Merge (läuft lokal)
# docker: Für Planetiler & ORS
# nodejs/npm/golang/librsvg2-bin: Für Assets/Sprites (zukünftig)
echo "👉 Installiere Pakete..."
apt-get install -y \
    wget \
    curl \
    git \
    unzip \
    tree \
    acl \
    osmium-tool \
    python3 \
    python3-venv \
    docker.io \
    docker-cli \
    nodejs \
    npm \
    golang \
    librsvg2-bin

echo "✅ Abhängigkeiten installiert."
