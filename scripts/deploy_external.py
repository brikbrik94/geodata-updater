#!/usr/bin/env python3
import json
import os
import shutil
import sys
from pathlib import Path

# --- KONFIGURATION ---
TILES_DIR = Path(os.environ.get("TILES_DIR", "/srv/tiles"))
ASSETS_DIR = Path(os.environ.get("ASSETS_DIR", "/srv/assets"))
STAGING_LAYERS_DIR = Path("/srv/info/staging/layers")
STAGING_LAYERS_DIR.mkdir(parents=True, exist_ok=True)
CONF_FILE = Path(os.environ.get("EXTERNAL_REPOS_CONF", str(Path(__file__).resolve().parent.parent / "conf" / "external_repos.txt")))

def log_info(msg): print(f"   ℹ️  {msg}")
def log_success(msg): print(f"   ✅ {msg}")
def log_warn(msg): print(f"   ⚠️  {msg}")
def log_error(msg): print(f"   ❌ {msg}")

# --- STATUS TRACKING ---
STATE_DIR = Path("/tmp/geodata_state")
STATE_DIR.mkdir(parents=True, exist_ok=True)

def mark_updated(change_type):
    """Markiert einen Datentyp als aktualisiert für nachfolgende Skripte."""
    (STATE_DIR / f"updated_{change_type}").touch()

def copy_file(src, dst, label, change_type=None):
    if not src.exists():
        log_warn(f"{label} nicht gefunden: {src}")
        return False
    
    # Inkrementelles Deployment: Prüfung auf Zeitstempel UND Größe
    if dst.exists():
        src_stat = src.stat()
        dst_stat = dst.stat()
        
        # Wenn Zeitstempel gleich/älter UND Größe identisch -> überspringen
        if src_stat.st_mtime <= dst_stat.st_mtime and src_stat.st_size == dst_stat.st_size:
            return "skipped"

    dst.parent.mkdir(parents=True, exist_ok=True)
    # Nutze shutil.copy2 um Metadaten (mtime) zu erhalten
    shutil.copy2(src, dst)
    if change_type:
        mark_updated(change_type)
    return "updated"

def copy_dir(src, dst, label, change_type=None):
    if not src.exists() or not src.is_dir():
        log_warn(f"{label} nicht gefunden oder kein Verzeichnis: {src}")
        return False
    
    # Grobe Inkremental-Prüfung für Verzeichnisse über den Zeitstempel des Ordners
    if dst.exists():
        src_mtime = src.stat().st_mtime
        dst_mtime = dst.stat().st_mtime
        if src_mtime <= dst_mtime:
            return "skipped"

    if dst.exists():
        shutil.rmtree(dst)
    shutil.copytree(src, dst)
    if change_type:
        mark_updated(change_type)
    return "updated"

def process_repo(repo_path):
    repo_path = Path(os.path.expanduser(repo_path))
    if not repo_path.exists():
        log_warn(f"Überspringe: Verzeichnis nicht gefunden: {repo_path}")
        return

    dist_dir = repo_path / "dist"
    manifest_file = dist_dir / "manifest.json"

    if not manifest_file.exists():
        log_warn(f"Überspringe: Keine dist/manifest.json in {repo_path}")
        return

    log_info(f"Verarbeite Plugin: {repo_path.name}")

    try:
        manifest = json.loads(manifest_file.read_text(encoding="utf-8"))
    except Exception as e:
        log_error(f"Fehler beim Lesen der manifest.json: {e}")
        return

    # 1. Globales Tileset (Legacy/Fallback)
    global_tileset = manifest.get("tileset")
    
    # 2. Datensätze (Datasets / Overlays)
    datasets = manifest.get("datasets", []) or manifest.get("overlays", [])
    
    if not datasets:
        log_warn("Keine Datensätze (datasets/overlays) im Manifest gefunden.")
    else:
        for ds in datasets:
            ds_id = ds.get("id")
            pmtiles_rel = ds.get("pmtiles_path")
            style_rel = ds.get("style_path")
            
            # Typ-Bestimmung
            ds_type = ds.get("type", global_tileset or "overlays")
            
            if ds_type in ["overlay", "overlays"]:
                tileset_dir = "overlays"
            elif ds_type in ["basemap", "basemaps"]:
                tileset_dir = "basemaps"
            else:
                tileset_dir = ds_type

            if not ds_id or not pmtiles_rel:
                log_warn(f"Datensatz unvollständig (ID oder PMTiles fehlt): {ds}")
                continue

            # Pfade auflösen
            pmtiles_src = dist_dir / pmtiles_rel
            style_src = dist_dir / style_rel if style_rel else None

            # Ziel-Pfade
            pmtiles_dst = TILES_DIR / tileset_dir / "pmtiles" / f"{ds_id}.pmtiles"
            style_dst = TILES_DIR / tileset_dir / "styles" / ds_id / "style.json"

            # PMTiles kopieren
            res_pm = copy_file(pmtiles_src, pmtiles_dst, "PMTiles", change_type="tiles")
            if res_pm == "updated":
                log_success(f"Deployed PMTiles: {tileset_dir}/{ds_id}.pmtiles")
            
            # Style kopieren
            if style_src:
                res_st = copy_file(style_src, style_dst, "Style", change_type="tiles")
                if res_st == "updated":
                    log_success(f"Deployed Style: {tileset_dir}/{ds_id}/style.json")

    # 3. Ressourcen (Sprites / Fonts)
    resources = manifest.get("resources", {})
    
    # A) Sprites
    sprites = resources.get("sprites", [])
    for s in sprites:
        if isinstance(s, str):
            s_id, s_rel = s, s
        elif isinstance(s, dict):
            s_id = s.get("id")
            s_rel = s.get("path") or (os.path.dirname(s.get("sprite_url", "")) if s.get("sprite_url") else None)
        else: continue
        
        if s_id and s_rel:
            src, dst = dist_dir / s_rel, ASSETS_DIR / "sprites" / s_id
            if copy_dir(src, dst, "Sprite", change_type="sprites") == "updated":
                log_success(f"Deployed Assets: sprites/{s_id}")

    # B) Fonts
    fonts = resources.get("fonts", [])
    for f in fonts:
        if isinstance(f, str):
            f_id, f_rel = f, f
        elif isinstance(f, dict):
            f_id, f_rel = f.get("id"), f.get("path")
        else: continue

        if f_id and f_rel:
            src, dst = dist_dir / f_rel, ASSETS_DIR / "fonts" / f_id
            if copy_dir(src, dst, "Font", change_type="fonts") == "updated":
                log_success(f"Deployed Assets: fonts/{f_id}")

    # 4. Layer List (Staging)
    layer_list_src = dist_dir / "layer-list.json"
    if layer_list_src.exists():
        layer_list_dst = STAGING_LAYERS_DIR / f"{repo_path.name}.json"
        res_ll = copy_file(layer_list_src, layer_list_dst, "Layer List", change_type="layers")
        if res_ll == "updated":
            log_success(f"Staged Layer List: {repo_path.name}.json")

def main():
    # Beim Start eines Deployment-Laufs die alten Flags löschen (optional, wir können sie auch am Ende löschen)
    # Aber hier löschen wir sie, damit wir den aktuellen Stand tracken.
    for f in STATE_DIR.glob("updated_*"):
        try: f.unlink()
        except: pass

    if not CONF_FILE.exists():
        log_info(f"Keine Konfiguration für externe Repos gefunden ({CONF_FILE}).")
        return

    with open(CONF_FILE, "r") as f:
        for line in [l.strip() for l in f if l.strip() and not l.strip().startswith("#")]:
            process_repo(line)

if __name__ == "__main__":
    main()
