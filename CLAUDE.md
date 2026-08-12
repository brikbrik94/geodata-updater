# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Agent Instructions

Bevor du nach den hier ergänzten, repo-spezifischen Angaben handelst: lies zuerst
`oe5ith-coding-rules/AGENT_INSTRUCTIONS.md` vollständig — die dortigen Mandate sind verbindlich
und werden hier nicht wiederholt.

## Project Overview

Geodata Updater is a Bash/Python **orchestrator** for a self-hosted vector map stack (PMTiles). It does not process geodata itself — actual data processing (download, merge, tile conversion) happens in separate "plugin" repositories. This repo's job is to trigger those plugins, collect their output, deploy it to a web root, build inventory metadata, and patch stylesheets with the correct final URLs.

This repository lives at two locations conceptually:
- **Git repo** (this checkout): source of truth for scripts/config/docs.
- **`/srv` on the target server**: the live, running deployment. `scripts/setup.sh` and `scripts/tools/deploy_scripts.sh` sync from the repo into `/srv` via `rsync`. Code changes here have no effect until synced/deployed.

There is no test suite, linter, or build step in this repo — it's operational Bash/Python glue. Verify changes by reading the scripts carefully and, where possible, running them against a real or scratch `/srv`-like directory tree.

## Commands

### Install / initial setup (on a fresh Debian/Ubuntu server)
```bash
./install.sh                      # installs deps + runs scripts/setup.sh (creates /srv tree, syncs scripts, initial asset build)
```

### Running the pipeline
```bash
/srv/scripts/start.sh             # full run: update all plugins, then deploy
/srv/scripts/run_deploy.sh        # deploy-only phase (skip plugin updates)
/srv/scripts/run_deploy.sh --force   # force full re-deploy, bypassing incremental-skip logic
```

### Deploying repo changes to the live server
```bash
scripts/tools/deploy_scripts.sh   # rsync scripts/, conf/, styles/, docs/ from repo -> /srv (TARGET_BASE=/srv by default)
```

### Individual pipeline stages (useful when debugging one phase)
```bash
python3 scripts/deploy_external.py     # copy PMTiles/styles/assets from each plugin's dist/ into /srv/tiles, /srv/assets
python3 scripts/run_inventory.py [--force]   # (re)build tiles/sprites/fonts inventories + endpoints_info.json
bash scripts/update_stylesheets.sh [--force] # patch style.json files with absolute URLs (wraps update_stylesheets.py)
scripts/run_assets.sh                  # build fonts (install_fonts.sh) and default sprite sets (build_sprites.sh, via Docker/spreet)
python3 scripts/tools/cleanup_tiles.py # remove orphaned PMTiles no longer referenced by any plugin manifest
scripts/ors/rebuild_ors_graphs.sh      # copy a merged OSM PBF into the ORS data dir and trigger graph rebuild
```

Individual inventory scripts (normally called via `run_inventory.py`, not directly):
`scripts/inventory/tiles.py`, `sprites.py`, `layers.py`, `fonts.sh`, `aggregate.py`.

All scripts source `scripts/config.env` (paths, base URLs) and `scripts/utils.sh` (shared `log_*` bash helpers) — check `config.env` first when something looks misconfigured.

## Architecture

### Plugin model
External geodata repos ("plugins", e.g. `geodata-osm`, `geodata-basemap-at`, `geodata-openskimap`) are listed by absolute path in `conf/external_repos.txt`. Each plugin:
- Optionally exposes an executable `update.sh` or `build.sh` at its root — invoked by `run_external_updates.sh` before deployment.
- Must publish artifacts under its own `dist/` directory, described by `dist/manifest.json`.

The manifest standard (see `docs/EXTERNAL_PLUGINS.md`) defines `datasets` (each with `id`, `type` = `basemap`/`overlay`, `pmtiles_path`, `style_path`, optional `sprite_id`) and `resources.sprites` / `resources.fonts` (arrays of `{id, path}`). Legacy fields (`tileset`, `overlays`, `sprite_url`) are still accepted for backward compatibility — see that doc before changing manifest parsing in `deploy_external.py`.

### Pipeline flow (see `docs/deploy_flow.md` for the diagram)
1. `start.sh` → `run_external_updates.sh` runs each plugin's `update.sh`/`build.sh`.
2. `start.sh` → `run_deploy.sh`:
   - `deploy_external.py` reads every plugin's `manifest.json` and copies PMTiles/styles into `/srv/tiles/{basemaps,overlays,elevation}/...` and sprites/fonts into `/srv/assets/{sprites,fonts}/<id>/`.
   - `run_inventory.py` runs `inventory/{tiles.py,sprites.py,fonts.sh,layers.py}` then `inventory/aggregate.py` to build `/srv/info/endpoints_info.json` (the master metadata consumed by web frontends).
   - `update_stylesheets.sh`/`.py` patches every deployed `style.json` with final absolute URLs (PMTiles, sprites, glyphs) using `endpoints_info.json` and `conf/sprite_mapping.json`.

### Incremental deployment via flag files
`deploy_external.py` and `run_inventory.py` avoid redundant work using touch-file flags in `/tmp/geodata_state/` (`updated_tiles`, `updated_sprites`, `updated_fonts`, `updated_layers`, `updated_master`), set when a copy actually changes something (`copy_file`/`copy_dir` compare mtime+size, not just directory timestamps — see the comment in `deploy_external.py` on why directory mtime alone is unreliable). Downstream scripts (`run_inventory.py`) check these flags to decide whether to re-run; `--force` bypasses all of it. `update_stylesheets.py` is the exception: it always re-checks every deployed `style.json` against the desired state and only writes files that actually differ, so it is unaffected by stale/missing flags (see resolved gap in `TODO.md`).

### Sprite resolution
Sprite IDs are resolved with explicit priority, no folder-based fallback: a dataset's `sprite_id` must match either an `id` under the plugin's own `resources.sprites`, or a global set (e.g. `temaki`, `basemap-at`). See `conf/sprite_mapping.json` and `docs/EXTERNAL_PLUGINS.md` §2.

### Directory roles
- `scripts/` — orchestration logic; synced verbatim to `/srv/scripts` by `deploy_scripts.sh`/`setup.sh`.
  - `inventory/` — per-asset-type inventory builders, called by `run_inventory.py`.
  - `tools/` — admin utilities (`cleanup_tiles.py`, `deploy_scripts.sh`, `fix_metadata_json.py`, doc/info generators).
  - `ors/` — OpenRouteService graph management (separate, manually-triggered subsystem).
  - `archive/` — obsolete scripts kept for reference only; not part of the active pipeline.
- `conf/` — `external_repos.txt` (plugin paths) and `sprite_mapping.json` (global sprite ID → path mapping).
- `docs/` — the authoritative technical docs (`TECHNICAL_DETAILS.md`, `EXTERNAL_PLUGINS.md`, `FOLDER_STRUCTURE.md`, `deploy_flow.md`); read these for anything not covered here before making structural changes.
- `styles/` — master style.json templates, pre-wired with placeholder URLs for `update_stylesheets.py` to patch.
- `migration_export/` — planning/spec exports written while splitting plugin logic (OSM, basemap.at, OpenSkiMap) out of this repo into standalone external repos. Reference material for that migration, not live code.

On the server, the deployed layout is `/srv/{scripts,tiles,assets,info,ors,conf,styles,docs}` — see `docs/FOLDER_STRUCTURE.md` for the full tree.

## Conventions
- Bash scripts: `set -euo pipefail`, load `config.env` + `utils.sh`, use `log_header`/`log_section`/`log_info`/`log_success`/`log_warn`/`log_error` for output (not raw `echo`) for consistency.
- Python scripts read config from environment variables (populated from `config.env` by the calling shell script), not from CLI flags, aside from `--force`.
- Keep the `scripts/inventory/` and `scripts/tools/` separation — inventory scripts only ever read deployed state and write to `/srv/info`; tools are ad-hoc admin operations.
- Don't hardcode server-specific absolute paths or credentials into anything under `docs/` (public-facing documentation).
