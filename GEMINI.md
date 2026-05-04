# Gemini Project Guide: Geodata Updater

## Project Overview
An automated orchestrator for processing and self-hosting vector maps (PMTiles). It manages the deployment lifecycle, asset generation (fonts/sprites), and dynamic stylesheet patching for external geodata plugins (OSM, basemap.at, OpenSkiMap).

### Core Technologies
- **Vector Tiles:** PMTiles (v3)
- **Engine:** External Plugins (Planetiler, Tippecanoe, vtpk2mbtiles)
- **Data Sources:** OSM, basemap.at, OpenSkiMap (via external repos)
- **Automation:** Bash (orchestration), Python (metadata & style processing)
- **Web:** Designed for Nginx serving static PMTiles and JSON styles

---

## Directory Structure & Roles
- `scripts/`: Central logic for orchestration and deployment.
  - `start.sh`: Main entry point (Update Plugins -> Deploy).
  - `run_external_updates.sh`: Triggers plugin builds.
  - `run_deploy.sh`: Manages data deployment and post-processing.
  - `run_inventory.py`: Orchestrates inventory generation.
  - `inventory/`: Specialized scripts for tiles, sprites, and fonts.
  - `tools/`: Administrative tools (cleanup, deployment, fixes).
  - `ors/`: OpenRouteService management.
  - `archive/`: Obsolete internal scripts.
- `conf/`: Global configuration (e.g., `external_repos.txt`, `sprite_mapping.json`).
- `docs/`: Technical documentation (deployment flow, plugin standard, structure).
- `styles/`: Master templates for vector styles.

---

## Pipeline Workflow (The "Big Picture")
1. **Orchestrate:** `start.sh` triggers `run_external_updates.sh`.
2. **Build (External):** Each plugin in `conf/external_repos.txt` runs its `update.sh`, generating data in its `dist/` directory.
3. **Deploy:** `deploy_external.py` copies PMTiles, Styles, and Assets from `dist/` to the web root (`/srv/tiles`, `/srv/assets`).
4. **Inventory:** `run_inventory.py` builds the `endpoints_info.json` master metadata.
5. **Patch:** `update_stylesheets.py` resolve URLs in all styles (PMTiles, Fonts, Sprites) using absolute server paths.
6. **Maintenance:** `scripts/tools/cleanup_tiles.py` removes orphaned data based on current manifests.

---

## Technical Constants & Conventions
- **Installation Path:** Typically `/srv` (scripts in `/srv/scripts`, tiles in `/srv/tiles`).
- **External Plugins:** MUST provide a `dist/manifest.json`. See [📄 Plugin-Standard](docs/EXTERNAL_PLUGINS.md).
- **Sprite Resolution:** Priority-based. Dataset-level `sprite_id` overrides global mappings.
- **Categorization:** Data is organized into `basemaps`, `overlays`, and `elevation` categories.

---

## AI Interaction Guidelines
- **Modular Edits:** Scripts are organized into subfolders (`inventory/`, `tools/`). Maintain this separation.
- **Environment Variables:** Scripts rely on `scripts/config.env`. Always check this for path configurations.
- **Plugin Integrity:** When suggesting changes, ensure they align with the `manifest.json` standard.
- **Security:** Do not expose server-specific credentials or absolute paths in public documentation.
---
