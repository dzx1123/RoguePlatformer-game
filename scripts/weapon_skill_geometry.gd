extends RefCounted

class_name WeaponSkillGeometry

## Shared combat and rendering bounds for the non-moon weapon skills.
## Keeping these rectangles centralized prevents their trails from implying
## substantially more reach than the actual hit checks.

const MIN_REACH_SCALE := 0.75
const MAX_REACH_SCALE := 2.20


static func get_twin_blades_rect(
	origin: Vector2,
	facing: float,
	reach_scale: float
) -> Rect2:
	var range_factor: float = sqrt(clampf(
		reach_scale,
		MIN_REACH_SCALE,
		MAX_REACH_SCALE
	))
	var forward_reach: float = 150.0 * range_factor
	var rear_reach: float = 34.0 * range_factor
	var safe_facing: float = -1.0 if facing < 0.0 else 1.0
	var left: float = origin.x - rear_reach
	if safe_facing < 0.0:
		left = origin.x - forward_reach
	return Rect2(
		Vector2(left, origin.y - 68.0 * range_factor),
		Vector2(
			forward_reach + rear_reach,
			116.0 * range_factor
		)
	)


static func get_greatsword_rect(
	origin: Vector2,
	facing: float,
	reach_scale: float
) -> Rect2:
	var range_factor: float = sqrt(clampf(
		reach_scale,
		MIN_REACH_SCALE,
		MAX_REACH_SCALE
	))
	var safe_facing: float = -1.0 if facing < 0.0 else 1.0
	var half_width: float = 118.0 * range_factor
	var center := origin + Vector2(
		safe_facing * 24.0 * range_factor,
		-4.0 * range_factor
	)
	return Rect2(
		center - Vector2(half_width, 62.0 * range_factor),
		Vector2(half_width * 2.0, 128.0 * range_factor)
	)
