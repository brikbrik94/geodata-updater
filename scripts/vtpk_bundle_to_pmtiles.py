#!/usr/bin/env python3
import argparse
import importlib
import inspect
import math
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


def tile_bounds(z: int, x: int, y: int):
    n = 1 << z
    lon_left = x / n * 360.0 - 180.0
    lon_right = (x + 1) / n * 360.0 - 180.0
    lat_top = math.degrees(math.atan(math.sinh(math.pi * (1 - 2 * y / n))))
    lat_bottom = math.degrees(math.atan(math.sinh(math.pi * (1 - 2 * (y + 1) / n))))
    return lon_left, lat_bottom, lon_right, lat_top


def set_header_value(header, key, value) -> None:
    if header is None or value is None:
        return
    if isinstance(header, dict):
        header[key] = value
    else:
        if hasattr(header, key):
            setattr(header, key, value)


def build_header(writer_module, stats):
    header_cls = getattr(writer_module, "Header", None)
    try:
        header = header_cls() if header_cls else {}
    except TypeError:
        header = {}

    tile_type = None
    tile_type_enum = getattr(writer_module, "TileType", None)
    if tile_type_enum is not None and hasattr(tile_type_enum, "MVT"):
        tile_type = tile_type_enum.MVT
    compression = None
    compression_enum = getattr(writer_module, "Compression", None)
    if compression_enum is not None and stats["compression"] is not None:
        compression_name = stats["compression"].upper()
        if hasattr(compression_enum, compression_name):
            compression = getattr(compression_enum, compression_name)

    set_header_value(header, "tile_type", tile_type)
    set_header_value(header, "tile_compression", compression)
    set_header_value(header, "min_zoom", stats["min_zoom"])
    set_header_value(header, "max_zoom", stats["max_zoom"])
    set_header_value(header, "min_lon", stats["min_lon"])
    set_header_value(header, "min_lat", stats["min_lat"])
    set_header_value(header, "max_lon", stats["max_lon"])
    set_header_value(header, "max_lat", stats["max_lat"])

    if stats["min_lon"] is not None and stats["min_lat"] is not None:
        center_lon = (stats["min_lon"] + stats["max_lon"]) / 2
        center_lat = (stats["min_lat"] + stats["max_lat"]) / 2
    else:
        center_lon = None
        center_lat = None

    set_header_value(header, "center_lon", center_lon)
    set_header_value(header, "center_lat", center_lat)
    set_header_value(header, "center_zoom", stats["max_zoom"])

    return header


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--tiles", required=True, help="Path to p12/tile directory")
    parser.add_argument("--output", required=True, help="Output PMTiles path")
    args = parser.parse_args()

    pmtiles = importlib.import_module("pmtiles")
    writer_module = importlib.import_module("pmtiles.writer")
    tile_module = importlib.import_module("pmtiles.tile")
    zxy_to_tileid = getattr(tile_module, "zxy_to_tileid", None)

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
        stats = {
            "min_zoom": None,
            "max_zoom": None,
            "min_lon": None,
            "min_lat": None,
            "max_lon": None,
            "max_lat": None,
            "compression": None,
        }

        def write_tile(z, x, y, data):
            def call_with_sig(method):
                try:
                    sig = inspect.signature(method)
                    params = [p.name for p in sig.parameters.values() if p.name != "self"]
                except (TypeError, ValueError):
                    params = []
                if len(params) == 2 and params[0] in {"tile_id", "tileid", "id"} and zxy_to_tileid:
                    method(zxy_to_tileid(z, x, y), data)
                elif len(params) >= 4:
                    method(z, x, y, data)
                else:
                    method((z, x, y), data)

            if hasattr(writer, "write_tile"):
                call_with_sig(writer.write_tile)
                return
            if hasattr(writer, "write"):
                call_with_sig(writer.write)
                return
            raise RuntimeError("PMTiles writer method not found")

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

                write_tile(z, x, y_xyz, blob)
                if stats["compression"] is None and blob:
                    stats["compression"] = "gzip" if blob[:2] == b"\x1f\x8b" else "none"
                stats["min_zoom"] = z if stats["min_zoom"] is None else min(stats["min_zoom"], z)
                stats["max_zoom"] = z if stats["max_zoom"] is None else max(stats["max_zoom"], z)
                min_lon, min_lat, max_lon, max_lat = tile_bounds(z, x, y_xyz)
                stats["min_lon"] = min_lon if stats["min_lon"] is None else min(stats["min_lon"], min_lon)
                stats["min_lat"] = min_lat if stats["min_lat"] is None else min(stats["min_lat"], min_lat)
                stats["max_lon"] = max_lon if stats["max_lon"] is None else max(stats["max_lon"], max_lon)
                stats["max_lat"] = max_lat if stats["max_lat"] is None else max(stats["max_lat"], max_lat)

                tiles_written += 1
                wrote = True

            if wrote:
                bundles += 1
                if bundles % 20 == 0:
                    print(f"  … {bundles} bundles, {tiles_written} tiles")

        if hasattr(writer, "finalize"):
            try:
                sig = inspect.signature(writer.finalize)
                params = len(sig.parameters)
                if params and next(iter(sig.parameters.values())).name == "self":
                    params -= 1
            except (TypeError, ValueError):
                params = 0
            if params >= 2:
                header = build_header(writer_module, stats)
                writer.finalize(header, {})
            elif params == 1:
                header = build_header(writer_module, stats)
                writer.finalize(header)
            else:
                writer.finalize()
        elif hasattr(writer, "close"):
            writer.close()

    print(f"✅ PMTiles fertig ({bundles} bundles, {tiles_written} tiles)")


if __name__ == "__main__":
    main()
