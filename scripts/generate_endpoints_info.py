#!/usr/bin/env python3
import json
import os
import datetime
from pathlib import Path

# --- KONFIGURATION ---
# Input Pfade (Inventare)
INFO_DIR = Path("/srv/info")
TILES_INV = Path(os.environ.get("TILES_INVENTORY_PATH", "/srv/info/tiles_inventory.json"))
FONTS_INV = Path(os.environ.get("FONTS_INVENTORY_PATH", "/srv/info/font_inventory.json"))

# Sprites: Wir prüfen beide üblichen Namen
SPRITES_INV = INFO_DIR / "sprite_inventory.json"
if not SPRITES_INV.exists():
    SPRITES_INV = INFO_DIR / "sprites_inventory.json"

# Output Pfad
OUTPUT_FILE = Path(os.environ.get("ENDPOINTS_INFO_PATH", "/srv/info/endpoints_info.json"))

# Base URLs
TILES_BASE_URL = os.environ.get("TILES_BASE_URL", "").rstrip("/")
ASSETS_BASE_URL = os.environ.get("ASSETS_BASE_URL", "").rstrip("/")

def load_json(path):
    if path.exists():
        try:
            return json.loads(path.read_text(encoding="utf-8"))
        except Exception as e:
            print(f"⚠️  Fehler beim Lesen von {path.name}: {e}")
            return {}
    return {}

def process_sprites(sprites_raw):
    """
    Wandelt die flache Dateiliste ["set/file.json", ...] 
    in strukturierte Objekte um.
    """
    if not isinstance(sprites_raw, list):
        return []

    sprite_sets = {}

    for rel_path in sprites_raw:
        parts = rel_path.split('/')
        if len(parts) < 2: continue
        
        set_id = parts[0]
        filename = parts[-1]
        
        if set_id not in sprite_sets:
            sprite_sets[set_id] = {
                "id": set_id,
                "files": [],
                "variants": []
            }
        
        sprite_sets[set_id]["files"].append(rel_path)

        if filename == "sprite.json":
            if ASSETS_BASE_URL:
                base_url = f"{ASSETS_BASE_URL}/sprites/{set_id}/sprite"
                sprite_sets[set_id]["url"] = base_url
                sprite_sets[set_id]["json_url"] = f"{base_url}.json"
                sprite_sets[set_id]["png_url"] = f"{base_url}.png"
                sprite_sets[set_id]["url_2x"] = f"{base_url}@2x"
    
    return sorted(list(sprite_sets.values()), key=lambda x: x["id"])

def process_fonts(fonts_data):
    """
    Erstellt eine kompakte Font-Info.
    Entfernt die Ranges-Listen und fügt Pfad/URL Infos hinzu.
    """
    if not isinstance(fonts_data, dict):
        return {}
    
    # Nur die Namen der Font-Familien (Keys) nehmen
    families = sorted(list(fonts_data.keys()))
    
    font_info = {
        # Verweis auf die Detail-Datei
        "inventory_path": str(FONTS_INV),
        "inventory_file": FONTS_INV.name,
        # Liste der verfügbaren Schriften (ohne Ranges)
        "families": families
    }
    
    # URL Template für den Zugriff (wichtig für MapLibre/Leaflet)
    if ASSETS_BASE_URL:
        font_info["url_template"] = f"{ASSETS_BASE_URL}/fonts/{{fontstack}}/{{range}}.pbf"
        
        # Optional: URL zur inventory Datei selbst (angenommen sie liegt im selben Web-Ordner)
        # font_info["inventory_url"] = ... (hängt vom Webserver-Setup ab)

    return font_info

def main():
    print(f"⚙️  Aggregiere Inventare zu {OUTPUT_FILE.name}...")

    # 1. Daten laden
    tiles_data = load_json(TILES_INV)
    fonts_data = load_json(FONTS_INV)
    sprites_data_raw = load_json(SPRITES_INV)

    # 2. Verarbeiten
    raw_sprites_list = sprites_data_raw.get("sprites", [])
    processed_sprites = process_sprites(raw_sprites_list)
    processed_fonts = process_fonts(fonts_data)

    # 3. Struktur zusammenbauen
    master_data = {
        "generated_at": datetime.datetime.now().isoformat(),
        "meta": {
             "tiles_base_url": TILES_BASE_URL,
             "assets_base_url": ASSETS_BASE_URL,
        },
        "datasets": tiles_data.get("datasets", []),
        "sprites": processed_sprites,
        "fonts": processed_fonts
    }

    # 4. Speichern
    OUTPUT_FILE.parent.mkdir(parents=True, exist_ok=True)
    try:
        OUTPUT_FILE.write_text(json.dumps(master_data, indent=2), encoding="utf-8")
        print(f"✅ MASTER JSON erstellt: {OUTPUT_FILE}")
        print(f"   - Datasets: {len(master_data['datasets'])}")
        print(f"   - Sprites:  {len(master_data['sprites'])} Sets")
        print(f"   - Fonts:    {len(processed_fonts.get('families', []))} Familien (Details in {processed_fonts['inventory_file']})")

    except Exception as e:
        print(f"❌ Fehler beim Schreiben der Master-JSON: {e}")

if __name__ == "__main__":
    main()
