# Goblin reference motion

The user supplied and authorized direct reuse of `goblin_motion_reference.gif`.
`tools/import_goblin_reference.py` unpacks its 17 frames without repainting limbs
or interpolating pixel artwork. The source remains in `assets/enemies/source/`.

Frame mapping: idle 0; melee attack 1–4; hurt 5–6; collapse 7–9; airborne crouch
10; walk 11–16. All six walk frames share one origin and the original 100 ms
duration at patrol speed. Pursuit cadence follows travel speed; stopping settles
to a contact pose, and turn anticipation preserves the outgoing facing.

Normal, elite, ranged and boss goblins use this same model. A skin-only palette
shader preserves eye, leather and weapon colours. Horn landmarks follow each
frame; elites/chiefs have longer horns. Ranged units also display a quiver and
drawn bow while keeping arrow damage and timing unchanged.

The GIF does not contain bow-shooting or jumping animation. Ranged attacks use
its guard/recoil poses with a drawn bow attachment, and jumping uses its tucked
pose. Original attack, hurt and death drawings are used for the other actions.

QA capture scripts write local artifacts under the ignored `test_output/`
directory. Tests cover all four variants, source frame order, facing, cadence,
foot registration, arrows, melee, boss phases and 20-room progression.
