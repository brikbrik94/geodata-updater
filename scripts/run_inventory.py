#!/usr/bin/env python3
import os
import subprocess
import sys
from pathlib import Path

# Pfade definieren
SCRIPT_DIR = Path(__file__).resolve().parent
INV_DIR = SCRIPT_DIR / "inventory"
STATE_DIR = Path("/tmp/geodata_state")
INFO_DIR = Path("/srv/info")

def log(msg):
    print(f"📦 [Inventory] {msg}")

def is_updated(change_type):
    """Prüft, ob eine Flag-Datei für diesen Typ existiert."""
    return (STATE_DIR / f"updated_{change_type}").exists()

def run_script(path):
    log(f"Starte {path.name}...")
    try:
        if path.suffix == ".py":
            subprocess.run([sys.executable, str(path)], check=True)
        elif path.suffix == ".sh":
            subprocess.run(["bash", str(path)], check=True)
        return True
    except subprocess.CalledProcessError as e:
        print(f"❌ Fehler in {path.name}: {e}")
        return False

def main():
    # Argument-Prüfung
    force = "--force" in sys.argv
    
    log("Prüfe auf notwendige Inventar-Updates...")
    if force:
        log("Force-Modus aktiv: Alle Inventare werden neu erstellt.")

    # Definition der Abhängigkeiten
    # Script -> Change Type Flag -> Erwartete Output Datei
    tasks = [
        {"script": "tiles.py",   "flag": "tiles",   "output": "tiles_inventory.json"},
        {"script": "sprites.py", "flag": "sprites", "output": "sprite_inventory.json"},
        {"script": "fonts.sh",   "flag": "fonts",   "output": "font_inventory.json"},
        {"script": "layers.py",  "flag": "layers",  "output": "layers_info.json"}
    ]

    any_change = False
    
    # 1. Einzel-Inventare prüfen und ggf. ausführen
    for task in tasks:
        script_path = INV_DIR / task["script"]
        output_path = INFO_DIR / task["output"]
        
        # Ausführen wenn: Force ODER Flag gesetzt ODER Output-Datei fehlt
        should_run = force or is_updated(task["flag"]) or not output_path.exists()
        
        if should_run:
            if run_script(script_path):
                any_change = True
        else:
            log(f"Überspringe {task['script']} (keine Änderungen).")

    # 2. Aggregation (aggregate.py)
    # Ausführen wenn: Force ODER Irgendein Inventar neu erstellt wurde ODER Master-JSON fehlt
    master_json = INFO_DIR / "endpoints_info.json"
    if force or any_change or not master_json.exists():
        log("Aggregiere Inventare zu Master-JSON...")
        run_script(INV_DIR / "aggregate.py")
        # Flag für nachfolgende Skripte (z.B. Stylesheets) setzen
        (STATE_DIR / "updated_master").touch()
    else:
        log("Überspringe Aggregation (Master-JSON ist aktuell).")

    log("✅ Inventar-Check abgeschlossen.")

if __name__ == "__main__":
    main()
