# Layer-List Integration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Integrate the new `layer-list.json` standard into the geodata-updater pipeline for automated layer representation.

**Architecture:** Use a staging approach where `deploy_external.py` copies plugin-specific layer lists to a central staging area, and a new inventory script aggregates them into a master `layers_info.json`.

**Tech Stack:** Python, Bash, JSON.

---

### Task 1: Update Deployment Logic
**Files:**
- Modify: `scripts/deploy_external.py`

- [ ] **Step 1: Add staging path configuration**
Modify the configuration section to include the staging directory.
```python
# scripts/deploy_external.py
# Add near other Path definitions
STAGING_LAYERS_DIR = Path("/srv/info/staging/layers")
STAGING_LAYERS_DIR.mkdir(parents=True, exist_ok=True)
```

- [ ] **Step 2: Add layer-list staging logic to `process_repo`**
Implement the copying of `layer-list.json` if it exists.
```python
# scripts/deploy_external.py inside process_repo(repo_path)
# After resource processing (Sprites/Fonts)

layer_list_src = dist_dir / "layer-list.json"
if layer_list_src.exists():
    layer_list_dst = STAGING_LAYERS_DIR / f"{repo_path.name}.json"
    if copy_file(layer_list_src, layer_list_dst, "Layer List", change_type="layers") == "updated":
        log_success(f"Staged Layer List: {repo_path.name}.json")
```

- [ ] **Step 3: Verification**
Verify the script compiles and the new logic is reachable.
Run: `python3 -m py_compile scripts/deploy_external.py`
Expected: No errors.

- [ ] **Step 4: Commit**
```bash
git add scripts/deploy_external.py
git commit -m "feat: stage layer-list.json in deploy_external.py"
```

### Task 2: Create Layer Inventory Script
**Files:**
- Create: `scripts/inventory/layers.py`

- [ ] **Step 1: Implement aggregation logic**
Create the script to merge staged files and resolve URLs.
```python
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
                for style in data.get("styles", []):
                    # Normalize and strip
                    layer_entry = {
                        "id": style.get("style_id"),
                        "name": style.get("name"),
                        "pmtiles_url": resolve_url(style.get("pmtiles_path")),
                        "groups": []
                    }
                    for g in style.get("groups", []):
                        group = {
                            "source_layer": g.get("source_layer"),
                            "name": g.get("name"),
                            "template": g.get("template"),
                            "style_layers": g.get("style_layers", [])
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
```

- [ ] **Step 2: Set executable permissions**
Run: `chmod +x scripts/inventory/layers.py`

- [ ] **Step 3: Verification with mock data**
Create a dummy staged file and run the script.
Run: `mkdir -p /srv/info/staging/layers && echo '{"styles":[{"style_id":"test","pmtiles_path":"pmtiles/test.pmtiles"}]}' > /srv/info/staging/layers/test.json && ./scripts/inventory/layers.py`
Expected: `layers_info.json` created with absolute URL.

- [ ] **Step 4: Commit**
```bash
git add scripts/inventory/layers.py
git commit -m "feat: add layers inventory aggregation script"
```

### Task 3: Integrate into Orchestration
**Files:**
- Modify: `scripts/run_inventory.py`

- [ ] **Step 1: Add Task to `run_inventory.py`**
Update the `tasks` list in the `main` function.
```python
# scripts/run_inventory.py
# In main() tasks list:
    tasks = [
        {"script": "tiles.py",   "flag": "tiles",   "output": "tiles_inventory.json"},
        {"script": "sprites.py", "flag": "sprites", "output": "sprite_inventory.json"},
        {"script": "fonts.sh",   "flag": "fonts",   "output": "font_inventory.json"},
        {"script": "layers.py",  "flag": "layers",  "output": "layers_info.json"} # ADD THIS
    ]
```

- [ ] **Step 2: Verification**
Run the orchestrator with `--force`.
Run: `python3 scripts/run_inventory.py --force`
Expected: `layers.py` is started and `layers_info.json` is generated.

- [ ] **Step 3: Commit**
```bash
git add scripts/run_inventory.py
git commit -m "feat: integrate layers inventory into orchestration"
```
