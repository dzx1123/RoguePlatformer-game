# Red Fang goblin reference animation

`goblin_motion_reference.gif` is the canonical movement reference supplied for
the ordinary melee goblin. It contains 17 frames at 100 ms per frame:

- frames 0-4: guarded wind-up, overhead anticipation, low forward strike, recovery;
- frames 5-9: stagger, fall, ground impact, prone pose;
- frames 10-14: low guarded idle/breathing;
- frames 15-16: alternating crouched walk contacts.

## Identity-preserve generation brief

Mode: **precise object edit / identity preserve**.

Keep the existing compact red Red Fang goblin identity unchanged: angular head,
black crown spikes, long pointed ear, cyan eye, mustard scarf, brown leather gear,
knobbly wooden club, and cyan charm. Transfer only the reference GIF's low center
of gravity, bent-knee silhouettes, overhead anticipation, forward low strike,
four-stage collapse, and stalking walk. Do not introduce green skin, a shield, a
sword, new armor, missing equipment, labels, shadows, or smooth painterly edges.
Generate clean fantasy pixel art on flat `#14F40C` chroma green.

The main output is a 4x4 sheet: idle, walk, attack, and hurt/death rows. The walk
output is a separate 4x2 eight-frame cycle. Every cell is normalized to 313x313,
its floor contact is baked to local y=300, and standing torso anchors are aligned.

## Runtime outputs

- `../red_fang_goblin_club_sheet_v2.png`
- `../red_fang_goblin_club_walk_sheet_v5.png`

Rebuild the normalized sheets with `tools/process_goblin_action_v2.ps1` and
`tools/process_goblin_walk_v4.ps1`; the two `*_chroma.png` files are the retained
generation sources.

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tools/process_goblin_walk_v4.ps1 -SourcePath assets/enemies/source/red_fang_goblin_reference_walk_v1_chroma.png -OutputPath assets/enemies/red_fang_goblin_club_walk_sheet_v5.png -TargetBottom 300 -TargetTorsoAnchor 146
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tools/process_goblin_action_v2.ps1 -SourcePath assets/enemies/source/red_fang_goblin_reference_sheet_v1_chroma.png -OutputPath assets/enemies/red_fang_goblin_club_sheet_v2.png -TargetBottom 300 -AttackSpillShift 22 -TargetIdleTorsoAnchor 152 -WalkSheetPath assets/enemies/red_fang_goblin_club_walk_sheet_v5.png
```
