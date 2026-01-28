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

# Config-Check
: "${ORS_DIR:?Variable ORS_DIR fehlt}"
: "${OSM_BUILD_DIR:?Variable OSM_BUILD_DIR fehlt}"
# Fallback, falls Variable in alter config.env noch fehlt
ORS_TARGET_NAME="${ORS_PBF_FILE:-osm_file.pbf}"

# Quell-Ordner: Wo liegen unsere fertigen PBFs? (Merged Output)
OSM_SRC_DIR="$OSM_BUILD_DIR/merged"

# Ziel-Datei für ORS
ORS_TARGET_PBF="$ORS_DIR/$ORS_TARGET_NAME"

log_section "ORS GRAPHIEN NEU BAUEN"

# 1. Verfügbare PBF-Dateien finden
mapfile -t AVAILABLE_PBFS < <(find "$OSM_SRC_DIR" -maxdepth 1 -name "*.osm.pbf" | sort)

if [ ${#AVAILABLE_PBFS[@]} -eq 0 ]; then
    log_error "Keine PBF-Dateien in $OSM_SRC_DIR gefunden!"
    log_info "Bitte zuerst scripts/run_merge.sh ausführen."
    exit 1
fi

SELECTED_FILE=""

# 2. Auswahl-Logik
if [ ${#AVAILABLE_PBFS[@]} -eq 1 ]; then
    # Automatisch wählen bei nur einer Datei
    SELECTED_FILE="${AVAILABLE_PBFS[0]}"
    log_info "Automatische Wahl: $(basename "$SELECTED_FILE")"
else
    # Interaktive Auswahl
    if [ -t 0 ]; then
        echo -e "${BLUE}Bitte wähle die PBF-Datei für den ORS Graph:${NC}"
        i=1
        for pbf in "${AVAILABLE_PBFS[@]}"; do
            echo "  [$i] $(basename "$pbf")"
            ((i++))
        done
        echo "  [q] Abbrechen"
        
        while true; do
            read -r -p "Auswahl (1-${#AVAILABLE_PBFS[@]}): " choice
            if [[ "$choice" == "q" ]]; then
                log_info "Abbruch durch Benutzer."
                exit 0
            fi
            
            if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#AVAILABLE_PBFS[@]}" ]; then
                INDEX=$((choice - 1))
                SELECTED_FILE="${AVAILABLE_PBFS[$INDEX]}"
                break
            else
                echo "Ungültige Eingabe."
            fi
        done
    else
        # Nicht-Interaktiv (Cronjob): Erste Datei nehmen
        SELECTED_FILE="${AVAILABLE_PBFS[0]}"
        log_warn "Cron-Modus: Nutze erste Datei: $(basename "$SELECTED_FILE")"
    fi
fi

# 3. Kopieren
log_info "Quelle: $(basename "$SELECTED_FILE")"
log_info "Ziel:   $ORS_TARGET_PBF"

mkdir -p "$ORS_DIR"
cp -f "$SELECTED_FILE" "$ORS_TARGET_PBF"

# 4. Rebuild Trigger
if [ -x "$ORS_DIR/rebuild_graphs.sh" ]; then
    log_info "Starte ORS-Rebuild Skript..."
    "$ORS_DIR/rebuild_graphs.sh"
elif [ -n "${ORS_REBUILD_CMD:-}" ]; then
    log_info "Führe ORS-Rebuild Befehl aus..."
    bash -c "$ORS_REBUILD_CMD"
else
    log_success "Datei bereitgestellt. Bitte ORS Container neu starten."
fi
