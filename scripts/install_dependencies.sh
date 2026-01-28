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
# - wget/curl: Downloads
# - osmium-tool: OSM Merging
# - openjdk-17-jre-headless: Für Planetiler (Java)
# - python3: Für JSON Generierung
# - git: Falls nicht da
echo "👉 Installiere Pakete..."
apt-get install -y \
    wget \
    curl \
    git \
    osmium-tool \
    python3 \
    openjdk-17-jre-headless

echo "✅ Abhängigkeiten installiert.
