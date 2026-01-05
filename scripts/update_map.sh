#!/bin/bash
set -euo pipefail

LOGFILE="${LOGFILE:-/var/log/osm_update.log}"
if [ ! -w "$(dirname "$LOGFILE")" ] && [ ! -w "$LOGFILE" ]; then
    LOGFILE="${LOGFILE_FALLBACK:-/srv/scripts/osm_update.log}"
    mkdir -p "$(dirname "$LOGFILE")"
fi

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
