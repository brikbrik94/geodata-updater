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
        layer_entry = output["layers"][0]
        group = layer_entry["groups"][0]

        self.assertEqual(layer_entry["version"], "1.0")
        self.assertIsNone(group["type"])
        self.assertIsNone(group["color"])
        self.assertIsNone(group["opacity"])
        self.assertIsNone(group["legend_items"])
        self.assertNotIn("original_file", group)

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
