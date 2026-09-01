extends Node2D

class_name WeaponSkillEffect

const GEOMETRY := preload("res://scripts/weapon_skill_geometry.gd")
const TWIN_HIT_PROGRESS: Array[float] = [0.18, 0.48, 0.78]

var _active: bool = false
var _progress: float = 0.0
var _facing: float = 1.0
var _weapon_id: StringName = WeaponCatalog.SWORD
var _reach_scale: float = 1.0
var _accent := Color.WHITE


func _ready() -> void:
	visible = false


func set_skill_state(
	active: bool,
	progress: float,
	facing: float,
	weapon_id: StringName,
	reach_scale: float,
	accent: Color
) -> void:
	_active = active and weapon_id != WeaponCatalog.SWORD
	_progress = clampf(progress, 0.0, 1.0)
	_facing = -1.0 if facing < 0.0 else 1.0
	_weapon_id = weapon_id
	_reach_scale = reach_scale
	_accent = accent
	visible = _active
	queue_redraw()


func is_effect_active() -> bool:
	return _active


func get_weapon_id() -> StringName:
	return _weapon_id


func _draw() -> void:
	if not _active:
		return
	match _weapon_id:
		WeaponCatalog.TWIN_BLADES:
			_draw_twin_blades()
		WeaponCatalog.GREATSWORD:
			_draw_greatsword()


func _draw_twin_blades() -> void:
	var bounds: Rect2 = GEOMETRY.get_twin_blades_rect(
		Vector2.ZERO,
		_facing,
		_reach_scale
	)
	var travel_start_x: float = (
		bounds.position.x if _facing > 0.0 else bounds.end.x
	)
	var travel_end_x: float = (
		bounds.end.x if _facing > 0.0 else bounds.position.x
	)
	for hit_index in range(TWIN_HIT_PROGRESS.size()):
		var hit_progress: float = TWIN_HIT_PROGRESS[hit_index]
		var pulse_age: float = (_progress - hit_progress) / 0.16
		if pulse_age < -0.75 or pulse_age > 1.0:
			continue
		var draw_progress: float = clampf(pulse_age + 0.75, 0.0, 1.0)
		var pulse_alpha: float = (
			smoothstep(0.0, 1.0, draw_progress / 0.28)
			* (1.0 - smoothstep(0.48, 1.0, draw_progress))
		)
		var lane_y: float = -36.0 + float(hit_index) * 20.0
		var live_x: float = lerpf(
			travel_start_x,
			travel_end_x,
			smoothstep(0.0, 1.0, draw_progress)
		)
		var slash_direction: float = -1.0 if hit_index % 2 == 0 else 1.0
		var slash_start := Vector2(
			live_x - _facing * 58.0,
			lane_y - slash_direction * 34.0
		)
		var slash_end := Vector2(
			live_x + _facing * 26.0,
			lane_y + slash_direction * 34.0
		)
		_draw_blade_streak(slash_start, slash_end, pulse_alpha, 10.0)
		for trail_index in range(3):
			var trail_offset: float = float(trail_index + 1) * 13.0
			draw_line(
				slash_start - Vector2(_facing * trail_offset, 0.0),
				slash_end - Vector2(_facing * trail_offset, 0.0),
				Color(
					_accent.r,
					_accent.g,
					_accent.b,
					pulse_alpha * (0.18 - float(trail_index) * 0.04)
				),
				maxf(1.0, 5.0 - float(trail_index)),
				true
			)


func _draw_greatsword() -> void:
	var bounds: Rect2 = GEOMETRY.get_greatsword_rect(
		Vector2.ZERO,
		_facing,
		_reach_scale
	)
	var windup: float = (
		smoothstep(0.0, 1.0, clampf((_progress - 0.08) / 0.30, 0.0, 1.0))
		* (1.0 - smoothstep(0.0, 1.0, clampf((_progress - 0.50) / 0.14, 0.0, 1.0)))
	)
	if windup > 0.01:
		var raised_start := Vector2(-_facing * 20.0, 8.0)
		var raised_end := Vector2(_facing * 30.0, -112.0)
		_draw_blade_streak(raised_start, raised_end, windup * 0.72, 13.0)

	var impact: float = 1.0 - clampf(absf(_progress - 0.62) / 0.12, 0.0, 1.0)
	if impact > 0.01:
		var cut_start := Vector2(-_facing * 34.0, -112.0)
		var cut_end := Vector2(_facing * 34.0, 24.0)
		_draw_blade_streak(cut_start, cut_end, impact, 20.0)
		draw_circle(
			cut_end,
			12.0 + impact * 18.0,
			Color(_accent.r, _accent.g, _accent.b, impact * 0.18)
		)

	var shockwave_progress: float = clampf((_progress - 0.60) / 0.28, 0.0, 1.0)
	if shockwave_progress <= 0.0:
		return
	var shockwave_alpha: float = 1.0 - smoothstep(0.42, 1.0, shockwave_progress)
	var center_x: float = bounds.get_center().x
	var half_width: float = bounds.size.x * 0.5 * shockwave_progress
	var wave_points := PackedVector2Array()
	for point_index in range(21):
		var weight: float = float(point_index) / 20.0
		var x_position: float = center_x + lerpf(-half_width, half_width, weight)
		var arch: float = sin(weight * PI)
		wave_points.append(Vector2(
			x_position,
			24.0 - arch * (10.0 + 16.0 * shockwave_progress)
		))
	draw_polyline(
		wave_points,
		Color(_accent.r, _accent.g, _accent.b, shockwave_alpha * 0.82),
		8.0,
		true
	)
	draw_polyline(
		wave_points,
		Color(1.0, 0.92, 0.76, shockwave_alpha * 0.92),
		2.0,
		true
	)


func _draw_blade_streak(
	start: Vector2,
	end: Vector2,
	alpha: float,
	width: float
) -> void:
	if alpha <= 0.001:
		return
	draw_line(
		start,
		end,
		Color(0.04, 0.02, 0.10, alpha * 0.44),
		width + 9.0,
		true
	)
	draw_line(
		start,
		end,
		Color(_accent.r, _accent.g, _accent.b, alpha * 0.90),
		width,
		true
	)
	draw_line(
		start,
		end,
		Color(1.0, 0.96, 0.90, alpha),
		maxf(1.5, width * 0.20),
		true
	)
