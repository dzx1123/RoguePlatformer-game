# Weapon identity polish

The one-hand hero is the proportion reference. Runtime calibration no longer
applies weapon-dependent scale or attack-dependent colour changes. Idle source
normalization measures warm leather boot pixels rather than a trailing blade.

Greatsword attack source: `assets/characters/weapon_sets/greatsword/source/hero_attack_fullbody_sheet_v4.png`.
Created with built-in imagegen, then imported through the existing complete-figure
pipeline with canonical heads and existing crescent effects.

Prompt specification: edit the twelve-pose 4x3 greatsword sheet, preserve pose order
and full-body silhouettes; use the standing sword as the sole identity reference:
broad straight navy polygon blade, orange central zigzag, gold guard, square cyan
gem in square gold collar, brown grip and gold pommel. Maintain consistent physical
sword proportions and hero identity across all swings. Request transparency, no
painted checkerboard, no white halo, no labels, and no baked slash effects.

The returned checker backdrop is removed by the importer. Old sources are retained
for provenance; the runtime and rebuild specification use v4.

Verification: runtime-material action comparison, canonical scale in every weapon
pose and facing, boot registration, animation-set loading and skill behaviour.
