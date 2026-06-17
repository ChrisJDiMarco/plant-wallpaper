#!/usr/bin/env python3
from __future__ import annotations

import argparse
from dataclasses import dataclass
import struct
import sys
import zlib
from collections.abc import Iterable
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_SOURCE_DIRECTORY = ROOT / "Generated" / "AIStageSources"
STAGE_COUNT = 10
ASSET_NAMES = (
    "cherry-tree",
    "maple-tree",
    "pine-tree",
    "fern",
    "moss-carpet",
    "clover-patch",
    "creeping-thyme",
    "ivy",
    "lavender",
    "wisteria",
    "jasmine",
    "orchid",
    "tulip",
    "sunflower",
    "bonsai",
    "japanese-maple",
    "willow",
    "birch",
    "dogwood",
    "magnolia",
    "olive-tree",
    "dwarf-citrus",
    "monstera",
    "hydrangea",
    "peony",
    "rose",
    "foxglove",
    "poppy",
    "iris",
    "lily",
    "wildflower-meadow",
    "lavender-field",
    "herb-cluster",
    "bamboo",
    "ornamental-grass",
    "cattails",
    "mushrooms",
    "lichens",
    "succulent",
    "pitcher-plant",
    "water-lily",
    "determinate-tomato",
    "sweet-pepper",
    "pea-vines",
    "string-beans",
    "cucumber-vine",
    "rosemary",
    "thyme",
    "oregano",
    "sage",
)

MIN_ASSET_WIDTH = 32
MIN_ASSET_HEIGHT = 48
MIN_VISIBLE_PIXEL_RATIO = 0.05
MAX_BOTTOM_GAP_RATIO = 0.22


@dataclass(frozen=True)
class PNGProfile:
    width: int
    height: int
    bit_depth: int
    color_type: int
    interlace_method: int
    alpha_bbox: tuple[int, int, int, int] | None
    visible_pixel_count: int

    @property
    def visible_pixel_ratio(self) -> float:
        return self.visible_pixel_count / max(1, self.width * self.height)

    @property
    def bottom_gap_ratio(self) -> float:
        if self.alpha_bbox is None:
            return 1.0
        return (self.height - self.alpha_bbox[3]) / max(1, self.height)

    @property
    def bbox_height_ratio(self) -> float:
        if self.alpha_bbox is None:
            return 0.0
        return (self.alpha_bbox[3] - self.alpha_bbox[1]) / max(1, self.height)


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Verify staged PNG growth assets against source-backed AI stage images."
    )
    parser.add_argument(
        "asset_directory",
        type=Path,
        help="Directory or SwiftPM resource bundle containing staged plant PNGs.",
    )
    parser.add_argument(
        "--source-directory",
        type=Path,
        default=DEFAULT_SOURCE_DIRECTORY,
        help="Directory containing AI source files named <slug>-stage-XX-source.png.",
    )
    parser.add_argument(
        "--require-complete-catalog",
        action="store_true",
        help="Require all active species to have all 10 staged assets.",
    )
    args = parser.parse_args()

    if args.require_complete_catalog:
        expected_names = complete_catalog_stage_asset_names()
        expectation = "complete catalog"
    else:
        expected_names = source_backed_stage_asset_names(args.source_directory)
        expectation = "source-backed AI"

    if not expected_names:
        print(
            f"asset verification failed: no expected {expectation} staged assets found",
            file=sys.stderr,
        )
        return 1

    errors = verify_stage_assets(args.asset_directory, expected_names=expected_names)
    if errors:
        for error in errors:
            print(f"asset verification failed: {error}", file=sys.stderr)
        return 1

    print(
        f"Verified {len(expected_names)} {expectation} staged plant assets "
        f"in {args.asset_directory}"
    )
    return 0


def verify_stage_assets(
    asset_directory: Path,
    expected_names: Iterable[str] | None = None,
) -> list[str]:
    if not asset_directory.exists():
        return [f"{asset_directory} does not exist"]

    expected_name_set = (
        set(expected_names)
        if expected_names is not None
        else set(source_backed_stage_asset_names(DEFAULT_SOURCE_DIRECTORY))
    )

    available = {
        path.name: path
        for path in asset_directory.rglob("*.png")
        if path.is_file()
    }
    errors: list[str] = []

    for file_name in sorted(expected_name_set):
        path = available.get(file_name)
        if path is None:
            errors.append(f"missing {file_name}")
            continue

        errors.extend(verify_stage_png(path, file_name))

    staged_names = [
        name for name in available
        if "-stage-" in name and name.endswith(".png")
    ]
    unexpected = sorted(set(staged_names) - expected_name_set)
    if unexpected:
        errors.append("unexpected staged assets: " + ", ".join(unexpected))

    return errors


def complete_catalog_stage_asset_names() -> set[str]:
    return {
        f"{asset_name}-stage-{stage_index:02d}.png"
        for asset_name in ASSET_NAMES
        for stage_index in range(STAGE_COUNT)
    }


def source_backed_stage_asset_names(source_directory: Path) -> set[str]:
    names: set[str] = set()
    if not source_directory.exists():
        return names

    for source_path in source_directory.glob("*-stage-??-source.*"):
        stem = source_path.stem
        if not stem.endswith("-source"):
            continue
        names.add(stem.removesuffix("-source") + ".png")

    return names


def verify_stage_png(path: Path, file_name: str) -> list[str]:
    errors: list[str] = []
    profile = png_profile(path)
    if profile is None:
        return [f"{file_name} is not a readable PNG"]

    if profile.width <= 0 or profile.height <= 0:
        errors.append(f"{file_name} has invalid dimensions {profile.width}x{profile.height}")
    if profile.width < MIN_ASSET_WIDTH or profile.height < MIN_ASSET_HEIGHT:
        errors.append(
            f"{file_name} is too small for a staged plant asset "
            f"({profile.width}x{profile.height})"
        )
    if profile.bit_depth != 8 or profile.color_type != 6 or profile.interlace_method != 0:
        errors.append(
            f"{file_name} must be an 8-bit non-interlaced RGBA PNG "
            f"(bit depth {profile.bit_depth}, color type {profile.color_type}, "
            f"interlace {profile.interlace_method})"
        )
    if profile.alpha_bbox is None or profile.visible_pixel_count == 0:
        errors.append(f"{file_name} has no visible plant pixels")
    elif profile.visible_pixel_ratio < MIN_VISIBLE_PIXEL_RATIO:
        errors.append(
            f"{file_name} has too little visible plant area "
            f"({profile.visible_pixel_ratio:.1%})"
        )
    elif profile.bottom_gap_ratio > MAX_BOTTOM_GAP_RATIO:
        errors.append(
            f"{file_name} does not reach the planting anchor "
            f"(bottom gap {profile.bottom_gap_ratio:.1%})"
        )
    if path.stat().st_size < 256:
        errors.append(f"{file_name} is suspiciously small")

    return errors


def png_dimensions(path: Path) -> tuple[int, int] | None:
    profile = png_profile(path)
    if profile is None:
        return None
    return profile.width, profile.height


def png_profile(path: Path) -> PNGProfile | None:
    try:
        chunks = read_png_chunks(path)
    except (OSError, ValueError, zlib.error):
        return None

    ihdr = chunks.get(b"IHDR", [None])[0]
    if ihdr is None or len(ihdr) != 13:
        return None

    width, height, bit_depth, color_type, compression, filter_method, interlace_method = struct.unpack(
        ">IIBBBBB",
        ihdr,
    )
    if width <= 0 or height <= 0:
        return PNGProfile(
            width=width,
            height=height,
            bit_depth=bit_depth,
            color_type=color_type,
            interlace_method=interlace_method,
            alpha_bbox=None,
            visible_pixel_count=0,
        )

    alpha_bbox: tuple[int, int, int, int] | None = None
    visible_pixel_count = 0

    if bit_depth == 8 and color_type == 6 and compression == 0 and filter_method == 0 and interlace_method == 0:
        idat = b"".join(chunks.get(b"IDAT", []))
        alpha_bbox, visible_pixel_count = rgba_alpha_profile(
            zlib.decompress(idat),
            width=width,
            height=height,
        )

    return PNGProfile(
        width=width,
        height=height,
        bit_depth=bit_depth,
        color_type=color_type,
        interlace_method=interlace_method,
        alpha_bbox=alpha_bbox,
        visible_pixel_count=visible_pixel_count,
    )


def read_png_chunks(path: Path) -> dict[bytes, list[bytes]]:
    chunks: dict[bytes, list[bytes]] = {}
    try:
        with path.open("rb") as file:
            signature = file.read(8)
            if signature != b"\x89PNG\r\n\x1a\n":
                raise ValueError("not a PNG")

            while True:
                chunk_length_data = file.read(4)
                if len(chunk_length_data) == 0:
                    break
                if len(chunk_length_data) != 4:
                    raise ValueError("truncated PNG chunk length")

                chunk_length = struct.unpack(">I", chunk_length_data)[0]
                chunk_type = file.read(4)
                chunk_data = file.read(chunk_length)
                crc = file.read(4)
                if len(chunk_type) != 4 or len(chunk_data) != chunk_length or len(crc) != 4:
                    raise ValueError("truncated PNG chunk")

                chunks.setdefault(chunk_type, []).append(chunk_data)
                if chunk_type == b"IEND":
                    break
    except OSError:
        raise

    return chunks


def rgba_alpha_profile(
    raw: bytes,
    width: int,
    height: int,
    alpha_threshold: int = 8,
) -> tuple[tuple[int, int, int, int] | None, int]:
    bytes_per_pixel = 4
    stride = width * bytes_per_pixel
    expected_minimum = height * (stride + 1)
    if len(raw) < expected_minimum:
        raise ValueError("truncated decompressed image data")

    previous = bytearray(stride)
    visible_count = 0
    min_x = width
    min_y = height
    max_x = -1
    max_y = -1
    cursor = 0

    for y in range(height):
        filter_type = raw[cursor]
        cursor += 1
        scanline = bytearray(raw[cursor:cursor + stride])
        cursor += stride
        unfilter_scanline(scanline, previous, filter_type, bytes_per_pixel)

        for x in range(width):
            alpha = scanline[x * bytes_per_pixel + 3]
            if alpha <= alpha_threshold:
                continue

            visible_count += 1
            min_x = min(min_x, x)
            min_y = min(min_y, y)
            max_x = max(max_x, x + 1)
            max_y = max(max_y, y + 1)

        previous = scanline

    if visible_count == 0:
        return None, 0

    return (min_x, min_y, max_x, max_y), visible_count


def unfilter_scanline(
    scanline: bytearray,
    previous: bytearray,
    filter_type: int,
    bytes_per_pixel: int,
) -> None:
    if filter_type == 0:
        return
    if filter_type == 1:
        for index in range(len(scanline)):
            left = scanline[index - bytes_per_pixel] if index >= bytes_per_pixel else 0
            scanline[index] = (scanline[index] + left) & 0xFF
        return
    if filter_type == 2:
        for index in range(len(scanline)):
            scanline[index] = (scanline[index] + previous[index]) & 0xFF
        return
    if filter_type == 3:
        for index in range(len(scanline)):
            left = scanline[index - bytes_per_pixel] if index >= bytes_per_pixel else 0
            up = previous[index]
            scanline[index] = (scanline[index] + ((left + up) // 2)) & 0xFF
        return
    if filter_type == 4:
        for index in range(len(scanline)):
            left = scanline[index - bytes_per_pixel] if index >= bytes_per_pixel else 0
            up = previous[index]
            up_left = previous[index - bytes_per_pixel] if index >= bytes_per_pixel else 0
            scanline[index] = (scanline[index] + paeth_predictor(left, up, up_left)) & 0xFF
        return

    raise ValueError(f"unsupported PNG filter type {filter_type}")


def paeth_predictor(left: int, up: int, up_left: int) -> int:
    estimate = left + up - up_left
    distance_left = abs(estimate - left)
    distance_up = abs(estimate - up)
    distance_up_left = abs(estimate - up_left)
    if distance_left <= distance_up and distance_left <= distance_up_left:
        return left
    if distance_up <= distance_up_left:
        return up
    return up_left


if __name__ == "__main__":
    raise SystemExit(main())
