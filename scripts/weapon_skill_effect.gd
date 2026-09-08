extends Node2D

class_name WeaponSkillEffect

const GEOMETRY := preload("res://scripts/weapon_skill_geometry.gd")
const TWIN_HIT_PROGRESS: Array[float] = [0.18, 0.48, 0.78]

var _active: bool = false
var _progress: float = 0.0
var _attack_active: bool = false
var _attack_progress: float = 0.0
var _attack_type: int = 0
var _draw_call_count: int = 0
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
	visible = _active or _attack_active
	queue_redraw()


func set_attack_state(
	active: bool,
	progress: float,
	facing: float,
	weapon_id: StringName,
	reach_scale: float,
	accent: Color,
	attack_type: int
) -> void:
	_attack_active = active and weapon_id != WeaponCatalog.SWORD
	_attack_progress = clampf(progress, 0.0, 1.0)
	_attack_type = clampi(attack_type, 0, 2)
	_facing = -1.0 if facing < 0.0 else 1.0
	_weapon_id = weapon_id
	_reach_scale = reach_scale
	_accent = accent
	visible = _active or _attack_active
	queue_redraw()


func is_effect_active() -> bool:
	return _active or _attack_active


func is_attack_effect_active() -> bool:
	return _attack_active


func get_weapon_id() -> StringName:
	return _weapon_id


func get_draw_call_count() -> int:
	return _draw_call_count


func _draw() -> void:
	_draw_call_count += 1
	if _attack_active:
		match _weapon_id:
			WeaponCatalog.TWIN_BLADES:
				_draw_twin_attack_qi()
			WeaponCatalog.GREATSWORD:
				_draw_great_attack_qi()
	if _active:
		match _weapon_id:
			WeaponCatalog.TWIN_BLADES:
				_draw_twin_blades()
			WeaponCatalog.GREATSWORD:
				_draw_greatsword()


func _draw_twin_attack_qi() -> void:
	# Two narrow, staggered ribbons sell speed without covering the character.
	for blade_index in range(2):
		var phase: float = clampf(
			(_attack_progress - 0.20 - float(blade_index) * 0.055) / 0.40,
			0.0,
			1.0
		)
		if phase <= 0.0 or phase >= 1.0:
			continue
		var alpha: float = pow(sin(phase * PI), 0.72)
		var points: PackedVector2Array = _attack_arc_points(
			_attack_type,
			_reach_scale * (0.92 + float(blade_index) * 0.08),
			float(blade_index) * 8.0 - 4.0
		)
		_draw_energy_ribbon(points, alpha * 0.92, 7.0 - float(blade_index), Color("#b48cff"))
		var echo := PackedVector2Array()
		for point: Vector2 in points:
			echo.append(point - Vector2(_facing * (10.0 + float(blade_index) * 7.0), 0.0))
		draw_polyline(echo, Color(0.28, 0.88, 1.0, alpha * 0.24), 3.0, true)


func _draw_great_attack_qi() -> void:
	# One broad pressure crescent follows the blade, then a delayed ground/air
	# compression line makes the weapon feel heavy instead of merely slow.
	var phase: float = clampf((_attack_progress - 0.31) / 0.46, 0.0, 1.0)
	if phase > 0.0 and phase < 1.0:
		var alpha: float = pow(sin(phase * PI), 0.62)
		var points := _attack_arc_points(_attack_type, _reach_scale * 1.12, 0.0)
		_draw_energy_ribbon(points, alpha, 17.0, Color("#ff9b62"))
		var inner := PackedVector2Array()
		for point: Vector2 in points:
			inner.append(point + Vector2(0.0, 4.0))
		draw_polyline(inner, Color(1.0, 0.88, 0.58, alpha * 0.70), 4.0, true)

	var impact_age: float = clampf((_attack_progress - 0.42) / 0.32, 0.0, 1.0)
	if impact_age <= 0.0 or impact_age >= 1.0:
		return
	var impact_alpha: float = 1.0 - smoothstep(0.18, 1.0, impact_age)
	var direction_y := 0.0
	if _attack_type == 1:
		direction_y = -58.0
	elif _attack_type == 2:
		direction_y = 24.0
	var center := Vector2(_facing * 82.0 * _reach_scale, direction_y)
	var half_length: float = lerpf(12.0, 62.0 * _reach_scale, impact_age)
	var normal := Vector2(0.0, 1.0) if _attack_type == 0 else Vector2(_facing, 0.0)
	draw_line(
		center - normal * half_length,
		center + normal * half_length,
		Color(_accent.r, _accent.g, _accent.b, impact_alpha * 0.28),
		lerpf(11.0, 2.0, impact_age),
		true
	)


func _attack_arc_points(attack_type: int, reach: float, lane_offset: float) -> PackedVector2Array:
	var start: Vector2
	var control: Vector2
	var finish: Vector2
	match attack_type:
		1:
			start = Vector2(-_facing * 12.0, 24.0 + lane_offset)
			control = Vector2(_facing * 76.0 * reach, -22.0 + lane_offset)
			finish = Vector2(_facing * 28.0 * reach, -122.0 * reach + lane_offset)
		2:
			start = Vector2(-_facing * 5.0, -104.0 * reach + lane_offset)
			control = Vector2(_facing * 82.0 * reach, -32.0 + lane_offset)
			finish = Vector2(_facing * 44.0 * reach, 30.0 + lane_offset)
		_:
			start = Vector2(-_facing * 24.0, 25.0 + lane_offset)
			control = Vector2(_facing * 62.0 * reach, -76.0 + lane_offset)
			finish = Vector2(_facing * 132.0 * reach, -4.0 + lane_offset)
	var points := PackedVector2Array()
	for point_index in range(19):
		var weight: float = float(point_index) / 18.0
		var inverse: float = 1.0 - weight
		points.append(
			start * inverse * inverse
			+ control * 2.0 * inverse * weight
			+ finish * weight * weight
		)
	return points


func _draw_energy_ribbon(
	points: PackedVector2Array,
	alpha: float,
	width: float,
	color: Color
) -> void:
	if points.size() < 2 or alpha <= 0.001:
		return
	draw_polyline(points, Color(0.03, 0.02, 0.09, alpha * 0.45), width + 12.0, true)
	draw_polyline(points, Color(color.r, color.g, color.b, alpha * 0.38), width + 6.0, true)
	draw_polyline(points, Color(color.r, color.g, color.b, alpha * 0.92), width, true)
	draw_polyline(points, Color(1.0, 0.97, 0.90, alpha * 0.92), maxf(1.4, width * 0.20), true)


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
