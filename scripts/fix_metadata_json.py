#!/usr/bin/env python3
import argparse
import json
import re
from pathlib import Path


def fix_json(value: str) -> str:
    value = re.sub(r"\\(?![\"\\/bfnrtu])", r"\\\\", value)
    out = []
    in_str = False
    esc = False
    for char in value:
        if not in_str:
            if char == '"':
                in_str = True
            out.append(char)
            continue
        if esc:
            out.append(char)
            esc = False
            continue
        if char == "\\":
            out.append(char)
            esc = True
            continue
        if char == '"':
            out.append(char)
            in_str = False
            continue
        if char == "\n":
            out.append("\\n")
        elif char == "\r":
            out.append("\\r")
        elif char == "\t":
            out.append("\\t")
        else:
            out.append(char)
    return "".join(out)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True)
    parser.add_argument("--output", required=True)
    args = parser.parse_args()

    src = Path(args.input)
    dst = Path(args.output)

    try:
        raw = src.read_text(encoding="utf-8", errors="replace")
        obj = json.loads(fix_json(raw))
        dst.write_text(json.dumps(obj, ensure_ascii=False, indent=2), encoding="utf-8")
        print("✅ metadata.json repariert")
    except Exception as exc:
        dst.write_text(
            json.dumps({"warning": "parse failed", "error": str(exc)}, indent=2),
            encoding="utf-8",
        )
        print("⚠️ metadata.json nicht vollständig reparierbar")


if __name__ == "__main__":
    main()
