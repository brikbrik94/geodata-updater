#!/bin/bash
set -e

# Pfad zu den Skripten im Git
SCRIPT_DIR="$(dirname "$0")/scripts"

echo "🚀 STARTE KOMPLETT-INSTALLATION"

# 1. Abhängigkeiten
bash "$SCRIPT_DIR/install_dependencies.sh"

# 2. Deployment
bash "$SCRIPT_DIR/deploy_local.sh"

echo "✅ Fertig."
