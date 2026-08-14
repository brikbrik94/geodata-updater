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
    legend_sections = {}

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
                    # Group-Felder werden 1:1 durchgereicht (kein Allowlisting einzelner
                    # Felder), da deren Inhalt/Struktur vom Plugin-Standard vorgegeben wird
                    # (siehe geodata-plugin-standard §5.3ff) und sich zwischen dessen Versionen
                    # ändert. Dieses Repo aggregiert nur, es interpretiert keine Standard-Felder.
                    for g in style.get("groups", []):
                        layer_entry["groups"].append(dict(g))
                    layers.append(layer_entry)

                # Geteilte Farbskalen (§5.5/§5.6): über alle Quellen nach id dedupliziert,
                # erste gefundene Definition gewinnt (Standard garantiert identischen Inhalt
                # pro id über alle Quellen hinweg).
                for section in data.get("legend_sections") or []:
                    section_id = section.get("id")
                    if section_id and section_id not in legend_sections:
                        legend_sections[section_id] = section
            except Exception as e:
                print(f"⚠️  Fehler beim Verarbeiten von {f.name}: {e}")

    output_data = {
        "generated_at": datetime.datetime.now().isoformat(),
        "meta": {"tiles_base_url": TILES_BASE_URL},
        "layers": layers,
        "legend_sections": list(legend_sections.values()) or None
    }
    
    OUTPUT_FILE.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT_FILE.write_text(json.dumps(output_data, indent=2), encoding="utf-8")
    print(f"✅ LAYER INFO erstellt: {OUTPUT_FILE} ({len(layers)} Styles)")

if __name__ == "__main__":
    main()
