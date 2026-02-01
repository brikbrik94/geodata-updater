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

log_header "ASSETS SETUP (Fonts & Sprites)"

# ---------------------------------------------------------
# 1. FONTS INSTALLIEREN
# ---------------------------------------------------------
# Lädt die Schriften herunter und entpackt sie nach /srv/assets/fonts
if [ -f "$SCRIPT_DIR/install_fonts.sh" ]; then
    "$SCRIPT_DIR/install_fonts.sh"
else
    log_warn "install_fonts.sh nicht gefunden - überspringe Download."
fi

# ---------------------------------------------------------
# 2. FONT INVENTORY & CLEANUP
# ---------------------------------------------------------
# Löscht defekte Ranges (<100 Byte) und erstellt font_inventory.json
if [ -f "$SCRIPT_DIR/font_inventory.sh" ]; then
    # Wir rufen es direkt auf. Das Skript nutzt eigene echo-Befehle,
    # daher lassen wir es einfach durchlaufen.
    "$SCRIPT_DIR/font_inventory.sh"
else
    log_warn "font_inventory.sh nicht gefunden - Inventory wird nicht aktualisiert."
fi

# ---------------------------------------------------------
# 3. SPRITES GENERIEREN
# ---------------------------------------------------------
# Erstellt die Icons (Sprite-Sheet) aus den SVGs
if [ -f "$SCRIPT_DIR/build_sprites.sh" ]; then
    "$SCRIPT_DIR/build_sprites.sh"
else
    log_warn "build_sprites.sh nicht gefunden - überspringe Sprites."
fi

log_success "Assets Setup abgeschlossen."
