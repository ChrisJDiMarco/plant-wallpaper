#!/usr/bin/env python3
from __future__ import annotations

import argparse
import colorsys
from pathlib import Path

from PIL import Image, ImageFilter


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Remove baked circular blossom/fruit/dot artifacts from plant PNG assets."
    )
    parser.add_argument("asset_directory", type=Path)
    args = parser.parse_args()

    count = 0
    changed = 0
    for path in sorted(args.asset_directory.glob("*.png")):
        if not should_sanitize(path):
            continue

        image = Image.open(path).convert("RGBA")
        sanitized, masked_pixels = sanitize_image(image)
        count += 1
        if masked_pixels > 0:
            sanitized.save(path)
            changed += 1

    print(f"Sanitized {changed} of {count} plant asset PNGs in {args.asset_directory}")
    return 0


def should_sanitize(path: Path) -> bool:
    name = path.name
    return name.endswith(".png") and (
        "-stage-" in name
        or name in {
            "cherry-tree.png",
            "maple-tree.png",
            "pine-tree.png",
            "tropical-foliage.png",
            "monstera.png",
            "lavender.png",
            "tulip.png",
            "sunflower.png",
            "flower-bed.png",
        }
    )


def sanitize_image(image: Image.Image) -> tuple[Image.Image, int]:
    mask = candidate_mask(image)
    mask = select_dot_components(mask, image)
    if not mask.getbbox():
        return image, 0

    expanded_mask = mask.filter(ImageFilter.MaxFilter(5))
    return fill_masked_pixels(image, expanded_mask), count_mask_pixels(expanded_mask)


def candidate_mask(image: Image.Image) -> Image.Image:
    width, height = image.size
    pixels = image.load()
    mask = Image.new("L", image.size, 0)
    mask_pixels = mask.load()

    for y in range(height):
        for x in range(width):
            red, green, blue, alpha = pixels[x, y]
            if is_dot_colored_pixel(red, green, blue, alpha):
                mask_pixels[x, y] = 255

    return mask


def is_dot_colored_pixel(red: int, green: int, blue: int, alpha: int) -> bool:
    if alpha < 48:
        return False

    hue, saturation, value = colorsys.rgb_to_hsv(red / 255, green / 255, blue / 255)
    if value < 0.28:
        return False

    # Keep normal foliage and woody trunks. Remove bright/saturated flowers,
    # fruit, bloom specks, magenta edge artifacts, and pale circular blossoms.
    is_green_foliage = 0.18 <= hue <= 0.50 and saturation > 0.10
    is_dark_wood = hue < 0.16 and value < 0.42 and green < 135
    if is_green_foliage or is_dark_wood:
        return False

    is_colored_bloom = saturation > 0.16 and (hue < 0.18 or hue > 0.56)
    is_pale_bloom = (
        red > 165
        and blue > 125
        and max(red, green, blue) - min(red, green, blue) > 14
    )
    is_yellow_or_orange_dot = red > 155 and green > 112 and blue < 145
    is_light_round_flower = red > 182 and green > 170 and blue > 142

    return is_colored_bloom or is_pale_bloom or is_yellow_or_orange_dot or is_light_round_flower


def select_dot_components(mask: Image.Image, image: Image.Image) -> Image.Image:
    width, height = mask.size
    source = mask.load()
    selected = Image.new("L", mask.size, 0)
    selected_pixels = selected.load()
    visited = bytearray(width * height)

    for y in range(height):
        for x in range(width):
            offset = y * width + x
            if visited[offset] or source[x, y] == 0:
                visited[offset] = 1
                continue

            points: list[tuple[int, int]] = []
            stack = [(x, y)]
            visited[offset] = 1
            left = right = x
            top = bottom = y

            while stack:
                current_x, current_y = stack.pop()
                points.append((current_x, current_y))
                left = min(left, current_x)
                right = max(right, current_x)
                top = min(top, current_y)
                bottom = max(bottom, current_y)

                for next_x in (current_x - 1, current_x, current_x + 1):
                    for next_y in (current_y - 1, current_y, current_y + 1):
                        if next_x == current_x and next_y == current_y:
                            continue
                        if next_x < 0 or next_y < 0 or next_x >= width or next_y >= height:
                            continue
                        next_offset = next_y * width + next_x
                        if visited[next_offset]:
                            continue
                        visited[next_offset] = 1
                        if source[next_x, next_y] > 0:
                            stack.append((next_x, next_y))

            if should_remove_component(points, left, top, right + 1, bottom + 1, image):
                for point_x, point_y in points:
                    selected_pixels[point_x, point_y] = 255

    return selected


def should_remove_component(
    points: list[tuple[int, int]],
    left: int,
    top: int,
    right: int,
    bottom: int,
    image: Image.Image,
) -> bool:
    area = len(points)
    if area < 2:
        return False

    width = right - left
    height = bottom - top
    max_dimension = max(width, height)
    min_dimension = max(1, min(width, height))
    fill_ratio = area / max(1, width * height)
    image_area = image.size[0] * image.size[1]

    is_small_blob = max_dimension <= 48 and area <= 1_400
    is_medium_blob = max_dimension <= 86 and area <= 4_500 and fill_ratio >= 0.035
    is_large_round_flower = max_dimension <= 140 and area <= 12_000 and max_dimension / min_dimension <= 3.8
    is_mass_of_small_blooms = area <= image_area * 0.22 and fill_ratio < 0.72

    return is_small_blob or is_medium_blob or is_large_round_flower or is_mass_of_small_blooms


def fill_masked_pixels(image: Image.Image, mask: Image.Image) -> Image.Image:
    donor = Image.new("RGBA", image.size, (0, 0, 0, 0))
    donor_pixels = donor.load()
    image_pixels = image.load()
    mask_pixels = mask.load()
    width, height = image.size

    for y in range(height):
        for x in range(width):
            if mask_pixels[x, y] == 0 and image_pixels[x, y][3] > 0:
                donor_pixels[x, y] = image_pixels[x, y]

    premultiplied = premultiply_alpha(donor)
    donor_alpha = donor.getchannel("A")
    output = image.copy()
    output_pixels = output.load()

    remaining: list[tuple[int, int]] = [
        (x, y)
        for y in range(height)
        for x in range(width)
        if mask_pixels[x, y] > 0
    ]

    for radius in (4, 9, 18, 36, 72):
        if not remaining:
            break

        blurred_rgb = premultiplied.filter(ImageFilter.GaussianBlur(radius=radius))
        blurred_alpha = donor_alpha.filter(ImageFilter.GaussianBlur(radius=radius))
        blurred_pixels = blurred_rgb.load()
        alpha_pixels = blurred_alpha.load()
        next_remaining: list[tuple[int, int]] = []

        for x, y in remaining:
            alpha = alpha_pixels[x, y]
            if alpha > 3:
                red, green, blue, _ = blurred_pixels[x, y]
                output_pixels[x, y] = (
                    clamp(red * 255 / alpha),
                    clamp(green * 255 / alpha),
                    clamp(blue * 255 / alpha),
                    image_pixels[x, y][3],
                )
            else:
                next_remaining.append((x, y))

        remaining = next_remaining

    for x, y in remaining:
        red, green, blue, alpha = image_pixels[x, y]
        luminance = int(red * 0.30 + green * 0.59 + blue * 0.11)
        output_pixels[x, y] = (
            clamp(luminance * 0.48),
            clamp(luminance * 0.68),
            clamp(luminance * 0.42),
            min(alpha, 150),
        )

    return output


def premultiply_alpha(image: Image.Image) -> Image.Image:
    output = Image.new("RGBA", image.size, (0, 0, 0, 0))
    input_pixels = image.load()
    output_pixels = output.load()
    width, height = image.size

    for y in range(height):
        for x in range(width):
            red, green, blue, alpha = input_pixels[x, y]
            output_pixels[x, y] = (
                red * alpha // 255,
                green * alpha // 255,
                blue * alpha // 255,
                alpha,
            )

    return output


def count_mask_pixels(mask: Image.Image) -> int:
    pixels = mask.load()
    width, height = mask.size
    return sum(1 for y in range(height) for x in range(width) if pixels[x, y] > 0)


def clamp(value: float) -> int:
    return max(0, min(255, int(round(value))))


if __name__ == "__main__":
    raise SystemExit(main())
