#!/bin/bash

# ==========================================
# KONFIGURATION
# ==========================================
DOCKER_IMAGE="local-spreet-builder"
SPREET_REPO="https://github.com/flother/spreet.git"
OUTPUT_DIR="/srv/assets/scripts"

# Maki Einstellungen
MAKI_REPO="https://github.com/mapbox/maki.git"
MAKI_OUT="maki-sprite"

# Temaki Einstellungen
TEMAKI_REPO="https://github.com/rapideditor/temaki.git"
TEMAKI_OUT="temaki-sprite"

# ==========================================
# 1. VORBEREITUNG
# ==========================================
echo "### START: Sprite Builder ###"

if ! command -v docker &> /dev/null; then
    echo "FEHLER: Docker läuft nicht."
    exit 1
fi

mkdir -p "$OUTPUT_DIR"

# Image bauen (nur einmal)
if [[ "$(docker images -q $DOCKER_IMAGE 2> /dev/null)" == "" ]]; then
    echo "--- Baue Docker Image (spreet)... ---"
    docker build -t $DOCKER_IMAGE $SPREET_REPO
fi

# ==========================================
# 2. MAKI PROZESS (Flat Structure)
# ==========================================
echo ""
echo "--- [1/2] Verarbeite MAKI Icons... ---"
TEMP_DIR="temp_maki_build"
FLAT_DIR="flat_maki"
rm -rf "$TEMP_DIR" "$FLAT_DIR"
mkdir -p "$FLAT_DIR"

git clone --depth 1 "$MAKI_REPO" "$TEMP_DIR" > /dev/null 2>&1

if [ -d "$TEMP_DIR/icons" ]; then
    # Maki hat flache Dateien, wir kopieren sie einfach
    cp "$TEMP_DIR/icons/"*.svg "$FLAT_DIR/"
    COUNT=$(ls -1 "$FLAT_DIR"/*.svg 2>/dev/null | wc -l)
    echo "    > $COUNT Maki Icons gefunden."

    # 1x Build
    docker run --rm --entrypoint /app/spreet \
        -v "$(pwd)/$FLAT_DIR:/sources" -v "$OUTPUT_DIR:/output" \
        $DOCKER_IMAGE /sources /output/$MAKI_OUT

    # 2x Build
    docker run --rm --entrypoint /app/spreet \
        -v "$(pwd)/$FLAT_DIR:/sources" -v "$OUTPUT_DIR:/output" \
        $DOCKER_IMAGE --retina /sources /output/${MAKI_OUT}@2x
else
    echo "FEHLER: Maki Icons nicht gefunden."
fi

# Aufräumen Maki
rm -rf "$TEMP_DIR" "$FLAT_DIR"

# ==========================================
# 3. TEMAKI PROZESS (Nested Structure)
# ==========================================
echo ""
echo "--- [2/2] Verarbeite TEMAKI Icons... ---"
TEMP_DIR="temp_temaki_build"
FLAT_DIR="flat_temaki"
rm -rf "$TEMP_DIR" "$FLAT_DIR"
mkdir -p "$FLAT_DIR"

git clone --depth 1 "$TEMAKI_REPO" "$TEMP_DIR" > /dev/null 2>&1

if [ -d "$TEMP_DIR/icons" ]; then
    # Temaki hat Unterordner -> Umbenennen zu kategorie_name.svg
    cd "$TEMP_DIR/icons" || exit
    find . -type f -name "*.svg" | while read -r FILE; do
        CLEAN_PATH="${FILE#./}"
        NEW_NAME="${CLEAN_PATH//\//_}" # Slashes zu Unterstrichen
        cp "$FILE" "../../$FLAT_DIR/$NEW_NAME"
    done
    cd ../..

    COUNT=$(ls -1 "$FLAT_DIR"/*.svg 2>/dev/null | wc -l)
    echo "    > $COUNT Temaki Icons gefunden."

    # 1x Build (ohne --unique für saubere Namen)
    docker run --rm --entrypoint /app/spreet \
        -v "$(pwd)/$FLAT_DIR:/sources" -v "$OUTPUT_DIR:/output" \
        $DOCKER_IMAGE /sources /output/$TEMAKI_OUT

    # 2x Build
    docker run --rm --entrypoint /app/spreet \
        -v "$(pwd)/$FLAT_DIR:/sources" -v "$OUTPUT_DIR:/output" \
        $DOCKER_IMAGE --retina /sources /output/${TEMAKI_OUT}@2x
else
    echo "FEHLER: Temaki Icons nicht gefunden."
fi

# Aufräumen Temaki
rm -rf "$TEMP_DIR" "$FLAT_DIR"

# ==========================================
# 4. ABSCHLUSS & RECHTE
# ==========================================
echo ""
echo "--- Fixiere Dateirechte... ---"
USER_ID=$(id -u)
GROUP_ID=$(id -g)
if [[ "$OSTYPE" != "msys" && "$OSTYPE" != "win32" ]]; then
     sudo chown $USER_ID:$GROUP_ID "$OUTPUT_DIR"/*sprite* 2>/dev/null || chown $USER_ID:$GROUP_ID "$OUTPUT_DIR"/*sprite*
fi

echo "=========================================="
echo "FERTIG! Folgende Dateien wurden erstellt:"
echo "=========================================="
ls -lh "$OUTPUT_DIR"/*sprite* | grep -E ".png|.json"
echo ""
echo "Nächste Schritte:"
echo "1. Lade diese Dateien auf deinen Webserver / S3 Bucket."
echo "2. Wähle in deiner style.json EINES der Sets aus:"
echo "   \"sprite\": \"https://dein-server.de/icons/maki-sprite\""
echo "   ODER"
echo "   \"sprite\": \"https://dein-server.de/icons/temaki-sprite\""
