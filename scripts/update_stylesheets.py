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
EXTERNAL_REPOS_CONF = Path(os.environ.get("EXTERNAL_REPOS_CONF", str(Path(__file__).resolve().parent.parent / "conf" / "external_repos.txt")))

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

        # Fallback: Falls URL im Env fehlt, nimm die aus der JSON (unter 'meta')
        meta = info_data.get("meta", {})
        if not TILES_BASE_URL:
            TILES_BASE_URL = (meta.get("tiles_base_url") or info_data.get("tiles_base_url") or "").rstrip("/")
        if not ASSETS_BASE_URL:
            ASSETS_BASE_URL = (meta.get("assets_base_url") or info_data.get("assets_base_url") or "").rstrip("/")
            
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

BASEMAP_AT_ATTRIBUTION = (
    '© <a href="https://www.basemap.at" '
    'target="_blank" rel="noopener noreferrer">basemap.at</a>'
)

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



def load_external_mappings():
    """
    Lädt Mappings für Sprites und PMTiles aus internen Configs und externen Manifesten.
    Returns: {
        "sprites": {"tileset/style_id": "sprite_id", ...},
        "pmtiles": {"tileset/style_id": "filename.pmtiles", ...},
        "default_sprite": "..."
    }
    """
    mapping = {
        "default_sprite": None,
        "sprites": {},
        "pmtiles": {}
    }

    # 1. Interne Mappings laden (statisch konfiguriert)
    if SPRITE_MAPPING_FILE.exists():
        try:
            raw = json.loads(SPRITE_MAPPING_FILE.read_text(encoding="utf-8"))
            if isinstance(raw, dict):
                # Legacy Support / v1
                default = raw.get("default")
                if isinstance(default, str) and default.strip():
                    mapping["default_sprite"] = default.strip()

                tilesets = raw.get("tilesets")
                if isinstance(tilesets, dict):
                    for key, value in tilesets.items():
                        if isinstance(value, str) and value.strip():
                            # Hier können wir noch keine style-id zuordnung machen
                            pass
                        elif isinstance(value, dict):
                            # v2 object: {sprite_set: "...", styles: {style_id: "..."}}
                            style_map = value.get("styles")
                            if isinstance(style_map, dict):
                                for style_id, sprite in style_map.items():
                                    mapping["sprites"][f"{key}/{style_id}"] = sprite

                styles = raw.get("styles")
                if isinstance(styles, dict):
                    for key, value in styles.items():
                        mapping["sprites"][key] = value

                defaults = raw.get("defaults")
                if isinstance(defaults, dict):
                    sprite_set = defaults.get("sprite_set")
                    if isinstance(sprite_set, str):
                        mapping["default_sprite"] = sprite_set
        except Exception as e:
            log_warn(f"Sprite-Mapping konnte nicht gelesen werden ({SPRITE_MAPPING_FILE}): {e}")

    # 2. Dynamisch aus externen Plugins laden (Single Source of Truth)
    if EXTERNAL_REPOS_CONF.exists():
        try:
            with open(EXTERNAL_REPOS_CONF, "r") as f:
                for line in f:
                    line = line.strip()
                    if not line or line.startswith("#"): continue
                    
                    repo_path = Path(os.path.expanduser(line))
                    manifest_file = repo_path / "dist" / "manifest.json"
                    
                    if manifest_file.exists():
                        manifest = json.loads(manifest_file.read_text(encoding="utf-8"))
                        global_tileset = manifest.get("tileset", "overlays")
                        datasets = manifest.get("datasets", []) or manifest.get("overlays", [])
                        for ds in datasets:
                            ds_id = ds.get("id")
                            if not ds_id: continue

                            # Deployment-Logik replizieren
                            ds_type = ds.get("type", global_tileset)
                            if ds_type in ["basemap", "basemaps"]:
                                tileset_dir = "basemaps"
                            elif ds_type in ["overlay", "overlays"]:
                                tileset_dir = "overlays"
                            else:
                                tileset_dir = ds_type

                            style_key = f"{tileset_dir}/{ds_id}"


                            # Sprite mapping
                            sprite_id = ds.get("sprite_id") or ds.get("sprite")
                            if sprite_id:
                                mapping["sprites"][style_key] = sprite_id
                            
                            # PMTiles mapping
                            # deploy_external.py verwendet immer {ds_id}.pmtiles als Zielname
                            mapping["pmtiles"][style_key] = f"{ds_id}.pmtiles"
        except Exception as e:
            log_warn(f"Fehler beim Laden externer Manifeste: {e}")

    return mapping


def resolve_sprite_set(mapping, tileset, style_id):
    style_key = f"{tileset}/{style_id}"

    if style_key in mapping["sprites"]:
        return mapping["sprites"][style_key]

    if mapping["default_sprite"]:
        return mapping["default_sprite"].replace("{tileset}", tileset).replace("{style_id}", style_id)

    # Fallbacks
    if tileset == "osm": return "temaki"
    if style_id == "openskimap": return "openskimap"
    return tileset


def normalize_basemap_attribution(data, tileset, style_id, changed_flag, change_log):
    """Sichert verpflichtende basemap.at Attributionen für Basemap- und Contours-Styles."""
    sources = data.get("sources")
    if not isinstance(sources, dict):
        return

    required_attribution = None
    if tileset == "basemap-at":
        required_attribution = BASEMAP_AT_ATTRIBUTION
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

def find_pmtiles_url(filename, tileset_hint=None):
    """Sucht die passende PMTiles-URL für einen Dateinamen."""
    if not filename:
        return None

    # 1. Präzises Matching in den Inventar-Daten
    for entry in tiles_entries:
        # Match über Filename (und optional Tileset zur Eindeutigkeit)
        if entry.get("pmtiles_file") == filename or entry.get("filename") == filename:
            if tileset_hint and entry.get("tileset") != tileset_hint:
                continue
            
            url = entry.get("pmtiles_internal") or entry.get("pmtiles_url")
            if url:
                return url if url.startswith("pmtiles://") else f"pmtiles://{url}"

    # 2. Fallback: Manuell bauen
    if TILES_BASE_URL:
        t_set = tileset_hint or "overlays"
        return f"pmtiles://{TILES_BASE_URL}/{t_set}/pmtiles/{filename}"
    
    return None

# --- KONFIGURATION ---
TILES_DIR = Path(os.environ.get("TILES_DIR", "/srv/tiles"))

def main():
    # Kein Flag-basiertes Überspringen mehr: die Prüfung pro Datei unten ist idempotent
    # (schreibt nur bei tatsächlicher Abweichung), daher wird bei jedem Lauf immer geprüft.

    # Suche alle style.json Dateien
    style_files = sorted(TILES_DIR.glob("*/styles/*/style.json"))
    if not style_files:
        log_error(f"Keine style.json Dateien unter {TILES_DIR} gefunden.")
        sys.exit(0) 

    updated_count = 0
    ext_mapping = load_external_mappings()

    for style_path in style_files:
        try:
            tileset = style_path.parents[2].name
            style_id = style_path.parent.name
        except IndexError:
            continue

        style_key = f"{tileset}/{style_id}"

        # Style laden
        try:
            data = json.loads(style_path.read_text(encoding="utf-8"))
        except Exception as e:
            log_error(f"Fehler beim Lesen von {style_path}: {e}")
            continue

        changed = [False]
        change_log = []
        font_replacements = set()

        # 1. Fonts normalisieren
        data = replace_fonts(data, changed, font_replacements)
        for old, new in sorted(font_replacements):
            change_log.append(f"      📝 Font: \"{old}\" -> \"{new}\"")

        # 2. Basemap-Attribution
        normalize_basemap_attribution(data, tileset, style_id, changed, change_log)

        # 3. Sprites (Absolute URL)
        sprite_id = resolve_sprite_set(ext_mapping, tileset, style_id)
        if ASSETS_BASE_URL:
            new_sprite = f"{ASSETS_BASE_URL}/sprites/{sprite_id}/sprite"
            if data.get("sprite") != new_sprite:
                change_log.append(f"      📝 Sprite: \"{data.get('sprite')}\" -> \"{new_sprite}\"")
                data["sprite"] = new_sprite
                changed[0] = True

        # 4. Glyphs (Absolute URL)
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

        # 5. Sources (PMTiles Absolute URL)
        sources = data.get("sources", {})
        if isinstance(sources, dict):
            for s_key, source in sources.items():
                if not isinstance(source, dict): continue
                if source.get("type") != "vector": continue

                old_url = source.get("url", "")
                
                # Ziel-Filename bestimmen
                target_filename = None
                
                # A) Aus Manifest (Sicherste Quelle)
                if style_key in ext_mapping["pmtiles"]:
                    target_filename = ext_mapping["pmtiles"][style_key]
                
                # B) Fallback auf bestehenden Filename in URL
                if not target_filename and ".pmtiles" in old_url:
                    target_filename = old_url.split("/")[-1].split("?")[0]
                
                # C) Fallback auf style_id
                if not target_filename:
                    target_filename = f"{style_id}.pmtiles"
                
                # Absolute URL bauen
                new_url = find_pmtiles_url(target_filename, tileset)
                
                if new_url and new_url != old_url:
                    change_log.append(f"      📝 Source '{s_key}': {old_url} -> {new_url}")
                    source["url"] = new_url
                    changed[0] = True

        # Speichern
        if changed[0]:
            style_path.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
            updated_count += 1
            log_success(f"Aktualisiert: {style_key}")
            if change_log:
                print("\n".join(change_log))
        else:
            log_info(f"Keine Änderungen: {style_key}")

    print(f"✅ Fertig. {updated_count} Stylesheets aktualisiert.")

if __name__ == "__main__":
    main()
