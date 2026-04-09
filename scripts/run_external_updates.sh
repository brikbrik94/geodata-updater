#!/bin/bash
set -euo pipefail

# 1. Utils laden
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/utils.sh" ]; then source "$SCRIPT_DIR/utils.sh"; else exit 1; fi

log_section "EXTERNE UPDATES TRIGGERN"

CONF_FILE="$(dirname "$SCRIPT_DIR")/conf/external_repos.txt"
if [ ! -f "$CONF_FILE" ]; then
    log_info "Keine externen Repositories konfiguriert ($CONF_FILE)."
    exit 0
fi

# 2. Zeilenweise lesen (Kommentare und Leerzeilen ignorieren)
grep -v '^#' "$CONF_FILE" | grep '[^[:space:]]' | while read -r repo_path; do
    # Tilde expandieren
    eval repo_path="$repo_path"

    if [ ! -d "$repo_path" ]; then
        log_warn "Überspringe: Verzeichnis nicht gefunden: $repo_path"
        continue
    fi

    log_header "Update: $(basename "$repo_path")"
    
    # 3. Update/Build Hook suchen
    UPD_HOOK=""
    for hook in "update.sh" "build.sh"; do
        if [ -x "$repo_path/$hook" ]; then
            UPD_HOOK="$repo_path/$hook"
            break
        fi
    done

    if [ -n "$UPD_HOOK" ]; then
        log_info "Starte $UPD_HOOK..."
        (cd "$repo_path" && bash "$UPD_HOOK")
        log_success "Update abgeschlossen."
    else
        log_info "Kein update.sh/build.sh gefunden. Überspringe Build-Schritt."
    fi
done
