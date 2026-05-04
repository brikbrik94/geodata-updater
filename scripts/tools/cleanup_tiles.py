#!/usr/bin/env python3
import json
import os
import shutil
import sys
from pathlib import Path

# --- KONFIGURATION ---
TILES_DIR = Path(os.environ.get("TILES_DIR", "/srv/tiles"))
BUILD_DIR = Path(os.environ.get("BUILD_DIR", "/srv/build"))
CONF_DIR = Path(__file__).resolve().parent.parent.parent / "conf"
EXTERNAL_CONF = CONF_DIR / "external_repos.txt"

def log_info(msg): print(f"ℹ️  {msg}")
def log_success(msg): print(f"✅ {msg}")
def log_warn(msg): print(f"⚠️  {msg}")
def log_error(msg): print(f"❌ {msg}")

def get_expected_files():
    """
    Ermittelt alle aktuell 'gültigen' PMTiles-Dateien basierend auf 
    den manifest.json Dateien der externen Repositories.
    Returns: Set von relativen Pfaden (z.B. 'basemaps/pmtiles/at.pmtiles')
    """
    expected = set()

    # Externe Repositories (Plugins)
    if EXTERNAL_CONF.exists():
        with open(EXTERNAL_CONF, "r") as f:
            for line in f:
                line = line.strip()
                if not line or line.startswith("#"):
                    continue
                
                repo_path = Path(os.path.expanduser(line))
                manifest_file = repo_path / "dist" / "manifest.json"
                
                if manifest_file.exists():
                    try:
                        manifest = json.loads(manifest_file.read_text(encoding="utf-8"))
                        global_tileset = manifest.get("tileset", "overlays")
                        
                        datasets = manifest.get("datasets", []) or manifest.get("overlays", [])
                        
                        for ds in datasets:
                            ds_id = ds.get("id")
                            ds_type = ds.get("type", global_tileset)
                            
                            # Mapping Logik (Synchron mit deploy_external.py)
                            if ds_type in ["basemap", "basemaps"]:
                                tileset_dir = "basemaps"
                            elif ds_type in ["overlay", "overlays"]:
                                tileset_dir = "overlays"
                            else:
                                tileset_dir = ds_type
                            
                            if ds_id:
                                expected.add(f"{tileset_dir}/pmtiles/{ds_id}.pmtiles")
                    except Exception as e:
                        log_warn(f"Fehler beim Parsen von {manifest_file}: {e}")

    # Sonderfälle / Manuelle Ausnahmen (Statische Dateien ohne Plugin)
    expected.add("elevation/pmtiles/at-elevation.pmtiles")
    expected.add("elevation/pmtiles/terrain-rgb.pmtiles")

    return expected

def ask_user(prompt):
    """Fragt den User nach Bestätigung."""
    while True:
        choice = input(f"{prompt} [y/N]: ").lower().strip()
        if choice in {'y', 'yes'}: return True
        if choice in {'n', 'no', ''}: return False

def main():
    if not TILES_DIR.exists():
        log_error(f"Tiles-Verzeichnis nicht gefunden: {TILES_DIR}")
        return

    log_info("Ermittle Soll-Zustand (aktive Datensätze)...")
    expected = get_expected_files()
    
    log_info(f"Scanne Ist-Zustand in: {TILES_DIR}...")
    actual_pmtiles = []
    for root, _, files in os.walk(TILES_DIR):
        for f in files:
            if f.endswith(".pmtiles"):
                full_path = Path(root) / f
                rel_path = full_path.relative_to(TILES_DIR)
                actual_pmtiles.append(rel_path)

    orphaned = [p for p in actual_pmtiles if p.as_posix() not in expected]

    if not orphaned:
        log_success("Keine verwaisten Tilesets gefunden.")
        return

    log_warn(f"{len(orphaned)} verwaiste Tilesets gefunden.")
    
    for rel_pm in sorted(orphaned):
        pm_path = TILES_DIR / rel_pm
        map_id = pm_path.stem
        tileset_dir = rel_pm.parts[0]
        
        # Zugehörige Dateien ermitteln
        # Struktur: <tileset>/pmtiles/<id>.pmtiles
        #           <tileset>/styles/<id>/style.json
        #           <tileset>/tilejson/<id>.json
        style_dir = TILES_DIR / tileset_dir / "styles" / map_id
        tilejson_file = TILES_DIR / tileset_dir / "tilejson" / f"{map_id}.json"
        
        print("-" * 40)
        print(f"VERWAIST: {rel_pm}")
        if style_dir.exists(): print(f"  -> Style:   {style_dir.relative_to(TILES_DIR)}")
        if tilejson_file.exists(): print(f"  -> TileJSON: {tilejson_file.relative_to(TILES_DIR)}")
        
        if ask_user(f"Datensatz '{map_id}' (inkl. Styles) löschen?"):
            # PMTiles löschen
            pm_path.unlink()
            log_info(f"Gelöscht: {rel_pm}")
            
            # Style-Ordner löschen
            if style_dir.exists():
                shutil.rmtree(style_dir)
                log_info(f"Gelöscht: {style_dir.relative_to(TILES_DIR)}")
            
            # TileJSON löschen
            if tilejson_file.exists():
                tilejson_file.unlink()
                log_info(f"Gelöscht: {tilejson_file.relative_to(TILES_DIR)}")
            
            log_success(f"Datensatz '{map_id}' erfolgreich entfernt.")
        else:
            log_info(f"Übersprungen: {map_id}")

    print("-" * 40)
    log_success("Bereinigung abgeschlossen.")

if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\nAbgebrochen.")
        sys.exit(0)
