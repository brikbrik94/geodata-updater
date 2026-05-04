#!/bin/bash
set -e

# Pfad zu den Skripten im Git
SCRIPT_DIR="$(dirname "$0")/scripts"

echo "🚀 STARTE KOMPLETT-INSTALLATION (Setup & Deployment)"

# 1. Abhängigkeiten installieren
if [ -f "$SCRIPT_DIR/install_dependencies.sh" ]; then
    bash "$SCRIPT_DIR/install_dependencies.sh"
fi

# 2. System-Setup & Verzeichnisse initialisieren
# (Das Setup kopiert nun auch die Skripte via rsync nach /srv/scripts)
if [ -f "$SCRIPT_DIR/setup.sh" ]; then
    bash "$SCRIPT_DIR/setup.sh"
fi

echo "✅ Installation erfolgreich abgeschlossen."
