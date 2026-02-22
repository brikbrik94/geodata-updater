#!/bin/bash
set -euo pipefail

# 1. Utils & Config laden
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/utils.sh" ]; then
    source "$SCRIPT_DIR/utils.sh"
else
    echo "❌ Fehler: utils.sh nicht gefunden!"
    exit 1
fi

log_section "ASSETS: SPRITE BUILDER"

# --- KONFIGURATION (mit Defaults aus utils/env oder Hardcoded) ---
OUTPUT_DIR="${ASSETS_DIR:-/srv/assets}/sprites"
INFO_DIR="${INFO_DIR:-/srv/info}"
BUILD_DIR="${BUILD_DIR:-/srv/build}"
ATTRIBUTION_DIR="$INFO_DIR/attribution"
SPRITE_INVENTORY_FILE="${SPRITE_INVENTORY_FILE:-sprite_inventory.json}"

# Externe Repos
DOCKER_IMAGE="local-spreet-builder"
SPREET_REPO="https://github.com/flother/spreet.git"
MAKI_REPO="https://github.com/mapbox/maki.git"
TEMAKI_REPO="https://github.com/rapideditor/temaki.git"

# Unterordner
MAKI_DIR="$OUTPUT_DIR/maki"
TEMAKI_DIR="$OUTPUT_DIR/temaki"
MAKI_OUT="sprite"
TEMAKI_OUT="sprite"

# --- VORBEREITUNG ---
if ! command -v docker &> /dev/null; then
    log_error "Docker läuft nicht. Abbruch."
    exit 1
fi

mkdir -p "$OUTPUT_DIR" "$MAKI_DIR" "$TEMAKI_DIR" "$INFO_DIR"
# Sudo nur wenn nötig (bei Systempfaden oft nötig)
if [ -w "$ATTRIBUTION_DIR" ]; then
    mkdir -p "$ATTRIBUTION_DIR/maki" "$ATTRIBUTION_DIR/temaki"
else
    sudo mkdir -p "$ATTRIBUTION_DIR/maki" "$ATTRIBUTION_DIR/temaki"
fi

# Image bauen (falls fehlt)
if [[ "$(docker images -q $DOCKER_IMAGE 2> /dev/null)" == "" ]]; then
    log_info "Baue Docker Image ($DOCKER_IMAGE)..."
    docker build -t $DOCKER_IMAGE $SPREET_REPO > /dev/null
fi

# --- 1. MAKI PROZESS ---
log_info "Verarbeite MAKI Icons..."
TEMP_DIR="temp_maki_build"
FLAT_DIR="flat_maki"
rm -rf "$TEMP_DIR" "$FLAT_DIR"
mkdir -p "$FLAT_DIR"

git clone --depth 1 "$MAKI_REPO" "$TEMP_DIR" > /dev/null 2>&1

if [ -d "$TEMP_DIR/icons" ]; then
    # Attribution
    if [ -f "$TEMP_DIR/LICENSE.txt" ]; then sudo cp "$TEMP_DIR/LICENSE.txt" "$ATTRIBUTION_DIR/maki/"; fi
    
    # Icons kopieren
    cp "$TEMP_DIR/icons/"*.svg "$FLAT_DIR/"
    COUNT=$(ls -1 "$FLAT_DIR"/*.svg 2>/dev/null | wc -l)
    echo "      > $COUNT Maki Icons gefunden."

    # Build 1x & 2x
    docker run --rm --entrypoint /app/spreet \
        -v "$(pwd)/$FLAT_DIR:/sources" -v "$MAKI_DIR:/output" \
        $DOCKER_IMAGE /sources /output/$MAKI_OUT >/dev/null

    docker run --rm --entrypoint /app/spreet \
        -v "$(pwd)/$FLAT_DIR:/sources" -v "$MAKI_DIR:/output" \
        $DOCKER_IMAGE --retina /sources /output/${MAKI_OUT}@2x >/dev/null
else
    log_warn "Maki Icons nicht gefunden (Download fehlgeschlagen?)"
fi

rm -rf "$TEMP_DIR" "$FLAT_DIR"

# --- 2. TEMAKI PROZESS ---
log_info "Verarbeite TEMAKI Icons..."
TEMP_DIR="temp_temaki_build"
FLAT_DIR="flat_temaki"
rm -rf "$TEMP_DIR" "$FLAT_DIR"
mkdir -p "$FLAT_DIR"

git clone --depth 1 "$TEMAKI_REPO" "$TEMP_DIR" > /dev/null 2>&1

if [ -d "$TEMP_DIR/icons" ]; then
    # Attribution
    if [ -f "$TEMP_DIR/LICENSE" ]; then sudo cp "$TEMP_DIR/LICENSE" "$ATTRIBUTION_DIR/temaki/"; fi
    
    # Flatten Structure
    cd "$TEMP_DIR/icons" || exit
    find . -type f -name "*.svg" | while read -r FILE; do
        CLEAN_PATH="${FILE#./}"
        NEW_NAME="${CLEAN_PATH//\//_}"
        cp "$FILE" "../../$FLAT_DIR/$NEW_NAME"
    done
    cd "$SCRIPT_DIR/.." # Zurück zum Root

    COUNT=$(ls -1 "$FLAT_DIR"/*.svg 2>/dev/null | wc -l)
    echo "      > $COUNT Temaki Icons gefunden."

    # Build
    docker run --rm --entrypoint /app/spreet \
        -v "$(pwd)/$FLAT_DIR:/sources" -v "$TEMAKI_DIR:/output" \
        $DOCKER_IMAGE /sources /output/$TEMAKI_OUT >/dev/null

    docker run --rm --entrypoint /app/spreet \
        -v "$(pwd)/$FLAT_DIR:/sources" -v "$TEMAKI_DIR:/output" \
        $DOCKER_IMAGE --retina /sources /output/${TEMAKI_OUT}@2x >/dev/null
else
    log_warn "Temaki Icons nicht gefunden."
fi

rm -rf "$TEMP_DIR" "$FLAT_DIR"

# --- 3. SPRITES AUS TILES-BUILD ÜBERNEHMEN ---
log_info "Prüfe auf Tileset-Sprites in $BUILD_DIR..."
if [[ -d "$BUILD_DIR" ]]; then
    FOUND_TILES_SPRITES=0
    # Wir suchen nach build/*/tmp/sprites
    # Nutze find mit mindepth, um direkt die tmp Ordner zu finden
    while IFS= read -r -d '' tmp_dir; do
        tileset_id="$(basename "$(dirname "$tmp_dir")")" # z.B. basemap-at
        sprites_dir="$tmp_dir/sprites"
        
        if [[ -d "$sprites_dir" ]]; then
            tileset_output_dir="$OUTPUT_DIR/$tileset_id"
            mkdir -p "$tileset_output_dir"
            
            # Kopiere die 4 Standard-Dateien
            for sprite_file in sprite.json sprite.png sprite@2x.json sprite@2x.png; do
                if [[ -f "$sprites_dir/$sprite_file" ]]; then
                    cp -f "$sprites_dir/$sprite_file" "$tileset_output_dir/$sprite_file"
                    FOUND_TILES_SPRITES=1
                fi
            done
            if [ $FOUND_TILES_SPRITES -eq 1 ]; then
                 echo "      > Übernommen: $tileset_id"
            fi
        fi
    done < <(find "$BUILD_DIR" -mindepth 2 -maxdepth 2 -type d -name tmp -print0)
fi

# --- 4. RECHTE ---
log_info "Setze Berechtigungen..."
USER_ID=$(id -u)
GROUP_ID=$(id -g)
if [[ "$OSTYPE" != "msys" ]]; then
     sudo chown -R $USER_ID:$GROUP_ID "$OUTPUT_DIR" 2>/dev/null || true
     chmod -R 755 "$OUTPUT_DIR"
fi

log_success "Sprites gebaut."
