#!/usr/bin/env bash
set -euo pipefail

TILES_DIR="${TILES_DIR:-/srv/tiles}"
ASSETS_DIR="${ASSETS_DIR:-/srv/assets}"
INFO_DIR="${INFO_DIR:-/srv/info}"
INFO_OUTPUT="${INFO_OUTPUT:-$INFO_DIR/endpoints_info.json}"
TILES_BASE_URL="${TILES_BASE_URL:-https://tiles.oe5ith.at}"
ASSETS_BASE_URL="${ASSETS_BASE_URL:-https://tiles.oe5ith.at/assets}"

python3 - <<'PY'
import json
import os
from datetime import datetime, timezone
from pathlib import Path

_tiles_dir = Path(os.environ.get("TILES_DIR", "/srv/tiles"))
_assets_dir = Path(os.environ.get("ASSETS_DIR", "/srv/assets"))
_info_output = Path(os.environ.get("INFO_OUTPUT", "/srv/info/endpoints_info.json"))
_tiles_base_url = os.environ.get("TILES_BASE_URL", "https://tiles.oe5ith.at").rstrip("/")
_assets_base_url = os.environ.get(
    "ASSETS_BASE_URL", "https://tiles.oe5ith.at/assets"
).rstrip("/")


def collect_files(
    root: Path,
    base_url: str,
    summarize_fonts: bool = False,
    drop_tileset_prefix: bool = False,
):
    entries = []
    seen_font_dirs = set()
    if root.exists():
        for path in sorted(p for p in root.rglob("*") if p.is_file()):
            rel_path = path.relative_to(root)
            if drop_tileset_prefix and len(rel_path.parts) > 1:
                if rel_path.parts[1] in ("pmtiles", "styles"):
                    rel_path = Path(*rel_path.parts[1:])
            if summarize_fonts and rel_path.parts[:1] == ("fonts",):
                if len(rel_path.parts) < 2:
                    continue
                font_dir = Path("fonts") / rel_path.parts[1]
                if font_dir in seen_font_dirs:
                    continue
                seen_font_dirs.add(font_dir)
                url = f"{base_url}/{font_dir.as_posix()}" if base_url else None
                entries.append(
                    {
                        "path": str(root / font_dir),
                        "relative_path": font_dir.as_posix(),
                        "url": url,
                    }
                )
                continue
            url = f"{base_url}/{rel_path.as_posix()}" if base_url else None
            entries.append(
                {
                    "path": str(path),
                    "relative_path": rel_path.as_posix(),
                    "url": url,
                }
            )
    return entries

info = {
    "generated_at": datetime.now(timezone.utc).isoformat(),
    "tiles_base_url": _tiles_base_url or None,
    "assets_base_url": _assets_base_url or None,
    "tiles": collect_files(
        _tiles_dir, _tiles_base_url, drop_tileset_prefix=True
    ),
    "assets": collect_files(_assets_dir, _assets_base_url, summarize_fonts=True),
}

_info_output.parent.mkdir(parents=True, exist_ok=True)
_info_output.write_text(json.dumps(info, indent=2, ensure_ascii=False) + "\n")
print(f"✅ Endpunkt-Info geschrieben: {_info_output}")
PY
