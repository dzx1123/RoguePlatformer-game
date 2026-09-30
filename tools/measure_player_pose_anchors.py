"""Measure existing artwork only; write head anchors without altering any images."""
from pathlib import Path
from PIL import Image
from build_weapon_fullbody_frames import hair_component_points, point_bounds

ROOT = Path(__file__).resolve().parents[1]
lines = ["extends RefCounted", "", "# Measured from existing art by tools/measure_player_pose_anchors.py.", "const HEADS := {"]
folders = [ROOT / "assets/characters/frames_polished", ROOT / "assets/characters/weapon_sets/twin_blades", ROOT / "assets/characters/weapon_sets/greatsword"]
for folder in folders:
    for path in sorted(folder.glob("hero_*.png")):
        image = Image.open(path).convert("RGBA")
        left, top, right, bottom = point_bounds(hair_component_points(image))
        x = (left + right - image.width) / 2
        y = (top + bottom - image.height) / 2
        key = "res://" + path.relative_to(ROOT).as_posix()
        lines.append(f'\t"{key}": Vector2({x}, {y}),')
lines.append("}")
(ROOT / "scripts/player_pose_anchors.gd").write_text("\n".join(lines) + "\n", encoding="utf-8")
print(f"Measured {len(lines) - 5} pose anchors; image files unchanged")
