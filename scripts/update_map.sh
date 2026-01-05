#!/bin/bash
set -euo pipefail

LOGFILE="${LOGFILE:-/var/log/osm_update.log}"
if [ ! -w "$(dirname "$LOGFILE")" ] && [ ! -w "$LOGFILE" ]; then
    LOGFILE="${LOGFILE_FALLBACK:-/srv/scripts/osm_update.log}"
    mkdir -p "$(dirname "$LOGFILE")"
fi
UPDATED_FLAG="/srv/osm/parts/updated.flag"
MERGED_FILE="/srv/osm/merged/complete_map.osm.pbf"
PMTILES_FILE="/srv/pmtiles/serve/at-plus.pmtiles"
INFO_JSON="/srv/pmtiles/serve/info.json"
TODAY="$(date +%Y-%m-%d)"

# Funktion für Logging mit Zeitstempel
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOGFILE"
}

log "=== START: Karten-Update Prozess ==="

# 1. Download
log "Schritt 1/3: Download starte..."
if ! /srv/scripts/download_osm.sh >> "$LOGFILE" 2>&1; then
    log "❌ FEHLER beim Download. Abbruch."
    exit 1
fi
if [ ! -f "$UPDATED_FLAG" ]; then
    if [ -f "$MERGED_FILE" ] && [ -f "$PMTILES_FILE" ] && [ -f "$INFO_JSON" ]; then
        DATASET_DATE=$(python3 -c "import json; print(json.load(open('$INFO_JSON')).get('dataset_date',''))" 2>/dev/null || true)
        if [ "$DATASET_DATE" = "$TODAY" ]; then
            log "ℹ️ Keine neuen Downloads und heutige PMTiles vorhanden. Merge und PMTiles werden übersprungen."
            exit 0
        fi
    fi
    log "ℹ️ Keine neuen Downloads, aber aktuelle Outputs fehlen. Merge/PMTiles laufen trotzdem."
fi

# 2. Merge
log "Schritt 2/3: Merge starte..."
if ! /srv/scripts/merge_osm.sh >> "$LOGFILE" 2>&1; then
    log "❌ FEHLER beim Mergen. Abbruch."
    exit 1
fi

# 3. PMTiles erstellen
log "Schritt 3/3: PMTiles Generierung starte..."
if ! /srv/scripts/create_pmtiles.sh >> "$LOGFILE" 2>&1; then
    log "❌ FEHLER bei Planetiler. Abbruch."
    exit 1
fi

log "✅ ERFOLG: Karte wurde komplett aktualisiert."
log "=== ENDE ==="
