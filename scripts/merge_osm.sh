#!/bin/bash
set -euo pipefail

# --- KONFIGURATION ---
# Die Liste aus dem Download-Script
INPUT_LIST="/srv/osm/parts/file_list.txt"
# Zielordner für die fertige Datei
OUTPUT_DIR="/srv/osm/merged"
# Name der finalen Datei
OUTPUT_FILENAME="complete_map.osm.pbf"
FULL_OUTPUT_PATH="$OUTPUT_DIR/$OUTPUT_FILENAME"

# --- VORBEREITUNG ---

# Prüfen, ob osmium installiert ist
if ! command -v osmium &> /dev/null; then
    echo "FEHLER: 'osmium-tool' ist nicht installiert."
    echo "Bitte mit 'apt-get install osmium-tool' nachinstallieren."
    exit 1
fi

# Prüfen, ob die Input-Liste existiert
if [ ! -f "$INPUT_LIST" ]; then
    echo "FEHLER: Keine Dateiliste ($INPUT_LIST) gefunden."
    echo "Bitte führe zuerst das Download-Script aus."
    exit 1
fi

# Prüfen, ob die Liste leer ist
if [ ! -s "$INPUT_LIST" ]; then
    echo "FEHLER: Die Dateiliste ist leer. Es gibt nichts zu mergen."
    exit 1
fi

# Zielordner erstellen
if [ ! -d "$OUTPUT_DIR" ]; then
    mkdir -p "$OUTPUT_DIR"
fi

# --- AUSFÜHRUNG ---

echo "--------------------------------------------------"
echo "Merge-Vorgang gestartet"
echo "Input-Liste: $INPUT_LIST"
echo "Ziel: $FULL_OUTPUT_PATH"
echo "--------------------------------------------------"

# Anzahl der zu verarbeitenden Dateien zählen
COUNT=$(wc -l < "$INPUT_LIST")
echo "Füge $COUNT Dateien zusammen..."

# Osmium Merge Befehl
# $(cat ...) liest die Dateipfade aus der Textdatei und übergibt sie als Argumente
# --overwrite sorgt dafür, dass die alte Datei ohne Nachfrage überschrieben wird (spart Platz)
xargs -a "$INPUT_LIST" osmium merge -o "$FULL_OUTPUT_PATH" --overwrite

# Ergebnis prüfen
if [ $? -eq 0 ]; then
    FILESIZE=$(du -h "$FULL_OUTPUT_PATH" | cut -f1)
    echo ""
    echo "✅ ERFOLG: Die Karten wurden erfolgreich zusammengefügt."
    echo "Größe der neuen Datei: $FILESIZE"
else
    echo ""
    echo "❌ FEHLER beim Mergen der Dateien."
    exit 1
fi

echo "--------------------------------------------------"
