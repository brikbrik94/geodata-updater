#!/bin/bash
set -euo pipefail

# --- KONFIGURATION ---
# Pfad zur Datei mit den Links
INPUT_FILE="/srv/scripts/links.txt"
# Zielordner für die Downloads
OUTPUT_DIR="/srv/osm/parts"
# Name der Datei, welche die Pfade der Downloads speichert
LIST_FILE="$OUTPUT_DIR/file_list.txt"
UPDATED_FLAG="$OUTPUT_DIR/updated.flag"

# --- VORBEREITUNG ---

# Prüfen, ob die Link-Datei existiert
if [ ! -f "$INPUT_FILE" ]; then
    echo "FEHLER: Die Datei $INPUT_FILE wurde nicht gefunden."
    exit 1
fi

# Zielordner erstellen, falls er nicht existiert
if [ ! -d "$OUTPUT_DIR" ]; then
    echo "Erstelle Zielordner: $OUTPUT_DIR"
    mkdir -p "$OUTPUT_DIR"
fi

# Die Listen-Datei leeren oder erstellen (damit wir bei jedem Lauf eine frische Liste haben)
> "$LIST_FILE"
rm -f "$UPDATED_FLAG"

# Links einlesen
mapfile -t URLS < <(grep -vE '^\s*($|#)' "$INPUT_FILE")
TOTAL_LINKS=${#URLS[@]}

# --- AUSFÜHRUNG ---

echo "--------------------------------------------------"
echo "Download-Script für Geofabrik PBFs gestartet"
echo "Gefundene Links: $TOTAL_LINKS"
echo "Speicherort: $OUTPUT_DIR"
echo "Dateiliste wird erstellt in: $LIST_FILE"
echo "--------------------------------------------------"

CURRENT=1
NEW_DOWNLOADS=0

for LINK in "${URLS[@]}"; do
    FILENAME=$(basename "$LINK")
    FULL_PATH="$OUTPUT_DIR/$FILENAME"
    
    echo ""
    echo "[Datei $CURRENT von $TOTAL_LINKS]: $FILENAME wird verarbeitet..."
    
    OLD_MTIME=""
    if [ -f "$FULL_PATH" ]; then
        OLD_MTIME=$(stat -c %Y "$FULL_PATH")
    fi

    # Download starten (nur wenn remote neuer ist)
    if wget -q --show-progress -N -P "$OUTPUT_DIR" "$LINK"; then
        echo "✓ Download OK."
        if [ ! -f "$FULL_PATH" ]; then
            echo "❌ FEHLER: Datei $FULL_PATH fehlt nach Download."
            continue
        fi
        NEW_MTIME=$(stat -c %Y "$FULL_PATH")
        if [ -z "$OLD_MTIME" ] || [ "$NEW_MTIME" != "$OLD_MTIME" ]; then
            NEW_DOWNLOADS=1
        fi
        # Absoluten Pfad in die Liste schreiben
        echo "$FULL_PATH" >> "$LIST_FILE"
    else
        echo "❌ FEHLER beim Download von $FILENAME - Wird nicht zur Liste hinzugefügt."
    fi
    
    ((CURRENT++))
done

echo ""
echo "--------------------------------------------------"
echo "Fertig! Die Liste der Dateien liegt hier:"
echo "$LIST_FILE"
if [ "$NEW_DOWNLOADS" -eq 1 ]; then
    touch "$UPDATED_FLAG"
    echo "Neue Dateien erkannt: Merge/PMTiles sollten neu laufen."
else
    echo "Keine neuen Dateien gefunden: Merge/PMTiles können übersprungen werden."
fi
echo "--------------------------------------------------"
