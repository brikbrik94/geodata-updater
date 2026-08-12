#!/usr/bin/env python3
import json
import os
import datetime
from pathlib import Path

# --- KONFIGURATION ---
STAGING_DIR = Path("/srv/info/staging/layers")
OUTPUT_FILE = Path("/srv/info/layers_info.json")
TILES_BASE_URL = os.environ.get("TILES_BASE_URL", "https://tiles.oe5ith.at").rstrip("/")

def resolve_url(pmtiles_path):
    # pmtiles_path usually starts with "pmtiles/..."
    # We need to determine the category (overlays/basemaps)
    # For now, we assume overlays if not specified, matching deploy_external logic
    category = "overlays" 
    filename = os.path.basename(pmtiles_path)
    return f"{TILES_BASE_URL}/{category}/pmtiles/{filename}"

def main():
    print(f"⚙️  Aggregiere Layer-Listen zu {OUTPUT_FILE.name}...")
    layers = []
    
    if STAGING_DIR.exists():
        for f in sorted(STAGING_DIR.glob("*.json")):
            try:
                data = json.loads(f.read_text(encoding="utf-8"))
                source_version = data.get("version")
                for style in data.get("styles", []):
                    # Normalize and strip
                    layer_entry = {
                        "id": style.get("style_id"),
                        "name": style.get("name"),
                        "pmtiles_url": resolve_url(style.get("pmtiles_path")),
                        "version": source_version,
                        "groups": []
                    }
                    for g in style.get("groups", []):
                        group = {
                            "source_layer": g.get("source_layer"),
                            "name": g.get("name"),
                            "template": g.get("template"),
                            "style_layers": g.get("style_layers", []),
                            "type": g.get("type"),
                            "color": g.get("color"),
                            "opacity": g.get("opacity"),
                            "legend_items": g.get("legend_items")
                        }
                        layer_entry["groups"].append(group)
                    layers.append(layer_entry)
            except Exception as e:
                print(f"⚠️  Fehler beim Verarbeiten von {f.name}: {e}")

    output_data = {
        "generated_at": datetime.datetime.now().isoformat(),
        "meta": {"tiles_base_url": TILES_BASE_URL},
        "layers": layers
    }
    
    OUTPUT_FILE.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT_FILE.write_text(json.dumps(output_data, indent=2), encoding="utf-8")
    print(f"✅ LAYER INFO erstellt: {OUTPUT_FILE} ({len(layers)} Styles)")

if __name__ == "__main__":
    main()
