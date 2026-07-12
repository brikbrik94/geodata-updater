# Design Spec: Legend Support in `layers_info.json`

## 1. Overview
The `layer-list.json` standard (see `docs/superpowers/specs/2026-05-04-layer-list-integration-design.md`) has been extended by plugins (first seen in `geodata-overlays`) to include per-group styling and legend metadata: `type`, `color`, `opacity`, and `legend_items`. This spec covers extending `scripts/inventory/layers.py` so this new metadata is carried through into the aggregated `layers_info.json`, enabling frontends to render legends without re-deriving them from style.json.

## 2. Scope
- **In scope**: `scripts/inventory/layers.py` — the per-group dict built while aggregating staged `layer-list.json` files.
- **Out of scope**: `deploy_external.py` (staging logic unchanged), `run_inventory.py` (orchestration unchanged), `aggregate.py`/`endpoints_info.json` (unaffected), style-level (`layer_entry`) fields (unaffected), the `layer-list.json` producer side (plugin repos, external to this repo).

## 3. New Fields
Each group object in a plugin's `dist/layer-list.json` may now contain, in addition to the existing `source_layer`, `name`, `template`, `style_layers`:

| Field | Type | Notes |
|---|---|---|
| `type` | string | MapLibre layer type, e.g. `"fill"`, `"line"`, `"symbol"` |
| `color` | string \| MapLibre expression \| null | Fixed color or a `match`/expression array; `null` for symbol layers without a flat color |
| `opacity` | number | |
| `legend_items` | array of `{label, color}` \| null | `null` when the group has no meaningful legend (e.g. single-color line/fill layers) |

`original_file` (relative path to the source GeoJSON in the plugin repo) is also present in the source but is internal build metadata with no frontend use, and is **not** carried through — same treatment as today.

## 4. Behavior
`scripts/inventory/layers.py`, in `main()`, extends the `group` dict built per entry of `style.get("groups", [])` to pass through `type`, `color`, `opacity`, and `legend_items` verbatim via `.get(key)`, alongside the existing fields.

- **Pass-through, no transformation**: values (including `color` as a nested MapLibre expression array) are copied as-is; no validation or flattening.
- **Fixed schema across plugins**: plugins whose `layer-list.json` predates this extension (e.g. `geodata-osm`, `geodata-basemap-at` today) simply lack these keys in their source groups, so `.get(key)` yields `None`/`null`. The output schema is therefore uniform across all groups regardless of source plugin version — every group object always has all eight keys, with `null` where the source doesn't provide a value, rather than keys being present/absent inconsistently.
- **No other changes**: `resolve_url()`, the style-level `layer_entry` dict, and the overall output envelope (`{generated_at, meta, layers}`) are unchanged. `aggregate.py` and `endpoints_info.json` are untouched — legend data lives only in `layers_info.json`.

## 5. Updated Data Structure (`layers_info.json`)
```json
{
  "generated_at": "ISO-8601",
  "meta": {
    "tiles_base_url": "..."
  },
  "layers": [
    {
      "id": "anfahrtszeit-linz",
      "name": "Anfahrtszeit Linz",
      "pmtiles_url": "https://tiles.oe5ith.at/overlays/pmtiles/anfahrtszeit-linz.pmtiles",
      "groups": [
        {
          "source_layer": "15_0",
          "name": "15-0",
          "template": "anfahrtszeit",
          "style_layers": ["anfahrtszeit-linz-15_0-fill", "anfahrtszeit-linz-15_0-labels"],
          "type": "fill",
          "color": ["match", ["get", "AA_MINS"], 15, "#10b981", "..."],
          "opacity": 0.4,
          "legend_items": [
            {"label": "0-15 min", "color": "#10b981"},
            {"label": "15-30 min", "color": "#84cc16"}
          ]
        },
        {
          "source_layer": "a1",
          "name": "A1",
          "template": "strassen",
          "style_layers": ["autobahnen-a1-line", "autobahnen-a1-line-proposed", "autobahnen-a1-labels"],
          "type": "line",
          "color": "#0000FF",
          "opacity": 0.8,
          "legend_items": null
        }
      ]
    }
  ]
}
```

## 6. Success Criteria
- [ ] Running `scripts/inventory/layers.py` against the staged `geodata-overlays` `layer-list.json` produces groups containing `type`, `color`, `opacity`, and `legend_items`, matching the source values.
- [ ] `original_file` does not appear in the output.
- [ ] Groups sourced from plugins without the new fields still produce all eight keys, with `null` for the missing ones (no `KeyError`, no inconsistent schema).
- [ ] No changes to `endpoints_info.json` output or to any other inventory file.
