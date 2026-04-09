# Gemini Project Guide: Geodata Updater

## Project Overview
An automated pipeline for processing and self-hosting vector maps (PMTiles). It manages the entire lifecycle from downloading raw geodata (OSM, basemap.at) to deployment and dynamic stylesheet generation.

### Core Technologies
- **Vector Tiles:** PMTiles (v3)
- **Engine:** [Planetiler](https://github.com/onthegomap/planetiler) (via Docker)
- **Data Sources:** OSM (.pbf), basemap.at (VTPK), OpenSkiMap
- **Automation:** Bash (orchestration), Python (metadata & style processing)
- **Web:** Designed for Nginx serving static PMTiles and JSON styles

---

## Directory Structure & Roles
- `scripts/`: The heart of the pipeline. Modular scripts for each stage.
  - `start.sh`: Main entry point.
  - `run_download.sh`, `run_merge.sh`, `run_pmtiles.sh`: Core pipeline stages.
  - `deploy_*.sh`: Deployment logic for tiles and styles.
- `conf/sources/`: Text files defining geodata regions (e.g., `at-plus.txt`).
- `deploy_*.sh`: Deployment logic for tiles and styles.
- `deploy_external.py`: Deploys third-party datasets from external repositories (plugins).
- `update_stylesheets.py`: Dynamically adjusts style.json files (URLs, fonts, sprites).
- `conf/sources/`: Text files defining geodata regions (e.g., `at-plus.txt`).
- `conf/sprite_mapping.json`: Static mapping of styles to sprite sets.
- `docs/`: In-depth documentation on deployment, structure, and technical details.
- `data/tmp/`: Working directory for downloads and intermediate builds.

---

## Pipeline Workflow (The "Big Picture")
1. **Download:** `run_download.sh` reads `conf/sources/*.txt`, fetches OSM PBFs (using `wget -N` for caching), and grabs `basemap.at` VTPKs if they are outdated (>2 months).
2. **Merge:** `run_merge.sh` uses `osmium-tool` to combine multiple OSM PBFs into a single regional file.
3. **Convert:** `run_pmtiles.sh` triggers `planetiler` (via Docker) to transform PBFs into PMTiles. It also handles specialized VTPK-to-PMTiles conversion for `basemap.at`.
4. **Deploy:** `deploy_all.sh` (or `deploy_pmtiles.sh`) moves PMTiles to the web root. External plugins are integrated via `deploy_external.py`.
5. **Post-Processing:** `update_stylesheets.py` scans all deployed styles. It resolves PMTiles URLs per source (using `endpoints_info.json`), applies font mappings, and assigns sprites based on internal (`conf/sprite_mapping.json`) or external (`/srv/info/sprite_mapping_external.json`) definitions.

---

## Technical Constants & Conventions
- **Installation Path:** Typically `/srv` (scripts in `/srv/scripts`, tiles in `/srv/tiles`).
- **External Plugins:** Must provide a `dist/manifest.json`. Metadata (like `sprite_id`) is persisted during deployment to allow seamless stylesheet updates.
- **Sprite Resolution:** Priority-based assignment. Explicit mappings for specific styles (`tileset/style_id`) allow decoupling assets from the tileset name.
- **Basemap.at Rules:** VTPK files are large; downloads are throttled/checked by date to save bandwidth.

---

## Developer Quick Links
- [Technical Details](docs/TECHNICAL_DETAILS.md) - Deep dive into script logic and parameters.
- [Folder Structure](docs/FOLDER_STRUCTURE.md) - How the `/srv` directory is organized.
- [Deployment Flow](docs/deploy_flow.md) - Mermaid diagram of the pipeline.

---

## AI Interaction Guidelines
- **Surgical Edits:** When modifying scripts, ensure they remain modular. Many scripts are called by `start.sh` or `run_*.sh`.
- **Environment Variables:** Scripts rely on `scripts/config.env` for path and URL configuration. Always check this file before suggesting configuration changes.
- **Docker Dependency:** PMTiles conversion requires a functional Docker environment.
