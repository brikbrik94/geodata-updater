#!/usr/bin/env python3
import os
import json
import datetime
import sys

# Konfiguration
WEB_ROOT = "/srv/www/tiles"
PMTILES_DIR = os.path.join(WEB_ROOT, "pmtiles")
OUTPUT_FILE = os.path.join(WEB_ROOT, "inventory.json")
BASE_URL = "https://tiles.oe5ith.at/pmtiles"

def get_file_info(filepath):
    """Liest Metadaten einer Datei aus."""
    stat = os.stat(filepath)
    size_mb = stat.st_size / (1024 * 1024)
    mtime = datetime.datetime.fromtimestamp(stat.st_mtime)
    
    filename = os.path.basename(filepath)
    
    return {
        "filename": filename,
        "url": f"{BASE_URL}/{filename}",
        "size_str": f"{size_mb:.1f} MB",
        "date_str": mtime.strftime("%d.%m.%Y"),
        "timestamp": mtime.timestamp() # Für Sortierung
    }

def main():
    inventory = {
        "generated_at": datetime.datetime.now().strftime("%d.%m.%Y %H:%M"),
        "files": []
    }

    if not os.path.exists(PMTILES_DIR):
        print(f"Warnung: Ordner {PMTILES_DIR} existiert nicht.")
        # Wir schreiben trotzdem ein leeres JSON, damit das Frontend nicht abstürzt
    else:
        # Alle .pmtiles Dateien scannen
        files = [f for f in os.listdir(PMTILES_DIR) if f.endswith('.pmtiles')]
        files.sort() # Alphabetisch sortieren
        
        for f in files:
            full_path = os.path.join(PMTILES_DIR, f)
            inventory["files"].append(get_file_info(full_path))

    # JSON schreiben
    with open(OUTPUT_FILE, 'w') as f:
        json.dump(inventory, f, indent=2)
    
    print(f"✅ Inventory JSON erstellt: {OUTPUT_FILE}")

if __name__ == "__main__":
    main()
