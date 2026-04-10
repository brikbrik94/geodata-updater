#!/usr/bin/env python3
import json
import os
import shutil
import sys
from pathlib import Path

# --- KONFIGURATION ---
TILES_DIR = Path(os.environ.get("TILES_DIR", "/srv/tiles"))
ASSETS_DIR = Path(os.environ.get("ASSETS_DIR", "/srv/assets"))
CONF_FILE = Path(os.environ.get("EXTERNAL_REPOS_CONF", str(Path(__file__).resolve().parent.parent / "conf" / "external_repos.txt")))

def log_info(msg): print(f"   ℹ️  {msg}")
def log_success(msg): print(f"   ✅ {msg}")
def log_warn(msg): print(f"   ⚠️  {msg}")
def log_error(msg): print(f"   ❌ {msg}")

def copy_file(src, dst, label):
    if not src.exists():
        log_warn(f"{label} nicht gefunden: {src}")
        return False
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dst)
    # log_info(f"{label} kopiert: {dst.name}")
    return True

def copy_dir(src, dst, label):
    if not src.exists() or not src.is_dir():
        log_warn(f"{label} nicht gefunden oder kein Verzeichnis: {src}")
        return False
    if dst.exists():
        shutil.rmtree(dst)
    shutil.copytree(src, dst)
    # log_info(f"{label} Verzeichnis kopiert: {dst.name}")
    return True

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

    # 1. Tileset Bestimmen (Standard: overlays)
    tileset = manifest.get("tileset", "overlays")
    
    # 2. Datensätze (Datasets / Overlays)
    # Support für "datasets" (Standard) oder "overlays" (Legacy)
    datasets = manifest.get("datasets", [])
    if not datasets:
        datasets = manifest.get("overlays", [])
    
    if not datasets:
        log_warn("Keine Datensätze (datasets/overlays) im Manifest gefunden.")
    else:
        for ds in datasets:
            ds_id = ds.get("id")
            pmtiles_rel = ds.get("pmtiles_path")
            style_rel = ds.get("style_path")

            if not ds_id or not pmtiles_rel:
                log_warn(f"Datensatz unvollständig (ID oder PMTiles fehlt): {ds}")
                continue

            # Pfade auflösen
            pmtiles_src = dist_dir / pmtiles_rel
            style_src = dist_dir / style_rel if style_rel else None

            # Ziel-Pfade
            pmtiles_dst = TILES_DIR / tileset / "pmtiles" / f"{ds_id}.pmtiles"
            style_dst = TILES_DIR / tileset / "styles" / ds_id / "style.json"

            # Kopieren
            if copy_file(pmtiles_src, pmtiles_dst, "PMTiles"):
                log_success(f"Deployed: {tileset}/pmtiles/{ds_id}.pmtiles")
            
            if style_src and copy_file(style_src, style_dst, "Style"):
                log_success(f"Deployed: {tileset}/styles/{ds_id}/style.json")

    # 3. Ressourcen (Sprites / Fonts)
    resources = manifest.get("resources", {})
    
    # A) Sprites
    sprites = resources.get("sprites", [])
    for s in sprites:
        s_id = s.get("id")
        # Support für "path" (Standard) oder "sprite_url" (Legacy)
        s_rel = s.get("path")
        if not s_rel:
            # Wenn "sprite_url" angegeben ist, nehmen wir den Verzeichnisnamen davon
            s_url = s.get("sprite_url", "")
            if s_url:
                s_rel = os.path.dirname(s_url)
        
        if s_id and s_rel:
            src = dist_dir / s_rel
            dst = ASSETS_DIR / "sprites" / s_id
            if copy_dir(src, dst, "Sprite"):
                log_success(f"Deployed Assets: sprites/{s_id}")

    # B) Fonts
    fonts = resources.get("fonts", [])
    for f in fonts:
        f_id = f.get("id")
        f_rel = f.get("path")
        if f_id and f_rel:
            src = dist_dir / f_rel
            dst = ASSETS_DIR / "fonts" / f_id
            if copy_dir(src, dst, "Font"):
                log_success(f"Deployed Assets: fonts/{f_id}")

def main():
    if not CONF_FILE.exists():
        log_info(f"Keine Konfiguration für externe Repos gefunden ({CONF_FILE}).")
        return

    with open(CONF_FILE, "r") as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            process_repo(line)

if __name__ == "__main__":
    main()
