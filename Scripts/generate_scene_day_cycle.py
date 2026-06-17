#!/usr/bin/env python3
from __future__ import annotations

import argparse
import base64
import json
import os
import subprocess
import sys
import urllib.error
import urllib.request
import uuid
from pathlib import Path

from PIL import Image, ImageEnhance


ROOT = Path(__file__).resolve().parents[1]
SCENE_DIR = ROOT / "Sources" / "PlantWallpaper" / "Resources" / "SceneAssets"
OPENAI_IMAGE_EDIT_ENDPOINT = "https://api.openai.com/v1/images/edits"
OPENAI_IMAGE_MODEL = "gpt-image-2"

PHASES = (
    {
        "slug": "sunrise",
        "label": "early sunrise",
        "prompt": "very early sunrise, low sun just above the left skyline, peach and pale lavender sky, faint high clouds, long soft shadows, calm humid tropical morning",
    },
    {
        "slug": "morning",
        "label": "clear morning",
        "prompt": "fresh clear morning, sun higher over the left skyline, clean blue upper sky, soft white trade-wind clouds, crisp but gentle shadows",
    },
    {
        "slug": "midday",
        "label": "bright midday",
        "prompt": "bright midday, sun high overhead, vivid blue sky, small realistic cumulus clouds, shorter shadows, warm Brazilian rooftop clarity",
    },
    {
        "slug": "afternoon",
        "label": "late afternoon",
        "prompt": "late afternoon, sun descending toward the right, warmer amber light on the terracotta surfaces, drifting cloud bands, longer angled shadows",
    },
    {
        "slug": "golden-hour",
        "label": "golden hour",
        "prompt": "golden hour, low warm sun near the horizon, glowing orange and rose sky, thin layered clouds, city skyline softly backlit, romantic but realistic",
    },
    {
        "slug": "night",
        "label": "night",
        "prompt": "beautiful clear night, deep blue tropical sky, soft moonlight, a few small stars, subtle city lights across the skyline, rooftop still readable and inviting",
    },
)


LOCAL_PRESETS = {
    "sunrise": {
        "brightness": 1.06,
        "contrast": 0.98,
        "color": 1.08,
        "top": (255, 214, 170, 82),
        "bottom": (252, 171, 108, 46),
    },
    "morning": {
        "brightness": 1.10,
        "contrast": 1.02,
        "color": 1.02,
        "top": (152, 205, 248, 74),
        "bottom": (255, 232, 184, 30),
    },
    "midday": {
        "brightness": 1.15,
        "contrast": 1.04,
        "color": 0.98,
        "top": (91, 178, 246, 82),
        "bottom": (255, 255, 232, 24),
    },
    "afternoon": {
        "brightness": 1.04,
        "contrast": 1.05,
        "color": 1.06,
        "top": (114, 174, 222, 52),
        "bottom": (245, 179, 113, 48),
    },
    "golden-hour": {
        "brightness": 0.98,
        "contrast": 1.03,
        "color": 1.14,
        "top": (245, 176, 128, 78),
        "bottom": (255, 126, 74, 50),
    },
    "night": {
        "brightness": 0.45,
        "contrast": 1.15,
        "color": 0.72,
        "top": (18, 38, 88, 148),
        "bottom": (6, 13, 30, 116),
    },
}


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Generate six time-of-day scene assets for a WallpaperGarden scene."
    )
    parser.add_argument("--scene", default="brazilian-rooftop-garden")
    parser.add_argument("--mode", choices=("local", "openai"), default="local")
    parser.add_argument("--source", type=Path)
    parser.add_argument("--output-directory", type=Path, default=SCENE_DIR)
    parser.add_argument("--openai-key", default=None)
    args = parser.parse_args()

    source = args.source or args.output_directory / f"{args.scene}.png"
    if not source.exists():
        print(f"missing source image: {source}", file=sys.stderr)
        return 1

    args.output_directory.mkdir(parents=True, exist_ok=True)

    if args.mode == "openai":
        api_key = args.openai_key or os.environ.get("OPENAI_API_KEY") or load_openai_key_from_keychain()
        if not api_key:
            print("OPENAI_API_KEY or saved WallpaperGarden Keychain key is required for --mode openai", file=sys.stderr)
            return 1
        for phase in PHASES:
            output = args.output_directory / f"{args.scene}-{phase['slug']}.png"
            generate_openai_phase(source, output, phase, api_key)
    else:
        for phase in PHASES:
            output = args.output_directory / f"{args.scene}-{phase['slug']}.png"
            generate_local_phase(source, output, phase["slug"])

    return 0


def load_openai_key_from_keychain() -> str | None:
    command = [
        "security",
        "find-generic-password",
        "-s",
        "com.chrisdimarco.wallpapergarden.openai",
        "-a",
        "openai-api-key",
        "-w",
    ]
    try:
        result = subprocess.run(command, check=False, capture_output=True, text=True)
    except OSError:
        return None
    key = result.stdout.strip()
    return key or None


def generate_openai_phase(source: Path, output: Path, phase: dict[str, str], api_key: str) -> None:
    prompt = day_cycle_prompt(phase)
    boundary = f"WallpaperGardenDayCycle-{uuid.uuid4()}"
    body = multipart_body(
        boundary=boundary,
        fields={
            "model": OPENAI_IMAGE_MODEL,
            "prompt": prompt,
            "size": "1536x1024",
            "quality": "medium",
            "output_format": "png",
            "n": "1",
        },
        image_data=source.read_bytes(),
    )
    request = urllib.request.Request(
        OPENAI_IMAGE_EDIT_ENDPOINT,
        data=body,
        method="POST",
        headers={
            "Authorization": f"Bearer {api_key.strip()}",
            "Content-Type": f"multipart/form-data; boundary={boundary}",
        },
    )

    print(f"Generating {output.name} with {OPENAI_IMAGE_MODEL}...")
    try:
        with urllib.request.urlopen(request, timeout=240) as response:
            payload = json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        message = exc.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"OpenAI generation failed for {phase['slug']}: {message}") from exc

    image_item = (payload.get("data") or [{}])[0]
    if image_item.get("b64_json"):
        output.write_bytes(base64.b64decode(image_item["b64_json"]))
        return

    if image_item.get("url"):
        with urllib.request.urlopen(image_item["url"], timeout=120) as image_response:
            output.write_bytes(image_response.read())
        return

    raise RuntimeError(f"OpenAI response did not include image data for {phase['slug']}")


def day_cycle_prompt(phase: dict[str, str]) -> str:
    return f"""Recreate the attached WallpaperGarden Brazilian rooftop garden wallpaper as the {phase['label']} member of a six-image time-of-day set.

The attached image is the source of truth. Preserve the exact rooftop layout, camera angle, architecture, terrace, skyline, blank soil beds, empty pots, tile details, and plant-free planting areas. Do not add plants, people, animals, text, UI, signs, or labels.

Apply this time-of-day transformation: {phase['prompt']}.

Make the sun position, sky color, cloud pattern, scene shadows, and rooftop lighting consistent with that time of day on a beautiful clear day in Brazil. Keep it realistic and suitable as a Mac desktop wallpaper.

Strictly avoid 2D graphic overlays, visible halos, circular lens-flare discs, oval cloud smudges, translucent pasted shapes, artificial sun rings, and artificial moon rings. Any sun, moon, stars, or clouds must look naturally photographed and integrated into the scene."""


def multipart_body(boundary: str, fields: dict[str, str], image_data: bytes) -> bytes:
    chunks: list[bytes] = []
    for key, value in sorted(fields.items()):
        chunks.append(f"--{boundary}\r\n".encode())
        chunks.append(f'Content-Disposition: form-data; name="{key}"\r\n\r\n'.encode())
        chunks.append(f"{value}\r\n".encode())
    chunks.append(f"--{boundary}\r\n".encode())
    chunks.append(b'Content-Disposition: form-data; name="image[]"; filename="source-wallpaper.png"\r\n')
    chunks.append(b"Content-Type: image/png\r\n\r\n")
    chunks.append(image_data)
    chunks.append(b"\r\n")
    chunks.append(f"--{boundary}--\r\n".encode())
    return b"".join(chunks)


def generate_local_phase(source: Path, output: Path, slug: str) -> None:
    preset = LOCAL_PRESETS[slug]
    image = Image.open(source).convert("RGB")
    image = ImageEnhance.Brightness(image).enhance(preset["brightness"])
    image = ImageEnhance.Contrast(image).enhance(preset["contrast"])
    image = ImageEnhance.Color(image).enhance(preset["color"])
    image = image.convert("RGBA")

    apply_vertical_tint(image, preset["top"], preset["bottom"])
    output.parent.mkdir(parents=True, exist_ok=True)
    image.convert("RGB").save(output, "PNG", optimize=True)
    print(f"Wrote {output}")


def apply_vertical_tint(image: Image.Image, top: tuple[int, int, int, int], bottom: tuple[int, int, int, int]) -> None:
    width, height = image.size
    overlay = Image.new("RGBA", image.size, (0, 0, 0, 0))
    pixels = overlay.load()
    for y in range(height):
        progress = y / max(1, height - 1)
        alpha_scale = 1.0 - 0.45 * progress
        color = tuple(
            int(top[channel] * (1 - progress) + bottom[channel] * progress)
            for channel in range(3)
        )
        alpha = int((top[3] * (1 - progress) + bottom[3] * progress) * alpha_scale)
        for x in range(width):
            pixels[x, y] = (*color, alpha)
    image.alpha_composite(overlay)


if __name__ == "__main__":
    raise SystemExit(main())
