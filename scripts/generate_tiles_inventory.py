#!/usr/bin/env python3
import json
import os
import datetime
from pathlib import Path

# --- KONFIGURATION ---
TILES_DIR = Path(os.environ.get("TILES_DIR", "/srv/tiles"))
# Output ist jetzt tiles_inventory.json
OUTPUT_FILE = Path(os.environ.get("TILES_INVENTORY_PATH", "/srv/info/tiles_inventory.json"))

# Base URL (Optional)
TILES_BASE_URL = os.environ.get("TILES_BASE_URL", "").rstrip("/")

def main():
    if not TILES_DIR.exists():
        print(f"❌ Fehler: Tiles Verzeichnis {TILES_DIR} existiert nicht.")
        return

    datasets = []
    
    # Sortierte Liste der Tilesets
    tileset_dirs = sorted([d for d in TILES_DIR.iterdir() if d.is_dir()])

    for tileset_dir in tileset_dirs:
        tileset_name = tileset_dir.name # z.B. "osm"
        
        pmtiles_dir = tileset_dir / "pmtiles"
        tilejson_dir = tileset_dir / "tilejson"
        styles_dir = tileset_dir / "styles"

        if not pmtiles_dir.exists():
            continue

        pmtiles_files = sorted(pmtiles_dir.glob("*.pmtiles"))

        for pmtiles_path in pmtiles_files:
            filename = pmtiles_path.name       
            map_id = pmtiles_path.stem         

            # 1. STYLE PFADE (optional, z.B. bei elevation/terrain gibt es ggf. keinen Style)
            style_file = styles_dir / map_id / "style.json"
            style_exists = style_file.exists()

            style_abs_path = style_file.as_posix() if style_exists else None
            style_rel_path = f"{tileset_name}/styles/{map_id}/style.json" if style_exists else None

            style_url = None
            if style_exists and TILES_BASE_URL:
                style_url = f"{TILES_BASE_URL}/{style_rel_path}"

            # 2. PMTILES PFADE
            pmtiles_abs_path = pmtiles_path.as_posix()
            pmtiles_rel_path = f"{tileset_name}/pmtiles/{filename}"
            pmtiles_url = None
            if TILES_BASE_URL:
                pmtiles_url = f"{TILES_BASE_URL}/{pmtiles_rel_path}"

            # 3. INFO JSON
            info_json_file = tilejson_dir / f"{map_id}.json"
            info_json_path = info_json_file.as_posix() if info_json_file.exists() else None
            
            dataset = {
                "id": map_id,
                "tileset": tileset_name,
                "path": style_abs_path,
                "relative_path": style_rel_path,
                "pmtiles_path": pmtiles_abs_path,
                "pmtiles_file": filename,
                "size_bytes": pmtiles_path.stat().st_size,
                "tileset_info_path": info_json_path,
                "has_style": style_exists
            }

            if style_url:
                dataset["url"] = style_url
            if pmtiles_url:
                dataset["pmtiles_url"] = pmtiles_url
                dataset["pmtiles_internal"] = f"pmtiles://{pmtiles_url}"

            datasets.append(dataset)
            print(f"   ➕ Dataset: {tileset_name}/{map_id}")

    output_data = {
        "generated_at": datetime.datetime.now().isoformat(),
        "datasets": datasets
    }
    
    OUTPUT_FILE.parent.mkdir(parents=True, exist_ok=True)
    try:
        OUTPUT_FILE.write_text(json.dumps(output_data, indent=2), encoding="utf-8")
        print(f"✅ Tiles Inventory gespeichert: {OUTPUT_FILE}")
    except Exception as e:
        print(f"❌ Fehler beim Schreiben: {e}")

if __name__ == "__main__":
    main()
