#!/bin/bash

# ==========================================
# KONFIGURATION
# ==========================================
DOCKER_IMAGE="local-spreet-builder"
SPREET_REPO="https://github.com/flother/spreet.git"
OUTPUT_DIR="/srv/assets/sprites"
ATTRIBUTION_DIR="/srv/info/attribution"
INFO_DIR="/srv/info"
SPRITE_INVENTORY_FILE="sprite_inventory.json"
BUILD_DIR="/srv/build"

# Maki Einstellungen
MAKI_REPO="https://github.com/mapbox/maki.git"
MAKI_OUT="sprite"
MAKI_DIR="$OUTPUT_DIR/maki"

# Temaki Einstellungen
TEMAKI_REPO="https://github.com/rapideditor/temaki.git"
TEMAKI_OUT="sprite"
TEMAKI_DIR="$OUTPUT_DIR/temaki"

# ==========================================
# 1. VORBEREITUNG
# ==========================================
echo "### START: Sprite Builder ###"

if ! command -v docker &> /dev/null; then
    echo "FEHLER: Docker läuft nicht."
    exit 1
fi

mkdir -p "$OUTPUT_DIR" "$MAKI_DIR" "$TEMAKI_DIR"
sudo mkdir -p "$ATTRIBUTION_DIR/maki" "$ATTRIBUTION_DIR/temaki"

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
    if [ -f "$TEMP_DIR/LICENSE.txt" ]; then
        sudo cp "$TEMP_DIR/LICENSE.txt" "$ATTRIBUTION_DIR/maki/"
    fi
    if [ -f "$TEMP_DIR/README.md" ]; then
        sudo cp "$TEMP_DIR/README.md" "$ATTRIBUTION_DIR/maki/"
    fi
    # Maki hat flache Dateien, wir kopieren sie einfach
    cp "$TEMP_DIR/icons/"*.svg "$FLAT_DIR/"
    COUNT=$(ls -1 "$FLAT_DIR"/*.svg 2>/dev/null | wc -l)
    echo "    > $COUNT Maki Icons gefunden."

    # 1x Build
    docker run --rm --entrypoint /app/spreet \
        -v "$(pwd)/$FLAT_DIR:/sources" -v "$MAKI_DIR:/output" \
        $DOCKER_IMAGE /sources /output/$MAKI_OUT

    # 2x Build
    docker run --rm --entrypoint /app/spreet \
        -v "$(pwd)/$FLAT_DIR:/sources" -v "$MAKI_DIR:/output" \
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
    if [ -f "$TEMP_DIR/LICENSE" ]; then
        sudo cp "$TEMP_DIR/LICENSE" "$ATTRIBUTION_DIR/temaki/"
    fi
    if [ -f "$TEMP_DIR/README.md" ]; then
        sudo cp "$TEMP_DIR/README.md" "$ATTRIBUTION_DIR/temaki/"
    fi
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
        -v "$(pwd)/$FLAT_DIR:/sources" -v "$TEMAKI_DIR:/output" \
        $DOCKER_IMAGE /sources /output/$TEMAKI_OUT

    # 2x Build
    docker run --rm --entrypoint /app/spreet \
        -v "$(pwd)/$FLAT_DIR:/sources" -v "$TEMAKI_DIR:/output" \
        $DOCKER_IMAGE --retina /sources /output/${TEMAKI_OUT}@2x
else
    echo "FEHLER: Temaki Icons nicht gefunden."
fi

# Aufräumen Temaki
rm -rf "$TEMP_DIR" "$FLAT_DIR"

# ==========================================
# 4. SPRITES AUS /srv/build ÜBERNEHMEN
# ==========================================
echo ""
echo "--- Übernehme Tileset-Sprites aus $BUILD_DIR... ---"
if [[ -d "$BUILD_DIR" ]]; then
    while IFS= read -r -d '' tmp_dir; do
        tileset_id="$(basename "$(dirname "$tmp_dir")")"
        sprites_dir="$tmp_dir/sprites"
        if [[ ! -d "$sprites_dir" ]]; then
            continue
        fi
        tileset_output_dir="$OUTPUT_DIR/$tileset_id"
        mkdir -p "$tileset_output_dir"
        for sprite_file in sprite.json sprite.png sprite@2x.json sprite@2x.png; do
            if [[ -f "$sprites_dir/$sprite_file" ]]; then
                cp -f "$sprites_dir/$sprite_file" "$tileset_output_dir/$sprite_file"
            fi
        done
    done < <(find "$BUILD_DIR" -mindepth 2 -maxdepth 2 -type d -name tmp -print0)
else
    echo "⚠️ Build-Verzeichnis nicht gefunden: $BUILD_DIR"
fi

# ==========================================
# 5. ABSCHLUSS & RECHTE
# ==========================================
echo ""
echo "--- Fixiere Dateirechte... ---"
USER_ID=$(id -u)
GROUP_ID=$(id -g)
if [[ "$OSTYPE" != "msys" && "$OSTYPE" != "win32" ]]; then
     sudo chown -R $USER_ID:$GROUP_ID "$OUTPUT_DIR" 2>/dev/null || chown -R $USER_ID:$GROUP_ID "$OUTPUT_DIR"
fi

echo ""
echo "--- Erstelle Sprite-Inventar... ---"
mkdir -p "$INFO_DIR"
TMP_SPRITE_INVENTORY="$(mktemp)"
echo "{" > "$TMP_SPRITE_INVENTORY"
echo "  \"sprites\": [" >> "$TMP_SPRITE_INVENTORY"

mapfile -t SPRITE_FILES < <(find "$OUTPUT_DIR" -type f \( -name "*.json" -o -name "*.png" \) -print | sed "s|^$OUTPUT_DIR/||" | sort)
if [ "${#SPRITE_FILES[@]}" -gt 0 ]; then
    for index in "${!SPRITE_FILES[@]}"; do
        separator=","
        if [ "$index" -eq $((${#SPRITE_FILES[@]} - 1)) ]; then
            separator=""
        fi
        echo "    \"${SPRITE_FILES[$index]}\"$separator" >> "$TMP_SPRITE_INVENTORY"
    done
fi

echo "  ]" >> "$TMP_SPRITE_INVENTORY"
echo "}" >> "$TMP_SPRITE_INVENTORY"

mv "$TMP_SPRITE_INVENTORY" "$INFO_DIR/$SPRITE_INVENTORY_FILE"

echo "=========================================="
echo "FERTIG! Folgende Dateien wurden erstellt:"
echo "=========================================="
find "$OUTPUT_DIR" -type f \( -name "*.json" -o -name "*.png" \) -print0 | xargs -0 -r ls -lh | grep -E ".png|.json"
echo ""
echo "Nächste Schritte:"
echo "1. Lade diese Dateien auf deinen Webserver / S3 Bucket."
echo "2. Wähle in deiner style.json EINES der Sets aus:"
echo "   \"sprite\": \"https://dein-server.de/icons/sprites/maki/sprite\""
echo "   ODER"
echo "   \"sprite\": \"https://dein-server.de/icons/sprites/temaki/sprite\""
