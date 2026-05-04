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

get_expected_md5() {
    local final_url="$1"
    if ! command -v curl >/dev/null 2>&1; then
        return 1
    fi

    local md5_line
    md5_line="$(curl -fsSL "${final_url}.md5" 2>/dev/null | head -n1 || true)"
    if [ -z "$md5_line" ]; then
        return 1
    fi

    echo "$md5_line" | awk '{print $1}' | tr '[:upper:]' '[:lower:]'
}

validate_osm_pbf() {
    local pbf="$1"

    if ! command -v osmium >/dev/null 2>&1; then
        log_warn "osmium nicht verfügbar - überspringe Integritätsprüfung für $(basename "$pbf")."
        return 0
    fi

    # fileinfo prüft Header, cat liest den gesamten Stream und findet Dekompressionsfehler zuverlässig.
    osmium fileinfo "$pbf" >/dev/null 2>&1 && osmium cat -f opl "$pbf" >/dev/null 2>&1
}

verify_md5_if_available() {
    local pbf="$1"
    local final_url="$2"

    if ! command -v md5sum >/dev/null 2>&1; then
        log_warn "md5sum nicht verfügbar - überspringe MD5-Check für $(basename "$pbf")."
        return 0
    fi

    local expected actual
    expected="$(get_expected_md5 "$final_url" || true)"

    if [ -z "$expected" ] || ! [[ "$expected" =~ ^[0-9a-f]{32}$ ]]; then
        log_info "Keine verwertbare MD5 von $(basename "$final_url").md5 gefunden - überspringe MD5-Check."
        return 0
    fi

    actual="$(md5sum "$pbf" | awk '{print $1}' | tr '[:upper:]' '[:lower:]')"
    if [ "$actual" != "$expected" ]; then
        log_error "MD5 mismatch für $(basename "$pbf"): erwartet $expected, bekommen $actual"
        return 1
    fi

    return 0
}

# Zähler
COUNT=0

# --- HAUPTSCHLEIFE ---
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

        log_info "Prüfe: $FILENAME"

        if ! command -v aria2c >/dev/null 2>&1; then
            log_error "aria2c nicht gefunden. Bitte installieren."
            exit 1
        fi

        FORCE_RELOAD=0
        if [ -f "$FULL_PATH" ] && [ -f "$META_FILE" ]; then
            PREV_FINAL_URL="$(cat "$META_FILE")"
            if [ "$PREV_FINAL_URL" != "$FINAL_URL" ]; then
                log_warn "Remote-Version geändert: $(basename "$PREV_FINAL_URL") -> $(basename "$FINAL_URL")"
                FORCE_RELOAD=1
            fi
        fi

        if [ "$FORCE_RELOAD" -eq 1 ]; then
            log_info " -> Full-Redownload wegen Versionswechsel"
            rm -f "$FULL_PATH" "$FULL_PATH.aria2"
        elif [ -f "$FULL_PATH" ]; then
            log_info " -> Nutze bestehende Datei mit Conditional-Get-Prüfung"
        else
            log_info " -> Starte neuen Download"
        fi

        SUCCESS=0
        for attempt in 1 2; do
            if aria2c --conditional-get=true -x16 -s16 --allow-overwrite=true --auto-file-renaming=false -d "$DOWNLOAD_BASE_DIR" -o "$FILENAME" "$LINK"; then
                if [ ! -f "$FULL_PATH" ]; then
                    log_error "Download scheinbar ok, aber Datei fehlt: $FILENAME"
                    continue
                fi

                if ! validate_osm_pbf "$FULL_PATH"; then
                    log_error "Integritätscheck fehlgeschlagen: $FULL_PATH"
                    rm -f "$FULL_PATH" "$FULL_PATH.aria2"
                    [ "$attempt" -eq 1 ] && log_warn "Neuer Versuch mit Full-Redownload ..."
                    continue
                fi

                if ! verify_md5_if_available "$FULL_PATH" "$FINAL_URL"; then
                    rm -f "$FULL_PATH" "$FULL_PATH.aria2"
                    [ "$attempt" -eq 1 ] && log_warn "Neuer Versuch nach MD5-Fehler ..."
                    continue
                fi

                echo "$FINAL_URL" > "$META_FILE"
                echo "$FULL_PATH" >> "$LIST_FILE"
                COUNT=$((COUNT + 1))
                SUCCESS=1
                break
            fi

            log_error "Download fehlgeschlagen: $LINK"
            [ "$attempt" -eq 1 ] && log_warn "Neuer Versuch ..."
        done

        if [ "$SUCCESS" -ne 1 ]; then
            log_error "Datei konnte nicht zuverlässig geladen werden: $FILENAME"
            exit 1
        fi
    done

    if [ -s "$LIST_FILE" ]; then
        ENTRY_COUNT=$(wc -l < "$LIST_FILE")
        log_success "Liste erstellt ($ENTRY_COUNT Dateien)."
    fi
    echo "" # Leerzeile für Abstand
done

log_success "Download abgeschlossen. $COUNT Dateien bereit."
