extends Node2D

## Short-lived procedural effects for weapon impacts and enemy defeats.
class_name CombatVfx

enum EffectType {
	HIT,
	DEFEAT,
}

const HIT_DURATION := 0.24
const DEFEAT_DURATION := 0.78

var _effect_type: int = EffectType.HIT
var _remaining: float = HIT_DURATION
var _duration: float = HIT_DURATION
var _facing: float = 1.0
var _scale_multiplier: float = 1.0
var _accent := Color("#8eeaff")
var _seed: float = 0.0


func play_hit(facing: float, scale_multiplier: float = 1.0) -> void:
	_effect_type = EffectType.HIT
	_duration = HIT_DURATION
	_remaining = HIT_DURATION
	_facing = 1.0 if facing >= 0.0 else -1.0
	_scale_multiplier = maxf(0.7, scale_multiplier)
	_accent = Color("#d8fbff")
	_seed = global_position.x * 0.031 + global_position.y * 0.017
	queue_redraw()


func play_defeat(accent: Color, scale_multiplier: float = 1.0) -> void:
	_effect_type = EffectType.DEFEAT
	_duration = DEFEAT_DURATION
	_remaining = DEFEAT_DURATION
	_scale_multiplier = maxf(0.8, scale_multiplier)
	# Defeat smoke is always a cool violet plume; keep boss scaling while
	# ignoring the old red/orange burst accent passed by the room controller.
	_accent = Color("#7d35c7")
	_seed = global_position.x * 0.021 + global_position.y * 0.043
	queue_redraw()


func _process(delta: float) -> void:
	_remaining = maxf(0.0, _remaining - delta)
	queue_redraw()
	if _remaining <= 0.0:
		queue_free()


func _draw() -> void:
	var progress: float = 1.0 - _remaining / _duration
	if _effect_type == EffectType.HIT:
		_draw_hit(progress)
	else:
		_draw_defeat(progress)


func _draw_hit(progress: float) -> void:
	var fade: float = pow(1.0 - progress, 1.45)
	var impact := Vector2(0.0, -8.0)
	var outer_color := Color("#4ddff5")
	var edge_color := Color("#213d87")
	var core_color := Color("#f6dd92")
	var reach: float = lerpf(24.0, 66.0, progress) * _scale_multiplier
	var start_angle: float = -1.28 if _facing > 0.0 else PI - 0.28
	var end_angle: float = 0.22 if _facing > 0.0 else PI + 1.28

	# Two offset crescent cuts read as a weapon strike rather than a generic ring.
	draw_arc(impact + Vector2(_facing * 5.0, 0.0), reach, start_angle, end_angle, 18, Color(edge_color, fade * 0.90), maxf(2.0, 6.0 * fade), true)
	draw_arc(impact + Vector2(_facing * 7.0, -1.0), reach * 0.92, start_angle + 0.05, end_angle - 0.04, 18, Color(outer_color, fade), maxf(1.5, 3.1 * fade), true)
	draw_arc(impact + Vector2(_facing * 9.0, -2.0), reach * 0.82, start_angle + 0.12, end_angle - 0.11, 15, Color(core_color, fade * 0.92), maxf(1.0, 1.5 * fade), true)

	var slash_direction := Vector2(_facing, -0.25).normalized()
	draw_line(impact - slash_direction * 14.0 * _scale_multiplier, impact + slash_direction * (20.0 + progress * 18.0) * _scale_multiplier, Color(core_color, fade * 0.86), maxf(1.0, 2.4 * fade), true)
	draw_circle(impact, (8.0 - progress * 3.0) * _scale_multiplier, Color(outer_color, fade * 0.34))
	for shard_index in range(9):
		var angle: float = _seed + float(shard_index) * TAU / 9.0
		var direction := Vector2(cos(angle), sin(angle) * 0.72 - 0.16).normalized()
		if direction.x * _facing < -0.42:
			direction.x *= -1.0
		var distance: float = lerpf(8.0, 56.0 + float(shard_index % 3) * 9.0, progress) * _scale_multiplier
		var shard_center := impact + direction * distance
		var shard_size: float = (5.0 - progress * 2.0) * _scale_multiplier
		var tangent := Vector2(-direction.y, direction.x) * shard_size * 0.44
		draw_colored_polygon(
			PackedVector2Array([shard_center - direction * shard_size, shard_center + tangent, shard_center + direction * shard_size, shard_center - tangent]),
			Color(_accent.lerp(outer_color, 0.55), fade * 0.90)
		)


func _draw_defeat(progress: float) -> void:
	var fade: float = pow(1.0 - progress, 1.18)
	var plume_radius: float = lerpf(16.0, 104.0, sqrt(progress)) * _scale_multiplier
	var center := Vector2(0.0, -14.0 + progress * 24.0)
	# Layered soft puffs approximate the reference smoke burst: compact flash,
	# expanding lobes, then a transparent violet fade.
	for puff_index in range(9):
		var angle: float = _seed + float(puff_index) * TAU / 9.0
		var orbit: float = plume_radius * (0.34 + float(puff_index % 3) * 0.09)
		var puff_center := center + Vector2(cos(angle), sin(angle) * 0.72) * orbit
		var puff_size: float = plume_radius * (0.25 + float(puff_index % 2) * 0.08)
		var tint := _accent.lerp(Color("#4b167f"), float(puff_index % 3) * 0.20)
		draw_circle(puff_center, puff_size, Color(tint, fade * (0.72 - float(puff_index % 3) * 0.09)))
	draw_circle(center, plume_radius * 0.38, Color("#9d55e8", fade * 0.46))
