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

func play_enemy_hit(enemy: RogueEnemy, facing: float, strength: float = 1.0) -> void:
	var bounds := enemy.get_impact_bounds()
	global_position = bounds.get_center()
	play_hit(facing, clampf(bounds.size.y / 90.0, 0.4, 2.2) * clampf(strength, 1.0, 1.15))


func play_hit(facing: float, scale_multiplier: float = 1.0) -> void:
	_effect_type = EffectType.HIT
	_duration = HIT_DURATION
	_remaining = HIT_DURATION
	_facing = 1.0 if facing >= 0.0 else -1.0
	_scale_multiplier = maxf(0.35, scale_multiplier)
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
	var fade := pow(maxf(0.0, 1.0 - progress), 1.65)
	if fade < 0.02:
		return
	var center := Vector2.ZERO
	var axis := Vector2(_facing * 0.74, -0.67).normalized()
	var normal := Vector2(-axis.y, axis.x)
	var length := (24.0 + 30.0 * sin(progress * PI * 0.75)) * _scale_multiplier
	# A narrow diagonal cut, with a white impact core and cyan tapered edges.
	for layer in range(3):
		var width: float = [8.0, 3.5, 1.3][layer] * _scale_multiplier * fade
		var tint: Color = [Color("#087bbd"), Color("#26dcff"), Color("#f3ffff")][layer]
		draw_colored_polygon(PackedVector2Array([
			center - axis * length * 0.7,
			center + normal * width,
			center + axis * length * 0.7,
			center - normal * width,
		]), Color(tint, fade * (0.45 if layer == 0 else 1.0)))
	var flash := maxf(0, 1.0 - progress * 3.0)
	for ray in range(6):
		var angle := float(ray) * TAU / 6.0 + 0.3
		var direction := Vector2(cos(angle), sin(angle))
		var tip := center + direction * (10.0 + float(ray % 2) * 9.0) * _scale_multiplier * flash
		var side := Vector2(-direction.y, direction.x) * 2.8 * _scale_multiplier * flash
		if flash > 0.001:
			draw_colored_polygon(PackedVector2Array([center + side, tip, center - side]), Color("#eaffff", flash))
	for shard in range(8):
		var direction := axis.rotated(sin(float(shard) * 2.4 + _seed) * 1.15)
		if shard % 3 == 0:
			direction = -direction
		var distance := (8.0 + progress * (28.0 + float(shard % 3) * 12.0)) * _scale_multiplier
		var point := center + direction * distance
		var size := (2.0 + float(shard % 3)) * _scale_multiplier * fade
		var side := Vector2(-direction.y, direction.x) * size * 0.35
		draw_colored_polygon(PackedVector2Array([point - direction * size, point + side, point + direction * size * 2.6, point - side]), Color("#50e8ff", fade))

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
