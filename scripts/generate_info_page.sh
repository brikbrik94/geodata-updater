#!/usr/bin/env bash
set -euo pipefail

INFO_DIR="${INFO_DIR:-/srv/info}"
INFO_PAGE_OUTPUT="${INFO_PAGE_OUTPUT:-$INFO_DIR/info.html}"
ENDPOINTS_INFO_PATH="${ENDPOINTS_INFO_PATH:-$INFO_DIR/endpoints_info.json}"
FONTS_INFO_PATH="${FONTS_INFO_PATH:-$INFO_DIR/font_inventory.json}"
BUILD_DIR="${BUILD_DIR:-/srv/build}"
ASSETS_DIR="${ASSETS_DIR:-/srv/assets}"

python3 - <<'PY'
import html
import json
import os
from datetime import datetime, timezone
from pathlib import Path

info_dir = Path(os.environ.get("INFO_DIR", "/srv/info"))
output_path = Path(os.environ.get("INFO_PAGE_OUTPUT", str(info_dir / "info.html")))
endpoints_path = Path(
    os.environ.get("ENDPOINTS_INFO_PATH", str(info_dir / "endpoints_info.json"))
)
fonts_path = Path(
    os.environ.get("FONTS_INFO_PATH", str(info_dir / "font_inventory.json"))
)
build_dir = Path(os.environ.get("BUILD_DIR", "/srv/build"))
assets_dir = Path(os.environ.get("ASSETS_DIR", "/srv/assets"))


def load_json(path: Path):
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError:
        return None
    except json.JSONDecodeError:
        return None


def escape(value):
    return html.escape(str(value))


endpoints = load_json(endpoints_path) or {}
fonts = load_json(fonts_path)

if fonts is None:
    fonts = {}
    fonts_root = assets_dir / "fonts"
    if fonts_root.exists():
        for font_dir in sorted(p for p in fonts_root.iterdir() if p.is_dir()):
            ranges = sorted(p.name for p in font_dir.glob("*.pbf"))
            fonts[font_dir.name] = ranges

tileset_infos = []
if build_dir.exists():
    for tileset_dir in sorted(p for p in build_dir.iterdir() if p.is_dir()):
        tmp_dir = tileset_dir / "tmp"
        if not tmp_dir.exists():
            continue
        for info_file in sorted(tmp_dir.glob("*.json")):
            data = load_json(info_file)
            if data is None:
                continue
            tileset_infos.append(
                {
                    "tileset": tileset_dir.name,
                    "path": info_file,
                    "data": data,
                }
            )


def render_endpoints(entries):
    if not entries:
        return "<p>Keine Endpunkte gefunden.</p>"
    rows = []
    for entry in entries:
        rel_path = escape(entry.get("relative_path", ""))
        url = entry.get("url")
        url_html = (
            f"<a href=\"{escape(url)}\">{escape(url)}</a>" if url else ""
        )
        rows.append(f"<tr><td>{rel_path}</td><td>{url_html}</td></tr>")
    return (
        "<table><thead><tr><th>Pfad</th><th>URL</th></tr></thead>"
        f"<tbody>{''.join(rows)}</tbody></table>"
    )


def render_fonts(font_map):
    if not font_map:
        return "<p>Keine Fonts gefunden.</p>"
    rows = []
    for font_name in sorted(font_map.keys()):
        ranges = font_map.get(font_name) or []
        range_list = ", ".join(escape(r) for r in ranges)
        rows.append(
            "<tr>"
            f"<td>{escape(font_name)}</td>"
            f"<td>{len(ranges)}</td>"
            f"<td>{range_list}</td>"
            "</tr>"
        )
    return (
        "<table><thead><tr><th>Font</th><th>Ranges</th><th>Dateien</th></tr></thead>"
        f"<tbody>{''.join(rows)}</tbody></table>"
    )


def render_tileset_infos(infos):
    if not infos:
        return "<p>Keine Tileset-Infos gefunden.</p>"
    blocks = []
    for info in infos:
        header = (
            f"<h3>{escape(info['tileset'])}</h3>"
            f"<p><code>{escape(info['path'])}</code></p>"
        )
        data_rows = []
        data = info.get("data") or {}
        for key, value in sorted(data.items()):
            data_rows.append(
                f"<tr><td>{escape(key)}</td><td>{escape(value)}</td></tr>"
            )
        table = (
            "<table><thead><tr><th>Feld</th><th>Wert</th></tr></thead>"
            f"<tbody>{''.join(data_rows)}</tbody></table>"
        )
        blocks.append(header + table)
    return "".join(blocks)


output_path.parent.mkdir(parents=True, exist_ok=True)

html_content = f"""<!DOCTYPE html>
<html lang=\"de\">
<head>
  <meta charset=\"utf-8\" />
  <meta name=\"viewport\" content=\"width=device-width, initial-scale=1\" />
  <title>Tileserver Info</title>
  <style>
    body {{ font-family: Arial, sans-serif; margin: 2rem; color: #1a1a1a; }}
    h1, h2, h3 {{ margin-top: 1.5rem; }}
    table {{ border-collapse: collapse; width: 100%; margin: 0.5rem 0 1.5rem; }}
    th, td {{ border: 1px solid #ddd; padding: 0.5rem; vertical-align: top; }}
    th {{ background: #f5f5f5; text-align: left; }}
    code {{ background: #f0f0f0; padding: 0.1rem 0.3rem; }}
    .meta {{ color: #555; font-size: 0.9rem; }}
  </style>
</head>
<body>
  <h1>Tileserver Info</h1>
  <p class=\"meta\">Generiert am {escape(datetime.now(timezone.utc).isoformat())}</p>

  <h2>Endpunkte</h2>
  <p><strong>Tiles Base URL:</strong> {escape(endpoints.get("tiles_base_url") or "-")}</p>
  <p><strong>Assets Base URL:</strong> {escape(endpoints.get("assets_base_url") or "-")}</p>

  <h3>Tiles</h3>
  {render_endpoints(endpoints.get("tiles") or [])}

  <h3>Assets</h3>
  {render_endpoints(endpoints.get("assets") or [])}

  <h2>Fonts & Ranges</h2>
  {render_fonts(fonts)}

  <h2>Tileset-Infos (Build TMP)</h2>
  {render_tileset_infos(tileset_infos)}
</body>
</html>
"""

output_path.write_text(html_content, encoding="utf-8")
print(f"✅ Info-Seite geschrieben: {output_path}")
PY
