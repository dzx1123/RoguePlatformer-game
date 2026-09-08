"""Build weapon-specific frames from complete full-body source sheets.

The source sheets are concept renders.  Each grid cell already contains one
complete character.  This tool only removes the edge-connected backdrop,
extracts the whole cell, and maps it to the existing hero's head/foot anchors.
It deliberately never masks, rotates, mirrors, or recombines body parts.
"""

from __future__ import annotations

from collections import deque
from dataclasses import dataclass
from pathlib import Path

from PIL import Image


PROJECT_ROOT = Path(__file__).resolve().parents[1]
FRAME_ROOT = PROJECT_ROOT / "assets" / "characters" / "frames_polished"
WEAPON_ROOT = PROJECT_ROOT / "assets" / "characters" / "weapon_sets"


@dataclass(frozen=True)
class SheetSpec:
    weapon_dir: str
    source_name: str
    columns: int
    rows: int
    output_names: tuple[str, ...]
    reference_names: tuple[str, ...]
    canvas_width: int
    match_character_scale: bool = False


RUN_OUTPUTS = tuple(f"hero_run_{index}.png" for index in range(12))
RUN_REFERENCES = RUN_OUTPUTS
AIR_OUTPUTS = (
    "hero_jump_takeoff.png",
    "hero_jump_rise.png",
    "hero_jump_apex.png",
    "hero_jump_fall.png",
    "hero_land.png",
)
AIR_REFERENCES = (
    "hero_jump_takeoff.png",
    "hero_jump_rise_v2.png",
    "hero_jump_apex_v2.png",
    "hero_jump_fall.png",
    "hero_land.png",
)
ATTACK_OUTPUTS = (
    "hero_attack_recovery.png",
    "hero_attack_forward_windup.png",
    "hero_attack_forward_strike.png",
    "hero_attack_forward_follow.png",
    "hero_attack_up_windup.png",
    "hero_attack_up_strike.png",
    "hero_attack_up_follow.png",
    "hero_attack_down_windup.png",
    "hero_attack_down_strike.png",
    "hero_attack_down_follow.png",
    "hero_skill_a.png",
    "hero_skill_b.png",
)
ATTACK_REFERENCES = (
    "hero_recovery.png",
    "hero_windup.png",
    "hero_slash.png",
    "hero_slash_followthrough.png",
    "hero_slash_up_windup.png",
    "hero_slash_up.png",
    "hero_slash_up_followthrough.png",
    "hero_slash_down_windup.png",
    "hero_slash_down.png",
    "hero_slash_down_followthrough.png",
    "hero_slash.png",
    "hero_slash_down.png",
)

SPECS = (
    SheetSpec("twin_blades", "hero_run_fullbody_sheet_v3.png", 4, 3, RUN_OUTPUTS, RUN_REFERENCES, 640, True),
    SheetSpec("greatsword", "hero_run_fullbody_sheet_v3.png", 4, 3, RUN_OUTPUTS, RUN_REFERENCES, 768, True),
    SheetSpec("twin_blades", "hero_air_fullbody_sheet_v3.png", 5, 1, AIR_OUTPUTS, AIR_REFERENCES, 640, True),
    SheetSpec("greatsword", "hero_air_fullbody_sheet_v3.png", 5, 1, AIR_OUTPUTS, AIR_REFERENCES, 768, True),
    SheetSpec("twin_blades", "hero_attack_fullbody_sheet_v3.png", 4, 3, ATTACK_OUTPUTS, ATTACK_REFERENCES, 640),
    SheetSpec("greatsword", "hero_attack_fullbody_sheet_v3.png", 4, 3, ATTACK_OUTPUTS, ATTACK_REFERENCES, 768),
)


def is_backdrop(pixel: tuple[int, int, int, int]) -> bool:
    red, green, blue, _alpha = pixel
    return min(red, green, blue) >= 205 and max(red, green, blue) - min(red, green, blue) <= 18


def remove_edge_backdrop(image: Image.Image) -> Image.Image:
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
        if point in visited or not is_backdrop(pixels[x, y]):
            continue
        visited.add(point)
        if x:
            queue.append((x - 1, y))
        if x + 1 < width:
            queue.append((x + 1, y))
        if y:
            queue.append((x, y - 1))
        if y + 1 < height:
            queue.append((x, y + 1))

    for x, y in visited:
        pixels[x, y] = (0, 0, 0, 0)

    # The assets are displayed at pixel scale.  Hard alpha prevents pale RGB
    # from the generated preview backdrop becoming a visible white halo.
    for y in range(height):
        for x in range(width):
            red, green, blue, alpha = pixels[x, y]
            if alpha == 0:
                pixels[x, y] = (0, 0, 0, 0)
            else:
                pixels[x, y] = (red, green, blue, 255)

    # Generated sheets sometimes leave near-white antialias pixels around pale
    # hair or steel.  At pixel scale those pixels read as a flashing white halo.
    # Convert only exposed neutral boundary pixels into the same dark navy ink
    # used by the canonical hero; internal white hair highlights stay untouched.
    boundary_pixels: list[tuple[int, int]] = []
    for y in range(1, height - 1):
        for x in range(1, width - 1):
            red, green, blue, alpha = pixels[x, y]
            if not alpha or min(red, green, blue) < 205 or max(red, green, blue) - min(red, green, blue) > 22:
                continue
            if any(pixels[nx, ny][3] == 0 for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1))):
                boundary_pixels.append((x, y))
    for x, y in boundary_pixels:
        pixels[x, y] = (20, 28, 43, 255)
    return cleaned


def cell_bounds(length: int, count: int, index: int) -> tuple[int, int]:
    return round(length * index / count), round(length * (index + 1) / count)


def _component_gap(first: tuple[int, int, int, int], second: tuple[int, int, int, int]) -> int:
    horizontal = max(0, max(first[0], second[0]) - min(first[2], second[2]))
    vertical = max(0, max(first[1], second[1]) - min(first[3], second[3]))
    return max(horizontal, vertical)


def extract_complete_figures(
    sheet: Image.Image,
    expected_count: int,
    columns: int,
    rows: int,
) -> list[Image.Image]:
    """Extract whole figures without cutting them at nominal grid boundaries.

    Image-generation grids are visually regular but a cloak, sword tip, or hair
    spike can cross the mathematical cell edge by a few pixels.  Cropping the
    cells first caused exactly the broken greatsword silhouettes seen in game.
    Segmenting the cleaned full sheet keeps every connected figure intact.
    """
    cleaned = remove_edge_backdrop(sheet)
    alpha = cleaned.getchannel("A")
    width, height = cleaned.size
    alpha_pixels = alpha.load()
    visited: set[tuple[int, int]] = set()
    components: list[dict[str, object]] = []

    for y in range(height):
        for x in range(width):
            if not alpha_pixels[x, y] or (x, y) in visited:
                continue
            queue: deque[tuple[int, int]] = deque([(x, y)])
            visited.add((x, y))
            points: list[tuple[int, int]] = []
            left = right = x
            top = bottom = y
            while queue:
                px, py = queue.popleft()
                points.append((px, py))
                left = min(left, px)
                right = max(right, px)
                top = min(top, py)
                bottom = max(bottom, py)
                for nx, ny in ((px - 1, py), (px + 1, py), (px, py - 1), (px, py + 1)):
                    if 0 <= nx < width and 0 <= ny < height and alpha_pixels[nx, ny] and (nx, ny) not in visited:
                        visited.add((nx, ny))
                        queue.append((nx, ny))
            components.append({
                "points": points,
                "area": len(points),
                "bounds": (left, top, right + 1, bottom + 1),
                "center": ((left + right) * 0.5, (top + bottom) * 0.5),
            })

    mains = sorted(components, key=lambda item: int(item["area"]), reverse=True)[:expected_count]
    if len(mains) != expected_count or int(mains[-1]["area"]) < 1000:
        raise RuntimeError(f"Expected {expected_count} complete figures, found {len(mains)}")

    # Preserve detached tassels and tiny ornament pixels when they sit next to a
    # main figure, while discarding distant checker residue or cross-cell dust.
    main_ids = {id(item) for item in mains}
    for component in components:
        if id(component) in main_ids:
            continue
        closest = min(mains, key=lambda item: _component_gap(component["bounds"], item["bounds"]))
        if int(component["area"]) >= 5 and _component_gap(component["bounds"], closest["bounds"]) <= 24:
            closest["points"].extend(component["points"])
            points = closest["points"]
            closest["bounds"] = (
                min(point[0] for point in points),
                min(point[1] for point in points),
                max(point[0] for point in points) + 1,
                max(point[1] for point in points) + 1,
            )

    mains.sort(key=lambda item: item["center"][1])
    ordered: list[dict[str, object]] = []
    for row_index in range(rows):
        row_start = row_index * columns
        row_items = mains[row_start:row_start + columns]
        row_items.sort(key=lambda item: item["center"][0])
        ordered.extend(row_items)

    figures: list[Image.Image] = []
    source_pixels = cleaned.load()
    for item in ordered:
        left, top, right, bottom = item["bounds"]
        figure = Image.new("RGBA", (right - left, bottom - top), (0, 0, 0, 0))
        figure_pixels = figure.load()
        for x, y in item["points"]:
            figure_pixels[x - left, y - top] = source_pixels[x, y]
        figures.append(figure)
    return figures


def hair_anchor_x(image: Image.Image) -> float:
    alpha_bounds = image.getchannel("A").getbbox()
    if alpha_bounds is None:
        raise RuntimeError("Cannot anchor an empty image")
    left, top, right, bottom = alpha_bounds
    scan_bottom = top + max(1, round((bottom - top) * 0.48))
    samples: list[int] = []
    pixels = image.convert("RGBA").load()
    for y in range(top, scan_bottom):
        for x in range(left, right):
            red, green, blue, alpha = pixels[x, y]
            if alpha and min(red, green, blue) >= 125 and max(red, green, blue) - min(red, green, blue) <= 48:
                samples.append(x)
    if not samples:
        return (left + right) * 0.5
    samples.sort()
    return float(samples[len(samples) // 2])


def character_scale_anchors(image: Image.Image) -> tuple[float, float, float] | None:
    """Return hair center, hair height and body foot line, ignoring long weapons."""
    bounds = image.getchannel("A").getbbox()
    if bounds is None:
        return None
    left, top, right, bottom = bounds
    pixels = image.convert("RGBA").load()
    skin: list[tuple[int, int]] = []
    scan_bottom = top + round((bottom - top) * 0.72)
    for y in range(top, scan_bottom):
        for x in range(left, right):
            red, green, blue, alpha = pixels[x, y]
            if alpha and red >= 145 and red >= green + 22 and 45 <= green <= 190 and blue <= 165:
                skin.append((x, y))
    if not skin:
        return None
    skin.sort(key=lambda point: point[1])
    upper_skin = skin[:max(1, len(skin) // 2)]
    face_x = sorted(point[0] for point in upper_skin)[len(upper_skin) // 2]
    face_y = sorted(point[1] for point in upper_skin)[len(upper_skin) // 2]

    hair: list[tuple[int, int]] = []
    for y in range(max(top, face_y - 105), min(bottom, face_y + 12)):
        for x in range(max(left, face_x - 95), min(right, face_x + 82)):
            red, green, blue, alpha = pixels[x, y]
            if alpha and min(red, green, blue) >= 120 and max(red, green, blue) - min(red, green, blue) <= 58:
                hair.append((x, y))
    if len(hair) < 24:
        return None
    hair_left = min(point[0] for point in hair)
    hair_right = max(point[0] for point in hair) + 1
    hair_top = min(point[1] for point in hair)
    hair_bottom = max(point[1] for point in hair) + 1
    hair_center = (hair_left + hair_right) * 0.5

    body_left = max(left, round(hair_center - 68))
    body_right = min(right, round(hair_center + 104))
    foot_y = max(
        y
        for y in range(top, bottom)
        for x in range(body_left, body_right)
        if pixels[x, y][3]
    ) + 1
    return hair_center, float(hair_bottom - hair_top), float(foot_y)


def normalize_complete_pose(
    source: Image.Image,
    reference: Image.Image,
    canvas_width: int,
    match_character_scale: bool,
) -> Image.Image:
    source_bounds = source.getchannel("A").getbbox()
    reference_bounds = reference.getchannel("A").getbbox()
    if source_bounds is None or reference_bounds is None:
        raise RuntimeError("Source or reference frame is empty")

    source_crop = source.crop(source_bounds)
    target_height = reference_bounds[3] - reference_bounds[1]
    # Some canonical attack frames touch the old canvas edge.  Never inherit
    # that crop: shrink the complete pose just enough to retain four clear
    # transparent pixels above it while preserving its reference foot line.
    target_height = min(target_height, max(1, reference_bounds[3] - 4))
    scale = target_height / float(source_crop.height)
    source_anchors = character_scale_anchors(source_crop)
    reference_anchors = character_scale_anchors(reference)
    if match_character_scale and source_anchors is not None and reference_anchors is not None:
        scale = max(0.78, min(reference_anchors[1] / max(1.0, source_anchors[1]), 1.42))
        maximum_scale = min(
            (canvas_width - 8) / float(source_crop.width),
            (416 - 8) / float(source_crop.height),
        )
        scale = min(scale, maximum_scale)
    resized = source_crop.resize(
        (
            max(1, round(source_crop.width * scale)),
            max(1, round(source_crop.height * scale)),
        ),
        Image.Resampling.NEAREST,
    )

    if match_character_scale and source_anchors is not None and reference_anchors is not None:
        reference_hair_x = reference_anchors[0] + (canvas_width - reference.width) * 0.5
        source_hair_x = source_anchors[0] * scale
    else:
        reference_hair_x = hair_anchor_x(reference) + (canvas_width - reference.width) * 0.5
        source_hair_x = hair_anchor_x(resized)
    target_x = round(reference_hair_x - source_hair_x)
    target_x = max(4, min(target_x, canvas_width - resized.width - 4))
    target_y = reference_bounds[3] - resized.height
    if match_character_scale and source_anchors is not None and reference_anchors is not None:
        target_y = round(reference_anchors[2] - source_anchors[2] * scale)
    target_y = max(4, min(target_y, 412 - resized.height))

    canvas = Image.new("RGBA", (canvas_width, 416), (0, 0, 0, 0))
    canvas.alpha_composite(resized, (target_x, target_y))
    return canvas


def boundary_fringe_count(image: Image.Image) -> int:
    pixels = image.load()
    width, height = image.size
    count = 0
    for y in range(1, height - 1):
        for x in range(1, width - 1):
            red, green, blue, alpha = pixels[x, y]
            if not alpha or min(red, green, blue) < 220 or max(red, green, blue) - min(red, green, blue) > 14:
                continue
            if any(pixels[nx, ny][3] == 0 for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1))):
                count += 1
    return count


def validate_frame(path: Path, image: Image.Image) -> None:
    bounds = image.getchannel("A").getbbox()
    if image.mode != "RGBA" or image.height != 416 or bounds is None:
        raise RuntimeError(f"Invalid frame format: {path}")
    if bounds[0] < 2 or bounds[2] > image.width - 2 or bounds[1] < 2 or bounds[3] > 414:
        raise RuntimeError(f"Frame lacks safe transparent margin: {path} {bounds}")
    if any(image.getpixel(point)[3] for point in ((0, 0), (image.width - 1, 0), (0, 415), (image.width - 1, 415))):
        raise RuntimeError(f"Opaque canvas corner: {path}")
    fringe = boundary_fringe_count(image)
    if fringe > 24:
        raise RuntimeError(f"Possible pale fringe: {path} count={fringe}")


def build_sheet(spec: SheetSpec) -> None:
    source_path = WEAPON_ROOT / spec.weapon_dir / "source" / spec.source_name
    sheet = Image.open(source_path).convert("RGBA")
    output_dir = WEAPON_ROOT / spec.weapon_dir

    expected_count = spec.columns * spec.rows
    if len(spec.output_names) != expected_count or len(spec.reference_names) != expected_count:
        raise RuntimeError(f"Grid/output mismatch for {source_path}")

    figures = extract_complete_figures(sheet, expected_count, spec.columns, spec.rows)
    for index, (output_name, reference_name) in enumerate(zip(spec.output_names, spec.reference_names)):
        complete_cell = figures[index]

        reference = Image.open(FRAME_ROOT / reference_name).convert("RGBA")
        frame = normalize_complete_pose(
            complete_cell,
            reference,
            spec.canvas_width,
            spec.match_character_scale,
        )
        output_path = output_dir / output_name
        validate_frame(output_path, frame)
        frame.save(output_path, optimize=True)
        print(f"wrote {output_path.relative_to(PROJECT_ROOT)} bounds={frame.getchannel('A').getbbox()}")


def main() -> None:
    for spec in SPECS:
        build_sheet(spec)


if __name__ == "__main__":
    main()
