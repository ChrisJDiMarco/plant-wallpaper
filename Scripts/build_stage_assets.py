#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path
from PIL import Image, ImageFilter


ROOT = Path(__file__).resolve().parents[1]
SOURCE_DIR = ROOT / "Docs" / "generated-stage-sources"
OUTPUT_DIR = ROOT / "Sources" / "PlantWallpaper" / "Resources" / "PlantAssets"
STAGE_COUNT = 10

SOURCES = {
    "cherry-tree": "cherry-tree-stages-source.png",
    "maple-tree": "maple-tree-stages-source.png",
    "pine-tree": "pine-tree-stages-source.png",
    "tropical-foliage": "fern-stages-source.png",
    "monstera": "monstera-stages-source.png",
    "lavender": "lavender-stages-source.png",
    "tulip": "tulip-stages-source.png",
    "sunflower": "sunflower-stages-source.png",
    "flower-bed": "flower-bed-stages-source.png",
}


def remove_chroma_key(image: Image.Image) -> Image.Image:
    rgba = image.convert("RGBA")
    pixels = rgba.load()
    width, height = rgba.size

    for y in range(height):
        for x in range(width):
            red, green, blue, alpha = pixels[x, y]
            matte_alpha = keyed_alpha((red, green, blue, alpha))
            if matte_alpha == 0:
                pixels[x, y] = (red, green, blue, 0)
            elif matte_alpha < 255:
                pixels[x, y] = (red, green, blue, min(alpha, matte_alpha))

    return decontaminate_magenta_edges(rgba)


def keyed_alpha(pixel: tuple[int, int, int, int]) -> int:
    red, green, blue, _ = pixel
    if red > 210 and blue > 210 and green < 110:
        return 0
    if red > 185 and blue > 185 and green < 150:
        return 40
    return 255


def is_background_candidate(pixel: tuple[int, int, int, int]) -> bool:
    red, green, blue, alpha = pixel
    if alpha == 0:
        return True

    chroma_gap = ((red + blue) / 2) - green
    return red > 205 and blue > 205 and green < 132 and chroma_gap > 86


def decontaminate_magenta_edges(image: Image.Image) -> Image.Image:
    pixels = image.load()
    width, height = image.size
    donor_image = Image.new("RGBA", image.size, (0, 0, 0, 0))
    donor_pixels = donor_image.load()

    for y in range(height):
        for x in range(width):
            red, green, blue, alpha = pixels[x, y]
            if alpha >= 180 and not is_background_candidate((red, green, blue, alpha)):
                donor_pixels[x, y] = (red, green, blue, 255)

    blurred_donors = donor_image.filter(ImageFilter.GaussianBlur(radius=4))
    donor_pixels = blurred_donors.load()

    for y in range(height):
        for x in range(width):
            red, green, blue, alpha = pixels[x, y]
            if alpha == 255:
                continue
            donor_red, donor_green, donor_blue, donor_alpha = donor_pixels[x, y]
            if donor_alpha > 0:
                pixels[x, y] = (donor_red, donor_green, donor_blue, alpha)

    return image


def crop_to_subject(image: Image.Image, padding: int) -> Image.Image:
    alpha = image.getchannel("A")
    bbox = alpha.getbbox()
    if bbox is None:
        return image

    left, top, right, bottom = bbox
    left = max(0, left - padding)
    top = max(0, top - padding)
    right = min(image.width, right + padding)
    bottom = min(image.height, bottom + padding)
    return image.crop((left, top, right, bottom))


def stage_cells(source: Image.Image, asset_name: str) -> list[Image.Image]:
    component_cells = component_stage_cells(source, asset_name)
    if len(component_cells) == STAGE_COUNT:
        return component_cells

    boundaries = stage_boundaries(source)
    return [
        source.crop((boundaries[index], 0, boundaries[index + 1], source.height))
        for index in range(STAGE_COUNT)
    ]


def component_stage_cells(source: Image.Image, asset_name: str) -> list[Image.Image]:
    keyed = remove_chroma_key(source)
    alpha = keyed.getchannel("A").point(lambda value: 255 if value > 32 else 0)
    dilated_alpha = alpha.filter(ImageFilter.MaxFilter(9))
    components = connected_components(dilated_alpha)
    minimum_area = max(80, source.width * source.height // 20_000)
    candidates = [
        component for component in components
        if component["area"] >= minimum_area
    ]

    if len(candidates) == STAGE_COUNT - 1 and asset_name == "tropical-foliage":
        fern_cells = [
            crop_dilated_component(keyed, component, radius=4, padding=8)
            for component in sorted(candidates, key=lambda item: item["center_x"])
        ]
        return synthesize_missing_fern_stage(fern_cells)

    selected = select_stage_components(candidates, source.width)
    if len(selected) != STAGE_COUNT:
        return []

    return [
        crop_dilated_component(keyed, component, radius=4, padding=8)
        for component in sorted(selected, key=lambda item: item["center_x"])
    ]


def connected_components(alpha: Image.Image) -> list[dict[str, int | float]]:
    width, height = alpha.size
    visited = bytearray(width * height)
    components: list[dict[str, int | float]] = []

    for y in range(height):
        row_offset = y * width
        for x in range(width):
            offset = row_offset + x
            if visited[offset] or alpha.getpixel((x, y)) <= 16:
                visited[offset] = 1
                continue

            stack = [(x, y)]
            visited[offset] = 1
            area = 0
            left = right = x
            top = bottom = y

            while stack:
                current_x, current_y = stack.pop()
                area += 1
                left = min(left, current_x)
                right = max(right, current_x)
                top = min(top, current_y)
                bottom = max(bottom, current_y)

                for next_x, next_y in (
                    (current_x - 1, current_y),
                    (current_x + 1, current_y),
                    (current_x, current_y - 1),
                    (current_x, current_y + 1),
                ):
                    if next_x < 0 or next_x >= width or next_y < 0 or next_y >= height:
                        continue
                    next_offset = next_y * width + next_x
                    if visited[next_offset]:
                        continue
                    visited[next_offset] = 1
                    if alpha.getpixel((next_x, next_y)) > 16:
                        stack.append((next_x, next_y))

            components.append({
                "left": left,
                "top": top,
                "right": right + 1,
                "bottom": bottom + 1,
                "area": area,
                "center_x": (left + right + 1) / 2,
            })

    return components


def select_stage_components(
    candidates: list[dict[str, int | float]],
    source_width: int,
) -> list[dict[str, int | float]]:
    if len(candidates) < STAGE_COUNT:
        return []

    selected: list[dict[str, int | float]] = []
    used: set[int] = set()
    for index in range(STAGE_COUNT):
        expected_x = (index + 0.5) * source_width / STAGE_COUNT
        ranked = sorted(
            (
                (abs(float(component["center_x"]) - expected_x), component_index, component)
                for component_index, component in enumerate(candidates)
                if component_index not in used
            ),
            key=lambda item: item[0],
        )
        if not ranked:
            return []

        _, component_index, component = ranked[0]
        used.add(component_index)
        selected.append(component)

    return selected


def crop_dilated_component(
    image: Image.Image,
    component: dict[str, int | float],
    radius: int,
    padding: int,
) -> Image.Image:
    left = max(0, int(component["left"]) - radius - padding)
    top = max(0, int(component["top"]) - radius - padding)
    right = min(image.width, int(component["right"]) + radius + padding)
    bottom = min(image.height, int(component["bottom"]) + radius + padding)
    return crop_to_subject(image.crop((left, top, right, bottom)), padding=padding)


def synthesize_missing_fern_stage(cells: list[Image.Image]) -> list[Image.Image]:
    if len(cells) != STAGE_COUNT - 1:
        return cells

    penultimate = scale_stage(cells[-1], factor=0.88)
    return [*cells[:-1], penultimate, cells[-1]]


def scale_stage(image: Image.Image, factor: float) -> Image.Image:
    width = max(1, int(image.width * factor))
    height = max(1, int(image.height * factor))
    scaled = image.resize((width, height), Image.Resampling.LANCZOS)
    return crop_to_subject(scaled, padding=8)


def stage_boundaries(source: Image.Image) -> list[int]:
    keyed = remove_chroma_key(source)
    alpha = keyed.getchannel("A")
    column_weights = []
    for x in range(source.width):
        non_empty = 0
        for y in range(source.height):
            if alpha.getpixel((x, y)) > 32:
                non_empty += 1
        column_weights.append(non_empty)

    boundaries = [0]
    search_radius = max(8, source.width // 34)
    for index in range(1, STAGE_COUNT):
        expected = round(index * source.width / STAGE_COUNT)
        start = max(boundaries[-1] + 8, expected - search_radius)
        end = min(source.width - 8, expected + search_radius)
        best_x = min(range(start, end), key=lambda x: smoothed_weight(column_weights, x))
        boundaries.append(best_x)
    boundaries.append(source.width)

    return boundaries


def smoothed_weight(column_weights: list[int], x: int) -> float:
    start = max(0, x - 4)
    end = min(len(column_weights), x + 5)
    return sum(column_weights[start:end]) / max(1, end - start)


def build_assets() -> None:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    for asset_name, filename in SOURCES.items():
        source_path = SOURCE_DIR / filename
        if not source_path.exists():
            raise FileNotFoundError(source_path)

        source = Image.open(source_path).convert("RGBA")
        cells = stage_cells(source, asset_name)
        if len(cells) != STAGE_COUNT:
            raise RuntimeError(f"Expected {STAGE_COUNT} stages for {asset_name}, got {len(cells)}")

        for index, cell in enumerate(cells):
            keyed = remove_chroma_key(cell)
            cropped = crop_to_subject(keyed, padding=10)
            output_path = OUTPUT_DIR / f"{asset_name}-stage-{index:02d}.png"
            cropped.save(output_path)
            print(output_path.relative_to(ROOT))


if __name__ == "__main__":
    build_assets()
