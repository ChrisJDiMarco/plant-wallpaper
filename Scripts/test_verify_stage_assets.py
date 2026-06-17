#!/usr/bin/env python3
from __future__ import annotations

import tempfile
import unittest
import zlib
from pathlib import Path

from verify_stage_assets import (
    png_profile,
    source_backed_stage_asset_names,
    verify_stage_assets,
)


class VerifyStageAssetsTests(unittest.TestCase):
    def test_png_profile_reports_visible_alpha_bounds(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "plant.png"
            write_rgba_png(
                path,
                width=12,
                height=16,
                visible_rect=(3, 2, 9, 15),
            )

            profile = png_profile(path)

            self.assertIsNotNone(profile)
            assert profile is not None
            self.assertEqual(profile.width, 12)
            self.assertEqual(profile.height, 16)
            self.assertEqual(profile.alpha_bbox, (3, 2, 9, 15))
            self.assertGreater(profile.visible_pixel_ratio, 0.35)
            self.assertLess(profile.bottom_gap_ratio, 0.08)

    def test_verifier_rejects_empty_transparent_assets(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            asset_directory = Path(directory)
            expected_names = ("tulip-stage-04.png",)
            write_expected_asset_set(asset_directory, expected_names)
            write_rgba_png(
                asset_directory / "tulip-stage-04.png",
                width=96,
                height=128,
                visible_rect=None,
            )

            errors = verify_stage_assets(asset_directory, expected_names=expected_names)

            self.assertTrue(any("has no visible plant pixels" in error for error in errors))

    def test_verifier_rejects_assets_detached_from_bottom_anchor(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            asset_directory = Path(directory)
            expected_names = ("maple-tree-stage-05.png",)
            write_expected_asset_set(asset_directory, expected_names)
            write_rgba_png(
                asset_directory / "maple-tree-stage-05.png",
                width=128,
                height=180,
                visible_rect=(32, 0, 96, 80),
            )

            errors = verify_stage_assets(asset_directory, expected_names=expected_names)

            self.assertTrue(any("does not reach the planting anchor" in error for error in errors))

    def test_verifier_rejects_tiny_growth_assets(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            asset_directory = Path(directory)
            expected_names = ("sunflower-stage-07.png",)
            write_expected_asset_set(asset_directory, expected_names)
            write_rgba_png(
                asset_directory / "sunflower-stage-07.png",
                width=20,
                height=24,
                visible_rect=(2, 2, 18, 23),
            )

            errors = verify_stage_assets(asset_directory, expected_names=expected_names)

            self.assertTrue(any("too small for a staged plant asset" in error for error in errors))

    def test_verifier_rejects_extra_staged_assets_without_ai_source(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            asset_directory = Path(directory)
            expected_names = ("fern-stage-00.png",)
            write_expected_asset_set(asset_directory, expected_names)
            write_rgba_png(
                asset_directory / "procedural-placeholder-stage-00.png",
                width=96,
                height=128,
                visible_rect=(30, 10, 70, 124),
            )

            errors = verify_stage_assets(asset_directory, expected_names=expected_names)

            self.assertTrue(any("unexpected staged assets" in error for error in errors))

    def test_source_backed_stage_names_are_derived_from_source_files(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            source_directory = Path(directory)
            (source_directory / "fern-stage-00-source.png").touch()
            (source_directory / "moss-carpet-stage-09-source.png").touch()
            (source_directory / "not-a-stage-source.png").touch()

            names = source_backed_stage_asset_names(source_directory)

            self.assertEqual(names, {"fern-stage-00.png", "moss-carpet-stage-09.png"})


def write_expected_asset_set(destination: Path, expected_names: tuple[str, ...]) -> None:
    for file_name in expected_names:
        write_rgba_png(
            destination / file_name,
            width=96,
            height=128,
            visible_rect=(30, 8, 70, 124),
        )


def write_rgba_png(
    path: Path,
    width: int,
    height: int,
    visible_rect: tuple[int, int, int, int] | None,
) -> None:
    rows = []
    for y in range(height):
        row = bytearray([0])
        for x in range(width):
            visible = (
                visible_rect is not None
                and visible_rect[0] <= x < visible_rect[2]
                and visible_rect[1] <= y < visible_rect[3]
            )
            if visible:
                row.extend((48, 128, 64, 255))
            else:
                row.extend((0, 0, 0, 0))
        rows.append(bytes(row))

    raw = b"".join(rows)
    path.write_bytes(
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", width.to_bytes(4, "big") + height.to_bytes(4, "big") + bytes([8, 6, 0, 0, 0]))
        + chunk(b"IDAT", zlib.compress(raw))
        + chunk(b"IEND", b"")
    )


def chunk(kind: bytes, data: bytes) -> bytes:
    checksum = zlib.crc32(kind + data) & 0xFFFFFFFF
    return len(data).to_bytes(4, "big") + kind + data + checksum.to_bytes(4, "big")


if __name__ == "__main__":
    unittest.main()
