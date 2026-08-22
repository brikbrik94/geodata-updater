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
        layer_entry = output["layers"][0]
        group = layer_entry["groups"][0]

        self.assertEqual(layer_entry["version"], "1.0")
        self.assertEqual(group["type"], "fill")
        self.assertEqual(group["color"], ["match", ["get", "AA_MINS"], 15, "#10b981", "#3b82f6"])
        self.assertEqual(group["opacity"], 0.4)
        self.assertEqual(group["legend_items"], [
            {"label": "0-15 min", "color": "#10b981"},
            {"label": "15-30 min", "color": "#84cc16"}
        ])
        self.assertEqual(group["original_file"], "Anfahrtszeit/Linz/15-0.geojson")

    def test_group_passes_through_v1_1_fields(self):
        self._write_staged_file("geodata-openskimap.json", {
            "version": "1.1",
            "styles": [
                {
                    "style_id": "openskimap",
                    "name": "OpenSkiMap",
                    "pmtiles_path": "openskimap.pmtiles",
                    "groups": [
                        {
                            "source_layer": "ski_lifts",
                            "name": "Lifte",
                            "template": "ski-lifts",
                            "original_file": "data/src/openskidata.gpkg",
                            "style_layers": ["ski-lifts-casing", "ski-lifts-line"],
                            "type": "line",
                            "color": None,
                            "opacity": 0.8,
                            "width": 3.0,
                            "dasharray": None,
                            "outline_color": "hsl(0, 0%, 100%)",
                            "outline_width": 5.0,
                            "icon": None,
                            "legend_items": [{"label": "Operating", "color": "hsl(0, 82%, 42%)"}],
                            "legend_scale_id": None
                        },
                        {
                            "source_layer": "ski_runs_downhill_poly",
                            "name": "Pisten",
                            "template": "ski-runs-downhill",
                            "style_layers": ["ski-runs-downhill-fill"],
                            "type": "fill",
                            "color": None,
                            "opacity": 0.25,
                            "width": None,
                            "dasharray": None,
                            "outline_color": None,
                            "outline_width": 5.0,
                            "icon": None,
                            "legend_items": None,
                            "legend_scale_id": "ski-difficulty-v1"
                        }
                    ]
                }
            ],
            "legend_sections": [
                {
                    "id": "ski-difficulty-v1",
                    "label": "Schwierigkeitsgrade",
                    "items": [
                        {"label": "Novice", "color": "hsl(125, 100%, 33%)"},
                        {"label": "Easy", "color": "hsl(208, 100%, 33%)"}
                    ]
                }
            ]
        })

        layers.main()

        output = json.loads(self.output_file.read_text(encoding="utf-8"))
        groups = {g["source_layer"]: g for g in output["layers"][0]["groups"]}

        lifts = groups["ski_lifts"]
        self.assertEqual(lifts["width"], 3.0)
        self.assertEqual(lifts["outline_color"], "hsl(0, 0%, 100%)")
        self.assertEqual(lifts["outline_width"], 5.0)
        self.assertIsNone(lifts["dasharray"])
        self.assertIsNone(lifts["icon"])
        self.assertIsNone(lifts["legend_scale_id"])

        runs = groups["ski_runs_downhill_poly"]
        self.assertEqual(runs["legend_scale_id"], "ski-difficulty-v1")
        self.assertIsNone(runs["legend_items"])
        self.assertEqual(runs["outline_width"], 5.0)

        self.assertEqual(output["legend_scales"], [
            {
                "id": "ski-difficulty-v1",
                "label": "Schwierigkeitsgrade",
                "items": [
                    {"label": "Novice", "color": "hsl(125, 100%, 33%)"},
                    {"label": "Easy", "color": "hsl(208, 100%, 33%)"}
                ]
            }
        ])

    def test_legend_scales_deduplicated_across_sources_first_wins(self):
        section = {
            "id": "ski-difficulty-v1",
            "label": "Schwierigkeitsgrade",
            "items": [{"label": "Novice", "color": "hsl(125, 100%, 33%)"}]
        }
        conflicting_section = {
            "id": "ski-difficulty-v1",
            "label": "Sollte ignoriert werden",
            "items": [{"label": "Anders", "color": "#000000"}]
        }
        self._write_staged_file("a-geodata-openskimap.json", {
            "version": "1.1",
            "styles": [],
            "legend_sections": [section]
        })
        self._write_staged_file("b-geodata-other.json", {
            "version": "1.1",
            "styles": [],
            "legend_sections": [conflicting_section]
        })

        layers.main()

        output = json.loads(self.output_file.read_text(encoding="utf-8"))
        self.assertEqual(output["legend_scales"], [section])

    def test_legend_scales_dedup_across_mixed_schema_versions(self):
        # Quellen migrieren unabhängig voneinander auf den v3.0-Standard - während der
        # Übergangszeit muss ein Konsument gleichzeitig eine Quelle mit dem alten Feldnamen
        # `legend_sections` (< v3.0) und eine mit dem neuen `legend_scales` (>= v3.0) verlustfrei
        # zusammenführen können.
        old_style_section = {
            "id": "ski-difficulty-v1",
            "label": "Schwierigkeitsgrade",
            "items": [{"label": "Novice", "color": "hsl(125, 100%, 33%)"}]
        }
        new_style_section = {
            "id": "lift-status-v1",
            "label": "Lift-Status",
            "items": [{"label": "Operating", "color": "#22c55e"}]
        }
        self._write_staged_file("a-geodata-overlays.json", {
            "version": "2.1",
            "styles": [],
            "legend_sections": [old_style_section]
        })
        self._write_staged_file("b-geodata-openskimap.json", {
            "version": "3.0",
            "styles": [],
            "legend_scales": [new_style_section]
        })

        layers.main()

        output = json.loads(self.output_file.read_text(encoding="utf-8"))
        self.assertEqual(output["legend_scales"], [old_style_section, new_style_section])

    def test_legend_scales_null_when_no_source_has_any(self):
        self._write_staged_file("geodata-osm.json", {
            "version": "1.0",
            "styles": [{
                "style_id": "roads",
                "name": "Roads",
                "pmtiles_path": "pmtiles/roads.pmtiles",
                "groups": []
            }]
        })

        layers.main()

        output = json.loads(self.output_file.read_text(encoding="utf-8"))
        self.assertIsNone(output["legend_scales"])

    def test_legend_top_level_block_passed_through_and_concatenated(self):
        # v3.0 (§5.4): `legend[]` ist ein eigenständiger, von `groups[]` getrennter Top-Level-
        # Block pro Quelle. Der Aggregator reicht ihn 1:1 durch und hängt die Blöcke mehrerer
        # Quellen aneinander - kein Dedup nach `heading` (keine globale Eindeutigkeit garantiert).
        openskimap_legend = [
            {
                "heading": "Pisten",
                "rows": [
                    {
                        "label": "Präpariert",
                        "style_layer_ids": ["ski-runs-downhill-fill"],
                        "render": [
                            {
                                "kind": "fill",
                                "color": {"mode": "scale", "scale_id": "ski-difficulty-v1"},
                                "stroke_color": None,
                                "opacity": 0.7,
                                "width": None,
                                "dasharray": None,
                                "radius": None,
                                "stroke_width": None,
                                "icon": None
                            }
                        ]
                    }
                ]
            }
        ]
        anfahrtszeit_legend = [
            {
                "heading": "Anfahrtszeit",
                "rows": [
                    {
                        "label": "Anfahrtszeit",
                        "style_layer_ids": ["15_0-fill"],
                        "render": [
                            {
                                "kind": "fill",
                                "color": {"mode": "scale", "scale_id": "anfahrtszeit-linz-15"},
                                "stroke_color": None,
                                "opacity": 0.6,
                                "width": None,
                                "dasharray": None,
                                "radius": None,
                                "stroke_width": None,
                                "icon": None
                            }
                        ]
                    }
                ]
            }
        ]
        self._write_staged_file("a-geodata-openskimap.json", {
            "version": "3.0",
            "styles": [],
            "legend": openskimap_legend
        })
        self._write_staged_file("b-geodata-overlays.json", {
            "version": "3.0",
            "styles": [],
            "legend": anfahrtszeit_legend
        })

        layers.main()

        output = json.loads(self.output_file.read_text(encoding="utf-8"))
        self.assertEqual(output["legend"], openskimap_legend + anfahrtszeit_legend)

    def test_legend_null_when_no_source_has_any(self):
        self._write_staged_file("geodata-osm.json", {
            "version": "1.0",
            "styles": [{
                "style_id": "roads",
                "name": "Roads",
                "pmtiles_path": "pmtiles/roads.pmtiles",
                "groups": []
            }]
        })

        layers.main()

        output = json.loads(self.output_file.read_text(encoding="utf-8"))
        self.assertIsNone(output["legend"])

    def test_group_only_contains_source_fields(self):
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
        layer_entry = output["layers"][0]
        group = layer_entry["groups"][0]

        self.assertEqual(layer_entry["version"], "1.0")
        self.assertEqual(group, {
            "source_layer": "roads",
            "name": "Roads",
            "template": "strassen",
            "style_layers": ["roads-line"]
        })

    def test_group_passes_through_v2_0_render_parts_unmodified(self):
        self._write_staged_file("geodata-overlays.json", {
            "version": "2.0",
            "styles": [
                {
                    "style_id": "loipen",
                    "name": "Loipen",
                    "pmtiles_path": "pmtiles/loipen.pmtiles",
                    "groups": [
                        {
                            "source_layer": "ski_runs",
                            "name": "Loipen",
                            "template": "ski-runs",
                            "original_file": "data/ski_runs.geojson",
                            "style_layers": ["ski-runs-outline", "ski-runs-line"],
                            "render": [
                                {
                                    "kind": "outline",
                                    "color": {"mode": "scale", "scale_id": "ski-difficulty-v1"},
                                    "opacity": 1,
                                    "width": 5.0,
                                    "dasharray": None,
                                    "radius": None,
                                    "icon": None
                                },
                                {
                                    "kind": "line",
                                    "color": {"mode": "fixed", "value": "#ffffff"},
                                    "opacity": 1,
                                    "width": 3.0,
                                    "dasharray": None,
                                    "radius": None,
                                    "icon": None
                                }
                            ]
                        }
                    ]
                }
            ],
            "legend_sections": [
                {
                    "id": "ski-difficulty-v1",
                    "label": "Schwierigkeitsgrade",
                    "items": [{"label": "Novice", "color": "hsl(125, 100%, 33%)"}]
                }
            ]
        })

        layers.main()

        output = json.loads(self.output_file.read_text(encoding="utf-8"))
        group = output["layers"][0]["groups"][0]

        self.assertEqual(group["render"], [
            {
                "kind": "outline",
                "color": {"mode": "scale", "scale_id": "ski-difficulty-v1"},
                "opacity": 1,
                "width": 5.0,
                "dasharray": None,
                "radius": None,
                "icon": None
            },
            {
                "kind": "line",
                "color": {"mode": "fixed", "value": "#ffffff"},
                "opacity": 1,
                "width": 3.0,
                "dasharray": None,
                "radius": None,
                "icon": None
            }
        ])
        self.assertNotIn("legend_items", group)
        self.assertNotIn("type", group)

    def test_version_is_tracked_per_source_not_globally_aggregated(self):
        self._write_staged_file("geodata-overlays.json", {
            "version": "1.1",
            "styles": [{
                "style_id": "anfahrtszeit-linz",
                "name": "Anfahrtszeit Linz",
                "pmtiles_path": "pmtiles/anfahrtszeit-linz.pmtiles",
                "groups": []
            }]
        })
        self._write_staged_file("geodata-osm.json", {
            "version": "1.0",
            "styles": [{
                "style_id": "roads",
                "name": "Roads",
                "pmtiles_path": "pmtiles/roads.pmtiles",
                "groups": []
            }]
        })

        layers.main()

        output = json.loads(self.output_file.read_text(encoding="utf-8"))
        versions_by_id = {entry["id"]: entry["version"] for entry in output["layers"]}

        self.assertEqual(versions_by_id["anfahrtszeit-linz"], "1.1")
        self.assertEqual(versions_by_id["roads"], "1.0")

    def test_source_without_version_defaults_to_null(self):
        self._write_staged_file("geodata-legacy.json", {
            "styles": [{
                "style_id": "legacy",
                "name": "Legacy",
                "pmtiles_path": "pmtiles/legacy.pmtiles",
                "groups": []
            }]
        })

        layers.main()

        output = json.loads(self.output_file.read_text(encoding="utf-8"))
        self.assertIsNone(output["layers"][0]["version"])


if __name__ == "__main__":
    unittest.main()
