#!/usr/bin/env bash
set -euo pipefail

TILES_DIR="${TILES_DIR:-/srv/tiles}"
TILES_BASE_URL="${TILES_BASE_URL:-}"
ASSETS_BASE_URL="${ASSETS_BASE_URL:-$TILES_BASE_URL}"
ENDPOINTS_INFO_PATH="${ENDPOINTS_INFO_PATH:-/srv/info/endpoints_info.json}"
SPRITE_URL_TEMPLATE="${SPRITE_URL_TEMPLATE:-${ASSETS_BASE_URL%/}/sprites/{tileset}/sprite}"
GLYPHS_URL_TEMPLATE="${GLYPHS_URL_TEMPLATE:-${ASSETS_BASE_URL%/}/fonts/{fontstack}/{range}.pbf}"
PMTILES_FILE_MAP="${PMTILES_FILE_MAP:-}"
PMTILES_FILE="${PMTILES_FILE:-}"

python3 - <<'PY'
import json
import os
from pathlib import Path

tiles_dir = Path(os.environ.get("TILES_DIR", "/srv/tiles"))
tiles_base_url = os.environ.get("TILES_BASE_URL", "").rstrip("/")
assets_base_url = os.environ.get("ASSETS_BASE_URL", "").rstrip("/")
endpoints_info_path = Path(
    os.environ.get("ENDPOINTS_INFO_PATH", "/srv/info/endpoints_info.json")
)
pmtiles_file = os.environ.get("PMTILES_FILE", "").strip()
pmtiles_map_raw = os.environ.get("PMTILES_FILE_MAP", "").strip()

if (not tiles_base_url or not assets_base_url) and endpoints_info_path.exists():
    endpoints_info = json.loads(endpoints_info_path.read_text(encoding="utf-8"))
    if not tiles_base_url:
        tiles_base_url = (endpoints_info.get("tiles_base_url") or "").rstrip("/")
    if not assets_base_url:
        assets_base_url = (endpoints_info.get("assets_base_url") or "").rstrip("/")

sprite_template = os.environ.get("SPRITE_URL_TEMPLATE", "").strip()
glyphs_template = os.environ.get("GLYPHS_URL_TEMPLATE", "").strip()
if not sprite_template and assets_base_url:
    sprite_template = f"{assets_base_url}/sprites/{{tileset}}/sprite"
if not glyphs_template and assets_base_url:
    glyphs_template = f"{assets_base_url}/fonts/{{fontstack}}/{{range}}.pbf"

if not tiles_base_url:
    raise SystemExit("❌ Keine tiles_base_url gefunden. Setze TILES_BASE_URL oder /srv/info/endpoints_info.json.")

font_map = {
    "Arial Regular": "Noto Sans Regular",
    "Arial Bold": "Noto Sans Bold",
    "Corbel Regular": "Open Sans Regular",
    "Corbel Italic": "Open Sans Italic",
    "Corbel Bold": "Open Sans Bold",
    "Corbel Bold Italic": "Open Sans Bold Italic",
    "Tahoma Regular": "Noto Sans Regular",
}

pmtiles_map = {}
if pmtiles_map_raw:
    for entry in pmtiles_map_raw.split():
        if ":" not in entry:
            print(f"⚠️ Ungültiger PMTILES_FILE_MAP Eintrag (erwartet tileset:file.pmtiles): {entry}")
            continue
        tileset, filename = entry.split(":", 1)
        pmtiles_map[tileset] = filename

def replace_fonts(node, changed_flag, replacements):
    if isinstance(node, dict):
        for key, value in node.items():
            node[key] = replace_fonts(value, changed_flag, replacements)
        return node
    if isinstance(node, list):
        for idx, value in enumerate(node):
            node[idx] = replace_fonts(value, changed_flag, replacements)
        return node
    if isinstance(node, str):
        replacement = font_map.get(node)
        if replacement and replacement != node:
            changed_flag[0] = True
            replacements.add((node, replacement))
            return replacement
    return node

style_files = sorted(tiles_dir.glob("*/styles/*/style.json"))
if not style_files:
    print(f"❌ Keine style.json Dateien unter {tiles_dir} gefunden.")
    raise SystemExit(1)

updated = 0
for style_path in style_files:
    tileset = style_path.parents[2].name
    style_id = style_path.parent.name
    current_pmtiles = pmtiles_map.get(tileset) or pmtiles_file
    if not current_pmtiles:
        pmtiles_dir = tiles_dir / tileset / "pmtiles"
        pmtiles_files = sorted(p.name for p in pmtiles_dir.glob("*.pmtiles"))
        if len(pmtiles_files) == 1:
            current_pmtiles = pmtiles_files[0]
        elif len(pmtiles_files) > 1:
            print(f"⚠️ Mehrere PMTiles gefunden für {tileset}, bitte PMTILES_FILE_MAP setzen.")

    data = json.loads(style_path.read_text(encoding="utf-8"))
    changed = [False]
    change_log = []
    font_replacements = set()

    data = replace_fonts(data, changed, font_replacements)
    if font_replacements:
        for old, new in sorted(font_replacements):
            change_log.append(f"    📝 Font: \"{old}\" -> \"{new}\"")

    if sprite_template:
        sprite_tileset = "temaki" if tileset == "osm" else tileset
        new_sprite = (
            sprite_template.replace("{tileset}", sprite_tileset)
            .replace("{style_id}", style_id)
        )
        if data.get("sprite") != new_sprite:
            change_log.append(f"    📝 Sprite: \"{data.get('sprite')}\" -> \"{new_sprite}\"")
            data["sprite"] = new_sprite
            changed[0] = True

    if glyphs_template:
        new_glyphs = (
            glyphs_template.replace("{tileset}", tileset)
            .replace("{style_id}", style_id)
            .replace("{fontstack}", "{fontstack}")
            .replace("{range}", "{range}")
        )
        if data.get("glyphs") != new_glyphs:
            change_log.append(f"    📝 Glyphs: \"{data.get('glyphs')}\" -> \"{new_glyphs}\"")
            data["glyphs"] = new_glyphs
            changed[0] = True

    if tiles_base_url and current_pmtiles:
        pmtiles_url = f"pmtiles://{tiles_base_url}/{tileset}/pmtiles/{current_pmtiles}"
        sources = data.get("sources", {})
        if isinstance(sources, dict):
            for source in sources.values():
                if not isinstance(source, dict):
                    continue
                url = source.get("url")
                if isinstance(url, str) and (
                    url.startswith("pmtiles://")
                    or "pfad/zu/deiner/datei.pmtiles" in url
                ):
                    if url != pmtiles_url:
                        change_log.append(f"    📝 Source URL: \"{url}\" -> \"{pmtiles_url}\"")
                        source["url"] = pmtiles_url
                        changed[0] = True

    if changed[0]:
        style_path.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
        updated += 1
        print(f"✅ Aktualisiert: {style_path}")
        if change_log:
            print("\n".join(change_log))
    else:
        print(f"ℹ️ Keine Änderungen nötig: {style_path}")

print(f"✅ Fertig. Aktualisierte Stylesheets: {updated}")
PY
