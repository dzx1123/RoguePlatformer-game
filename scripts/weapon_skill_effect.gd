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
var _crescent_surface_polygon_count: int = 0
var _slash_shard_polygon_count: int = 0
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


func get_filled_slash_polygon_count() -> int:
	# Kept as a compatibility alias for older smoke tests.
	return _crescent_surface_polygon_count


func get_crescent_surface_polygon_count() -> int:
	return _crescent_surface_polygon_count


func get_slash_shard_polygon_count() -> int:
	return _slash_shard_polygon_count


func _draw() -> void:
	_draw_call_count += 1
	_crescent_surface_polygon_count = 0
	_slash_shard_polygon_count = 0
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
	# Two hollow blade faces, matching the longsword's painted crescent: a
	# transparent inner arc, a saturated band, and a broad white cutting edge.
	# The second blade uses a different bow so they never collapse into one pie.
	for blade_index in range(2):
		var phase: float = clampf(
			(_attack_progress - 0.18 - float(blade_index) * 0.07) / 0.38,
			0.0,
			1.0
		)
		if phase <= 0.0 or phase >= 1.0:
			continue
		var alpha: float = pow(sin(phase * PI), 0.70)
		var points: PackedVector2Array
		var depth: float
		var body_color: Color
		var rim_color: Color
		if blade_index == 0:
			points = _attack_arc_points(_attack_type, _reach_scale * 0.78, -4.0)
			depth = [16.0, 20.0, 18.0][_attack_type]
			body_color = Color("#7043d8")
			rim_color = Color("#c49aff")
		else:
			points = _twin_secondary_arc_points(_attack_type, _reach_scale * 0.72)
			depth = [14.0, 17.0, 16.0][_attack_type]
			body_color = Color("#159bc4")
			rim_color = Color("#63e9ff")
		_draw_attack_crescent(
			points,
			alpha * (0.94 if blade_index == 0 else 0.86),
			depth,
			body_color,
			rim_color,
			Color("#f7ffff")
		)
		_draw_slash_shards(
			points,
			alpha * 0.90,
			depth,
			rim_color,
			blade_index
		)


func _draw_great_attack_qi() -> void:
	if _attack_type == 2:
		_draw_great_smash_qi()
		return
	# One thicker hollow crescent.  It keeps the longsword's inner-void / white
	# edge language while reading heavier and warmer than the one-handed cut.
	var phase: float = clampf((_attack_progress - 0.32) / 0.42, 0.0, 1.0)
	if phase <= 0.0 or phase >= 1.0:
		return
	var alpha: float = pow(sin(phase * PI), 0.60)
	var points := _attack_arc_points(_attack_type, _reach_scale * 0.70, 0.0)
	var depth: float = 22.0 if _attack_type == 0 else 26.0
	_draw_attack_crescent(
		points,
		alpha,
		depth,
		Color("#d64b24"),
		Color("#ff9d52"),
		Color("#fff0bf")
	)
	_draw_slash_shards(points, alpha, depth, Color("#ffb063"), 2)


func _draw_great_smash_qi() -> void:
	# Overhead smash: a near-vertical hollow blade face plus a ground shock that
	# carries the area-of-effect read.  Timing stays on the existing hit window.
	var phase: float = clampf((_attack_progress - 0.34) / 0.38, 0.0, 1.0)
	if phase > 0.0 and phase < 1.0:
		var alpha: float = pow(sin(phase * PI), 0.55)
		var points := _quadratic_arc_points(
			Vector2(-_facing * 6.0, -98.0),
			Vector2(_facing * 8.0, -16.0),
			Vector2(_facing * 16.0, 36.0)
		)
		_draw_attack_crescent(
			points,
			alpha,
			24.0,
			Color("#d64b24"),
			Color("#ff9d52"),
			Color("#fff6d0")
		)
		_draw_slash_shards(points, alpha, 24.0, Color("#ffb063"), 2)
	var shock: float = clampf((_attack_progress - 0.46) / 0.30, 0.0, 1.0)
	if shock <= 0.0:
		return
	var shock_alpha: float = 1.0 - smoothstep(0.42, 1.0, shock)
	var half_width: float = 68.0 * _reach_scale * (0.42 + shock * 0.58)
	var ground := _quadratic_arc_points(
		Vector2(-half_width, 34.0),
		Vector2(0.0, 18.0 - shock * 8.0),
		Vector2(half_width, 34.0)
	)
	_draw_attack_crescent(
		ground,
		shock_alpha * 0.92,
		16.0 + shock * 6.0,
		Color("#d64b24"),
		Color("#ff9d52"),
		Color("#fff0bf")
	)
	_draw_slash_shards(ground, shock_alpha, 18.0, Color("#ffd27a"), 3)
	draw_circle(
		Vector2(_facing * 10.0, 32.0),
		8.0 + shock * 14.0,
		Color(1.0, 0.90, 0.70, shock_alpha * 0.22)
	)


func _attack_arc_points(attack_type: int, reach: float, lane_offset: float) -> PackedVector2Array:
	var start: Vector2
	var control: Vector2
	var finish: Vector2
	match attack_type:
		1:
			start = Vector2(-_facing * 10.0, 18.0 + lane_offset)
			control = Vector2(_facing * 48.0 * reach, 2.0 + lane_offset)
			finish = Vector2(
				_facing * 16.0 * reach,
				-60.0 * clampf(reach, 0.84, 1.16) + lane_offset
			)
		2:
			start = Vector2(-_facing * 14.0, -18.0 + lane_offset)
			control = Vector2(_facing * 26.0 * reach, 16.0 + lane_offset)
			finish = Vector2(_facing * 68.0 * reach, 26.0 + lane_offset)
		_:
			start = Vector2(-_facing * 20.0, 10.0 + lane_offset)
			control = Vector2(_facing * 26.0 * reach, -8.0 + lane_offset)
			finish = Vector2(_facing * 74.0 * reach, 2.0 + lane_offset)
	return _quadratic_arc_points(start, control, finish)


func _twin_secondary_arc_points(attack_type: int, reach: float) -> PackedVector2Array:
	var start: Vector2
	var control: Vector2
	var finish: Vector2
	match attack_type:
		1:
			start = Vector2(-_facing * 6.0, 22.0)
			control = Vector2(_facing * 34.0 * reach, -10.0)
			finish = Vector2(
				_facing * 2.0,
				-54.0 * clampf(reach, 0.84, 1.10)
			)
		2:
			start = Vector2(-_facing * 8.0, -24.0)
			control = Vector2(_facing * 20.0 * reach, 8.0)
			finish = Vector2(_facing * 58.0 * reach, 34.0)
		_:
			start = Vector2(-_facing * 16.0, -8.0)
			control = Vector2(_facing * 30.0 * reach, 14.0)
			finish = Vector2(_facing * 66.0 * reach, -12.0)
	return _quadratic_arc_points(start, control, finish)


func _quadratic_arc_points(start: Vector2, control: Vector2, finish: Vector2) -> PackedVector2Array:
	var points := PackedVector2Array()
	for point_index in range(23):
		var weight: float = float(point_index) / 22.0
		var inverse: float = 1.0 - weight
		points.append(
			start * inverse * inverse
			+ control * 2.0 * inverse * weight
			+ finish * weight * weight
		)
	return points


func _draw_attack_crescent(
	points: PackedVector2Array,
	alpha: float,
	depth: float,
	body_color: Color,
	rim_color: Color,
	edge_color: Color
) -> void:
	if points.size() < 2 or alpha <= 0.001:
		return
	# Leave the inner third empty so the face reads as a blade, not a filled pie.
	# Layer order matches the baked longsword crescents: glow, body, rim, white edge.
	_draw_crescent_band(
		points,
		depth * 0.86,
		depth * 1.26,
		Color(rim_color.r, rim_color.g, rim_color.b, alpha * 0.20),
		0.52
	)
	_draw_crescent_band(
		points,
		depth * 0.30,
		depth * 0.86,
		Color(body_color.r, body_color.g, body_color.b, alpha * 0.86),
		0.58
	)
	_draw_crescent_band(
		points,
		depth * 0.48,
		depth * 0.80,
		Color(rim_color.r, rim_color.g, rim_color.b, alpha * 0.74),
		0.62
	)
	_draw_crescent_band(
		points,
		depth * 0.72,
		depth * 1.02,
		Color(edge_color.r, edge_color.g, edge_color.b, alpha * 0.97),
		0.68
	)
	_draw_crescent_band(
		points,
		depth * 0.24,
		depth * 0.36,
		Color(rim_color.r, rim_color.g, rim_color.b, alpha * 0.76),
		0.72
	)


func _draw_crescent_band(
	points: PackedVector2Array,
	inner_depth: float,
	outer_depth: float,
	color: Color,
	taper_power: float
) -> void:
	var inner := PackedVector2Array()
	var outer := PackedVector2Array()
	var final_index: int = points.size() - 1
	for point_index in range(points.size()):
		var previous: Vector2 = points[maxi(0, point_index - 1)]
		var following: Vector2 = points[mini(final_index, point_index + 1)]
		var tangent: Vector2 = (following - previous).normalized()
		if tangent.is_zero_approx():
			tangent = Vector2(_facing, 0.0)
		# Multiplying by facing keeps this one-sided surface a true horizontal
		# mirror when the player turns left.
		var normal := Vector2(-tangent.y, tangent.x) * _facing
		var progress: float = float(point_index) / float(final_index)
		var taper: float = pow(maxf(0.0, sin(progress * PI)), taper_power)
		inner.append(points[point_index] + normal * inner_depth * taper)
		outer.append(points[point_index] + normal * outer_depth * taper)

	# Adjacent convex quads render reliably on the project's GL backend while
	# preserving the hollow crescent silhouette.
	for point_index in range(final_index):
		var segment := PackedVector2Array()
		var leading_is_point: bool = (
			outer[point_index].distance_squared_to(inner[point_index]) < 0.0001
		)
		var trailing_is_point: bool = (
			outer[point_index + 1].distance_squared_to(inner[point_index + 1]) < 0.0001
		)
		if leading_is_point:
			segment = PackedVector2Array([
				outer[point_index],
				outer[point_index + 1],
				inner[point_index + 1],
			])
		elif trailing_is_point:
			segment = PackedVector2Array([
				outer[point_index],
				outer[point_index + 1],
				inner[point_index],
			])
		else:
			segment = PackedVector2Array([
				outer[point_index],
				outer[point_index + 1],
				inner[point_index + 1],
				inner[point_index],
			])
		draw_colored_polygon(segment, color)
		_crescent_surface_polygon_count += 1


func _draw_slash_shards(
	points: PackedVector2Array,
	alpha: float,
	depth: float,
	color: Color,
	pattern_offset: int
) -> void:
	if points.size() < 3 or alpha <= 0.001:
		return
	var samples: Array[float] = [0.16, 0.78, 0.91]
	for shard_index in range(samples.size()):
		var progress: float = clampf(
			samples[shard_index] + float(pattern_offset) * 0.018,
			0.08,
			0.96
		)
		var sample_index: int = clampi(
			roundi(progress * float(points.size() - 1)),
			1,
			points.size() - 2
		)
		var tangent: Vector2 = (
			points[sample_index + 1] - points[sample_index - 1]
		).normalized()
		if tangent.is_zero_approx():
			tangent = Vector2(_facing, 0.0)
		var normal := Vector2(-tangent.y, tangent.x) * _facing
		var size: float = 6.0 + float((shard_index + pattern_offset) % 3) * 2.5
		var centre: Vector2 = (
			points[sample_index]
			+ normal * depth * (1.08 + float(shard_index) * 0.08)
			- tangent * float(shard_index) * 2.0
		)
		var shard := PackedVector2Array([
			centre + tangent * size,
			centre - tangent * size * 0.62 + normal * size * 0.34,
			centre - tangent * size * 0.12 + normal * size,
		])
		draw_colored_polygon(
			shard,
			Color(color.r, color.g, color.b, alpha * (0.72 - shard_index * 0.13))
		)
		_slash_shard_polygon_count += 1


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
