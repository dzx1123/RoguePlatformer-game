"""Bake one-hand-style crescent art into weapon-specific strike frames.

The source sheet contains only the three approved crescent silhouettes derived
from the polished one-hand attack frames.  This module keeps those painted
white cores, soft glows and pixel shards intact; it only scales, positions and
theme-tints the finished raster artwork before compositing it into a frame.
"""

from __future__ import annotations

from collections import deque
from functools import lru_cache
from pathlib import Path
import colorsys

from PIL import Image, ImageChops, ImageFilter


PROJECT_ROOT = Path(__file__).resolve().parents[1]
WEAPON_ROOT = PROJECT_ROOT / "assets" / "characters" / "weapon_sets"
EFFECT_SOURCE = (
    WEAPON_ROOT
    / "source_effects"
    / "one_hand_crescent_reference_alpha_v1.png"
)

POSE_EFFECTS = {
    "hero_attack_forward_strike.png": "forward",
    "hero_attack_up_strike.png": "up",
    "hero_attack_down_strike.png": "down",
}

# Maximum effect bounds at the same source resolution as the 640 x 416
# one-hand frames.  Larger greatsword artwork applies a modest uniform scale
# after this fit; the shape itself never gets procedurally redrawn.
EFFECT_MAX_SIZE = {
    "forward": (430, 110),
    "up": (420, 360),
    "down": (450, 240),
}
EFFECT_CANONICAL_CENTER = {
    "forward": (420.0, 270.0),
    "up": (405.0, 165.0),
    "down": (398.0, 278.0),
}
WEAPON_EFFECT_SCALE = {
    "twin_blades": 1.0,
    "greatsword": 1.12,
}
WEAPON_EFFECT_OFFSET = {
    ("greatsword", "forward"): (20.0, 0.0),
    ("greatsword", "down"): (20.0, 28.0),
}


def _connected_alpha_components(
    alpha: Image.Image,
    threshold: int = 24,
) -> list[list[tuple[int, int]]]:
    width, height = alpha.size
    pixels = alpha.load()
    remaining = {
        (x, y)
        for y in range(height)
        for x in range(width)
        if pixels[x, y] >= threshold
    }
    components: list[list[tuple[int, int]]] = []
    while remaining:
        start = remaining.pop()
        component = [start]
        queue = deque([start])
        while queue:
            x, y = queue.popleft()
            for neighbor_x in range(max(0, x - 1), min(width, x + 2)):
                for neighbor_y in range(max(0, y - 1), min(height, y + 2)):
                    neighbor = (neighbor_x, neighbor_y)
                    if neighbor in remaining:
                        remaining.remove(neighbor)
                        component.append(neighbor)
                        queue.append(neighbor)
        components.append(component)
    return components


def _component_center_x(component: list[tuple[int, int]]) -> float:
    return (
        min(point[0] for point in component)
        + max(point[0] for point in component)
    ) * 0.5


@lru_cache(maxsize=1)
def _source_effects() -> dict[str, Image.Image]:
    source = Image.open(EFFECT_SOURCE).convert("RGBA")
    source_alpha = source.getchannel("A")
    components = sorted(
        _connected_alpha_components(source_alpha),
        key=len,
        reverse=True,
    )[:3]
    if len(components) != 3:
        raise RuntimeError(f"Could not isolate three crescent effects: {EFFECT_SOURCE}")

    # Component size varies by pose, so horizontal order is the stable label:
    # forward, rising, downward.
    ordered = sorted(components, key=_component_center_x)
    effects: dict[str, Image.Image] = {}
    for effect_name, component in zip(("forward", "up", "down"), ordered):
        component_mask = Image.new("L", source.size, 0)
        component_pixels = component_mask.load()
        for point in component:
            component_pixels[point] = 255
        # Recover the soft semi-transparent fringe removed by the component
        # threshold, without admitting pixels from a neighboring panel.
        influence = component_mask.filter(ImageFilter.MaxFilter(25))
        isolated_alpha = ImageChops.multiply(source_alpha, influence)
        isolated = source.copy()
        isolated.putalpha(isolated_alpha)
        bounds = isolated_alpha.getbbox()
        if bounds is None:
            raise RuntimeError(f"Empty crescent component: {effect_name}")
        effects[effect_name] = isolated.crop(bounds)
    return effects


def _fit_effect(effect: Image.Image, effect_name: str, scale: float) -> Image.Image:
    maximum_width, maximum_height = EFFECT_MAX_SIZE[effect_name]
    fit_scale = min(
        maximum_width / float(effect.width),
        maximum_height / float(effect.height),
    ) * scale
    size = (
        max(1, round(effect.width * fit_scale)),
        max(1, round(effect.height * fit_scale)),
    )
    return effect.resize(size, Image.Resampling.LANCZOS)


def _tint_greatsword(effect: Image.Image) -> Image.Image:
    tinted = effect.copy().convert("RGBA")
    pixels = tinted.load()
    for y in range(tinted.height):
        for x in range(tinted.width):
            red, green, blue, alpha = pixels[x, y]
            if not alpha:
                continue
            _hue, saturation, value = colorsys.rgb_to_hsv(
                red / 255.0,
                green / 255.0,
                blue / 255.0,
            )
            # Low-saturation pixels are the reference's broad white cutting
            # edge and remain white. Saturated cyan fringe becomes warm orange.
            new_red, new_green, new_blue = colorsys.hsv_to_rgb(
                0.075,
                min(1.0, saturation * 0.92),
                value,
            )
            pixels[x, y] = (
                round(new_red * 255.0),
                round(new_green * 255.0),
                round(new_blue * 255.0),
                alpha,
            )
    return tinted


@lru_cache(maxsize=12)
def prepared_effect(effect_name: str, weapon_dir: str) -> Image.Image:
    scale = WEAPON_EFFECT_SCALE[weapon_dir]
    effect = _fit_effect(_source_effects()[effect_name], effect_name, scale)
    if weapon_dir == "greatsword":
        effect = _tint_greatsword(effect)
    return effect


def bake_effect_into_frame(
    frame: Image.Image,
    weapon_dir: str,
    output_name: str,
) -> Image.Image:
    effect_name = POSE_EFFECTS.get(output_name)
    if effect_name is None:
        return frame
    effect = prepared_effect(effect_name, weapon_dir)
    canonical_x, canonical_y = EFFECT_CANONICAL_CENTER[effect_name]
    center_x = canonical_x + (frame.width - 640) * 0.5
    center_y = canonical_y + (frame.height - 416) * 0.5
    offset_x, offset_y = WEAPON_EFFECT_OFFSET.get(
        (weapon_dir, effect_name),
        (0.0, 0.0),
    )
    target_x = round(center_x + offset_x - effect.width * 0.5)
    target_y = round(center_y + offset_y - effect.height * 0.5)
    if (
        target_x < 2
        or target_y < 2
        or target_x + effect.width > frame.width - 2
        or target_y + effect.height > frame.height - 2
    ):
        raise RuntimeError(
            f"Baked effect lacks canvas margin: {weapon_dir}/{output_name} "
            f"at {(target_x, target_y)} size={effect.size} canvas={frame.size}"
        )
    result = frame.copy().convert("RGBA")
    result.alpha_composite(effect, (target_x, target_y))
    return result


def main() -> None:
    preview_root = PROJECT_ROOT / "tests" / "artifacts" / "weapon_baked_effect_preview"
    for weapon_dir in ("twin_blades", "greatsword"):
        for output_name in POSE_EFFECTS:
            source_path = WEAPON_ROOT / weapon_dir / output_name
            frame = Image.open(source_path).convert("RGBA")
            preview = bake_effect_into_frame(frame, weapon_dir, output_name)
            output_path = preview_root / weapon_dir / output_name
            output_path.parent.mkdir(parents=True, exist_ok=True)
            preview.save(output_path, optimize=True)
            print(f"wrote {output_path.relative_to(PROJECT_ROOT)}")


if __name__ == "__main__":
    main()
