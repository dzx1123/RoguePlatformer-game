extends RefCounted

class_name MoonWheelGeometry

## Shared geometry for both rendering and combat. Keeping the center and radii in
## one place prevents the painted moon arc from drifting away from its hit area.
const CENTER_FORWARD := 6.0
const CENTER_Y := -18.0
const BASE_RADIUS := Vector2(82.0, 76.0)
const MIN_REACH_SCALE := 0.75
const MAX_REACH_SCALE := 2.20


static func get_local_center(facing: float) -> Vector2:
	var safe_facing := -1.0 if facing < 0.0 else 1.0
	return Vector2(CENTER_FORWARD * safe_facing, CENTER_Y)


static func get_world_center(origin: Vector2, facing: float) -> Vector2:
	return origin + get_local_center(facing)


static func get_radii(reach_scale: float) -> Vector2:
	# Weapon reach remains meaningful without making the skill grow linearly into
	# a screen-wide invisible rectangle at higher tiers.
	var range_factor := sqrt(clampf(reach_scale, MIN_REACH_SCALE, MAX_REACH_SCALE))
	return BASE_RADIUS * range_factor


static func rect_intersects_ellipse(
	hit_rect: Rect2,
	center: Vector2,
	radii: Vector2
) -> bool:
	var normalized_rect := hit_rect.abs()
	var rect_end := normalized_rect.end
	var closest_point := Vector2(
		clampf(center.x, normalized_rect.position.x, rect_end.x),
		clampf(center.y, normalized_rect.position.y, rect_end.y)
	)
	var safe_radii := Vector2(maxf(1.0, radii.x), maxf(1.0, radii.y))
	var normalized_delta := (closest_point - center) / safe_radii
	return normalized_delta.length_squared() <= 1.0
