#!/usr/bin/env python3
from __future__ import annotations

import math
import random
import sys
from dataclasses import dataclass
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter


ROOT = Path(__file__).resolve().parents[1]
OUTPUT_DIR = ROOT / "Sources" / "PlantWallpaper" / "Resources" / "PlantAssets"
STAGE_COUNT = 10


@dataclass(frozen=True)
class SpeciesProfile:
    raw: str
    slug: str
    kind: str
    primary: tuple[int, int, int]
    secondary: tuple[int, int, int]
    accent: tuple[int, int, int]
    stem: tuple[int, int, int]
    traits: tuple[str, ...] = ()


SPECIES: tuple[SpeciesProfile, ...] = (
    SpeciesProfile("fern", "fern", "foliage", (65, 135, 88), (112, 172, 104), (185, 210, 150), (62, 92, 58), ("frond",)),
    SpeciesProfile("mossCarpet", "moss-carpet", "meadow", (71, 129, 72), (106, 164, 84), (169, 193, 122), (62, 94, 55), ("carpet",)),
    SpeciesProfile("cloverPatch", "clover-patch", "meadow", (58, 133, 75), (96, 172, 91), (236, 236, 218), (58, 104, 61), ("clover",)),
    SpeciesProfile("creepingThyme", "creeping-thyme", "meadow", (86, 132, 82), (130, 157, 92), (190, 126, 184), (72, 94, 62), ("creeping",)),
    SpeciesProfile("ivy", "ivy", "foliage", (45, 116, 73), (85, 150, 82), (180, 204, 146), (65, 81, 54), ("vine",)),
    SpeciesProfile("wisteria", "wisteria", "flower", (64, 122, 76), (106, 162, 94), (159, 92, 190), (92, 85, 58), ("droop", "vine")),
    SpeciesProfile("jasmine", "jasmine", "flower", (53, 128, 77), (96, 162, 91), (247, 244, 221), (70, 102, 60), ("star", "vine")),
    SpeciesProfile("orchid", "orchid", "flower", (72, 134, 84), (104, 160, 102), (185, 83, 172), (70, 105, 62), ("orchid",)),
    SpeciesProfile("bonsai", "bonsai", "tree", (49, 113, 75), (100, 148, 92), (192, 210, 162), (96, 63, 43), ("bonsai",)),
    SpeciesProfile("japaneseMaple", "japanese-maple", "tree", (127, 52, 56), (181, 86, 66), (223, 146, 77), (93, 55, 39), ("maple", "red")),
    SpeciesProfile("willow", "willow", "tree", (74, 129, 75), (131, 165, 86), (186, 194, 116), (91, 67, 42), ("willow",)),
    SpeciesProfile("birch", "birch", "tree", (82, 139, 88), (137, 172, 100), (212, 218, 178), (218, 211, 187), ("birch",)),
    SpeciesProfile("dogwood", "dogwood", "tree", (72, 134, 80), (129, 166, 91), (240, 218, 224), (98, 69, 47), ("blossom",)),
    SpeciesProfile("magnolia", "magnolia", "tree", (67, 123, 77), (112, 151, 88), (239, 211, 218), (99, 67, 47), ("large-blossom",)),
    SpeciesProfile("oliveTree", "olive-tree", "tree", (96, 126, 85), (152, 166, 120), (188, 190, 143), (93, 74, 50), ("olive",)),
    SpeciesProfile("dwarfCitrus", "dwarf-citrus", "tree", (53, 128, 73), (108, 163, 86), (225, 150, 50), (93, 64, 43), ("citrus",)),
    SpeciesProfile("hydrangea", "hydrangea", "flower", (56, 127, 78), (98, 158, 88), (121, 151, 210), (72, 104, 63), ("cluster",)),
    SpeciesProfile("peony", "peony", "flower", (62, 129, 77), (105, 157, 83), (229, 139, 164), (72, 103, 58), ("ruffle",)),
    SpeciesProfile("rose", "rose", "flower", (54, 127, 76), (94, 152, 83), (198, 56, 77), (75, 94, 55), ("rose",)),
    SpeciesProfile("foxglove", "foxglove", "flower", (62, 128, 77), (104, 154, 86), (184, 86, 161), (74, 105, 62), ("spike",)),
    SpeciesProfile("poppy", "poppy", "flower", (71, 131, 78), (119, 153, 86), (218, 76, 55), (72, 100, 57), ("cup",)),
    SpeciesProfile("iris", "iris", "flower", (67, 123, 82), (104, 151, 86), (106, 90, 189), (72, 102, 59), ("iris",)),
    SpeciesProfile("lily", "lily", "flower", (66, 128, 78), (111, 157, 86), (238, 196, 117), (72, 104, 60), ("lily",)),
    SpeciesProfile("wildflowerMeadow", "wildflower-meadow", "meadow", (75, 129, 77), (123, 158, 84), (220, 150, 88), (74, 104, 58), ("wildflower",)),
    SpeciesProfile("lavenderField", "lavender-field", "meadow", (82, 128, 82), (126, 149, 86), (143, 96, 182), (75, 102, 61), ("lavender-field",)),
    SpeciesProfile("herbCluster", "herb-cluster", "foliage", (65, 126, 78), (117, 157, 93), (177, 188, 123), (71, 98, 57), ("herb",)),
    SpeciesProfile("bamboo", "bamboo", "foliage", (72, 141, 75), (139, 175, 82), (204, 198, 113), (102, 131, 54), ("bamboo",)),
    SpeciesProfile("ornamentalGrass", "ornamental-grass", "meadow", (111, 130, 80), (165, 155, 91), (210, 178, 118), (99, 105, 62), ("grass",)),
    SpeciesProfile("cattails", "cattails", "meadow", (82, 125, 77), (134, 151, 78), (110, 73, 45), (80, 104, 57), ("cattail",)),
    SpeciesProfile("mushrooms", "mushrooms", "meadow", (98, 126, 88), (153, 132, 104), (204, 126, 137), (114, 91, 70), ("mushroom",)),
    SpeciesProfile("lichens", "lichens", "meadow", (112, 138, 91), (165, 180, 122), (205, 213, 166), (94, 109, 76), ("lichen",)),
    SpeciesProfile("succulent", "succulent", "foliage", (78, 139, 116), (129, 171, 143), (187, 197, 166), (80, 111, 89), ("succulent",)),
    SpeciesProfile("pitcherPlant", "pitcher-plant", "foliage", (72, 126, 82), (119, 145, 88), (150, 63, 77), (78, 104, 62), ("pitcher",)),
    SpeciesProfile("waterLily", "water-lily", "meadow", (54, 126, 91), (93, 151, 104), (236, 211, 224), (69, 104, 72), ("water-lily",)),
)


def main() -> None:
    if "--allow-procedural-placeholder-assets" not in sys.argv:
        raise SystemExit(
            "This procedural placeholder generator is retired for normal use. "
            "Use one-by-one AI stage images instead, or pass "
            "--allow-procedural-placeholder-assets for an explicit emergency placeholder rebuild."
        )
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    for profile in SPECIES:
        for stage_index in range(STAGE_COUNT):
            image = render_stage(profile, stage_index)
            output_path = OUTPUT_DIR / f"{profile.slug}-stage-{stage_index:02d}.png"
            image.save(output_path)
            print(output_path.relative_to(ROOT))


def render_stage(profile: SpeciesProfile, stage_index: int) -> Image.Image:
    growth = (stage_index + 1) / STAGE_COUNT
    seed = stable_seed(profile.slug, stage_index)
    rng = random.Random(seed)
    if profile.kind == "tree":
        size = (420, 620)
    elif profile.kind == "flower":
        size = (330, 470)
    elif profile.kind == "foliage":
        size = (360, 470)
    else:
        size = (380, 320)

    image = Image.new("RGBA", size, (0, 0, 0, 0))
    if profile.kind == "tree":
        draw_tree(image, profile, growth, rng)
    elif profile.kind == "flower":
        draw_flower(image, profile, growth, rng)
    elif profile.kind == "foliage":
        draw_foliage(image, profile, growth, rng)
    else:
        draw_meadow(image, profile, growth, rng)

    image = image.filter(ImageFilter.UnsharpMask(radius=1.2, percent=60, threshold=8))
    return crop_to_alpha(image, padding=16)


def draw_tree(image: Image.Image, profile: SpeciesProfile, growth: float, rng: random.Random) -> None:
    draw = ImageDraw.Draw(image, "RGBA")
    width, height = image.size
    anchor = (width * 0.50, height - 8)
    total_height = height * (0.18 + 0.76 * growth)
    trunk_top = (anchor[0] + rng.uniform(-8, 8) * growth, anchor[1] - total_height * (0.70 + 0.12 * growth))
    trunk_width = max(5, 9 + 18 * growth)
    draw_tapered_stem(draw, anchor, trunk_top, trunk_width, profile.stem)

    branch_count = max(2, int(4 + growth * 11))
    for index in range(branch_count):
        t = (index + 1) / (branch_count + 1)
        side = -1 if index % 2 == 0 else 1
        start = (
            lerp(anchor[0], trunk_top[0], t * 0.88),
            lerp(anchor[1], trunk_top[1], t * 0.88),
        )
        length = total_height * rng.uniform(0.12, 0.26) * (0.5 + growth)
        end = (
            start[0] + side * length * rng.uniform(0.55, 1.05),
            start[1] - length * rng.uniform(0.25, 0.70),
        )
        draw.line([start, end], fill=with_alpha(shade(profile.stem, 0.80), 150), width=max(1, int(trunk_width * 0.20)))

    if growth < 0.20:
        draw_seedling(image, anchor, profile, growth, rng)
        return

    if "willow" in profile.traits:
        draw_willow_canopy(image, trunk_top, total_height, profile, growth, rng)
    elif "birch" in profile.traits:
        draw_birch_bark(draw, anchor, trunk_top, trunk_width)
        draw_leaf_cloud(image, trunk_top, total_height, profile, growth, rng, airy=True)
    elif "bonsai" in profile.traits:
        draw_bonsai_canopy(image, trunk_top, total_height, profile, growth, rng)
    elif "maple" in profile.traits:
        draw_leaf_cloud(image, trunk_top, total_height, profile, growth, rng, leaf_shape="maple")
    elif "olive" in profile.traits:
        draw_leaf_cloud(image, trunk_top, total_height, profile, growth, rng, narrow=True, airy=True)
    else:
        draw_leaf_cloud(image, trunk_top, total_height, profile, growth, rng)

    if growth > 0.62 and any(trait in profile.traits for trait in ("blossom", "large-blossom", "citrus")):
        draw_tree_accents(image, trunk_top, total_height, profile, growth, rng)


def draw_flower(image: Image.Image, profile: SpeciesProfile, growth: float, rng: random.Random) -> None:
    draw = ImageDraw.Draw(image, "RGBA")
    width, height = image.size
    anchor = (width * 0.5, height - 8)
    stem_count = max(1, int(1 + growth * 5))
    spread = width * (0.05 + growth * 0.22)
    for index in range(stem_count):
        offset = 0 if stem_count == 1 else lerp(-spread, spread, index / max(1, stem_count - 1))
        stem_height = height * rng.uniform(0.28, 0.80) * (0.45 + growth * 0.80)
        top = (anchor[0] + offset + rng.uniform(-8, 8), anchor[1] - stem_height)
        base = (anchor[0] + offset * 0.22, anchor[1])
        draw_curve(draw, base, (base[0] + offset * 0.22, (base[1] + top[1]) / 2), top, profile.stem, max(3, int(4 + growth * 4)))
        leaf_pairs = max(1, int(growth * 4))
        for leaf_index in range(leaf_pairs):
            t = (leaf_index + 1) / (leaf_pairs + 1)
            center = (lerp(base[0], top[0], t), lerp(base[1], top[1], t))
            side = -1 if leaf_index % 2 == 0 else 1
            draw_leaf(image, center, (24 + 20 * growth, 10 + 9 * growth), side * rng.uniform(24, 52), profile.secondary, alpha=220)

        if growth > 0.38:
            bloom = min(1, (growth - 0.38) / 0.62)
            draw_bloom(image, top, profile, bloom, rng)
    draw_base_leaves(image, anchor, profile, growth, rng)


def draw_foliage(image: Image.Image, profile: SpeciesProfile, growth: float, rng: random.Random) -> None:
    width, height = image.size
    anchor = (width * 0.5, height - 8)
    if "frond" in profile.traits:
        draw_fern(image, anchor, profile, growth, rng)
    elif "vine" in profile.traits:
        draw_vines(image, anchor, profile, growth, rng)
    elif "bamboo" in profile.traits:
        draw_bamboo(image, anchor, profile, growth, rng)
    elif "succulent" in profile.traits:
        draw_succulent(image, anchor, profile, growth, rng)
    elif "pitcher" in profile.traits:
        draw_pitcher(image, anchor, profile, growth, rng)
    else:
        draw_herbs(image, anchor, profile, growth, rng)


def draw_meadow(image: Image.Image, profile: SpeciesProfile, growth: float, rng: random.Random) -> None:
    width, height = image.size
    anchor = (width * 0.5, height - 8)
    if "mushroom" in profile.traits:
        draw_mushrooms(image, anchor, profile, growth, rng)
    elif "lichen" in profile.traits:
        draw_lichens(image, anchor, profile, growth, rng)
    elif "water-lily" in profile.traits:
        draw_water_lily(image, anchor, profile, growth, rng)
    elif "cattail" in profile.traits:
        draw_cattails(image, anchor, profile, growth, rng)
    elif "grass" in profile.traits:
        draw_grass(image, anchor, profile, growth, rng)
    else:
        draw_groundcover(image, anchor, profile, growth, rng)


def draw_leaf_cloud(
    image: Image.Image,
    top: tuple[float, float],
    total_height: float,
    profile: SpeciesProfile,
    growth: float,
    rng: random.Random,
    leaf_shape: str = "oval",
    airy: bool = False,
    narrow: bool = False,
) -> None:
    count = int((58 if airy else 96) * growth + 18)
    radius_x = total_height * (0.30 if narrow else 0.43) * growth
    radius_y = total_height * 0.28 * growth
    center = (top[0], top[1] + radius_y * 0.18)
    draw_canopy_backfill(image, center, radius_x, radius_y, profile, growth, rng, airy=airy, narrow=narrow)
    for index in range(count):
        angle = rng.uniform(0, math.tau)
        distance = math.sqrt(rng.random())
        x = center[0] + math.cos(angle) * radius_x * distance
        y = center[1] + math.sin(angle) * radius_y * distance
        size = rng.uniform(20, 48) * (0.74 + growth * 0.66)
        color = shade(profile.primary if index % 3 else profile.secondary, rng.uniform(0.78, 1.22))
        if leaf_shape == "maple":
            draw_star_leaf(image, (x, y), size, color, rng.uniform(-40, 40))
        else:
            draw_leaf(image, (x, y), (size, size * rng.uniform(0.42, 0.68)), rng.uniform(-80, 80), color, alpha=220)


def draw_canopy_backfill(
    image: Image.Image,
    center: tuple[float, float],
    radius_x: float,
    radius_y: float,
    profile: SpeciesProfile,
    growth: float,
    rng: random.Random,
    airy: bool,
    narrow: bool,
) -> None:
    if growth < 0.26:
        return

    leaves = int((18 if airy else 30) + growth * (12 if airy else 22))
    for index in range(leaves):
        angle = rng.uniform(0, math.tau)
        distance = rng.random() ** 0.72
        x = center[0] + math.cos(angle) * radius_x * distance
        y = center[1] + math.sin(angle) * radius_y * distance
        size = rng.uniform(34, 72) * (0.58 + growth * 0.52)
        color = shade(profile.primary if index % 2 else profile.secondary, rng.uniform(0.84, 1.10))
        draw_leaf(
            image,
            (x, y),
            (size * (0.74 if narrow else 1.0), size * rng.uniform(0.36, 0.56)),
            rng.uniform(-75, 75),
            color,
            alpha=118 if airy else 132,
        )


def draw_willow_canopy(image: Image.Image, top: tuple[float, float], total_height: float, profile: SpeciesProfile, growth: float, rng: random.Random) -> None:
    draw_leaf_cloud(image, top, total_height, profile, growth, rng, airy=True)
    draw = ImageDraw.Draw(image, "RGBA")
    for _ in range(int(14 + growth * 28)):
        start_x = top[0] + rng.uniform(-total_height * 0.34, total_height * 0.34) * growth
        start_y = top[1] + rng.uniform(8, total_height * 0.25)
        length = total_height * rng.uniform(0.18, 0.34) * growth
        end = (start_x + rng.uniform(-8, 8), start_y + length)
        draw_curve(draw, (start_x, start_y), (start_x + rng.uniform(-18, 18), start_y + length * 0.45), end, profile.secondary, 2)
        for t in (0.28, 0.52, 0.76):
            draw_leaf(image, (lerp(start_x, end[0], t), lerp(start_y, end[1], t)), (14, 5), rng.uniform(70, 110), profile.primary, alpha=210)


def draw_bonsai_canopy(image: Image.Image, top: tuple[float, float], total_height: float, profile: SpeciesProfile, growth: float, rng: random.Random) -> None:
    for offset in (-0.32, 0.0, 0.34):
        local_top = (top[0] + total_height * offset * growth, top[1] + rng.uniform(-18, 20))
        draw_leaf_cloud(image, local_top, total_height * 0.55, profile, growth, rng, airy=True)


def draw_tree_accents(image: Image.Image, top: tuple[float, float], total_height: float, profile: SpeciesProfile, growth: float, rng: random.Random) -> None:
    bloom = min(1, (growth - 0.62) / 0.38)
    count = int(5 + 20 * bloom)
    for _ in range(count):
        center = (
            top[0] + rng.uniform(-total_height * 0.34, total_height * 0.34) * growth,
            top[1] + rng.uniform(-total_height * 0.12, total_height * 0.30) * growth,
        )
        if "citrus" in profile.traits:
            draw_fruit(image, center, 8 + 8 * bloom, profile.accent)
        else:
            draw_petal_flower(image, center, 6 + 8 * bloom, profile.accent, petals=5)


def draw_bloom(image: Image.Image, center: tuple[float, float], profile: SpeciesProfile, bloom: float, rng: random.Random) -> None:
    if "droop" in profile.traits:
        for strand in range(3):
            x = center[0] + (strand - 1) * 12
            for bead in range(max(2, int(4 + bloom * 7))):
                y = center[1] + bead * (7 + bloom * 3)
                draw_petal_flower(image, (x + rng.uniform(-4, 4), y), 4 + bloom * 4, profile.accent, petals=4)
    elif "spike" in profile.traits:
        for bead in range(max(3, int(5 + bloom * 8))):
            y = center[1] + bead * 9
            draw_bell(image, (center[0] + rng.uniform(-8, 8), y), 11 + bloom * 5, profile.accent)
    elif "cluster" in profile.traits or "ruffle" in profile.traits:
        for _ in range(int(8 + bloom * 18)):
            draw_petal_flower(
                image,
                (center[0] + rng.uniform(-22, 22) * bloom, center[1] + rng.uniform(-18, 18) * bloom),
                5 + bloom * 5,
                shade(profile.accent, rng.uniform(0.86, 1.14)),
                petals=5,
            )
    elif "orchid" in profile.traits:
        draw_petal_flower(image, center, 18 + bloom * 14, profile.accent, petals=5, elongated=True)
        draw_petal_flower(image, (center[0] + 18, center[1] + 22), 12 + bloom * 8, shade(profile.accent, 1.1), petals=5, elongated=True)
    elif "iris" in profile.traits:
        for angle in (-65, 0, 65):
            draw_leaf(image, center, (26 + bloom * 22, 11 + bloom * 7), angle, profile.accent, alpha=235)
    elif "lily" in profile.traits:
        draw_petal_flower(image, center, 18 + bloom * 12, profile.accent, petals=6, elongated=True)
    elif "rose" in profile.traits:
        for radius in (18, 13, 8):
            draw_petal_flower(image, center, radius * (0.65 + bloom * 0.35), shade(profile.accent, 1 + (18 - radius) * 0.01), petals=7)
    elif "cup" in profile.traits:
        draw_petal_flower(image, center, 18 + bloom * 12, profile.accent, petals=4)
    elif "star" in profile.traits:
        draw_petal_flower(image, center, 13 + bloom * 9, profile.accent, petals=6, elongated=True)
    else:
        draw_petal_flower(image, center, 15 + bloom * 10, profile.accent, petals=6)


def draw_fern(image: Image.Image, anchor: tuple[float, float], profile: SpeciesProfile, growth: float, rng: random.Random) -> None:
    draw = ImageDraw.Draw(image, "RGBA")
    fronds = int(5 + growth * 9)
    for index in range(fronds):
        angle = lerp(-72, 72, index / max(1, fronds - 1)) + rng.uniform(-8, 8)
        length = (95 + 210 * growth) * rng.uniform(0.78, 1.08)
        end = point_from(anchor, angle - 90, length)
        draw_curve(draw, anchor, point_from(anchor, angle - 90, length * 0.45), end, profile.stem, max(2, int(3 + growth * 3)))
        leaflets = int(5 + growth * 9)
        for leaflet in range(leaflets):
            t = (leaflet + 1) / (leaflets + 1)
            center = (lerp(anchor[0], end[0], t), lerp(anchor[1], end[1], t))
            side_size = (16 + 14 * growth) * (1 - t * 0.45)
            draw_leaf(image, center, (side_size, side_size * 0.33), angle + 28, profile.primary, alpha=220)
            draw_leaf(image, center, (side_size, side_size * 0.33), angle - 28, profile.secondary, alpha=210)


def draw_vines(image: Image.Image, anchor: tuple[float, float], profile: SpeciesProfile, growth: float, rng: random.Random) -> None:
    draw = ImageDraw.Draw(image, "RGBA")
    strands = int(3 + growth * 6)
    for strand in range(strands):
        x_offset = rng.uniform(-70, 70) * growth
        start = (anchor[0] + x_offset * 0.2, anchor[1])
        end = (anchor[0] + x_offset, anchor[1] - rng.uniform(130, 330) * growth)
        control = ((start[0] + end[0]) / 2 + rng.uniform(-44, 44), (start[1] + end[1]) / 2)
        draw_curve(draw, start, control, end, profile.stem, max(2, int(3 + growth * 2)))
        leaves = int(4 + growth * 9)
        for leaf_index in range(leaves):
            t = (leaf_index + 1) / (leaves + 1)
            center = quadratic_point(start, control, end, t)
            draw_leaf(image, center, (22 + growth * 12, 12 + growth * 8), rng.uniform(-80, 80), profile.primary if leaf_index % 2 else profile.secondary, alpha=220)


def draw_bamboo(image: Image.Image, anchor: tuple[float, float], profile: SpeciesProfile, growth: float, rng: random.Random) -> None:
    draw = ImageDraw.Draw(image, "RGBA")
    culms = int(2 + growth * 7)
    for index in range(culms):
        x = anchor[0] + lerp(-90, 90, index / max(1, culms - 1)) * growth
        height = rng.uniform(120, 340) * growth
        top = (x + rng.uniform(-14, 14), anchor[1] - height)
        draw.line([(x, anchor[1]), top], fill=with_alpha(profile.stem, 230), width=max(4, int(5 + growth * 5)))
        sections = max(2, int(height / 42))
        for s in range(sections):
            y = lerp(anchor[1], top[1], s / sections)
            draw.line([(x - 7, y), (x + 7, y)], fill=with_alpha(shade(profile.stem, 0.75), 190), width=2)
        for _ in range(int(2 + growth * 4)):
            center = (x + rng.uniform(-18, 18), top[1] + rng.uniform(8, height * 0.55))
            draw_leaf(image, center, (34, 8), rng.uniform(-45, 45), profile.primary, alpha=220)


def draw_succulent(image: Image.Image, anchor: tuple[float, float], profile: SpeciesProfile, growth: float, rng: random.Random) -> None:
    visual_growth = 0.34 + growth * 0.66
    rings = int(3 + visual_growth * 5)
    for ring in range(rings, 0, -1):
        petals = int(7 + ring * 3)
        radius = (14 + ring * 18) * visual_growth
        for petal in range(petals):
            angle = petal * 360 / petals + ring * 11
            center = point_from(anchor, angle, radius * 0.32)
            draw_leaf(image, center, (radius * 0.74, radius * 0.27), angle, shade(profile.primary, 0.85 + ring * 0.04), alpha=228)


def draw_pitcher(image: Image.Image, anchor: tuple[float, float], profile: SpeciesProfile, growth: float, rng: random.Random) -> None:
    draw_base_leaves(image, anchor, profile, growth, rng)
    count = int(2 + growth * 5)
    draw = ImageDraw.Draw(image, "RGBA")
    for index in range(count):
        x = anchor[0] + lerp(-70, 70, index / max(1, count - 1)) * growth
        h = rng.uniform(70, 145) * growth
        top = (x + rng.uniform(-8, 8), anchor[1] - h)
        draw_curve(draw, (x, anchor[1]), (x + rng.uniform(-14, 14), anchor[1] - h * 0.45), top, profile.stem, 3)
        body = (top[0], top[1] + 22)
        draw_round_pod(image, body, (22 + 14 * growth, 46 + 28 * growth), profile.accent)
        draw_leaf(image, (body[0], body[1] - 30), (28, 9), rng.uniform(-25, 25), shade(profile.accent, 1.18), alpha=225)


def draw_herbs(image: Image.Image, anchor: tuple[float, float], profile: SpeciesProfile, growth: float, rng: random.Random) -> None:
    draw = ImageDraw.Draw(image, "RGBA")
    stems = int(5 + growth * 12)
    for index in range(stems):
        angle = rng.uniform(-40, 40)
        length = rng.uniform(70, 190) * growth
        end = point_from(anchor, angle - 90, length)
        draw_curve(draw, anchor, point_from(anchor, angle - 90, length * 0.48), end, profile.stem, max(2, int(2 + growth * 3)))
        for t in (0.34, 0.56, 0.78):
            center = (lerp(anchor[0], end[0], t), lerp(anchor[1], end[1], t))
            draw_leaf(image, center, (18 + growth * 14, 8 + growth * 7), angle + rng.uniform(-55, 55), profile.primary, alpha=220)


def draw_groundcover(image: Image.Image, anchor: tuple[float, float], profile: SpeciesProfile, growth: float, rng: random.Random) -> None:
    draw = ImageDraw.Draw(image, "RGBA")
    width = image.size[0] * (0.24 + growth * 0.52)
    count = int(16 + growth * 56)
    for index in range(count):
        x = anchor[0] + rng.uniform(-width / 2, width / 2)
        y = anchor[1] - rng.uniform(4, 60 + growth * 82)
        if "clover" in profile.traits:
            for angle in (0, 120, 240):
                draw_leaf(image, (x + math.cos(math.radians(angle)) * 5, y + math.sin(math.radians(angle)) * 4), (13, 9), angle, profile.primary, alpha=220)
        else:
            draw_leaf(image, (x, y), (15 + growth * 11, 7 + growth * 7), rng.uniform(-80, 80), profile.primary if index % 2 else profile.secondary, alpha=218)
        if growth > 0.55 and (index + stable_seed(profile.slug, 0)) % 11 == 0:
            draw_petal_flower(image, (x, y - 8), 4 + growth * 4, profile.accent, petals=5)
    draw.line([(anchor[0] - width / 2, anchor[1]), (anchor[0] + width / 2, anchor[1])], fill=with_alpha(profile.stem, 70), width=3)


def draw_grass(image: Image.Image, anchor: tuple[float, float], profile: SpeciesProfile, growth: float, rng: random.Random) -> None:
    draw = ImageDraw.Draw(image, "RGBA")
    blades = int(18 + growth * 62)
    spread = image.size[0] * (0.20 + growth * 0.42)
    for _ in range(blades):
        x = anchor[0] + rng.uniform(-spread / 2, spread / 2)
        length = rng.uniform(58, 160) * growth
        bend = rng.uniform(-42, 42)
        draw_curve(draw, (x, anchor[1]), (x + bend * 0.4, anchor[1] - length * 0.48), (x + bend, anchor[1] - length), profile.primary if rng.random() > 0.35 else profile.secondary, 2)
        if growth > 0.68 and rng.random() > 0.80:
            draw_leaf(image, (x + bend, anchor[1] - length), (22, 5), rng.uniform(-70, 70), profile.accent, alpha=210)


def draw_cattails(image: Image.Image, anchor: tuple[float, float], profile: SpeciesProfile, growth: float, rng: random.Random) -> None:
    draw_grass(image, anchor, profile, growth, rng)
    draw = ImageDraw.Draw(image, "RGBA")
    stalks = int(2 + growth * 6)
    for index in range(stalks):
        x = anchor[0] + lerp(-90, 90, index / max(1, stalks - 1)) * growth
        h = rng.uniform(110, 230) * growth
        top = (x + rng.uniform(-8, 8), anchor[1] - h)
        draw.line([(x, anchor[1]), top], fill=with_alpha(profile.stem, 210), width=3)
        if growth > 0.45:
            draw_round_pod(image, (top[0], top[1] + 16), (13, 37), profile.accent)


def draw_mushrooms(image: Image.Image, anchor: tuple[float, float], profile: SpeciesProfile, growth: float, rng: random.Random) -> None:
    draw_groundcover(image, anchor, profile, min(0.55, growth), rng)
    draw = ImageDraw.Draw(image, "RGBA")
    count = int(3 + growth * 10)
    spread = image.size[0] * (0.16 + growth * 0.34)
    for _ in range(count):
        x = anchor[0] + rng.uniform(-spread / 2, spread / 2)
        stem_h = rng.uniform(26, 72) * growth
        cap_w = rng.uniform(22, 46) * growth
        draw.line([(x, anchor[1]), (x, anchor[1] - stem_h)], fill=with_alpha((218, 203, 176), 230), width=max(4, int(cap_w * 0.18)))
        cap_box = [x - cap_w / 2, anchor[1] - stem_h - cap_w * 0.36, x + cap_w / 2, anchor[1] - stem_h + cap_w * 0.24]
        draw.ellipse(cap_box, fill=with_alpha(shade(profile.accent, rng.uniform(0.84, 1.12)), 235))


def draw_lichens(image: Image.Image, anchor: tuple[float, float], profile: SpeciesProfile, growth: float, rng: random.Random) -> None:
    draw = ImageDraw.Draw(image, "RGBA")
    width = image.size[0] * (0.22 + growth * 0.46)
    count = int(20 + growth * 55)
    for _ in range(count):
        x = anchor[0] + rng.uniform(-width / 2, width / 2)
        y = anchor[1] - rng.uniform(0, 48 + growth * 64)
        r = rng.uniform(4, 13) * (0.65 + growth * 0.55)
        draw.ellipse([x - r, y - r * 0.62, x + r, y + r * 0.62], fill=with_alpha(shade(profile.primary if rng.random() > 0.4 else profile.secondary, rng.uniform(0.82, 1.14)), 210))


def draw_water_lily(image: Image.Image, anchor: tuple[float, float], profile: SpeciesProfile, growth: float, rng: random.Random) -> None:
    draw = ImageDraw.Draw(image, "RGBA")
    count = int(2 + growth * 7)
    spread = image.size[0] * (0.18 + growth * 0.42)
    for index in range(count):
        x = anchor[0] + lerp(-spread / 2, spread / 2, index / max(1, count - 1)) + rng.uniform(-10, 10)
        y = anchor[1] - rng.uniform(10, 92) * growth
        draw_leaf(image, (x, y), (42 + 28 * growth, 26 + 16 * growth), rng.uniform(-22, 22), profile.primary, alpha=224)
    if growth > 0.48:
        draw_petal_flower(image, (anchor[0], anchor[1] - 76 * growth), 14 + 18 * growth, profile.accent, petals=9, elongated=True)
    draw.line([(anchor[0] - spread / 2, anchor[1]), (anchor[0] + spread / 2, anchor[1])], fill=with_alpha(profile.stem, 50), width=2)


def draw_seedling(image: Image.Image, anchor: tuple[float, float], profile: SpeciesProfile, growth: float, rng: random.Random) -> None:
    draw = ImageDraw.Draw(image, "RGBA")
    top = (anchor[0] + rng.uniform(-6, 6), anchor[1] - 70 * (0.5 + growth))
    draw.line([anchor, top], fill=with_alpha(profile.stem, 220), width=max(3, int(4 + growth * 5)))
    draw_leaf(image, (top[0] - 12, top[1] + 12), (26, 12), -32, profile.primary, alpha=230)
    draw_leaf(image, (top[0] + 14, top[1] + 8), (24, 11), 34, profile.secondary, alpha=220)


def draw_base_leaves(image: Image.Image, anchor: tuple[float, float], profile: SpeciesProfile, growth: float, rng: random.Random) -> None:
    count = int(3 + growth * 8)
    for index in range(count):
        angle = lerp(-72, 72, index / max(1, count - 1)) + rng.uniform(-8, 8)
        center = point_from(anchor, angle - 90, rng.uniform(12, 42) * growth)
        draw_leaf(image, center, (28 + 26 * growth, 10 + 12 * growth), angle, profile.primary if index % 2 else profile.secondary, alpha=220)


def draw_tapered_stem(draw: ImageDraw.ImageDraw, base: tuple[float, float], top: tuple[float, float], width: float, color: tuple[int, int, int]) -> None:
    steps = 6
    for index in range(steps):
        t0 = index / steps
        t1 = (index + 1) / steps
        p0 = (lerp(base[0], top[0], t0), lerp(base[1], top[1], t0))
        p1 = (lerp(base[0], top[0], t1), lerp(base[1], top[1], t1))
        local_width = max(2, int(width * (1 - t0 * 0.64)))
        draw.line([p0, p1], fill=with_alpha(shade(color, 0.84 + t0 * 0.22), 240), width=local_width)
    draw.line([base, top], fill=with_alpha(shade(color, 1.18), 120), width=max(1, int(width * 0.18)))


def draw_birch_bark(draw: ImageDraw.ImageDraw, base: tuple[float, float], top: tuple[float, float], width: float) -> None:
    steps = 9
    for index in range(1, steps):
        t = index / steps
        x = lerp(base[0], top[0], t)
        y = lerp(base[1], top[1], t)
        draw.line([(x - width * 0.22, y), (x + width * 0.28, y + 3)], fill=(70, 68, 58, 160), width=2)


def draw_petal_flower(
    image: Image.Image,
    center: tuple[float, float],
    radius: float,
    color: tuple[int, int, int],
    petals: int,
    elongated: bool = False,
) -> None:
    for index in range(petals):
        angle = index * 360 / petals
        petal_center = point_from(center, angle, radius * 0.48)
        size = (radius * (1.18 if elongated else 0.92), radius * 0.42)
        draw_leaf(image, petal_center, size, angle, color, alpha=232)
    draw_round_pod(image, center, (radius * 0.34, radius * 0.34), shade(color, 0.72))


def draw_bell(image: Image.Image, center: tuple[float, float], size: float, color: tuple[int, int, int]) -> None:
    draw_round_pod(image, center, (size, size * 1.35), color)
    draw_leaf(image, (center[0], center[1] + size * 0.50), (size * 0.9, size * 0.22), 0, shade(color, 1.14), alpha=230)


def draw_round_pod(image: Image.Image, center: tuple[float, float], size: tuple[float, float], color: tuple[int, int, int]) -> None:
    draw = ImageDraw.Draw(image, "RGBA")
    x, y = center
    w, h = size
    draw.ellipse([x - w / 2, y - h / 2, x + w / 2, y + h / 2], fill=with_alpha(color, 230))
    draw.ellipse([x - w * 0.26, y - h * 0.34, x + w * 0.08, y - h * 0.04], fill=with_alpha(shade(color, 1.28), 90))


def draw_fruit(image: Image.Image, center: tuple[float, float], radius: float, color: tuple[int, int, int]) -> None:
    draw_round_pod(image, center, (radius * 1.05, radius * 0.96), color)


def draw_star_leaf(image: Image.Image, center: tuple[float, float], size: float, color: tuple[int, int, int], angle: float) -> None:
    for offset in (-34, -16, 0, 16, 34):
        draw_leaf(image, center, (size * 0.62, size * 0.20), angle + offset, color, alpha=220)


def draw_leaf(
    image: Image.Image,
    center: tuple[float, float],
    size: tuple[float, float],
    angle: float,
    color: tuple[int, int, int],
    alpha: int,
) -> None:
    w = max(2, int(size[0] * 2.2))
    h = max(2, int(size[1] * 2.2))
    patch = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(patch, "RGBA")
    draw.ellipse([w * 0.08, h * 0.22, w * 0.92, h * 0.78], fill=with_alpha(color, alpha))
    draw.ellipse([w * 0.18, h * 0.28, w * 0.52, h * 0.48], fill=with_alpha(shade(color, 1.24), max(30, alpha // 4)))
    draw.line([(w * 0.16, h * 0.50), (w * 0.86, h * 0.50)], fill=with_alpha(shade(color, 0.72), min(180, alpha)), width=max(1, int(h * 0.035)))
    rotated = patch.rotate(angle, resample=Image.Resampling.BICUBIC, expand=True)
    image.alpha_composite(rotated, (int(center[0] - rotated.width / 2), int(center[1] - rotated.height / 2)))


def draw_curve(
    draw: ImageDraw.ImageDraw,
    start: tuple[float, float],
    control: tuple[float, float],
    end: tuple[float, float],
    color: tuple[int, int, int],
    width: int,
) -> None:
    points = [quadratic_point(start, control, end, t / 18) for t in range(19)]
    draw.line(points, fill=with_alpha(color, 220), width=width, joint="curve")
    if width > 3:
        draw.line(points, fill=with_alpha(shade(color, 1.2), 70), width=max(1, width // 3), joint="curve")


def crop_to_alpha(image: Image.Image, padding: int) -> Image.Image:
    alpha = image.getchannel("A")
    bbox = alpha.getbbox()
    if bbox is None:
        return image
    left, top, right, bottom = bbox
    left = max(0, left - padding)
    top = max(0, top - padding)
    right = min(image.width, right + padding)
    bottom = min(image.height, bottom + padding // 3)
    cropped = image.crop((left, top, right, bottom))
    min_width, min_height = (72, 90)
    if cropped.width >= min_width and cropped.height >= min_height:
        return cropped
    canvas = Image.new("RGBA", (max(min_width, cropped.width), max(min_height, cropped.height)), (0, 0, 0, 0))
    canvas.alpha_composite(cropped, ((canvas.width - cropped.width) // 2, canvas.height - cropped.height))
    return canvas


def quadratic_point(
    start: tuple[float, float],
    control: tuple[float, float],
    end: tuple[float, float],
    t: float,
) -> tuple[float, float]:
    one_minus = 1 - t
    return (
        one_minus * one_minus * start[0] + 2 * one_minus * t * control[0] + t * t * end[0],
        one_minus * one_minus * start[1] + 2 * one_minus * t * control[1] + t * t * end[1],
    )


def point_from(point: tuple[float, float], angle_degrees: float, distance: float) -> tuple[float, float]:
    radians = math.radians(angle_degrees)
    return (point[0] + math.cos(radians) * distance, point[1] + math.sin(radians) * distance)


def lerp(a: float, b: float, t: float) -> float:
    return a + (b - a) * t


def shade(color: tuple[int, int, int], factor: float) -> tuple[int, int, int]:
    return tuple(max(0, min(255, int(channel * factor))) for channel in color)


def with_alpha(color: tuple[int, int, int], alpha: int) -> tuple[int, int, int, int]:
    return color[0], color[1], color[2], max(0, min(255, alpha))


def stable_seed(slug: str, stage_index: int) -> int:
    value = 17
    for character in slug:
        value = value * 31 + ord(character)
    return value + stage_index * 9_973


if __name__ == "__main__":
    main()
