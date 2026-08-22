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
    legend_scales = {}
    legend = []

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

                # legend[] (§5.4, ab v3.0): eigenständiger, von groups[] getrennter
                # Legend-Block pro Quelle. 1:1 durchgereicht und über alle Quellen aneinander-
                # gehängt - kein Dedup nach `heading` möglich/nötig, da `heading` keine globale
                # Eindeutigkeit beansprucht (anders als legend_scales[].id).
                for entry in data.get("legend") or []:
                    legend.append(dict(entry))

                # Geteilte Farbskalen (§5.7, bis v2.1.0 als `legend_sections` benannt, Inhalt
                # unverändert): über alle Quellen nach id dedupliziert, erste gefundene
                # Definition gewinnt (Standard garantiert identischen Inhalt pro id über alle
                # Quellen hinweg). Quellen migrieren unabhängig voneinander auf v3.0 - solange
                # nicht alle umgestellt sind, muss hier sowohl der alte als auch der neue
                # Feldname gelesen werden, damit keine Skalen-Definitionen verloren gehen.
                for section in (data.get("legend_scales") or data.get("legend_sections") or []):
                    section_id = section.get("id")
                    if section_id and section_id not in legend_scales:
                        legend_scales[section_id] = section
            except Exception as e:
                print(f"⚠️  Fehler beim Verarbeiten von {f.name}: {e}")

    output_data = {
        "generated_at": datetime.datetime.now().isoformat(),
        "meta": {"tiles_base_url": TILES_BASE_URL},
        "layers": layers,
        "legend": legend or None,
        "legend_scales": list(legend_scales.values()) or None
    }
    
    OUTPUT_FILE.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT_FILE.write_text(json.dumps(output_data, indent=2), encoding="utf-8")
    print(f"✅ LAYER INFO erstellt: {OUTPUT_FILE} ({len(layers)} Styles)")

if __name__ == "__main__":
    main()
