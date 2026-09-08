"""Normalize approved weapon concepts into anchored game animation bases.

The concepts are composition references, not runtime textures.  This tool
removes generated backdrop pixels, preserves the approved silhouette, scales
the visible hero to the current 345 px body height, and maps the character's
foot anchor to the same Y=403 baseline used by the polished longsword frames.
"""

from __future__ import annotations

from collections import deque
from dataclasses import dataclass
from pathlib import Path

from PIL import Image


PROJECT_ROOT = Path(__file__).resolve().parents[1]
CONCEPT_DIR = PROJECT_ROOT / "docs" / "weapon_concepts"
OUTPUT_ROOT = PROJECT_ROOT / "assets" / "characters" / "weapon_sets"
FOOT_BASELINE_Y = 403
TARGET_VISIBLE_HEIGHT = 345


@dataclass(frozen=True)
class PoseSpec:
    source: Path
    output: Path
    canvas_size: tuple[int, int]
    source_body_anchor_x: int
    background_mode: str


POSES = (
    PoseSpec(
        source=CONCEPT_DIR / "shadow_twin_blades_idle_concept_v1.png",
        output=OUTPUT_ROOT / "twin_blades" / "hero_idle.png",
        canvas_size=(640, 416),
        source_body_anchor_x=810,
        background_mode="alpha",
    ),
    PoseSpec(
        source=CONCEPT_DIR / "falling_star_greatblade_rear_carry_concept_v2.png",
        output=OUTPUT_ROOT / "greatsword" / "hero_idle.png",
        canvas_size=(768, 416),
        source_body_anchor_x=920,
        background_mode="flood_white",
    ),
)


def clear_low_alpha(image: Image.Image) -> Image.Image:
    cleaned = image.convert("RGBA")
    red, green, blue, alpha = cleaned.split()
    alpha = alpha.point(lambda value: 0 if value < 4 else value)
    return Image.merge("RGBA", (red, green, blue, alpha))


def is_checker_background(pixel: tuple[int, int, int, int]) -> bool:
    red, green, blue, _alpha = pixel
    return min(red, green, blue) >= 230 and max(red, green, blue) - min(red, green, blue) <= 8


def clear_connected_white_background(image: Image.Image) -> Image.Image:
    """Flood only edge-connected near-white pixels so white hair stays intact."""
    cleaned = image.convert("RGBA")
    width, height = cleaned.size
    pixels = cleaned.load()
    queue: deque[tuple[int, int]] = deque()
    visited: set[tuple[int, int]] = set()

    for x in range(width):
        queue.append((x, 0))
        queue.append((x, height - 1))
    for y in range(height):
        queue.append((0, y))
        queue.append((width - 1, y))

    while queue:
        x, y = queue.popleft()
        point = (x, y)
        if point in visited or not is_checker_background(pixels[x, y]):
            continue
        visited.add(point)
        if x > 0:
            queue.append((x - 1, y))
        if x + 1 < width:
            queue.append((x + 1, y))
        if y > 0:
            queue.append((x, y - 1))
        if y + 1 < height:
            queue.append((x, y + 1))

    for x, y in visited:
        red, green, blue, _alpha = pixels[x, y]
        pixels[x, y] = (red, green, blue, 0)
    return clear_low_alpha(cleaned)


def normalize_pose(spec: PoseSpec) -> Image.Image:
    source = Image.open(spec.source).convert("RGBA")
    if spec.background_mode == "flood_white":
        source = clear_connected_white_background(source)
    else:
        source = clear_low_alpha(source)

    visible_bounds = source.getchannel("A").getbbox()
    if visible_bounds is None:
        raise RuntimeError(f"No visible pixels in {spec.source}")
    left, top, right, bottom = visible_bounds
    scale = TARGET_VISIBLE_HEIGHT / float(bottom - top)
    resized_size = (
        max(1, round(source.width * scale)),
        max(1, round(source.height * scale)),
    )
    resized = source.resize(resized_size, Image.Resampling.NEAREST)
    resized_bounds = resized.getchannel("A").getbbox()
    if resized_bounds is None:
        raise RuntimeError(f"Resized pose is empty: {spec.output}")

    canvas_width, canvas_height = spec.canvas_size
    target_anchor_x = canvas_width // 2
    target_x = round(target_anchor_x - spec.source_body_anchor_x * scale)
    target_y = FOOT_BASELINE_Y + 1 - resized_bounds[3]
    canvas = Image.new("RGBA", spec.canvas_size, (0, 0, 0, 0))
    canvas.alpha_composite(resized, (target_x, target_y))

    output_bounds = canvas.getchannel("A").getbbox()
    if output_bounds is None:
        raise RuntimeError(f"Normalized pose is empty: {spec.output}")
    if output_bounds[0] < 4 or output_bounds[2] > canvas_width - 4:
        raise RuntimeError(f"Horizontal safety margin failed for {spec.output}: {output_bounds}")
    if output_bounds[3] != FOOT_BASELINE_Y + 1:
        raise RuntimeError(f"Foot baseline failed for {spec.output}: {output_bounds}")
    return canvas


def main() -> None:
    for spec in POSES:
        spec.output.parent.mkdir(parents=True, exist_ok=True)
        pose = normalize_pose(spec)
        pose.save(spec.output, optimize=True)
        print(f"wrote {spec.output.relative_to(PROJECT_ROOT)} {pose.size} {pose.getchannel('A').getbbox()}")


if __name__ == "__main__":
    main()
