# Design Spec: Layer-List Integration (Standard v1.3+)

## 1. Overview
This specification describes the integration of the new `layer-list.json` standard into the `geodata-updater` pipeline. This metadata provides detailed information about vector layers, groups, and templates within PMTiles datasets, enabling advanced UI features and automated layer representation.

## 2. Architecture (Approach A: Strict Separation)
The integration follows the established "Staging & Aggregation" pattern:
1. **Staging (Deployment Phase)**: `deploy_external.py` extracts `layer-list.json` from plugins.
2. **Aggregation (Inventory Phase)**: A new `layers.py` script merges staged data into a master `layers_info.json`.
3. **Linking**: The `id` field serves as the unique identifier to link entries between `endpoints_info.json` and `layers_info.json`.

## 3. Component Details

### 3.1 `scripts/deploy_external.py`
- **Logic**: Check for `dist/layer-list.json` in each repository.
- **Staging Path**: `/srv/info/staging/layers/<repo_name>.json`.
- **State Management**: Touch `/tmp/geodata_state/updated_layers` upon change.

### 3.2 `scripts/inventory/layers.py` (NEW)
- **Input**: All files in `/srv/info/staging/layers/*.json`.
- **Processing**:
    - Normalize `style_id` to `id`.
    - Resolve `pmtiles_path` to absolute `pmtiles_url` using `TILES_BASE_URL`.
    - Strip internal-only fields (e.g., `original_file`).
- **Output**: `/srv/info/layers_info.json`.

### 3.3 `scripts/run_inventory.py`
- **Task Addition**: Integrate `layers.py` into the main inventory orchestration.
- **Dependency**: Ensure it runs when `updated_layers` flag is set or output is missing.

## 4. Data Structure (`layers_info.json`)
```json
{
  "generated_at": "ISO-8601",
  "meta": {
    "tiles_base_url": "...",
    "assets_base_url": "..."
  },
  "layers": [
    {
      "id": "anfahrtszeit-linz",
      "name": "Anfahrtszeit Linz",
      "pmtiles_url": "https://tiles.oe5ith.at/overlays/pmtiles/anfahrtszeit-linz.pmtiles",
      "groups": [
        {
          "source_layer": "...",
          "name": "...",
          "template": "...",
          "style_layers": ["..."]
        }
      ]
    }
  ]
}
```

## 5. Success Criteria
- [ ] `deploy_external.py` successfully stages `layer-list.json` from `geodata-overlays`.
- [ ] `layers_info.json` is generated with valid absolute URLs.
- [ ] No regression in `endpoints_info.json` generation.
- [ ] The pipeline completes successfully without errors.
