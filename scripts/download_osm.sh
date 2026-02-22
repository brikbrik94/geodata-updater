#!/bin/bash
set -euo pipefail

# Utils laden (lädt auch config.env)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/utils.sh" ]; then
    source "$SCRIPT_DIR/utils.sh"
else
    echo "❌ Fehler: utils.sh nicht gefunden!"
    exit 1
fi

# --- KONFIGURATION ---
# Wir nutzen die Variablen aus config.env, falls vorhanden
# SOURCES_DIR: Wo liegen die .txt Dateien? (Standard: /srv/scripts/sources)
SOURCES_DIR="${INSTALL_DIR:-/srv/scripts}/sources"

# DOWNLOAD_BASE_DIR: Wo sollen die PBFs hin? (Standard: /srv/build/osm/src)
DOWNLOAD_BASE_DIR="${OSM_BUILD_DIR:-/srv/build/osm}/src"

log_section "SCHRITT 1: DOWNLOAD OSM DATEN"

if [ ! -d "$SOURCES_DIR" ]; then
    log_error "Quellen-Verzeichnis nicht gefunden: $SOURCES_DIR"
    exit 1
fi

mkdir -p "$DOWNLOAD_BASE_DIR"

get_final_url() {
    local input_url="$1"
    if command -v curl >/dev/null 2>&1; then
        curl -Ls -o /dev/null -w '%{url_effective}' "$input_url"
    else
        # Fallback ohne curl: nutze Original-URL
        echo "$input_url"
    fi
}

# Zähler
COUNT=0

# --- HAUPTSCHLEIFE ---
# (Ab hier deine Original-Logik)
for source_file in "$SOURCES_DIR"/*.txt; do
    [ -e "$source_file" ] || continue

    MAP_NAME="$(basename "$source_file" .txt)"
    LIST_FILE="$DOWNLOAD_BASE_DIR/${MAP_NAME}.list"

    log_header "Konfiguration: $MAP_NAME"

    # Liste leeren
    > "$LIST_FILE"

    mapfile -t URLS < <(grep -vE '^\s*($|#)' "$source_file")

    if [ ${#URLS[@]} -eq 0 ]; then
        log_warn "Keine URLs in $source_file gefunden."
        continue
    fi

    for LINK in "${URLS[@]}"; do
        FILENAME=$(basename "$LINK")
        FULL_PATH="$DOWNLOAD_BASE_DIR/$FILENAME"
        META_FILE="$DOWNLOAD_BASE_DIR/.${FILENAME}.source-url"
        FINAL_URL="$(get_final_url "$LINK")"

        # Wir nutzen aria2c für parallele Downloads
        log_info "Prüfe: $FILENAME"

        if ! command -v aria2c >/dev/null 2>&1; then
            log_error "aria2c nicht gefunden. Bitte installieren."
            exit 1
        fi

        # Geofabrik *-latest URLs zeigen auf datierte Dateien.
        # Wenn sich das Redirect-Ziel ändert, wird die lokale Datei verworfen,
        # damit keine korrupten Mischstände durch alte Partials entstehen.
        if [ -f "$FULL_PATH" ] && [ -f "$META_FILE" ]; then
            PREV_FINAL_URL="$(cat "$META_FILE")"
            if [ "$PREV_FINAL_URL" != "$FINAL_URL" ]; then
                log_warn "Remote-Version geändert: $(basename "$PREV_FINAL_URL") -> $(basename "$FINAL_URL")"
                log_info " -> Starte Full-Redownload: $FILENAME"
                rm -f "$FULL_PATH" "$FULL_PATH.aria2"
            fi
        fi

        # Ohne -c (continue), damit kein unsicheres Resume alter Partials erfolgt.
        # --conditional-get=true lädt nur neu, wenn die Remote-Datei geändert wurde.
        if aria2c --conditional-get=true -x16 -s16 --allow-overwrite=true --auto-file-renaming=false -d "$DOWNLOAD_BASE_DIR" -o "$FILENAME" "$LINK"; then
            if [ -f "$FULL_PATH" ]; then
                if command -v osmium >/dev/null 2>&1 && osmium fileinfo "$FULL_PATH" >/dev/null 2>&1; then
                    echo "$FINAL_URL" > "$META_FILE"
                    echo "$FULL_PATH" >> "$LIST_FILE"
                    COUNT=$((COUNT+1))
                else
                    log_error "Datei ist nicht als OSM PBF lesbar: $FULL_PATH"
                    rm -f "$FULL_PATH" "$FULL_PATH.aria2"
                fi
            else
                 log_error "Download scheinbar ok, aber Datei fehlt: $FILENAME"
            fi
        else
            log_error "Download fehlgeschlagen: $LINK"
        fi
    done

    if [ -s "$LIST_FILE" ]; then
        ENTRY_COUNT=$(wc -l < "$LIST_FILE")
        log_success "Liste erstellt ($ENTRY_COUNT Dateien)."
    fi
    echo "" # Leerzeile für Abstand
done

log_success "Download abgeschlossen. $COUNT Dateien bereit."
