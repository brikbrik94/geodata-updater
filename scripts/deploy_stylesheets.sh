#!/usr/bin/env bash
set -euo pipefail

# --- KONFIGURATION ---
TILES_DIR="${TILES_DIR:-/srv/tiles}"
BUILD_DIR="${BUILD_DIR:-/srv/build}"
# Fallback auf das styles/ Verzeichnis im Repo-Root, falls im Build nichts liegt
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STYLES_FALLBACK_DIR="${STYLES_SOURCE_DIR:-$REPO_ROOT/styles}"

# 1. Targets definieren (Identisch zu deploy_pmtiles.sh für Konsistenz)
DEFAULT_TARGETS=(
  "osm:at-plus.pmtiles"
  "basemap-at:basemap-at.pmtiles"
  "overlays:basemap-at-contours.pmtiles"
)

if [[ -n "${PMTILES_TARGETS:-}" ]]; then
  mapfile -t TARGETS <<<"${PMTILES_TARGETS}"
else
  TARGETS=("${DEFAULT_TARGETS[@]}")
fi

echo "🎨 Start Stylesheet Deployment für ${#TARGETS[@]} Targets..."

# --- HAUPTSCHLEIFE ---
for target in "${TARGETS[@]}"; do
  # Format prüfen (tileset:dateiname)
  if [[ "$target" != *:* ]]; then
    echo "⚠️  Überspringe ungültiges Target Format: $target"
    continue
  fi

  tileset="${target%%:*}"
  filename="${target#*:}"
  
  # LOGIK: Style-ID ist der Dateiname OHNE Endung
  # at-plus.pmtiles -> at-plus
  style_id="${filename%.*}"
  
  # Ziel: /srv/tiles/osm/styles/at-plus
  dest_dir="$TILES_DIR/$tileset/styles/$style_id"
  
  # Quelle bestimmen:
  # Zuerst schauen wir, ob im Build-Ordner (tmp/styles) etwas generiert wurde (z.B. bei basemap.at)
  # Wenn nicht, nehmen wir den statischen styles/ Ordner aus dem Repo.
  src_dir="$BUILD_DIR/$tileset/tmp/styles"
  if [[ ! -d "$src_dir" ]]; then
    src_dir="$STYLES_FALLBACK_DIR"
  fi

  echo "➡️  Verarbeite: $tileset -> $style_id"

  # --- STYLE SUCHEN (Hierarchie) ---
  found_style=""

  # 1. Spezifischer Style für diese ID (z.B. styles/osm/at-plus/style.json)
  if [[ -f "$src_dir/$tileset/$style_id/style.json" ]]; then
    found_style="$src_dir/$tileset/$style_id/style.json"
    
  # 2. Allgemeiner Style für das Tileset (z.B. styles/osm/style.json)
  elif [[ -f "$src_dir/$tileset/style.json" ]]; then
    found_style="$src_dir/$tileset/style.json"

  # 3. VTPK Root Datei (Spezialfall für basemap.at Extrakte)
  elif [[ -f "$src_dir/root.json" ]]; then
    found_style="$src_dir/root.json"
    
  # 4. Globaler Fallback (z.B. styles/style.json im Repo Root)
  elif [[ -f "$src_dir/style.json" ]]; then
    found_style="$src_dir/style.json"
  fi

  # --- KOPIEREN ---
  if [[ -n "$found_style" ]]; then
    mkdir -p "$dest_dir"
    cp -f "$found_style" "$dest_dir/style.json"
    chmod 644 "$dest_dir/style.json"
    echo "   ✅ OK: $found_style"
    echo "      -> $dest_dir/style.json"
  else
    echo "   ❌ Warnung: Kein passendes style.json in $src_dir gefunden."
  fi

done

echo "✅ Stylesheet Deployment abgeschlossen."
