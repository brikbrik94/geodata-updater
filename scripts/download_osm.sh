#!/bin/bash

# --- KONFIGURATION ---
# Pfad zur Datei mit den Links
INPUT_FILE="/srv/scripts/links.txt"
# Zielordner für die Downloads
OUTPUT_DIR="/srv/osm/parts"
# Name der Datei, welche die Pfade der Downloads speichert
LIST_FILE="$OUTPUT_DIR/file_list.txt"

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

for LINK in "${URLS[@]}"; do
    FILENAME=$(basename "$LINK")
    FULL_PATH="$OUTPUT_DIR/$FILENAME"
    
    echo ""
    echo "[Datei $CURRENT von $TOTAL_LINKS]: $FILENAME wird verarbeitet..."
    
    # Download starten
    wget -q --show-progress -c -P "$OUTPUT_DIR" "$LINK"
    
    # Prüfen ob wget erfolgreich war (0 = Erfolg)
    if [ $? -eq 0 ]; then
        echo "✓ Download OK."
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
echo "--------------------------------------------------"
