"""Measure the boot line without letting a trailing greatsword define body height."""
from PIL import Image


def boot_line(image: Image.Image, hair_bounds: tuple[int, int, int, int]) -> float:
    pixels = image.convert("RGBA").load()
    head_x = (hair_bounds[0] + hair_bounds[2]) * 0.5
    hair_width = hair_bounds[2] - hair_bounds[0]
    left = max(0, round(head_x - hair_width * 1.4))
    right = min(image.width, round(head_x + hair_width * 1.0))
    # Leather boots have dark warm pixels; the blade has cool metal and bright runes.
    for y in range(image.height - 1, round(image.height * 0.55), -1):
        count = 0
        for x in range(left, right):
            r, g, b, a = pixels[x, y]
            if a >= 128 and 24 < r < 175 and r > g * 1.10 and g > b * 1.10:
                count += 1
        if count >= 3:
            return float(y + 1)
    raise RuntimeError("Cannot find leather boot line for body registration")
