"""Losslessly unpack the user-provided GIF; no redrawing of its motion."""
from pathlib import Path
from PIL import Image
import json

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets/enemies/source/goblin_motion_reference.gif"
OUT = ROOT / "assets/enemies/goblin_reference_atlas.png"


def main():
    source = Image.open(SOURCE)
    assert source.n_frames == 17 and source.size == (136, 122)
    cell = (144, 138)
    atlas = Image.new("RGBA", (cell[0] * 17, cell[1]))
    durations = []
    for index in range(17):
        source.seek(index)
        frame = source.convert("RGBA")
        # One shared registration for the entire walk cycle preserves authored bob.
        offset_y = 12 if index >= 11 else (1 if 7 <= index <= 9 else 8)
        atlas.alpha_composite(frame, (index * cell[0] + 4, offset_y))
        durations.append(source.info.get("duration", 100))
    atlas.save(OUT)
    (OUT.with_suffix(".json")).write_text(json.dumps({
        "source": SOURCE.name, "cell": cell, "durations_ms": durations,
        "idle": [0], "attack": [1, 2, 3, 4], "hurt": [5, 6],
        "death": [7, 8, 9], "air": [10], "walk": [11, 12, 13, 14, 15, 16],
    }, indent=2), encoding="utf-8")
    print("Imported 17 original frames; walk timing 6 x 100 ms, shared origin")


if __name__ == "__main__":
    main()
