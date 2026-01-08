#!/usr/bin/env python3
import argparse
import importlib
import re
import struct
from pathlib import Path

_re_level = re.compile(r"/L([0-9A-Fa-f]{2})/")
_re_bundle = re.compile(r"R([0-9A-Fa-f]{4})C([0-9A-Fa-f]{4})\.bundle$")


def iter_bundles(root: Path):
    for path in root.rglob("*.bundle"):
        yield path


def parse_level(path: Path) -> int:
    match = _re_level.search(path.as_posix())
    if match:
        return int(match.group(1), 16)
    for part in path.parts:
        if part.startswith("L") and len(part) == 3:
            return int(part[1:], 16)
    raise ValueError(path)


def parse_rc(path: Path):
    match = _re_bundle.match(path.name)
    if not match:
        raise ValueError(path.name)
    return int(match.group(1), 16), int(match.group(2), 16)


def u32(buffer: bytes, offset: int) -> int:
    return struct.unpack_from("<I", buffer, offset)[0]


def iter_tiles(bundle: Path):
    with bundle.open("rb") as handle:
        header = handle.read(64)
        idx = handle.read(8 * 16384)
        if len(header) < 64 or len(idx) < 8 * 16384:
            return

        payload_start = 64 + 8 * 16384

        sane = 0
        for i in range(0, min(1600, len(idx)), 8):
            off = u32(idx, i)
            sz = u32(idx, i + 4)
            if off and sz:
                sane += 1
        mode_a = sane >= 20

        for tile_index in range(16384):
            i = tile_index * 8
            if mode_a:
                off = u32(idx, i)
                sz = u32(idx, i + 4)
            else:
                off = int.from_bytes(idx[i:i + 5], "little")
                sz = int.from_bytes(idx[i + 5:i + 8], "little")

            if off and sz:
                handle.seek(payload_start + off)
                blob = handle.read(sz)
                if len(blob) == sz:
                    yield tile_index, blob


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--tiles", required=True, help="Path to p12/tile directory")
    parser.add_argument("--output", required=True, help="Output PMTiles path")
    args = parser.parse_args()

    pmtiles = importlib.import_module("pmtiles")
    writer_module = importlib.import_module("pmtiles.writer")

    if hasattr(writer_module, "Writer"):
        Writer = writer_module.Writer
    elif hasattr(writer_module, "PMTilesWriter"):
        Writer = writer_module.PMTilesWriter
    else:
        raise RuntimeError("PMTiles writer API not found in pmtiles package")

    out_path = Path(args.output)
    if out_path.exists():
        out_path.unlink()

    with out_path.open("wb") as handle:
        writer = Writer(handle)
        tiles_written = 0
        bundles = 0

        for bundle in iter_bundles(Path(args.tiles)):
            z = parse_level(bundle)
            r0, c0 = parse_rc(bundle)
            wrote = False

            for tile_index, blob in iter_tiles(bundle):
                row = tile_index // 128
                col = tile_index % 128

                y_tms = r0 + row
                x = c0 + col
                y_xyz = (1 << z) - 1 - y_tms

                if hasattr(writer, "write_tile"):
                    writer.write_tile(z, x, y_xyz, blob)
                elif hasattr(writer, "write"):
                    writer.write(z, x, y_xyz, blob)
                else:
                    raise RuntimeError("PMTiles writer method not found")

                tiles_written += 1
                wrote = True

            if wrote:
                bundles += 1
                if bundles % 20 == 0:
                    print(f"  … {bundles} bundles, {tiles_written} tiles")

        if hasattr(writer, "finalize"):
            writer.finalize()
        elif hasattr(writer, "close"):
            writer.close()

    print(f"✅ PMTiles fertig ({bundles} bundles, {tiles_written} tiles)")


if __name__ == "__main__":
    main()
