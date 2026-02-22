#!/usr/bin/env python3
import datetime
import json
import os
from pathlib import Path

SPRITES_DIR = Path(os.environ.get("SPRITES_DIR", "/srv/assets/sprites"))
OUTPUT_FILE = Path(
    os.environ.get(
        "SPRITE_INVENTORY_PATH",
        str(Path(os.environ.get("INFO_DIR", "/srv/info")) / os.environ.get("SPRITE_INVENTORY_FILE", "sprite_inventory.json")),
    )
)


def main() -> int:
    sprites = []

    if SPRITES_DIR.exists():
        for path in SPRITES_DIR.rglob("*"):
            if path.is_file() and path.suffix.lower() in {".json", ".png"}:
                sprites.append(path.relative_to(SPRITES_DIR).as_posix())

    sprites.sort()
    OUTPUT_FILE.parent.mkdir(parents=True, exist_ok=True)

    payload = {
        "generated_at": datetime.datetime.now().isoformat(),
        "sprites": sprites,
    }

    OUTPUT_FILE.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
    print(f"✅ Sprite-Inventory erstellt: {OUTPUT_FILE} ({len(sprites)} Dateien)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
