#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

"$SCRIPT_DIR/deploy_pmtiles.sh"
"$SCRIPT_DIR/deploy_stylesheets.sh"

TILES_DIR="${TILES_DIR:-/srv/tiles}"
TILES_BASE_URL="${TILES_BASE_URL:-}"
INFO_OUTPUT="${INFO_OUTPUT:-$TILES_DIR/deploy_info.json}"

python3 - <<'PY'
import json
import os
from datetime import datetime, timezone
from pathlib import Path

_tiles_dir = Path(os.environ.get("TILES_DIR", "/srv/tiles"))
_base_url = os.environ.get("TILES_BASE_URL", "").rstrip("/")
_output = Path(os.environ.get("INFO_OUTPUT", str(_tiles_dir / "deploy_info.json")))

_tilesets = {}

for pmtiles_path in _tiles_dir.glob("*/pmtiles/*.pmtiles"):
    tileset = pmtiles_path.parent.parent.name
    tileset_entry = _tilesets.setdefault(tileset, {"pmtiles": [], "styles": []})
    file_name = pmtiles_path.name
    url = f"{_base_url}/{tileset}/pmtiles/{file_name}" if _base_url else None
    tileset_entry["pmtiles"].append(
        {
            "file": file_name,
            "path": str(pmtiles_path),
            "url": url,
        }
    )

for style_path in _tiles_dir.glob("*/styles/*/style.json"):
    tileset = style_path.parents[2].name
    style_id = style_path.parent.name
    tileset_entry = _tilesets.setdefault(tileset, {"pmtiles": [], "styles": []})
    url = f"{_base_url}/{tileset}/styles/{style_id}/style.json" if _base_url else None
    tileset_entry["styles"].append(
        {
            "id": style_id,
            "path": str(style_path),
            "url": url,
        }
    )

info = {
    "generated_at": datetime.now(timezone.utc).isoformat(),
    "tiles_base_url": _base_url or None,
    "tilesets": [
        {
            "id": tileset,
            "pmtiles": sorted(entry["pmtiles"], key=lambda item: item["file"]),
            "styles": sorted(entry["styles"], key=lambda item: item["id"]),
        }
        for tileset, entry in sorted(_tilesets.items())
    ],
}

_output.parent.mkdir(parents=True, exist_ok=True)
_output.write_text(json.dumps(info, indent=2, ensure_ascii=False) + "\n")
print(f"✅ Deployment-Info geschrieben: {_output}")
PY
