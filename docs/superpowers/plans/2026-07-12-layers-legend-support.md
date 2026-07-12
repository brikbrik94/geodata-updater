# Legend Support in layers_info.json Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Extend `scripts/inventory/layers.py` so the per-group legend metadata (`type`, `color`, `opacity`, `legend_items`) that plugins now emit in `dist/layer-list.json` is carried through into the aggregated `/srv/info/layers_info.json`.

**Architecture:** Single-file change. `layers.py` already loops over staged `layer-list.json` files (`/srv/info/staging/layers/*.json`, written there by `deploy_external.py`) and builds a per-group dict for the output. That dict gets four new keys, read via `.get(key)` so plugins without the new fields yield `null` instead of a missing key or a crash. `original_file` is read from the source but deliberately not copied into the output. No other file changes.

**Tech Stack:** Python 3 stdlib only (`json`, `pathlib`, `unittest`) — no new dependencies. This repo has no existing test suite or test runner; this plan introduces the first test file, using stdlib `unittest` (not pytest, which is not among this repo's installed dependencies per `scripts/install_dependencies.sh`) so it runs anywhere `python3` runs, with no extra install step.

## Global Constraints

- New fields (`type`, `color`, `opacity`, `legend_items`) are passed through **verbatim**, no transformation or validation (per spec §4).
- `original_file` must **not** appear in the output (per spec §3–4).
- Every group in the output must always contain all eight keys (`source_layer`, `name`, `template`, `style_layers`, `type`, `color`, `opacity`, `legend_items`), with `null` for any the source doesn't provide — schema must be uniform across plugins regardless of source version (per spec §4).
- No changes to `resolve_url()`, the style-level `layer_entry` dict, the output envelope (`{generated_at, meta, layers}`), `aggregate.py`, `endpoints_info.json`, or `run_inventory.py` (per spec §2).

---

### Task 1: Pass through legend metadata in `layers.py`

**Files:**
- Modify: `scripts/inventory/layers.py:35-42` (the `group` dict construction inside `main()`)
- Test: `scripts/inventory/test_layers.py` (new file)

**Interfaces:**
- Consumes: `layers.STAGING_DIR` (`pathlib.Path`), `layers.OUTPUT_FILE` (`pathlib.Path`), `layers.main()` (no args, no return — reads `STAGING_DIR`, writes `OUTPUT_FILE`). These are module-level globals in `scripts/inventory/layers.py`, reassignable by tests to redirect I/O without touching `/srv`.
- Produces: no new public interface; `layers.main()`'s output file gains four keys per group as described in Global Constraints.

- [ ] **Step 1: Write the failing tests**

Create `scripts/inventory/test_layers.py`:

```python
#!/usr/bin/env python3
import json
import os
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import layers


class LayersLegendPassthroughTest(unittest.TestCase):
    def setUp(self):
        self.tmp_dir = tempfile.TemporaryDirectory()
        self.staging_dir = Path(self.tmp_dir.name) / "staging"
        self.staging_dir.mkdir()
        self.output_file = Path(self.tmp_dir.name) / "layers_info.json"

        self._orig_staging_dir = layers.STAGING_DIR
        self._orig_output_file = layers.OUTPUT_FILE
        layers.STAGING_DIR = self.staging_dir
        layers.OUTPUT_FILE = self.output_file

    def tearDown(self):
        layers.STAGING_DIR = self._orig_staging_dir
        layers.OUTPUT_FILE = self._orig_output_file
        self.tmp_dir.cleanup()

    def _write_staged_file(self, name, data):
        (self.staging_dir / name).write_text(json.dumps(data), encoding="utf-8")

    def test_group_passes_through_new_fields_with_legend(self):
        self._write_staged_file("geodata-overlays.json", {
            "version": "1.0",
            "styles": [
                {
                    "style_id": "anfahrtszeit-linz",
                    "name": "Anfahrtszeit Linz",
                    "pmtiles_path": "pmtiles/anfahrtszeit-linz.pmtiles",
                    "groups": [
                        {
                            "source_layer": "15_0",
                            "name": "15-0",
                            "template": "anfahrtszeit",
                            "original_file": "Anfahrtszeit/Linz/15-0.geojson",
                            "style_layers": ["anfahrtszeit-linz-15_0-fill"],
                            "type": "fill",
                            "color": ["match", ["get", "AA_MINS"], 15, "#10b981", "#3b82f6"],
                            "opacity": 0.4,
                            "legend_items": [
                                {"label": "0-15 min", "color": "#10b981"},
                                {"label": "15-30 min", "color": "#84cc16"}
                            ]
                        }
                    ]
                }
            ]
        })

        layers.main()

        output = json.loads(self.output_file.read_text(encoding="utf-8"))
        group = output["layers"][0]["groups"][0]

        self.assertEqual(group["type"], "fill")
        self.assertEqual(group["color"], ["match", ["get", "AA_MINS"], 15, "#10b981", "#3b82f6"])
        self.assertEqual(group["opacity"], 0.4)
        self.assertEqual(group["legend_items"], [
            {"label": "0-15 min", "color": "#10b981"},
            {"label": "15-30 min", "color": "#84cc16"}
        ])
        self.assertNotIn("original_file", group)

    def test_group_without_new_fields_defaults_to_null(self):
        self._write_staged_file("geodata-osm.json", {
            "version": "1.0",
            "styles": [
                {
                    "style_id": "roads",
                    "name": "Roads",
                    "pmtiles_path": "pmtiles/roads.pmtiles",
                    "groups": [
                        {
                            "source_layer": "roads",
                            "name": "Roads",
                            "template": "strassen",
                            "style_layers": ["roads-line"]
                        }
                    ]
                }
            ]
        })

        layers.main()

        output = json.loads(self.output_file.read_text(encoding="utf-8"))
        group = output["layers"][0]["groups"][0]

        self.assertIsNone(group["type"])
        self.assertIsNone(group["color"])
        self.assertIsNone(group["opacity"])
        self.assertIsNone(group["legend_items"])
        self.assertNotIn("original_file", group)


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `python3 scripts/inventory/test_layers.py -v`
Expected: Both tests `FAIL` — `test_group_passes_through_new_fields_with_legend` and `test_group_without_new_fields_defaults_to_null` raise `KeyError: 'type'` (the current `group` dict has no `type`/`color`/`opacity`/`legend_items` keys at all).

- [ ] **Step 3: Implement the minimal change**

In `scripts/inventory/layers.py`, replace the `group` dict construction (currently lines 35-40) with:

```python
                    for g in style.get("groups", []):
                        group = {
                            "source_layer": g.get("source_layer"),
                            "name": g.get("name"),
                            "template": g.get("template"),
                            "style_layers": g.get("style_layers", []),
                            "type": g.get("type"),
                            "color": g.get("color"),
                            "opacity": g.get("opacity"),
                            "legend_items": g.get("legend_items")
                        }
                        layer_entry["groups"].append(group)
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `python3 scripts/inventory/test_layers.py -v`
Expected: `OK` — both tests pass (`Ran 2 tests ... OK`).

- [ ] **Step 5: Commit**

```bash
git add scripts/inventory/layers.py scripts/inventory/test_layers.py
git commit -m "$(cat <<'EOF'
feat: pass through legend metadata in layers_info.json

Plugins now emit type/color/opacity/legend_items per group in
layer-list.json; carry these through into the aggregated
layers_info.json so frontends can render legends without
re-deriving them from style.json.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 2: Manual verification against real staged data

This host already has a staged `layer-list.json` from the `geodata-overlays` plugin at `/srv/info/staging/layers/geodata-overlays.json` (the same content shown in `/mnt/geodata/geodata-overlays/dist/layer-list.json`). `layers.py` reads/writes real `/srv` paths directly (`STAGING_DIR`/`OUTPUT_FILE` are not environment-overridable), so running it here regenerates the real `/srv/info/layers_info.json` — this is the script's normal, idempotent job (it's what `run_inventory.py` already triggers during deploys), so running it is safe.

**Files:** none (verification only, no code changes)

- [ ] **Step 1: Run the script for real**

Run: `python3 scripts/inventory/layers.py`
Expected: Output ends with `✅ LAYER INFO erstellt: /srv/info/layers_info.json (14 Styles)` (14 styles matches the 14 datasets in `/mnt/geodata/geodata-overlays/dist/manifest.json`).

- [ ] **Step 2: Confirm legend data landed in the real output file**

Run: `python3 -c "import json; d=json.load(open('/srv/info/layers_info.json')); g=[grp for l in d['layers'] if l['id']=='anfahrtszeit-linz' for grp in l['groups']][0]; print(json.dumps(g, indent=2))"`
Expected: Prints a group object with `source_layer`, `name`, `template`, `style_layers`, `type: "fill"`, a `color` match-expression, `opacity: 0.4`, and a non-null `legend_items` list of `{label, color}` objects — and no `original_file` key.

- [ ] **Step 3: Confirm a legend-less group still has all keys with nulls**

Run: `python3 -c "import json; d=json.load(open('/srv/info/layers_info.json')); g=[grp for l in d['layers'] if l['id']=='autobahnen' for grp in l['groups']][0]; print(json.dumps(g, indent=2))"`
Expected: Prints a group with `type: "line"`, `color: "#0000FF"`, `opacity: 0.8`, `legend_items: null` (autobahnen groups have no legend in the source data).

- [ ] **Step 4: Confirm no regression in `endpoints_info.json`**

Run: `git -C /root/git/geodata-updater status --short` and `md5sum /srv/info/endpoints_info.json`
Expected: `git status` shows no changes outside the two files committed in Task 1 (the run in Step 1 only touches `/srv/info/layers_info.json`, which is a deployment artifact, not tracked in git). `endpoints_info.json`'s checksum is unchanged from before Step 1 (this task doesn't touch it, but confirms `layers.py` didn't have side effects on it).

No commit for this task — it's a verification-only task with no file changes in the repo.
