"""Build the authored night-bat hanging pose at the runtime pixel scale."""

from __future__ import annotations

from collections import deque
from pathlib import Path

from PIL import Image


PROJECT_ROOT = Path(__file__).resolve().parents[1]
SOURCE = PROJECT_ROOT / "assets" / "enemies" / "source" / "night_bat_hang_source_v1.png"
OUTPUT = PROJECT_ROOT / "assets" / "enemies" / "night_bat_hang.png"


def largest_alpha_component(image: Image.Image) -> Image.Image:
    rgba = image.convert("RGBA")
    alpha = rgba.getchannel("A")
    pixels = alpha.load()
    width, height = rgba.size
    visited: set[tuple[int, int]] = set()
    largest: list[tuple[int, int]] = []

    for y in range(height):
        for x in range(width):
            if pixels[x, y] < 32 or (x, y) in visited:
                continue
            queue: deque[tuple[int, int]] = deque([(x, y)])
            visited.add((x, y))
            component: list[tuple[int, int]] = []
            while queue:
                px, py = queue.popleft()
                component.append((px, py))
                for nx, ny in ((px - 1, py), (px + 1, py), (px, py - 1), (px, py + 1)):
                    if 0 <= nx < width and 0 <= ny < height and pixels[nx, ny] >= 32 and (nx, ny) not in visited:
                        visited.add((nx, ny))
                        queue.append((nx, ny))
            if len(component) > len(largest):
                largest = component

    if not largest:
        raise RuntimeError("The hanging bat source has no visible component")
    left = min(point[0] for point in largest)
    top = min(point[1] for point in largest)
    right = max(point[0] for point in largest) + 1
    bottom = max(point[1] for point in largest) + 1
    isolated = Image.new("RGBA", (right - left, bottom - top), (0, 0, 0, 0))
    source_pixels = rgba.load()
    isolated_pixels = isolated.load()
    for x, y in largest:
        red, green, blue, alpha_value = source_pixels[x, y]
        isolated_pixels[x - left, y - top] = (red, green, blue, 255 if alpha_value >= 32 else 0)
    return isolated


def main() -> None:
    figure = largest_alpha_component(Image.open(SOURCE))
    target_height = 47
    target_width = max(1, round(figure.width * target_height / figure.height))
    figure = figure.resize((target_width, target_height), Image.Resampling.NEAREST)
    canvas = Image.new("RGBA", (32, 56), (0, 0, 0, 0))
    canvas.alpha_composite(figure, ((canvas.width - figure.width) // 2, 4))
    bounds = canvas.getchannel("A").getbbox()
    if bounds is None or bounds[0] < 2 or bounds[1] < 2 or bounds[2] > 30 or bounds[3] > 54:
        raise RuntimeError(f"Hanging bat lacks safe transparent padding: {bounds}")
    canvas.save(OUTPUT, optimize=True)
    print(f"wrote {OUTPUT.relative_to(PROJECT_ROOT)} bounds={bounds}")


if __name__ == "__main__":
    main()
