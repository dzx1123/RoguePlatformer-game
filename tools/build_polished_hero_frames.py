"""Build centered, unclipped hero frames from the project's source artwork.

The source action strip contains overlapping poses.  The first five poses are
separate alpha-connected components, so they can be extracted without cutting
the cape or sword.  The slash and recovery poses already have clean masks in
the legacy frame exports; those masks are re-centered onto the same canvas.

The source walk poses barely move their feet.  A deterministic lower-body rig
therefore cuts only the two opaque leg silhouettes from the clean walk frame
and renders explicit contact, passing, tuck, fall, and landing poses.  The
coat, cape, arms, face, and complete sword always remain on one untouched body
layer, avoiding the rectangular part masks that previously damaged the art.
"""

from __future__ import annotations

from collections import deque
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw


PROJECT_ROOT = Path(__file__).resolve().parents[1]
SOURCE_PATH = PROJECT_ROOT / "assets/characters/swordsman-actions-reference-v1.png"
LEGACY_DIR = PROJECT_ROOT / "assets/characters/frames"
OUTPUT_DIR = PROJECT_ROOT / "assets/characters/frames_polished"

CANVAS_SIZE = (640, 416)
FOOT_ANCHOR_X = 320
FOOT_BASELINE_Y = 402

# The two largest lower-body clusters are the boots. Their midpoint is a much
# steadier animation anchor than the visual bounding-box center, which moves as
# the cape and sword swing around the character.
SOURCE_FRAME_SPECS = {
    "hero_idle.png": ((18, 214, 348, 558), 175.25),
    "hero_walk_1.png": ((310, 221, 647, 561), 470.25),
    "hero_walk_2.png": ((619, 224, 941, 558), 771.75),
    "hero_walk_3.png": ((911, 218, 1240, 557), 1069.50),
    "hero_windup.png": ((1223, 219, 1474, 558), 1373.75),
}

SLASH_FOOT_ANCHOR_X = 190.0
SLASH_SOURCE_LEFT = 1451
RECOVERY_SOURCE_LEFT = 1785

BACK_LEG_POLYGON = [
    (278, 326),
    (318, 326),
    (321, 346),
    (307, 367),
    (297, 404),
    (232, 404),
    (233, 380),
    (254, 354),
    (268, 340),
]
FRONT_LEG_POLYGON = [
    (329, 324),
    (374, 324),
    (374, 345),
    (389, 354),
    (414, 368),
    (414, 394),
    (349, 404),
    (346, 376),
    (338, 350),
]
BACK_LEG_PIVOT = (292, 327)
FRONT_LEG_PIVOT = (350, 325)

# name, back angle, front angle, back offset, front offset, reversed leg order
RUN_POSE_SPECS = [
    ("hero_run_0.png", -32.0, 32.0, (0, 0), (0, 0), False),
    ("hero_run_1.png", -12.0, 12.0, (0, -3), (0, -8), False),
    ("hero_run_2.png", 28.0, -28.0, (0, -9), (0, -4), False),
    ("hero_run_3.png", 20.0, -20.0, (30, -7), (-30, -3), True),
    ("hero_run_4.png", 60.0, -60.0, (58, 0), (-58, 0), True),
    ("hero_run_5.png", 25.0, -25.0, (30, -3), (-30, -8), True),
    ("hero_run_6.png", 15.0, -15.0, (0, -4), (0, -9), False),
    ("hero_run_7.png", -10.0, 10.0, (0, -7), (0, -2), False),
]

AIR_POSE_SPECS = [
    ("hero_jump_takeoff.png", -40.0, 40.0, (0, 0), (0, 0), False),
    ("hero_jump_tuck.png", 55.0, -55.0, (0, -14), (0, -14), False),
    ("hero_jump_fall.png", 8.0, -8.0, (0, -2), (0, -2), False),
    ("hero_land.png", -45.0, 45.0, (0, 0), (0, 0), False),
]


def alpha_component(source: Image.Image, seed_box: tuple[int, int, int, int]) -> set[tuple[int, int]]:
    """Return the connected opaque component whose bounds match seed_box."""
    alpha = source.getchannel("A")
    width, height = source.size
    expected_left, expected_top, expected_right, expected_bottom = seed_box

    seed = None
    for y in range(expected_top, expected_bottom + 1):
        for x in range(expected_left, expected_right + 1):
            if alpha.getpixel((x, y)) > 0:
                seed = (x, y)
                break
        if seed is not None:
            break
    if seed is None:
        raise RuntimeError(f"No opaque pixel found inside {seed_box}")

    visited = {seed}
    queue = deque([seed])
    while queue:
        x, y = queue.popleft()
        for offset_y in (-1, 0, 1):
            for offset_x in (-1, 0, 1):
                if offset_x == 0 and offset_y == 0:
                    continue
                next_x = x + offset_x
                next_y = y + offset_y
                point = (next_x, next_y)
                if not (0 <= next_x < width and 0 <= next_y < height):
                    continue
                if point in visited or alpha.getpixel(point) == 0:
                    continue
                visited.add(point)
                queue.append(point)

    xs = [point[0] for point in visited]
    ys = [point[1] for point in visited]
    actual_box = (min(xs), min(ys), max(xs), max(ys))
    if actual_box != seed_box:
        raise RuntimeError(f"Expected component {seed_box}, found {actual_box}")
    return visited


def build_source_frame(
    source: Image.Image,
    component: set[tuple[int, int]],
    source_box: tuple[int, int, int, int],
    foot_anchor_x: float,
) -> Image.Image:
    canvas = Image.new("RGBA", CANVAS_SIZE, (0, 0, 0, 0))
    bottom = source_box[3]
    translate_x = round(FOOT_ANCHOR_X - foot_anchor_x)
    translate_y = FOOT_BASELINE_Y - bottom

    source_pixels = source.load()
    canvas_pixels = canvas.load()
    for source_x, source_y in component:
        target_x = source_x + translate_x
        target_y = source_y + translate_y
        if 0 <= target_x < CANVAS_SIZE[0] and 0 <= target_y < CANVAS_SIZE[1]:
            canvas_pixels[target_x, target_y] = source_pixels[source_x, source_y]
        else:
            raise RuntimeError(f"Frame pixel escaped canvas at {(target_x, target_y)}")
    return canvas


def is_attack_arc_color(pixel: tuple[int, int, int, int]) -> bool:
    red, green, blue, alpha = pixel
    return (
        alpha > 0
        and red + green + blue > 240
        and blue * 4 >= red * 3
        and blue * 10 >= green * 8
    )


def build_slash_frame() -> Image.Image:
    slash = Image.open(LEGACY_DIR / "hero_slash.png").convert("RGBA")
    recovery = Image.open(LEGACY_DIR / "hero_recovery.png").convert("RGBA")
    canvas = Image.new("RGBA", CANVAS_SIZE, (0, 0, 0, 0))
    offset_x = round(FOOT_ANCHOR_X - SLASH_FOOT_ANCHOR_X)

    # The old slash mask is clean, but its right-hand arc was outside the old
    # 384 px canvas.  Reattach only the cool-white arc pixels that landed in
    # the neighboring recovery export.  The source-coordinate conversion keeps
    # the effect continuous without copying the neighboring character/cape.
    canvas.alpha_composite(slash, (offset_x, 1))
    recovery_pixels = recovery.load()
    canvas_pixels = canvas.load()
    source_delta_x = RECOVERY_SOURCE_LEFT - SLASH_SOURCE_LEFT
    for recovery_y in range(180, 341):
        for recovery_x in range(0, 151):
            pixel = recovery_pixels[recovery_x, recovery_y]
            if not is_attack_arc_color(pixel):
                continue
            target_x = recovery_x + source_delta_x + offset_x
            if 0 <= target_x < CANVAS_SIZE[0]:
                canvas_pixels[target_x, recovery_y] = pixel
    return canvas


def masked_part(source: Image.Image, polygon: list[tuple[int, int]]) -> tuple[Image.Image, Image.Image]:
    polygon_mask = Image.new("L", source.size, 0)
    ImageDraw.Draw(polygon_mask).polygon(polygon, fill=255)
    alpha_mask = ImageChops.multiply(polygon_mask, source.getchannel("A"))
    part = Image.new("RGBA", source.size, (0, 0, 0, 0))
    part.paste(source, (0, 0), alpha_mask)
    return part, alpha_mask


def transform_part(
    part: Image.Image,
    angle: float,
    pivot: tuple[int, int],
    offset: tuple[int, int],
) -> Image.Image:
    rotated = part.rotate(
        angle,
        resample=Image.Resampling.NEAREST,
        center=pivot,
        expand=False,
    )
    transformed = Image.new("RGBA", part.size, (0, 0, 0, 0))
    transformed.alpha_composite(rotated, offset)
    return transformed


def align_to_floor(pose: Image.Image) -> Image.Image:
    alpha_bounds = pose.getchannel("A").getbbox()
    if alpha_bounds is None:
        raise RuntimeError("Cannot floor-align an empty hero pose")
    offset_y = FOOT_BASELINE_Y + 1 - alpha_bounds[3]
    aligned = Image.new("RGBA", pose.size, (0, 0, 0, 0))
    aligned.alpha_composite(pose, (0, offset_y))
    return aligned


def build_articulated_poses(base_frame: Image.Image) -> dict[str, Image.Image]:
    back_leg, back_mask = masked_part(base_frame, BACK_LEG_POLYGON)
    front_leg, front_mask = masked_part(base_frame, FRONT_LEG_POLYGON)
    removed_legs = ImageChops.lighter(back_mask, front_mask)
    body = base_frame.copy()
    body.putalpha(ImageChops.subtract(base_frame.getchannel("A"), removed_legs))

    poses: dict[str, Image.Image] = {}
    for filename, back_angle, front_angle, back_offset, front_offset, reverse_order in [
        *RUN_POSE_SPECS,
        *AIR_POSE_SPECS,
    ]:
        transformed_back = transform_part(back_leg, back_angle, BACK_LEG_PIVOT, back_offset)
        transformed_front = transform_part(front_leg, front_angle, FRONT_LEG_PIVOT, front_offset)
        pose = Image.new("RGBA", CANVAS_SIZE, (0, 0, 0, 0))
        if reverse_order:
            pose.alpha_composite(transformed_front)
            pose.alpha_composite(transformed_back)
        else:
            pose.alpha_composite(transformed_back)
            pose.alpha_composite(transformed_front)
        pose.alpha_composite(body)
        if filename.startswith("hero_run_") or filename in {
            "hero_jump_takeoff.png",
            "hero_land.png",
        }:
            pose = align_to_floor(pose)
        poses[filename] = pose
    return poses


def main() -> None:
    source = Image.open(SOURCE_PATH).convert("RGBA")
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    built_frames: dict[str, Image.Image] = {}
    for filename, (source_box, foot_anchor_x) in SOURCE_FRAME_SPECS.items():
        component = alpha_component(source, source_box)
        frame = build_source_frame(source, component, source_box, foot_anchor_x)
        built_frames[filename] = frame
        frame.save(OUTPUT_DIR / filename, optimize=True)

    slash = build_slash_frame()
    slash.save(OUTPUT_DIR / "hero_slash.png", optimize=True)

    # The source recovery pose is permanently occluded by the slash arc in the
    # concept strip.  Returning to the clean idle pose is visually coherent and
    # lets code provide the recoil motion without inventing damaged pixels.
    built_frames["hero_idle.png"].copy().save(
        OUTPUT_DIR / "hero_recovery.png", optimize=True
    )

    articulated_poses = build_articulated_poses(built_frames["hero_walk_2.png"])
    for filename, pose in articulated_poses.items():
        pose.save(OUTPUT_DIR / filename, optimize=True)


if __name__ == "__main__":
    main()
