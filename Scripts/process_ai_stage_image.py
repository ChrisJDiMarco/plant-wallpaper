#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import shutil
from dataclasses import asdict, dataclass
from pathlib import Path

from PIL import Image, ImageFilter, ImageStat


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_OUTPUT_DIR = ROOT / "Sources" / "PlantWallpaper" / "Resources" / "PlantAssets"
DEFAULT_SOURCE_DIR = ROOT / "Generated" / "AIStageSources"
DEFAULT_QA_DIR = ROOT / "Generated" / "AIStageQA"
KEY_COLOR = (255, 0, 255)


@dataclass(frozen=True)
class StageQA:
    slug: str
    stage: int
    source: str
    output: str
    width: int
    height: int
    alpha_bbox: tuple[int, int, int, int] | None
    visible_ratio: float
    bottom_gap_ratio: float
    transparent_corner_count: int
    edge_alpha_ratio: float


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Turn one AI-generated chroma-key plant image into one transparent staged plant PNG."
    )
    parser.add_argument("slug", help="Plant asset slug, e.g. japanese-maple")
    parser.add_argument("stage", type=int, help="Stage index, 0 through 9")
    parser.add_argument("source", type=Path, help="AI source PNG/JPEG path")
    parser.add_argument("--output-dir", type=Path, default=DEFAULT_OUTPUT_DIR)
    parser.add_argument("--source-dir", type=Path, default=DEFAULT_SOURCE_DIR)
    parser.add_argument("--qa-dir", type=Path, default=DEFAULT_QA_DIR)
    parser.add_argument("--threshold", type=int, default=58)
    parser.add_argument("--softness", type=int, default=44)
    parser.add_argument("--key-color", default="#ff00ff", help="Hex chroma-key color used in the source image.")
    parser.add_argument("--min-width", type=int, default=92)
    parser.add_argument("--min-height", type=int, default=104)
    args = parser.parse_args()

    if args.stage < 0 or args.stage > 9:
        raise SystemExit("Stage must be between 0 and 9")

    source = args.source.expanduser().resolve()
    if not source.exists():
        raise SystemExit(f"Missing source image: {source}")

    args.output_dir.mkdir(parents=True, exist_ok=True)
    args.source_dir.mkdir(parents=True, exist_ok=True)
    args.qa_dir.mkdir(parents=True, exist_ok=True)

    source_copy = args.source_dir / f"{args.slug}-stage-{args.stage:02d}-source{source.suffix.lower() or '.png'}"
    if source_copy.resolve() != source:
        shutil.copy2(source, source_copy)

    image = Image.open(source).convert("RGBA")
    transparent = remove_chroma_background(
        image,
        key_color=parse_hex_color(args.key_color),
        threshold=args.threshold,
        softness=args.softness,
    )
    normalized = normalize_stage(transparent, min_width=args.min_width, min_height=args.min_height)

    output_path = args.output_dir / f"{args.slug}-stage-{args.stage:02d}.png"
    normalized.save(output_path)

    qa = build_qa(args.slug, args.stage, source_copy, output_path, normalized)
    qa_path = args.qa_dir / f"{args.slug}-stage-{args.stage:02d}.json"
    qa_path.write_text(json.dumps(asdict(qa), indent=2) + "\n")

    errors = qa_errors(qa)
    print(json.dumps(asdict(qa), indent=2))
    if errors:
        for error in errors:
            print(f"qa warning: {error}")
    return 0


def parse_hex_color(value: str) -> tuple[int, int, int]:
    cleaned = value.strip().removeprefix("#")
    if len(cleaned) != 6:
        raise ValueError(f"Expected six-digit hex color, got {value}")
    return tuple(int(cleaned[index : index + 2], 16) for index in (0, 2, 4))


def remove_chroma_background(
    image: Image.Image,
    key_color: tuple[int, int, int],
    threshold: int,
    softness: int,
) -> Image.Image:
    rgb = image.convert("RGB")
    alpha = Image.new("L", image.size, 255)
    rgb_pixels = rgb.load()
    alpha_pixels = alpha.load()
    hard_edge = threshold + max(1, softness)

    for y in range(image.height):
        for x in range(image.width):
            red, green, blue = rgb_pixels[x, y]
            value = color_distance((red, green, blue), key_color)
            key_score = chroma_key_score((red, green, blue), key_color)
            if value <= threshold:
                alpha_pixels[x, y] = 0
            elif value < hard_edge:
                alpha_pixels[x, y] = int(255 * ((value - threshold) / softness))
            if key_score > 0:
                alpha_pixels[x, y] = min(alpha_pixels[x, y], max(0, 255 - key_score))

    alpha = alpha.filter(ImageFilter.MinFilter(3)).filter(ImageFilter.GaussianBlur(0.35))
    alpha = alpha.point(lambda value: 0 if value < 18 else value)
    red, green, blue, _old_alpha = image.split()
    rgb = despill_key_color(Image.merge("RGB", (red, green, blue)), alpha, key_color)
    output = Image.merge("RGBA", (*rgb.split(), alpha))
    clear_fully_transparent_rgb(output)
    return output


def color_distance(color: tuple[int, int, int], key_color: tuple[int, int, int]) -> int:
    return round(
        (
            (color[0] - key_color[0]) ** 2
            + (color[1] - key_color[1]) ** 2
            + (color[2] - key_color[2]) ** 2
        )
        ** 0.5
    )


def chroma_key_score(color: tuple[int, int, int], key_color: tuple[int, int, int]) -> int:
    red, green, blue = color
    key_red, key_green, key_blue = key_color
    if key_red > 220 and key_blue > 220 and key_green < 40:
        magenta_strength = min(red, blue) - green
        if red > 112 and blue > 112 and magenta_strength > 18:
            return min(245, max(0, int((magenta_strength - 18) * 3.1)))
    if key_green > 220 and key_red < 40 and key_blue < 40:
        green_strength = green - max(red, blue)
        if green > 112 and green_strength > 18:
            return min(245, max(0, int((green_strength - 18) * 3.1)))
    if key_blue > 220 and key_red < 40 and key_green < 40:
        blue_strength = blue - max(red, green)
        if blue > 70 and blue_strength > 10:
            multiplier = 5.2 if blue > 118 else 3.8
            return min(255, max(0, int((blue_strength - 10) * multiplier)))
    if key_red > 220 and key_green < 40 and key_blue < 40:
        red_strength = red - max(green, blue)
        if red > 112 and red_strength > 18:
            return min(245, max(0, int((red_strength - 18) * 3.1)))
    if key_green > 220 and key_blue > 220 and key_red < 40:
        cyan_strength = min(green, blue) - red
        if green > 112 and blue > 112 and cyan_strength > 18:
            return min(245, max(0, int((cyan_strength - 18) * 3.1)))
    return 0


def despill_key_color(rgb: Image.Image, alpha: Image.Image, key_color: tuple[int, int, int]) -> Image.Image:
    pixels = rgb.load()
    alpha_pixels = alpha.load()
    for y in range(rgb.height):
        for x in range(rgb.width):
            if alpha_pixels[x, y] >= 250:
                continue
            red, green, blue = pixels[x, y]
            if key_color == (255, 0, 255):
                spill = max(0, min(red, blue) - green - 6)
                if spill:
                    pixels[x, y] = (
                        max(0, red - spill),
                        min(255, green + spill // 5),
                        max(0, blue - spill),
                    )
            elif key_color == (0, 255, 0):
                spill = max(0, green - max(red, blue) - 6)
                if spill:
                    pixels[x, y] = (
                        red,
                        max(0, green - spill),
                        blue,
                    )
            elif key_color == (0, 0, 255):
                spill = max(0, blue - max(red, green) - 6)
                if spill:
                    pixels[x, y] = (
                        red,
                        green,
                        max(0, blue - spill),
                    )
            elif key_color == (255, 0, 0):
                spill = max(0, red - max(green, blue) - 6)
                if spill:
                    pixels[x, y] = (
                        max(0, red - spill),
                        green,
                        blue,
                    )
            elif key_color == (0, 255, 255):
                spill = max(0, min(green, blue) - red - 6)
                if spill:
                    pixels[x, y] = (
                        red,
                        max(0, green - spill),
                        max(0, blue - spill),
                    )
    return rgb


def clear_fully_transparent_rgb(image: Image.Image) -> None:
    pixels = image.load()
    for y in range(image.height):
        for x in range(image.width):
            red, green, blue, alpha = pixels[x, y]
            if alpha == 0:
                pixels[x, y] = (0, 0, 0, 0)


def normalize_stage(image: Image.Image, min_width: int, min_height: int) -> Image.Image:
    alpha = image.getchannel("A")
    bbox = alpha.getbbox()
    if bbox is None:
        raise ValueError("Image has no visible pixels after background removal")

    left, top, right, bottom = bbox
    plant_width = right - left
    plant_height = bottom - top
    pad_x = max(20, round(plant_width * 0.14))
    pad_top = max(20, round(plant_height * 0.10))
    pad_bottom = max(10, round(plant_height * 0.04))
    crop_box = (
        max(0, left - pad_x),
        max(0, top - pad_top),
        min(image.width, right + pad_x),
        min(image.height, bottom + pad_bottom),
    )
    cropped = image.crop(crop_box)
    cropped = trim_transparent_edge_noise(cropped)

    target_width = max(min_width, cropped.width)
    target_height = max(min_height, cropped.height)
    canvas = Image.new("RGBA", (target_width, target_height), (0, 0, 0, 0))
    canvas.alpha_composite(
        cropped,
        ((target_width - cropped.width) // 2, target_height - cropped.height),
    )
    return canvas


def trim_transparent_edge_noise(image: Image.Image) -> Image.Image:
    alpha = image.getchannel("A")
    bbox = alpha.point(lambda value: 255 if value > 24 else 0).getbbox()
    if bbox is None:
        return image
    left, top, right, bottom = bbox
    return image.crop((left, top, right, bottom))


def build_qa(slug: str, stage: int, source: Path, output: Path, image: Image.Image) -> StageQA:
    alpha = image.getchannel("A")
    bbox = alpha.getbbox()
    visible = ImageStat.Stat(alpha).sum[0] / 255
    visible_ratio = visible / max(1, image.width * image.height)
    bottom_gap_ratio = 1.0 if bbox is None else (image.height - bbox[3]) / max(1, image.height)
    corners = [
        alpha.getpixel((0, 0)),
        alpha.getpixel((image.width - 1, 0)),
        alpha.getpixel((0, image.height - 1)),
        alpha.getpixel((image.width - 1, image.height - 1)),
    ]
    edge_alpha_ratio = edge_visible_ratio(alpha)
    return StageQA(
        slug=slug,
        stage=stage,
        source=str(source),
        output=str(output),
        width=image.width,
        height=image.height,
        alpha_bbox=bbox,
        visible_ratio=visible_ratio,
        bottom_gap_ratio=bottom_gap_ratio,
        transparent_corner_count=sum(1 for value in corners if value == 0),
        edge_alpha_ratio=edge_alpha_ratio,
    )


def edge_visible_ratio(alpha: Image.Image) -> float:
    width, height = alpha.size
    visible = 0
    total = width * 2 + height * 2 - 4
    for x in range(width):
        visible += 1 if alpha.getpixel((x, 0)) > 8 else 0
        visible += 1 if alpha.getpixel((x, height - 1)) > 8 else 0
    for y in range(1, height - 1):
        visible += 1 if alpha.getpixel((0, y)) > 8 else 0
        visible += 1 if alpha.getpixel((width - 1, y)) > 8 else 0
    return visible / max(1, total)


def qa_errors(qa: StageQA) -> list[str]:
    errors: list[str] = []
    if qa.transparent_corner_count < 4:
        errors.append("corners are not fully transparent")
    if qa.edge_alpha_ratio > 0.08:
        errors.append(f"subject likely touches/crosses an edge ({qa.edge_alpha_ratio:.1%})")
    if qa.visible_ratio < 0.05:
        errors.append(f"visible plant area is low ({qa.visible_ratio:.1%})")
    if qa.bottom_gap_ratio > 0.22:
        errors.append(f"plant bottom is not anchor-aligned ({qa.bottom_gap_ratio:.1%})")
    return errors


if __name__ == "__main__":
    raise SystemExit(main())
