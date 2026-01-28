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

log_section "DEPLOY: STYLESHEETS"

# Config-Check
: "${TILES_DIR:?Fehlt}"
: "${BUILD_DIR:?Fehlt}"
: "${TILES_BASE_URL:?Fehlt}"

# Repo Root für statische Styles (z.B. OSM)
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Targets definieren
# Format: "tileset:pmtiles_datei"
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

for target in "${TARGETS[@]}"; do
    if [[ "$target" != *:* ]]; then continue; fi

    tileset="${target%%:*}"
    filename="${target#*:}"
    filename_no_ext="${filename%.*}"
    style_id="$filename_no_ext"

    # --- 1. Quelle finden ---
    src=""
    
    # A) Prüfen auf extrahiertes root.json (typisch für VTPK imports wie Basemap/Contours)
    # Suchpfad 1: Im Unterordner (neu) -> build/overlays/tmp/basemap-at-contours/styles/root.json
    path_vtpk_sub="$BUILD_DIR/$tileset/tmp/$filename_no_ext/styles/root.json"
    # Suchpfad 2: Direkt im tmp/styles (alt) -> build/basemap-at/tmp/styles/root.json
    path_vtpk_flat="$BUILD_DIR/$tileset/tmp/styles/root.json"

    if [ -f "$path_vtpk_sub" ]; then
        src="$path_vtpk_sub"
    elif [ -f "$path_vtpk_flat" ]; then
        src="$path_vtpk_flat"
    fi

    # B) Fallback für OSM: Statischer Style aus dem Repo
    if [ -z "$src" ] && [ "$tileset" == "osm" ]; then
        # Versuche verschiedene Orte für den OSM Style
        if [ -f "$REPO_ROOT/styles/style.json" ]; then
            src="$REPO_ROOT/styles/style.json"
        elif [ -f "$TILES_DIR/osm/styles/at-plus/style.json" ]; then
            # Falls er schon da ist (manuell kopiert), nutzen wir ihn als Basis
            src="$TILES_DIR/osm/styles/at-plus/style.json"
        fi
    fi

    if [ -z "$src" ]; then
        log_warn "Kein Style gefunden für $target - überspringe."
        continue
    fi

    # --- 2. Ziel vorbereiten ---
    dest_dir="$TILES_DIR/$tileset/styles/$style_id"
    dest_file="$dest_dir/style.json"
    mkdir -p "$dest_dir"

    # --- 3. Kopieren & Anpassen ---
    # Wir nutzen sed, um die URL zur PMTiles Datei einzusetzen
    # Ziel-URL Format: "pmtiles://https://tiles.oe5ith.at/tileset/pmtiles/datei.pmtiles"
    
    public_url="pmtiles://$TILES_BASE_URL/$tileset/pmtiles/$filename"
    
    # Logik:
    # 1. Kopiere Datei
    cp "$src" "$dest_file"
    
    # 2. Ersetze Platzhalter oder bestehende URLs
    # VTPK styles haben oft "url": "..." im "sources" Block.
    # Wir suchen nach der Zeile mit "url": und ersetzen den Inhalt.
    # Hinweis: Das ist ein simpler Replace. Für komplexe JSONs wäre jq besser, aber sed reicht meist.
    
    # Temporäre Datei
    tmp_sed=$(mktemp)
    
    if [ "$tileset" == "osm" ]; then
        # Bei OSM ersetzen wir "{TILE_URL}" oder passen "url": an
        sed "s|{TILE_URL}|$public_url|g" "$dest_file" > "$tmp_sed"
    else
        # Bei VTPKs (Basemap) ersetzen wir die interne Referenz
        # Wir suchen nach "url": "..." innerhalb der sources und tauschen es hart aus.
        # Achtung: Das ersetzt ALLE "url": Einträge. Bei einem VTPK Style gibt es meist nur eine Source.
        sed "s|\"url\": *\"[^\"]*\"|\"url\": \"$public_url\"|g" "$dest_file" > "$tmp_sed"
    fi
    
    mv "$tmp_sed" "$dest_file"
    chmod 644 "$dest_file"

    log_success "Style erstellt: $tileset/$style_id"
done
