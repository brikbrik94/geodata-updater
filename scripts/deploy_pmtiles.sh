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

log_section "DEPLOY: PMTILES"

# Config-Check: Sind die Variablen aus config.env da?
: "${TILES_DIR:?Variable TILES_DIR fehlt (config.env?)}"
: "${BUILD_DIR:?Variable BUILD_DIR fehlt (config.env?)}"

# Definition der zu deployenden Dateien
# Format: "tileset_ordner:dateiname.pmtiles"
DEFAULT_TARGETS=(
  "osm:at-plus.pmtiles"
  "basemap-at:basemap-at.pmtiles"
  "overlays:basemap-at-contours.pmtiles"
)

# Falls Targets per Env übergeben wurden, diese nutzen (für Spezialfälle)
if [[ -n "${PMTILES_TARGETS:-}" ]]; then
  mapfile -t TARGETS <<<"${PMTILES_TARGETS}"
else
  TARGETS=("${DEFAULT_TARGETS[@]}")
fi

missing=0

for target in "${TARGETS[@]}"; do
  # Validierung des Formats
  if [[ "$target" != *:* ]]; then
    log_error "Ungültiger Eintrag: '$target' (Erwarte: ordner:datei.pmtiles)"
    missing=1
    continue
  fi

  tileset="${target%%:*}"
  filename="${target#*:}"

  # --- Quelle finden ---
  # 1. Versuch: Direkt im tmp Ordner
  src="$BUILD_DIR/$tileset/tmp/$filename"

  # 2. Versuch: Im Unterordner (Dateiname ohne Endung als Ordner)
  # Beispiel: overlays/tmp/basemap-at-contours/basemap-at-contours.pmtiles
  if [[ ! -f "$src" ]]; then
      filename_no_ext="${filename%.*}"
      src_subdir="$BUILD_DIR/$tileset/tmp/$filename_no_ext/$filename"
      if [[ -f "$src_subdir" ]]; then
          src="$src_subdir"
      fi
  fi

  # --- Ziel definieren ---
  dest_dir="$TILES_DIR/$tileset/pmtiles"
  dest="$dest_dir/$filename"

  # --- Prüfen & Kopieren ---
  if [[ ! -f "$src" ]]; then
    log_warn "Quelle fehlt: $filename"
    log_info "Gesucht in: $BUILD_DIR/$tileset/tmp/..."
    missing=1
    continue
  fi

  mkdir -p "$dest_dir"
  
  # Kopieren (überschreiben erzwingen)
  cp -f "$src" "$dest"
  chmod 644 "$dest"
  
  log_success "$tileset: $filename installiert."

done

if [[ "$missing" -ne 0 ]]; then
  log_error "Deployment unvollständig (siehe oben)."
  exit 1
fi

# (Kein Exit hier, damit run_deploy.sh weiterlaufen kann)
