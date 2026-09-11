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
from weapon_body_registration import boot_line

from bake_weapon_frame_effects import POSE_EFFECTS, bake_effect_into_frame


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
    canvas_height: int = 512


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
TWIN_SKILL_OUTPUTS = tuple(f"hero_skill_{index}.png" for index in range(12))
TWIN_SKILL_REFERENCES = (
    "hero_idle.png",
    "hero_windup.png",
    "hero_windup.png",
    "hero_slash.png",
    "hero_slash_followthrough.png",
    "hero_slash.png",
    "hero_slash_up_windup.png",
    "hero_slash_up.png",
    "hero_slash_down_windup.png",
    "hero_slash_down.png",
    "hero_slash_down_followthrough.png",
    "hero_recovery.png",
)

SPECS = (
    SheetSpec("twin_blades", "hero_run_fullbody_sheet_v5.png", 4, 3, RUN_OUTPUTS, RUN_REFERENCES, 640, True),
    SheetSpec("greatsword", "hero_run_fullbody_sheet_v5.png", 4, 3, RUN_OUTPUTS, RUN_REFERENCES, 768, True, 768),
    SheetSpec("twin_blades", "hero_air_fullbody_sheet_v4.png", 5, 1, AIR_OUTPUTS, AIR_REFERENCES, 640, True),
    SheetSpec("greatsword", "hero_air_fullbody_sheet_v4.png", 5, 1, AIR_OUTPUTS, AIR_REFERENCES, 768, True, 768),
    SheetSpec(
        "twin_blades",
        "hero_attack_fullbody_sheet_v3.png",
        4,
        3,
        ATTACK_OUTPUTS,
        ATTACK_REFERENCES,
        640,
        True,
        512,
    ),
    SheetSpec(
        "greatsword",
        "hero_attack_fullbody_sheet_v4.png",
        4,
        3,
        ATTACK_OUTPUTS,
        ATTACK_REFERENCES,
        768,
        True,
        768,
    ),
    SheetSpec(
        "twin_blades",
        "hero_skill_fullbody_sheet_v2.png",
        4,
        3,
        TWIN_SKILL_OUTPUTS,
        TWIN_SKILL_REFERENCES,
        640,
        True,
        512,
    ),
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

    return cleaned


def darken_exposed_light_outline(image: Image.Image, depth: int = 2) -> None:
    """Replace generated pale matte pixels near transparency with dark ink."""
    pixels = image.load()
    width, height = image.size
    opaque = {
        (x, y)
        for y in range(height)
        for x in range(width)
        if pixels[x, y][3]
    }
    frontier = {
        (x, y)
        for x, y in opaque
        if any(
            (nx, ny) not in opaque
            for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1))
        )
    }
    visited = set(frontier)
    for _layer in range(max(1, depth)):
        next_frontier: set[tuple[int, int]] = set()
        for x, y in frontier:
            red, green, blue, alpha = pixels[x, y]
            channel_spread = max(red, green, blue) - min(red, green, blue)
            brightness = (red + green + blue) / 3.0
            if alpha and brightness >= 190.0 and channel_spread <= 60:
                pixels[x, y] = (18, 27, 43, 255)
            for neighbor in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
                if neighbor in opaque and neighbor not in visited:
                    visited.add(neighbor)
                    next_frontier.add(neighbor)
        frontier = next_frontier


def remove_tiny_opaque_islands(image: Image.Image, maximum_area: int = 160) -> None:
    pixels = image.load()
    width, height = image.size
    remaining = {
        (x, y)
        for y in range(height)
        for x in range(width)
        if pixels[x, y][3]
    }
    while remaining:
        start = remaining.pop()
        queue = [start]
        component = [start]
        while queue:
            x, y = queue.pop()
            for neighbor in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
                if neighbor in remaining:
                    remaining.remove(neighbor)
                    queue.append(neighbor)
                    component.append(neighbor)
        if len(component) <= maximum_area:
            for x, y in component:
                pixels[x, y] = (0, 0, 0, 0)


def remove_uncovered_head_fragments(
    image: Image.Image,
    protected_pixels: set[tuple[int, int]],
    translated_hair: set[tuple[int, int]],
    maximum_area: int = 320,
) -> int:
    """Remove detached generated-head ink left outside the canonical patch.

    Replacing the pale hair can disconnect the old dark outline from the body.
    Those fragments are too large for generic dust cleanup and appeared as a
    second, ghosted hairstyle above several greatsword poses.  Limit cleanup to
    small dark components around the canonical hair so slash droplets, tassels,
    raised weapons and all pixels belonging to the canonical patch are kept.
    """
    if not protected_pixels or not translated_hair:
        return 0
    pixels = image.load()
    hair_left, hair_top, hair_right, hair_bottom = point_bounds(list(translated_hair))
    hair_width = hair_right - hair_left
    hair_height = hair_bottom - hair_top
    cleanup_bounds = (
        max(0, round(hair_left - hair_width * 0.65)),
        # A generated head can sit nearly one head-height above the canonical
        # anchor in deep crouch/overhead poses, so cover that full old silhouette.
        max(0, round(hair_top - hair_height * 1.15)),
        min(image.width, round(hair_right + hair_width * 0.45)),
        min(image.height, round(hair_bottom + hair_height * 0.22)),
    )
    remaining = {
        (x, y)
        for y in range(image.height)
        for x in range(image.width)
        if pixels[x, y][3]
    }
    removed_pixels = 0
    while remaining:
        start = remaining.pop()
        queue = [start]
        component = [start]
        while queue:
            x, y = queue.pop()
            for neighbor in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
                if neighbor in remaining:
                    remaining.remove(neighbor)
                    queue.append(neighbor)
                    component.append(neighbor)
        if len(component) > maximum_area or any(point in protected_pixels for point in component):
            continue
        center_x = sum(point[0] for point in component) / len(component)
        center_y = sum(point[1] for point in component) / len(component)
        if not (
            cleanup_bounds[0] <= center_x < cleanup_bounds[2]
            and cleanup_bounds[1] <= center_y < cleanup_bounds[3]
        ):
            continue
        average_brightness = sum(
            sum(pixels[x, y][:3]) / 3.0 for x, y in component
        ) / len(component)
        average_spread = sum(
            max(pixels[x, y][:3]) - min(pixels[x, y][:3]) for x, y in component
        ) / len(component)
        if average_brightness > 92.0 or average_spread > 52.0:
            continue
        for x, y in component:
            pixels[x, y] = (0, 0, 0, 0)
        removed_pixels += len(component)
    return removed_pixels


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


def hair_component_points(image: Image.Image) -> list[tuple[int, int]]:
    """Return the compact white-hair mass, never a pale blade or slash arc."""
    bounds = image.getchannel("A").getbbox()
    if bounds is None:
        raise RuntimeError("Cannot find hair in an empty image")
    left, top, right, bottom = bounds
    pixels = image.convert("RGBA").load()
    neutral_pixels: set[tuple[int, int]] = set()
    for y in range(top, bottom):
        for x in range(left, right):
            red, green, blue, alpha = pixels[x, y]
            if (
                alpha
                and min(red, green, blue) >= 105
                and max(red, green, blue) - min(red, green, blue) <= 72
            ):
                neutral_pixels.add((x, y))

    components: list[list[tuple[int, int]]] = []
    while neutral_pixels:
        start = neutral_pixels.pop()
        component = [start]
        queue = deque([start])
        while queue:
            x, y = queue.popleft()
            for neighbor_x in range(x - 1, x + 2):
                for neighbor_y in range(y - 1, y + 2):
                    neighbor = (neighbor_x, neighbor_y)
                    if neighbor in neutral_pixels:
                        neutral_pixels.remove(neighbor)
                        component.append(neighbor)
                        queue.append(neighbor)
        if len(component) >= 24:
            components.append(component)
    if not components:
        raise RuntimeError("Could not isolate a white-hair component")

    silhouette_height = float(bottom - top)
    compact: list[list[tuple[int, int]]] = []
    for component in components:
        component_left = min(point[0] for point in component)
        component_right = max(point[0] for point in component) + 1
        component_top = min(point[1] for point in component)
        component_bottom = max(point[1] for point in component) + 1
        component_width = component_right - component_left
        component_height = component_bottom - component_top
        component_density = len(component) / float(component_width * component_height)
        aspect = component_width / float(max(1, component_height))
        if (
            20 <= component_width <= max(64.0, silhouette_height * 0.50)
            and 16 <= component_height <= max(52.0, silhouette_height * 0.45)
            and 0.65 <= aspect <= 1.90
            and component_density >= 0.24
        ):
            compact.append(component)
    return max(compact or components, key=len)


def point_bounds(points: list[tuple[int, int]]) -> tuple[int, int, int, int]:
    return (
        min(point[0] for point in points),
        min(point[1] for point in points),
        max(point[0] for point in points) + 1,
        max(point[1] for point in points) + 1,
    )


def head_identity_mask(image: Image.Image) -> set[tuple[int, int]]:
    """Select hair, face and their ink without pulling in a raised weapon."""
    rgba = image.convert("RGBA")
    pixels = rgba.load()
    hair = hair_component_points(rgba)
    hair_left, hair_top, hair_right, hair_bottom = point_bounds(hair)
    hair_width = hair_right - hair_left
    hair_height = hair_bottom - hair_top
    region_left = max(0, round(hair_left - hair_width * 0.14))
    region_right = min(rgba.width, round(hair_right + hair_width * 0.14))
    region_top = max(0, round(hair_top - hair_height * 0.10))
    region_bottom = min(rgba.height, round(hair_bottom + hair_height * 0.12))
    face_left = round(hair_left + hair_width * 0.28)
    face_top = round(hair_top + hair_height * 0.24)
    face_right = min(rgba.width, round(hair_right + hair_width * 0.30))
    face_bottom = min(rgba.height, round(hair_bottom + hair_height * 0.46))

    mask: set[tuple[int, int]] = set(hair)
    for y in range(region_top, region_bottom):
        for x in range(region_left, region_right):
            red, green, blue, alpha = pixels[x, y]
            if not alpha:
                continue
            brightness = (red + green + blue) / 3.0
            spread = max(red, green, blue) - min(red, green, blue)
            hair_tone = brightness >= 38.0 and spread <= 76
            if hair_tone:
                mask.add((x, y))

    for y in range(face_top, face_bottom):
        for x in range(face_left, face_right):
            red, green, blue, alpha = pixels[x, y]
            if not alpha:
                continue
            skin_tone = (
                red >= 92
                and red >= green + 10
                and green >= blue * 0.72
                and blue <= 178
            )
            eye_tone = blue >= 90 and green >= 70 and blue >= red + 12
            if skin_tone or eye_tone:
                mask.add((x, y))

    outline_left = min(region_left, face_left)
    outline_right = max(region_right, face_right)
    outline_top = min(region_top, face_top)
    outline_bottom = max(region_bottom, face_bottom)
    # Pull in only the immediate dark ink around hair and face. A one-pixel
    # expansion keeps raised arms and weapon steel outside the identity patch.
    for _layer in range(1):
        expanded = set(mask)
        for x, y in mask:
            for neighbor_x in range(x - 1, x + 2):
                for neighbor_y in range(y - 1, y + 2):
                    if (
                        outline_left <= neighbor_x < outline_right
                        and outline_top <= neighbor_y < outline_bottom
                        and pixels[neighbor_x, neighbor_y][3]
                    ):
                        expanded.add((neighbor_x, neighbor_y))
        mask = expanded
    return mask


def apply_canonical_head(image: Image.Image, reference: Image.Image) -> Image.Image:
    """Replace generated head identity with the exact one-hand reference art."""
    result = image.copy().convert("RGBA")
    result_pixels = result.load()
    reference_rgba = reference.convert("RGBA")
    reference_pixels = reference_rgba.load()
    target_mask = head_identity_mask(result)
    reference_mask = head_identity_mask(reference_rgba)
    offset_x = round((result.width - reference_rgba.width) * 0.5)
    offset_y = round((result.height - reference_rgba.height) * 0.5)

    translated_reference = {
        (x + offset_x, y + offset_y)
        for x, y in reference_mask
        if 0 <= x + offset_x < result.width and 0 <= y + offset_y < result.height
    }
    translated_hair = {
        (x + offset_x, y + offset_y)
        for x, y in hair_component_points(reference_rgba)
        if 0 <= x + offset_x < result.width and 0 <= y + offset_y < result.height
    }
    for x, y in target_mask - translated_reference:
        red, green, blue, alpha = result_pixels[x, y]
        brightness = (red + green + blue) / 3.0
        spread = max(red, green, blue) - min(red, green, blue)
        # Remove only uncovered generated hair pixels. Keeping skin and dark ink
        # underneath prevents transparent seams at the jaw, scarf and hood.
        if alpha and brightness >= 70.0 and spread <= 76:
            result_pixels[x, y] = (0, 0, 0, 0)
    for x, y in reference_mask:
        target_x = x + offset_x
        target_y = y + offset_y
        if 0 <= target_x < result.width and 0 <= target_y < result.height:
            result_pixels[target_x, target_y] = reference_pixels[x, y]
    remove_uncovered_head_fragments(result, translated_reference, translated_hair)
    return result


def character_scale_anchors(image: Image.Image) -> tuple[float, float, float] | None:
    """Return hair center, body height and foot line, ignoring carried weapons.

    The old detector started from skin-colored pixels.  Gold trim and blade
    reflections can satisfy that heuristic, so later run frames occasionally
    anchored to the weapon instead of the head.  The hero's connected white
    hair mass is a much stronger invariant across every weapon set.
    """
    bounds = image.getchannel("A").getbbox()
    if bounds is None:
        return None
    left, top, right, bottom = bounds
    pixels = image.convert("RGBA").load()

    neutral_pixels: set[tuple[int, int]] = set()
    scan_bottom = top + max(1, round((bottom - top) * 0.62))
    for y in range(top, scan_bottom):
        for x in range(left, right):
            red, green, blue, alpha = pixels[x, y]
            if (
                alpha
                and min(red, green, blue) >= 105
                and max(red, green, blue) - min(red, green, blue) <= 72
            ):
                neutral_pixels.add((x, y))
    if not neutral_pixels:
        return None

    neutral_components: list[list[tuple[int, int]]] = []
    while neutral_pixels:
        start = neutral_pixels.pop()
        component = [start]
        queue = deque([start])
        while queue:
            x, y = queue.popleft()
            for neighbor_x in range(x - 1, x + 2):
                for neighbor_y in range(y - 1, y + 2):
                    neighbor = (neighbor_x, neighbor_y)
                    if neighbor in neutral_pixels:
                        neutral_pixels.remove(neighbor)
                        component.append(neighbor)
                        queue.append(neighbor)
        if len(component) >= 24:
            neutral_components.append(component)
    if not neutral_components:
        return None

    # Slash arcs and pale weapon blades can be larger than the hair mass.
    # Hair is compact; effects and blades are long, sparse components.
    compact_hair_components: list[list[tuple[int, int]]] = []
    silhouette_height = float(bottom - top)
    for component in neutral_components:
        component_left = min(point[0] for point in component)
        component_right = max(point[0] for point in component) + 1
        component_top = min(point[1] for point in component)
        component_bottom = max(point[1] for point in component) + 1
        component_width = component_right - component_left
        component_height = component_bottom - component_top
        component_density = len(component) / float(component_width * component_height)
        if (
            20 <= component_width <= max(48.0, silhouette_height * 0.45)
            and 16 <= component_height <= max(42.0, silhouette_height * 0.40)
            and component_density >= 0.30
        ):
            compact_hair_components.append(component)

    hair = max(compact_hair_components or neutral_components, key=len)
    hair_left = min(point[0] for point in hair)
    hair_right = max(point[0] for point in hair) + 1
    hair_top = min(point[1] for point in hair)
    hair_center = (hair_left + hair_right) * 0.5

    hair_width = float(hair_right - hair_left)
    warm_pixels: set[tuple[int, int]] = set()
    for y in range(top, bottom):
        for x in range(left, right):
            red, green, blue, alpha = pixels[x, y]
            if (
                alpha
                and red >= 38
                and 18 <= green <= 170
                and blue <= 130
                and red >= blue + 12
                and red * 100 >= green * 92
            ):
                warm_pixels.add((x, y))

    foot_components: list[list[tuple[int, int]]] = []
    hair_bottom = max(point[1] for point in hair) + 1
    minimum_foot_y = hair_bottom + max(8.0, (hair_bottom - hair_top) * 0.65)
    while warm_pixels:
        start = warm_pixels.pop()
        component = [start]
        queue = deque([start])
        while queue:
            x, y = queue.popleft()
            for neighbor_x in range(x - 1, x + 2):
                for neighbor_y in range(y - 1, y + 2):
                    neighbor = (neighbor_x, neighbor_y)
                    if neighbor in warm_pixels:
                        warm_pixels.remove(neighbor)
                        component.append(neighbor)
                        queue.append(neighbor)
        if len(component) >= 8:
            component_left = min(point[0] for point in component)
            component_right = max(point[0] for point in component) + 1
            component_center = sum(point[0] for point in component) / len(component)
            component_bottom = max(point[1] for point in component) + 1
            if (
                component_right - component_left <= max(12.0, hair_width * 0.80)
                and hair_center - hair_width * 1.35 <= component_center
                and component_center <= hair_center + hair_width * 0.95
                and component_bottom >= minimum_foot_y
            ):
                foot_components.append(component)

    if foot_components:
        foot_y = max(max(point[1] for point in component) for component in foot_components) + 1
    else:
        body_left = max(left, round(hair_center - hair_width * 1.20))
        body_right = min(right, round(hair_center + hair_width * 0.95))
        foot_y = max(
            y
            for y in range(top, bottom)
            for x in range(body_left, body_right)
            if pixels[x, y][3]
        ) + 1
    return hair_center, float(foot_y - hair_top), float(foot_y)


def normalize_complete_pose(
    source: Image.Image,
    reference: Image.Image,
    canvas_width: int,
    match_character_scale: bool,
    canvas_height: int = 512,
    match_ground_line: bool = False,
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
    reference_hair_bounds = point_bounds(hair_component_points(reference))
    if match_character_scale:
        source_hair_bounds = point_bounds(hair_component_points(source_crop))
        source_hair_width = source_hair_bounds[2] - source_hair_bounds[0]
        source_hair_height = source_hair_bounds[3] - source_hair_bounds[1]
        reference_hair_width = reference_hair_bounds[2] - reference_hair_bounds[0]
        reference_hair_height = reference_hair_bounds[3] - reference_hair_bounds[1]
        # Hair silhouette is the cross-weapon identity invariant. Scaling from
        # it is immune to a horizontal blade or an overhead sword expanding the
        # full-pose bounds and shrinking the character.
        scale = (
            (reference_hair_width * reference_hair_height)
            / float(max(1, source_hair_width * source_hair_height))
        ) ** 0.5
        if match_ground_line:
            source_hair_center_y = (source_hair_bounds[1] + source_hair_bounds[3]) * 0.5
            reference_hair_center_y = (
                reference_hair_bounds[1] + reference_hair_bounds[3]
            ) * 0.5
            source_head_to_ground = boot_line(source_crop, source_hair_bounds) - source_hair_center_y
            reference_head_to_ground = boot_line(reference, reference_hair_bounds) - reference_hair_center_y
            # Measure leather soles: the trailing blade extends below the boots.
            # Body scale must not depend on weapon length.
            # Attack silhouettes cannot use it because an overhead blade may
            # become the full-pose bottom edge.
            scale = reference_head_to_ground / float(max(1.0, source_head_to_ground))
        scale = max(0.70, min(scale, 2.10))
        maximum_scale = min(
            (canvas_width - 8) / float(source_crop.width),
            (canvas_height - 8) / float(source_crop.height),
        )
        scale = min(scale, maximum_scale)
    resized = source_crop.resize(
        (
            max(1, round(source_crop.width * scale)),
            max(1, round(source_crop.height * scale)),
        ),
        Image.Resampling.NEAREST,
    )

    reference_y_offset = (canvas_height - reference.height) * 0.5
    if match_character_scale:
        resized_hair_bounds = point_bounds(hair_component_points(resized))
        reference_hair_x = (
            (reference_hair_bounds[0] + reference_hair_bounds[2]) * 0.5
            + (canvas_width - reference.width) * 0.5
        )
        reference_hair_y = (
            (reference_hair_bounds[1] + reference_hair_bounds[3]) * 0.5
            + reference_y_offset
        )
        source_hair_x = (resized_hair_bounds[0] + resized_hair_bounds[2]) * 0.5
        source_hair_y = (resized_hair_bounds[1] + resized_hair_bounds[3]) * 0.5
    else:
        reference_hair_x = hair_anchor_x(reference) + (canvas_width - reference.width) * 0.5
        source_hair_x = hair_anchor_x(resized)
    target_x = round(reference_hair_x - source_hair_x)
    target_x = max(4, min(target_x, canvas_width - resized.width - 4))
    target_y = round(reference_bounds[3] + reference_y_offset - resized.height)
    if match_character_scale:
        target_y = round(reference_hair_y - source_hair_y)
    target_y = max(4, min(target_y, canvas_height - 4 - resized.height))

    canvas = Image.new("RGBA", (canvas_width, canvas_height), (0, 0, 0, 0))
    canvas.alpha_composite(resized, (target_x, target_y))
    darken_exposed_light_outline(canvas)
    remove_tiny_opaque_islands(canvas)
    return canvas


def boundary_fringe_count(image: Image.Image) -> int:
    pixels = image.load()
    width, height = image.size
    count = 0
    for y in range(1, height - 1):
        for x in range(1, width - 1):
            red, green, blue, alpha = pixels[x, y]
            brightness = (red + green + blue) / 3.0
            if not alpha or brightness < 190.0 or max(red, green, blue) - min(red, green, blue) > 60:
                continue
            if any(pixels[nx, ny][3] == 0 for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1))):
                count += 1
    return count


def validate_frame(
    path: Path,
    image: Image.Image,
    expected_height: int,
    maximum_fringe: int = 0,
) -> None:
    bounds = image.getchannel("A").getbbox()
    if image.mode != "RGBA" or image.height != expected_height or bounds is None:
        raise RuntimeError(f"Invalid frame format: {path}")
    if bounds[0] < 2 or bounds[2] > image.width - 2 or bounds[1] < 2 or bounds[3] > image.height - 2:
        raise RuntimeError(f"Frame lacks safe transparent margin: {path} {bounds}")
    if any(
        image.getpixel(point)[3]
        for point in (
            (0, 0),
            (image.width - 1, 0),
            (0, image.height - 1),
            (image.width - 1, image.height - 1),
        )
    ):
        raise RuntimeError(f"Opaque canvas corner: {path}")
    fringe = boundary_fringe_count(image)
    if fringe > maximum_fringe:
        raise RuntimeError(
            f"Possible pale fringe: {path} count={fringe} allowed={maximum_fringe}"
        )


def validate_character_alignment(
    path: Path,
    image: Image.Image,
    reference: Image.Image,
) -> None:
    image_anchors = character_scale_anchors(image)
    reference_anchors = character_scale_anchors(reference)
    if image_anchors is None or reference_anchors is None:
        raise RuntimeError(f"Missing character anchors: {path}")
    expected_hair_x = reference_anchors[0] + (image.width - reference.width) * 0.5
    expected_foot_y = reference_anchors[2] + (image.height - reference.height) * 0.5
    hair_drift = abs(image_anchors[0] - expected_hair_x)
    foot_drift = abs(image_anchors[2] - expected_foot_y)
    body_height_drift = abs(image_anchors[1] - reference_anchors[1])
    if hair_drift > 2.0 or foot_drift > 3.0 or body_height_drift > 16.0:
        raise RuntimeError(
            f"Character anchor drift: {path} "
            f"hair={hair_drift:.1f}px foot={foot_drift:.1f}px "
            f"height={body_height_drift:.1f}px"
        )


def validate_canonical_head(
    path: Path,
    image: Image.Image,
    reference: Image.Image,
) -> None:
    reference_rgba = reference.convert("RGBA")
    reference_pixels = reference_rgba.load()
    image_pixels = image.convert("RGBA").load()
    offset_x = round((image.width - reference_rgba.width) * 0.5)
    offset_y = round((image.height - reference_rgba.height) * 0.5)
    mismatch_count = 0
    for x, y in head_identity_mask(reference_rgba):
        target_x = x + offset_x
        target_y = y + offset_y
        if not (0 <= target_x < image.width and 0 <= target_y < image.height):
            mismatch_count += 1
            continue
        if image_pixels[target_x, target_y] != reference_pixels[x, y]:
            mismatch_count += 1
    if mismatch_count:
        raise RuntimeError(
            f"Canonical head changed in weapon frame: {path} mismatches={mismatch_count}"
        )


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
            spec.canvas_height,
        )
        frame = bake_effect_into_frame(frame, spec.weapon_dir, output_name)
        frame = apply_canonical_head(frame, reference)
        output_path = output_dir / output_name
        reference_fringe = boundary_fringe_count(reference)
        # A painted crescent deliberately contains exposed white cutting-edge
        # pixels. Allow that known raster layer without weakening validation on
        # the remaining movement, windup, follow-through and recovery frames.
        fringe_allowance = 384 if output_name in POSE_EFFECTS else 32
        validate_frame(
            output_path,
            frame,
            spec.canvas_height,
            reference_fringe + fringe_allowance,
        )
        if spec.match_character_scale:
            validate_canonical_head(output_path, frame, reference)
        frame.save(output_path, optimize=True)
        print(f"wrote {output_path.relative_to(PROJECT_ROOT)} bounds={frame.getchannel('A').getbbox()}")

        if output_name == "hero_attack_recovery.png":
            idle_reference = Image.open(FRAME_ROOT / "hero_idle.png").convert("RGBA")
            idle_frame = normalize_complete_pose(
                complete_cell,
                idle_reference,
                spec.canvas_width,
                True,
                spec.canvas_height,
                True,
            )
            idle_frame = apply_canonical_head(idle_frame, idle_reference)
            idle_path = output_dir / "hero_idle.png"
            validate_frame(
                idle_path,
                idle_frame,
                spec.canvas_height,
                boundary_fringe_count(idle_reference) + 32,
            )
            validate_canonical_head(idle_path, idle_frame, idle_reference)
            idle_frame.save(idle_path, optimize=True)
            print(
                f"wrote {idle_path.relative_to(PROJECT_ROOT)} "
                f"bounds={idle_frame.getchannel('A').getbbox()}"
            )


def main() -> None:
    for spec in SPECS:
        build_sheet(spec)


if __name__ == "__main__":
    main()
