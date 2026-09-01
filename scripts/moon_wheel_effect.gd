extends Node2D

class_name MoonWheelEffect

const GEOMETRY := preload("res://scripts/moon_wheel_geometry.gd")
const DEEP_VIOLET := Color(0.075, 0.025, 0.18, 1.0)
const DARK_MOON := Color(0.09, 0.03, 0.21, 1.0)
const GHOST_VIOLET := Color(0.43, 0.20, 0.96, 1.0)
const MOON_VIOLET := Color(0.76, 0.43, 1.0, 1.0)
const MOON_CORE := Color(0.84, 0.96, 1.0, 1.0)

var _active: bool = false
var _progress: float = 0.0
var _facing: float = 1.0
var _hit_radii := Vector2.ZERO
var _accent := Color("#78d9ef")


func _ready() -> void:
	visible = false


func set_skill_state(
	active: bool,
	progress: float,
	facing: float,
	hit_radii: Vector2,
	accent: Color
) -> void:
	_active = active
	_progress = clampf(progress, 0.0, 1.0)
	_facing = -1.0 if facing < 0.0 else 1.0
	_hit_radii = hit_radii
	_accent = accent
	visible = _active
	queue_redraw()


func is_effect_active() -> bool:
	return _active


func get_effect_center() -> Vector2:
	return GEOMETRY.get_local_center(_facing)


func get_hit_radii() -> Vector2:
	return _hit_radii


func _draw() -> void:
	if not _active or _hit_radii.x <= 0.0 or _hit_radii.y <= 0.0:
		return

	var center: Vector2 = get_effect_center()
	var opening_progress: float = smoothstep(
		0.0,
		1.0,
		clampf((_progress - 0.10) / 0.22, 0.0, 1.0)
	)
	var opening_fade: float = 1.0 - smoothstep(
		0.0,
		1.0,
		clampf((_progress - 0.40) / 0.12, 0.0, 1.0)
	)
	var moon_draw: float = smoothstep(
		0.0,
		1.0,
		clampf((_progress - 0.28) / 0.24, 0.0, 1.0)
	)
	var secondary_draw: float = smoothstep(
		0.0,
		1.0,
		clampf((_progress - 0.35) / 0.22, 0.0, 1.0)
	)
	var darken: float = smoothstep(
		0.0,
		1.0,
		clampf((_progress - 0.50) / 0.14, 0.0, 1.0)
	)
	var cut_progress: float = smoothstep(
		0.0,
		1.0,
		clampf((_progress - 0.56) / 0.14, 0.0, 1.0)
	)
	var shatter: float = smoothstep(
		0.0,
		1.0,
		clampf((_progress - 0.68) / 0.15, 0.0, 1.0)
	)
	var shard_progress: float = clampf((_progress - 0.68) / 0.24, 0.0, 1.0)
	var moon_fade: float = 1.0 - smoothstep(
		0.0,
		1.0,
		clampf((_progress - 0.70) / 0.16, 0.0, 1.0)
	)
	var impact: float = 1.0 - clampf(absf(_progress - 0.70) / 0.085, 0.0, 1.0)
	var stroke_radii := Vector2(
		maxf(8.0, _hit_radii.x - 11.0),
		maxf(8.0, _hit_radii.y - 11.0)
	)

	# The rising slash leaves a short crescent before the larger two-handed moon.
	if opening_progress > 0.01 and opening_fade > 0.01:
		_draw_tapered_arc(
			center + Vector2(_facing * 3.0, 4.0),
			stroke_radii * Vector2(0.67, 0.70),
			2.42,
			5.34,
			opening_progress,
			10.0,
			opening_fade * 0.92,
			MOON_VIOLET,
			MOON_CORE
		)

	# A translucent violet body turns the traced outline into a readable dark moon.
	if moon_draw > 0.02 and shatter < 0.99:
		var moon_body_alpha: float = (
			0.05 * moon_draw
			+ 0.28 * darken
			+ 0.08 * impact
		) * (1.0 - shatter)
		_draw_filled_ellipse(
			center,
			stroke_radii * 0.82,
			Color(DARK_MOON.r, DARK_MOON.g, DARK_MOON.b, moon_body_alpha)
		)
		_draw_filled_ellipse(
			center + Vector2(-_facing * stroke_radii.x * 0.12, -stroke_radii.y * 0.10),
			stroke_radii * Vector2(0.54, 0.60),
			Color(GHOST_VIOLET.r, GHOST_VIOLET.g, GHOST_VIOLET.b, moon_body_alpha * 0.22)
		)

	# The main brush stroke nearly closes the circle; its small lower gap makes it
	# read as a sword trail rather than a shield ring.
	if moon_draw > 0.01 and moon_fade > 0.01:
		_draw_tapered_arc(
			center,
			stroke_radii,
			2.54,
			2.54 + TAU * 0.94,
			moon_draw,
			15.0,
			moon_fade * (0.78 + impact * 0.22),
			GHOST_VIOLET,
			MOON_CORE
		)
		_draw_tapered_arc(
			center,
			stroke_radii * Vector2(0.80, 0.78),
			2.92,
			2.92 + TAU * 0.42,
			secondary_draw,
			7.0,
			moon_fade * 0.42,
			MOON_VIOLET,
			Color(_accent.r, _accent.g, _accent.b, 1.0)
		)

	# Fine cracks become visible while the character turns the blade downward.
	if darken > 0.02 and shatter < 0.96:
		for crack_index in range(7):
			var crack_angle: float = -2.70 + float(crack_index) * 0.82
			var crack_direction := Vector2(
				cos(crack_angle) * _facing,
				sin(crack_angle)
			)
			var crack_start := center + Vector2(
				crack_direction.x * stroke_radii.x * 0.10,
				crack_direction.y * stroke_radii.y * 0.10
			)
			var crack_end := center + Vector2(
				crack_direction.x * stroke_radii.x * (0.42 + float(crack_index % 3) * 0.08),
				crack_direction.y * stroke_radii.y * (0.42 + float(crack_index % 3) * 0.08)
			)
			draw_line(
				crack_start,
				crack_end,
				Color(MOON_VIOLET.r, MOON_VIOLET.g, MOON_VIOLET.b, darken * (1.0 - shatter) * 0.42),
				1.4,
				true
			)

	# The descending blade is the actual hit cue. It reaches the opposite edge at
	# 70%, exactly when player.gd emits the skill hit.
	if cut_progress > 0.01 and shatter < 0.99:
		var cut_start := center + Vector2(
			-_facing * stroke_radii.x * 0.52,
			-stroke_radii.y * 0.70
		)
		var cut_end := center + Vector2(
			_facing * stroke_radii.x * 0.62,
			stroke_radii.y * 0.64
		)
		var live_cut_end: Vector2 = cut_start.lerp(cut_end, cut_progress)
		draw_line(
			cut_start,
			live_cut_end,
			Color(DEEP_VIOLET.r, DEEP_VIOLET.g, DEEP_VIOLET.b, 0.58 * moon_fade),
			18.0,
			true
		)
		draw_line(
			cut_start,
			live_cut_end,
			Color(MOON_VIOLET.r, MOON_VIOLET.g, MOON_VIOLET.b, 0.88 * moon_fade),
			8.0,
			true
		)
		draw_line(
			cut_start,
			live_cut_end,
			Color(MOON_CORE.r, MOON_CORE.g, MOON_CORE.b, 0.96 * moon_fade),
			2.5,
			true
		)

	if impact > 0.0:
		_draw_filled_ellipse(
			center,
			stroke_radii * Vector2(0.42 + impact * 0.14, 0.38 + impact * 0.12),
			Color(MOON_VIOLET.r, MOON_VIOLET.g, MOON_VIOLET.b, impact * 0.12)
		)

	# The completed dark moon breaks into outward-moving violet shards after the
	# hit. These are faint recovery particles, not part of the damage boundary.
	if shard_progress > 0.01:
		_draw_shards(center, stroke_radii, shard_progress)

	for mote_index in range(5):
		var mote_phase: float = _progress * 8.0 + float(mote_index) * 1.37
		var mote_position := center + Vector2(
			cos(mote_phase) * stroke_radii.x * (0.24 + float(mote_index) * 0.075) * _facing,
			sin(mote_phase * 1.17) * stroke_radii.y * 0.46
		)
		var mote_alpha: float = (1.0 - shatter) * moon_draw * 0.30 + impact * 0.22
		draw_circle(
			mote_position,
			1.4 + float(mote_index % 2),
			Color(MOON_VIOLET.r, MOON_VIOLET.g, MOON_VIOLET.b, mote_alpha)
		)


func _draw_tapered_arc(
	center: Vector2,
	radii: Vector2,
	start_angle: float,
	end_angle: float,
	progress: float,
	base_width: float,
	alpha: float,
	stroke_color: Color,
	core_color: Color
) -> void:
	var safe_progress: float = clampf(progress, 0.0, 1.0)
	if safe_progress <= 0.001 or alpha <= 0.001:
		return
	var live_end_angle: float = lerpf(start_angle, end_angle, safe_progress)
	var points := _ellipse_arc_points(center, radii, start_angle, live_end_angle, 38)
	for segment_index in range(points.size() - 1):
		var segment_weight: float = (
			float(segment_index) + 0.5
		) / float(maxi(1, points.size() - 1))
		var taper: float = pow(maxf(0.0, sin(segment_weight * PI)), 0.58)
		var live_width: float = maxf(1.0, base_width * (0.18 + taper * 0.82))
		draw_line(
			points[segment_index],
			points[segment_index + 1],
			Color(DEEP_VIOLET.r, DEEP_VIOLET.g, DEEP_VIOLET.b, alpha * 0.34),
			live_width + 8.0,
			true
		)
		draw_line(
			points[segment_index],
			points[segment_index + 1],
			Color(stroke_color.r, stroke_color.g, stroke_color.b, alpha * 0.86),
			live_width,
			true
		)
		draw_line(
			points[segment_index],
			points[segment_index + 1],
			Color(core_color.r, core_color.g, core_color.b, alpha),
			maxf(1.2, live_width * 0.20),
			true
		)


func _draw_filled_ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	if color.a <= 0.001:
		return
	var points := PackedVector2Array()
	for point_index in range(49):
		var angle: float = TAU * float(point_index) / 48.0
		points.append(center + Vector2(
			cos(angle) * radii.x,
			sin(angle) * radii.y
		))
	draw_colored_polygon(points, color)


func _draw_shards(center: Vector2, radii: Vector2, shatter: float) -> void:
	var travel_progress: float = smoothstep(0.0, 1.0, shatter)
	var shard_alpha: float = 1.0 - smoothstep(0.58, 1.0, shatter)
	for shard_index in range(12):
		var angle: float = -PI + float(shard_index) / 12.0 * TAU
		var direction := Vector2(cos(angle) * _facing, sin(angle))
		var tangent := Vector2(-direction.y, direction.x)
		var edge := center + Vector2(
			direction.x * radii.x * 0.82,
			direction.y * radii.y * 0.82
		)
		var travel: float = (8.0 + float(shard_index % 4) * 2.5) * travel_progress
		var shard_center: Vector2 = edge + direction * travel
		var shard_size: float = 4.0 + float(shard_index % 3) * 1.7
		var shard_points := PackedVector2Array([
			shard_center + direction * shard_size,
			shard_center - direction * shard_size * 0.65 + tangent * shard_size * 0.42,
			shard_center - direction * shard_size * 0.65 - tangent * shard_size * 0.42,
		])
		draw_colored_polygon(
			shard_points,
			Color(MOON_VIOLET.r, MOON_VIOLET.g, MOON_VIOLET.b, shard_alpha * 0.66)
		)
		draw_line(
			shard_center,
			shard_center + direction * (5.0 + shatter * 8.0),
			Color(MOON_CORE.r, MOON_CORE.g, MOON_CORE.b, shard_alpha * 0.42),
			1.2,
			true
		)


func _ellipse_arc_points(
	center: Vector2,
	radii: Vector2,
	start_angle: float,
	end_angle: float,
	segments: int
) -> PackedVector2Array:
	var points := PackedVector2Array()
	var safe_segments := maxi(2, segments)
	for segment_index in range(safe_segments + 1):
		var weight := float(segment_index) / float(safe_segments)
		var angle := lerpf(start_angle, end_angle, weight)
		points.append(center + Vector2(
			cos(angle) * radii.x * _facing,
			sin(angle) * radii.y
		))
	return points
