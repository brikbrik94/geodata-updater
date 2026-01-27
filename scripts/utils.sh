#!/bin/bash

# --- FARBEN & FORMATIERUNG ---
# Nutzt ANSI Escape Codes für farbige Ausgabe
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m' # No Color

# --- LOGGING FUNKTIONEN ---

# Große Abschnitts-Überschrift
# Nutzung: log_section "Download Phase"
log_section() {
    echo ""
    echo -e "${BOLD}${BLUE}==========================================================${NC}"
    echo -e "${BOLD}${BLUE}   $1${NC}"
    echo -e "${BOLD}${BLUE}==========================================================${NC}"
}

# Unter-Überschrift (z.B. für eine einzelne Karte)
# Nutzung: log_header "Verarbeite Karte: Tirol"
log_header() {
    echo -e "${BOLD}${CYAN}👉 $1${NC}"
}

# Standard Info
# Nutzung: log_info "Prüfe Dateien..."
log_info() {
    echo -e "   ${DIM}ℹ️  $1${NC}"
}

# Erfolg
# Nutzung: log_success "Datei erstellt."
log_success() {
    echo -e "   ${GREEN}✅ $1${NC}"
}

# Warnung
# Nutzung: log_warn "Datei existiert nicht, überspringe."
log_warn() {
    echo -e "   ${YELLOW}⚠️  $1${NC}"
}

# Fehler (beendet das Skript optional nicht, Nutzung mit exit 1 wenn nötig)
# Nutzung: log_error "Konnte Server nicht erreichen."
log_error() {
    echo -e "   ${RED}❌ $1${NC}" >&2
}

# Zeitstempel Hilfsfunktion
get_timestamp() {
    date "+%H:%M:%S"
}

