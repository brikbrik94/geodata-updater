#!/usr/bin/env python3
import json
import os
import sys
from pathlib import Path

# --- KONFIGURATION AUS ENV ---
TILES_DIR = Path(os.environ.get("TILES_DIR", "/srv/tiles"))
TILES_BASE_URL = os.environ.get("TILES_BASE_URL", "").rstrip("/")
ASSETS_BASE_URL = os.environ.get("ASSETS_BASE_URL", "").rstrip("/")
ENDPOINTS_INFO_PATH = Path(os.environ.get("ENDPOINTS_INFO_PATH", "/srv/info/endpoints_info.json"))
SPRITE_MAPPING_FILE = Path(os.environ.get("SPRITE_MAPPING_FILE", str(Path(__file__).resolve().parent.parent / "conf" / "sprite_mapping.json")))

# Templates
SPRITE_URL_TEMPLATE = os.environ.get("SPRITE_URL_TEMPLATE", "").strip()
GLYPHS_URL_TEMPLATE = os.environ.get("GLYPHS_URL_TEMPLATE", "").strip()

# Globale PMTiles Einstellung (Fallback)
PMTILES_FILE_GLOBAL = os.environ.get("PMTILES_FILE", "").strip()
PMTILES_FILE_MAP_RAW = os.environ.get("PMTILES_FILE_MAP", "").strip()

# --- LOGGING HELPER ---
def log_info(msg):
    print(f"   ℹ️  {msg}")

def log_success(msg):
    print(f"   ✅ {msg}")

def log_warn(msg):
    print(f"   ⚠️  {msg}")

def log_error(msg):
    print(f"   ❌ {msg}")

# --- INIT ---
if not TILES_BASE_URL:
    log_warn("Keine TILES_BASE_URL gefunden. Links werden evtl. unvollständig sein.")

# Defaults für Templates berechnen, falls leer
if not SPRITE_URL_TEMPLATE and ASSETS_BASE_URL:
    SPRITE_URL_TEMPLATE = f"{ASSETS_BASE_URL}/sprites/{{tileset}}/sprite"
if not GLYPHS_URL_TEMPLATE and ASSETS_BASE_URL:
    GLYPHS_URL_TEMPLATE = f"{ASSETS_BASE_URL}/fonts/{{fontstack}}/{{range}}.pbf"

# Endpoints Info laden
tiles_entries = []
if ENDPOINTS_INFO_PATH.exists():
    try:
        info_data = json.loads(ENDPOINTS_INFO_PATH.read_text(encoding="utf-8"))
        
        # NEU: Wir unterstützen das neue "datasets" Format und das alte "tiles" Format
        tiles_entries = info_data.get("datasets", [])
        if not tiles_entries:
            tiles_entries = info_data.get("tiles", []) or []

        # Fallback: Falls URL im Env fehlt, nimm die aus der JSON
        if not TILES_BASE_URL:
            TILES_BASE_URL = (info_data.get("tiles_base_url") or "").rstrip("/")
    except Exception as e:
        log_warn(f"Fehler beim Lesen von endpoints_info.json: {e}")

# Mapping parsen (tileset -> filename)
pmtiles_map = {}
if PMTILES_FILE_MAP_RAW:
    for entry in PMTILES_FILE_MAP_RAW.split():
        if ":" in entry:
            parts = entry.split(":", 1)
            pmtiles_map[parts[0]] = parts[1]

# Font Mapping (für Standardisierung)
FONT_MAP = {
    "Arial Regular": "Noto Sans Regular",
    "Arial Bold": "Noto Sans Bold",
    "Corbel Regular": "Open Sans Regular",
    "Corbel Italic": "Open Sans Italic",
    "Corbel Bold": "Open Sans Bold",
    "Corbel Bold Italic": "Open Sans Bold Italic",
    "Tahoma Regular": "Noto Sans Regular",
}

MAPLIBRE_OSM_ATTRIBUTION = (
    '© <a href="https://www.openstreetmap.org/copyright" '
    'target="_blank" rel="noopener noreferrer">OpenStreetMap contributors</a>'
)
BASEMAP_AT_ATTRIBUTION = (
    '© <a href="https://www.basemap.at" '
    'target="_blank" rel="noopener noreferrer">basemap.at</a>'
)
BASEMAP_WITH_OSM_ATTRIBUTION = f"{BASEMAP_AT_ATTRIBUTION} | {MAPLIBRE_OSM_ATTRIBUTION}"

# --- FUNKTIONEN ---

def replace_fonts(node, changed_flag, replacements, parent_key=None):
    """Rekursive Funktion zum Ersetzen von Font-Namen."""
    if isinstance(node, dict):
        for key, value in node.items():
            node[key] = replace_fonts(value, changed_flag, replacements, key)
        return node
    if isinstance(node, list):
        for idx, value in enumerate(node):
            node[idx] = replace_fonts(value, changed_flag, replacements, parent_key)
        return node
    if isinstance(node, str):
        replacement = FONT_MAP.get(node, node)
        if parent_key in {"text-font", "text-fonts"}:
            normalized = replacement.replace(" ", "-")
            if normalized != node:
                changed_flag[0] = True
                replacements.add((node, normalized))
                return normalized
        if replacement != node:
            changed_flag[0] = True
            replacements.add((node, replacement))
            return replacement
    return node



def load_sprite_mapping():
    mapping = {"default": None, "tilesets": {}, "styles": {}}

    if not SPRITE_MAPPING_FILE.exists():
        return mapping

    try:
        raw = json.loads(SPRITE_MAPPING_FILE.read_text(encoding="utf-8"))
    except Exception as e:
        log_warn(f"Sprite-Mapping konnte nicht gelesen werden ({SPRITE_MAPPING_FILE}): {e}")
        return mapping

    if not isinstance(raw, dict):
        log_warn(f"Sprite-Mapping hat ungültiges Format: {SPRITE_MAPPING_FILE}")
        return mapping

    # v1 (legacy): {default, tilesets: {tileset: sprite}, styles: {tileset/style: sprite}}
    default = raw.get("default")
    if isinstance(default, str) and default.strip():
        mapping["default"] = default.strip()

    tilesets = raw.get("tilesets")
    if isinstance(tilesets, dict):
        for key, value in tilesets.items():
            if not isinstance(key, str) or not key.strip():
                continue

            # v1 direct string
            if isinstance(value, str) and value.strip():
                mapping["tilesets"][key.strip()] = value.strip()
                continue

            # v2 object: {sprite_set: "...", styles: {style_id: "..."}}
            if isinstance(value, dict):
                sprite_set = value.get("sprite_set")
                if isinstance(sprite_set, str) and sprite_set.strip():
                    mapping["tilesets"][key.strip()] = sprite_set.strip()

                style_map = value.get("styles")
                if isinstance(style_map, dict):
                    for style_id, sprite in style_map.items():
                        if isinstance(style_id, str) and isinstance(sprite, str) and style_id.strip() and sprite.strip():
                            mapping["styles"][f"{key.strip()}/{style_id.strip()}"] = sprite.strip()

    # v1 top-level style overrides
    styles = raw.get("styles")
    if isinstance(styles, dict):
        for key, value in styles.items():
            if isinstance(key, str) and isinstance(value, str) and key.strip() and value.strip():
                mapping["styles"][key.strip()] = value.strip()

    # v2 defaults block
    defaults = raw.get("defaults")
    if isinstance(defaults, dict):
        sprite_set = defaults.get("sprite_set")
        if isinstance(sprite_set, str) and sprite_set.strip():
            mapping["default"] = sprite_set.strip()

    return mapping


def resolve_sprite_tileset(mapping, tileset, style_id):
    style_key = f"{tileset}/{style_id}"

    if style_key in mapping["styles"]:
        return mapping["styles"][style_key]

    if tileset in mapping["tilesets"]:
        return mapping["tilesets"][tileset]

    if mapping["default"]:
        return mapping["default"].replace("{tileset}", tileset).replace("{style_id}", style_id)

    # Kompatibilitäts-Fallback (altes Verhalten)
    if tileset == "osm":
        return "temaki"
    if tileset == "overlays" and style_id == "openskimap":
        return "openskimap"
    return tileset


def normalize_basemap_attribution(data, tileset, style_id, changed_flag, change_log):
    """Sichert verpflichtende Attributionen für basemap.at und ergänzt OSM im MapLibre-Format."""
    sources = data.get("sources")
    if not isinstance(sources, dict):
        return

    required_attribution = None
    if tileset == "basemap-at":
        required_attribution = BASEMAP_WITH_OSM_ATTRIBUTION
    elif tileset == "overlays" and style_id == "basemap-at-contours":
        required_attribution = BASEMAP_AT_ATTRIBUTION

    if not required_attribution:
        return

    for source_name, source in sources.items():
        if not isinstance(source, dict):
            continue

        current = source.get("attribution")
        if current != required_attribution:
            source["attribution"] = required_attribution
            changed_flag[0] = True
            change_log.append(
                f"      📝 Attribution '{source_name}': auf '{required_attribution}' gesetzt"
            )

def main():
    # Suche alle style.json Dateien
    style_files = sorted(TILES_DIR.glob("*/styles/*/style.json"))
    if not style_files:
        log_error(f"Keine style.json Dateien unter {TILES_DIR} gefunden.")
        # Kein Fehlercode, da vielleicht einfach noch nichts da ist
        sys.exit(0) 

    updated_count = 0
    sprite_mapping = load_sprite_mapping()

    for style_path in style_files:
        # Pfad-Struktur: .../tiles/{tileset}/styles/{style_id}/style.json
        try:
            tileset = style_path.parents[2].name
            style_id = style_path.parent.name
        except IndexError:
            log_warn(f"Überspringe Datei mit unerwarteter Struktur: {style_path}")
            continue

        # 1. Bestimme die passende PMTiles Datei
        current_pmtiles = None
        
        # A) Exakter Match (Priorität!) - Style ID == PMTiles Name
        candidate_exact = TILES_DIR / tileset / "pmtiles" / f"{style_id}.pmtiles"
        if candidate_exact.exists():
            current_pmtiles = candidate_exact.name
        
        # B) Mapping / Global
        if not current_pmtiles:
            current_pmtiles = pmtiles_map.get(tileset) or PMTILES_FILE_GLOBAL
        
        # C) Ordner Scan (Fallback)
        if not current_pmtiles:
            pmtiles_dir = TILES_DIR / tileset / "pmtiles"
            if pmtiles_dir.exists():
                pmtiles_files = sorted(p.name for p in pmtiles_dir.glob("*.pmtiles"))
                if len(pmtiles_files) == 1:
                    current_pmtiles = pmtiles_files[0]
                elif len(pmtiles_files) > 1:
                    log_warn(f"Mehrdeutigkeit bei {tileset}/{style_id}: {pmtiles_files}. Erwartete '{style_id}.pmtiles' nicht gefunden.")

        # Style laden
        try:
            data = json.loads(style_path.read_text(encoding="utf-8"))
        except Exception as e:
            log_error(f"Fehler beim Lesen von {style_path}: {e}")
            continue

        changed = [False]
        change_log = []
        font_replacements = set()

        # Fonts ersetzen
        data = replace_fonts(data, changed, font_replacements)
        for old, new in sorted(font_replacements):
            change_log.append(f"      📝 Font: \"{old}\" -> \"{new}\"")

        # Basemap-Attribution prüfen und ggf. auf MapLibre-kompatibles Format korrigieren
        normalize_basemap_attribution(data, tileset, style_id, changed, change_log)

        # Sprite URL
        if SPRITE_URL_TEMPLATE:
            sprite_tileset = resolve_sprite_tileset(sprite_mapping, tileset, style_id)
            new_sprite = (
                SPRITE_URL_TEMPLATE.replace("{tileset}", sprite_tileset)
                .replace("{style_id}", style_id)
            )
            if data.get("sprite") != new_sprite:
                change_log.append(f"      📝 Sprite: ... -> \"{new_sprite}\"")
                data["sprite"] = new_sprite
                changed[0] = True

        # Glyphs URL
        if GLYPHS_URL_TEMPLATE:
            new_glyphs = (
                GLYPHS_URL_TEMPLATE.replace("{tileset}", tileset)
                .replace("{style_id}", style_id)
                .replace("{fontstack}", "{fontstack}")
                .replace("{range}", "{range}")
            )
            if data.get("glyphs") != new_glyphs:
                data["glyphs"] = new_glyphs
                changed[0] = True

        # Sources URL (PMTiles)
        if current_pmtiles:
            pmtiles_url = None
            
            # Versuch 1: URL aus endpoints_info.json (Präzises Matching)
            for entry in tiles_entries:
                # Neues Format Check (datasets): Match über Dateiname + Tileset
                if entry.get("filename") == current_pmtiles and entry.get("tileset") == tileset:
                    pmtiles_url = entry.get("pmtiles_internal") or entry.get("pmtiles_url")
                    if pmtiles_url: break
                
                # Altes Format Check (tiles) - Pfad-basiert
                expected_path = (TILES_DIR / tileset / "pmtiles" / current_pmtiles).as_posix()
                if entry.get("path") == expected_path:
                    entry_url = entry.get("url")
                    if entry_url:
                        pmtiles_url = (
                            entry_url if entry_url.startswith("pmtiles://") 
                            else f"pmtiles://{entry_url}"
                        )
                    break
            
            # Versuch 2: Manuell bauen (Fallback)
            if not pmtiles_url and TILES_BASE_URL:
                # relative_path wäre z.B. osm/pmtiles/at.pmtiles
                pmtiles_url = f"pmtiles://{TILES_BASE_URL}/{tileset}/pmtiles/{current_pmtiles}"
            
            if pmtiles_url:
                sources = data.get("sources", {})
                if isinstance(sources, dict):
                    for s_key, source in sources.items():
                        if not isinstance(source, dict): continue
                        
                        old_url = source.get("url")
                        should_update = False
                        
                        # Nur bestimmte Quellen updaten
                        if tileset == "osm" and s_key == "openmaptiles":
                            should_update = True
                        elif source.get("type") == "vector" and "url" in source:
                            should_update = True
                        
                        if should_update and isinstance(old_url, str):
                            if old_url != pmtiles_url:
                                change_log.append(f"      📝 Source '{s_key}': ... -> \"{current_pmtiles}\"")
                                source["url"] = pmtiles_url
                                changed[0] = True

        # Speichern
        if changed[0]:
            style_path.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
            updated_count += 1
            log_success(f"Aktualisiert: {tileset}/{style_id} (PMTiles: {current_pmtiles})")
            if change_log:
                print("\n".join(change_log))
        else:
            log_info(f"Keine Änderungen: {tileset}/{style_id}")

    print(f"✅ Fertig. {updated_count} Stylesheets aktualisiert.")

if __name__ == "__main__":
    main()
