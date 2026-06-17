#!/usr/bin/env python3
from __future__ import annotations

import argparse
import shutil
from pathlib import Path

from PIL import Image, ImageChops, ImageFilter, ImageStat


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_OUTPUT_DIR = ROOT / "Sources" / "PlantWallpaper" / "Resources" / "PlantAssets"
DEFAULT_SOURCE_DIR = ROOT / "Generated" / "AIStageSheets"
STAGE_COUNT = 10
KEY_COLOR = (255, 0, 255)


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Turn one AI-generated chroma-key plant growth sheet into ten transparent stage PNGs."
    )
    parser.add_argument("slug", help="Plant asset slug, e.g. japanese-maple")
    parser.add_argument("source", type=Path, help="AI stage sheet PNG/JPEG path")
    parser.add_argument("--output-dir", type=Path, default=DEFAULT_OUTPUT_DIR)
    parser.add_argument("--source-dir", type=Path, default=DEFAULT_SOURCE_DIR)
    parser.add_argument("--stages", type=int, default=STAGE_COUNT)
    parser.add_argument("--threshold", type=int, default=58)
    parser.add_argument("--softness", type=int, default=44)
    parser.add_argument(
        "--layout",
        choices=("auto", "horizontal", "grid-5x2"),
        default="grid-5x2",
        help="Expected sheet layout. AI prompts should use grid-5x2 for reliable growth-stage slicing.",
    )
    parser.add_argument("--min-width", type=int, default=88)
    parser.add_argument("--min-height", type=int, default=96)
    args = parser.parse_args()

    source = args.source.expanduser().resolve()
    if not source.exists():
        raise SystemExit(f"Missing source image: {source}")

    args.output_dir.mkdir(parents=True, exist_ok=True)
    args.source_dir.mkdir(parents=True, exist_ok=True)
    copied_source = args.source_dir / f"{args.slug}-ai-stage-sheet{source.suffix.lower() or '.png'}"
    if copied_source.resolve() != source:
        shutil.copy2(source, copied_source)

    image = Image.open(source).convert("RGBA")
    transparent = remove_chroma_background(
        image,
        threshold=args.threshold,
        softness=args.softness,
    )
    debug_transparent = args.source_dir / f"{args.slug}-transparent-sheet.png"
    transparent.save(debug_transparent)

    written: list[Path] = []
    for stage_index, stage in enumerate(extract_stage_crops(transparent, args.stages, args.layout)):
        normalized = normalize_stage(stage, min_width=args.min_width, min_height=args.min_height)
        output_path = args.output_dir / f"{args.slug}-stage-{stage_index:02d}.png"
        normalized.save(output_path)
        written.append(output_path)

    print(f"Processed {args.slug}: {len(written)} stages")
    print(f"Source copy: {copied_source}")
    print(f"Transparent sheet: {debug_transparent}")
    for path in written:
        print(path)
    return 0


def remove_chroma_background(image: Image.Image, threshold: int, softness: int) -> Image.Image:
    rgb = image.convert("RGB")
    key = Image.new("RGB", image.size, KEY_COLOR)
    distance = ImageChops.difference(rgb, key).convert("L")

    alpha = Image.new("L", image.size, 255)
    distance_pixels = distance.load()
    alpha_pixels = alpha.load()
    hard_edge = threshold + max(1, softness)

    for y in range(image.height):
        for x in range(image.width):
            value = distance_pixels[x, y]
            if value <= threshold:
                alpha_pixels[x, y] = 0
            elif value < hard_edge:
                alpha_pixels[x, y] = int(255 * ((value - threshold) / softness))

    alpha = alpha.filter(ImageFilter.MinFilter(3)).filter(ImageFilter.GaussianBlur(0.35))

    output = image.copy()
    red, green, blue, _old_alpha = output.split()
    cleaned_rgb = Image.merge("RGB", (red, green, blue))
    cleaned_rgb = despill_magenta(cleaned_rgb, alpha)
    output = Image.merge("RGBA", (*cleaned_rgb.split(), alpha))
    clear_fully_transparent_rgb(output)
    return output


def despill_magenta(rgb: Image.Image, alpha: Image.Image) -> Image.Image:
    pixels = rgb.load()
    alpha_pixels = alpha.load()
    for y in range(rgb.height):
        for x in range(rgb.width):
            if alpha_pixels[x, y] >= 250:
                continue
            red, green, blue = pixels[x, y]
            spill = max(0, min(red, blue) - green - 8)
            if spill:
                pixels[x, y] = (
                    max(0, red - spill // 2),
                    green,
                    max(0, blue - spill // 2),
                )
    return rgb


def clear_fully_transparent_rgb(image: Image.Image) -> None:
    pixels = image.load()
    for y in range(image.height):
        for x in range(image.width):
            red, green, blue, alpha = pixels[x, y]
            if alpha == 0:
                pixels[x, y] = (0, 0, 0, 0)


def extract_stage_crops(image: Image.Image, stage_count: int, layout: str) -> list[Image.Image]:
    if layout == "grid-5x2":
        return extract_grid_crops(image, columns=5, rows=2)
    if layout == "horizontal":
        return extract_horizontal_crops(image, stage_count)

    grid_crops = extract_grid_crops(image, columns=5, rows=2)
    if all(crop.getchannel("A").getbbox() is not None for crop in grid_crops):
        return grid_crops
    return extract_horizontal_crops(image, stage_count)


def extract_grid_crops(image: Image.Image, columns: int, rows: int) -> list[Image.Image]:
    crops: list[Image.Image] = []
    for row in range(rows):
        for column in range(columns):
            left = round(image.width * column / columns)
            right = round(image.width * (column + 1) / columns)
            top = round(image.height * row / rows)
            bottom = round(image.height * (row + 1) / rows)
            crops.append(image.crop((left, top, right, bottom)))
    return crops


def extract_horizontal_crops(image: Image.Image, stage_count: int) -> list[Image.Image]:
    alpha = image.getchannel("A")
    connected = alpha.filter(ImageFilter.MaxFilter(41))
    spans = alpha_column_spans(connected, stage_count)
    if len(spans) != stage_count:
        spans = equal_spans(image.width, stage_count)

    crops: list[Image.Image] = []
    for left, right in spans:
        expanded_left = max(0, left - 22)
        expanded_right = min(image.width, right + 22)
        crop = image.crop((expanded_left, 0, expanded_right, image.height))
        crops.append(crop)
    return crops


def alpha_column_spans(alpha: Image.Image, stage_count: int) -> list[tuple[int, int]]:
    width, height = alpha.size
    pixels = alpha.load()
    threshold = max(5, int(height * 0.015))
    active: list[bool] = []
    for x in range(width):
        count = 0
        for y in range(height):
            if pixels[x, y] > 12:
                count += 1
        active.append(count >= threshold)

    spans: list[tuple[int, int]] = []
    start: int | None = None
    for x, is_active in enumerate(active):
        if is_active and start is None:
            start = x
        elif not is_active and start is not None:
            spans.append((start, x))
            start = None
    if start is not None:
        spans.append((start, width))

    spans = [span for span in spans if span[1] - span[0] >= 5]
    spans = merge_close_spans(spans, max_gap=max(12, width // 140))
    while len(spans) > stage_count:
        spans = merge_nearest_pair(spans)
    return spans


def merge_close_spans(spans: list[tuple[int, int]], max_gap: int) -> list[tuple[int, int]]:
    if not spans:
        return []
    merged = [spans[0]]
    for left, right in spans[1:]:
        previous_left, previous_right = merged[-1]
        if left - previous_right <= max_gap:
            merged[-1] = (previous_left, right)
        else:
            merged.append((left, right))
    return merged


def merge_nearest_pair(spans: list[tuple[int, int]]) -> list[tuple[int, int]]:
    if len(spans) <= 1:
        return spans
    gap_index = min(
        range(len(spans) - 1),
        key=lambda index: spans[index + 1][0] - spans[index][1],
    )
    merged = spans[:gap_index]
    merged.append((spans[gap_index][0], spans[gap_index + 1][1]))
    merged.extend(spans[gap_index + 2 :])
    return merged


def equal_spans(width: int, stage_count: int) -> list[tuple[int, int]]:
    return [
        (round(width * index / stage_count), round(width * (index + 1) / stage_count))
        for index in range(stage_count)
    ]


def normalize_stage(stage: Image.Image, min_width: int, min_height: int) -> Image.Image:
    alpha = stage.getchannel("A")
    bbox = alpha.getbbox()
    if bbox is None:
        raise ValueError("Stage has no visible pixels after background removal")

    left, top, right, bottom = bbox
    plant_width = right - left
    plant_height = bottom - top
    pad_x = max(14, round(plant_width * 0.12))
    pad_top = max(14, round(plant_height * 0.08))
    pad_bottom = max(8, round(plant_height * 0.035))
    crop_box = (
        max(0, left - pad_x),
        max(0, top - pad_top),
        min(stage.width, right + pad_x),
        min(stage.height, bottom + pad_bottom),
    )
    cropped = stage.crop(crop_box)

    target_width = max(min_width, cropped.width)
    target_height = max(min_height, cropped.height)
    canvas = Image.new("RGBA", (target_width, target_height), (0, 0, 0, 0))
    canvas.alpha_composite(
        cropped,
        ((target_width - cropped.width) // 2, target_height - cropped.height),
    )

    if visible_ratio(canvas) < 0.035:
        canvas = pad_to_visible_ratio(canvas, min_ratio=0.05)
    return canvas


def visible_ratio(image: Image.Image) -> float:
    alpha = image.getchannel("A")
    stat = ImageStat.Stat(alpha)
    visible = stat.sum[0] / 255
    return visible / max(1, image.width * image.height)


def pad_to_visible_ratio(image: Image.Image, min_ratio: float) -> Image.Image:
    if visible_ratio(image) >= min_ratio:
        return image

    alpha = image.getchannel("A")
    bbox = alpha.getbbox()
    if bbox is None:
        return image

    left, top, right, bottom = bbox
    cropped = image.crop((left, top, right, bottom))
    target_width = max(72, cropped.width + 22)
    target_height = max(80, cropped.height + 18)
    canvas = Image.new("RGBA", (target_width, target_height), (0, 0, 0, 0))
    canvas.alpha_composite(
        cropped,
        ((target_width - cropped.width) // 2, target_height - cropped.height - 4),
    )
    return canvas


if __name__ == "__main__":
    raise SystemExit(main())
