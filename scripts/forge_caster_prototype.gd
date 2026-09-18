extends "res://scripts/rogue_enemy.gd"

## Stationary combat prototype; uses existing hit geometry, not final character art.
const ART := preload("res://scripts/forge_character_art.gd")
var cast_pose_time := 0.0
var animation_time := 0.0

func _process(delta: float) -> void:
	# Follow combat processing so menu pauses and event choices freeze animation too.
	if is_physics_processing():
		animation_time += delta
		queue_redraw()

func _pose_motion(pose: int, progress: float = 0.0) -> Vector2:
	if _is_defeated:
		return Vector2.ONE
	if _hurt_remaining > 0:
		return Vector2(1.06, 0.94)
	if pose == 1:
		return Vector2(1.0 + 0.08 * progress, 1.0 - 0.08 * progress)
	if pose == 2:
		return Vector2(1.05, 0.96)
	var breath := sin(animation_time * 3.0) * 0.015
	return Vector2(1.0 - breath, 1.0 + breath)
func _ready() -> void:
	super._ready()
	_enemy_sprite.hide()
	if is_instance_valid(_reference_adornment):
		_reference_adornment.hide()

func get_impact_bounds() -> Rect2:
	var height := get_impact_height()
	var size := Vector2(height * 0.7, height) * global_scale.abs()
	return Rect2(to_global(Vector2(0, 24 - height * 0.5)) - size * 0.5, size)

func _physics_process(delta: float) -> void:
	if _is_defeated:
		_death_remaining -= delta
		if _death_remaining <= 0:
			defeated.emit()
			queue_free()
		queue_redraw()
		return
	_hurt_remaining = maxf(0, _hurt_remaining - delta)
	cast_pose_time = maxf(0, cast_pose_time - delta)
	_hurt_invulnerability_remaining = maxf(0, _hurt_invulnerability_remaining - delta)
	velocity.x = move_toward(velocity.x, 0, 900 * delta)
	velocity.y += 1800 * delta
	move_and_slide()
	queue_redraw()

func _draw() -> void:
	var pose := 3 if _is_defeated else (1 if cast_pose_time > 0.8 else (2 if cast_pose_time > 0 else 0))
	ART.draw_actor(self, 0, pose, _art_facing(), 90, _hurt_remaining > 0, _art_alpha(), _pose_motion(pose, clampf((1.52 - cast_pose_time) / 0.72, 0, 1)))
	draw_rect(Rect2(-28, -44, 56, 4), Color("#39252b"))
	draw_rect(Rect2(-28, -44, 56 * float(_current_health) / maxf(_max_health, 1), 4), Color("#f5b562"))

func _art_facing() -> float:
	return signf(_target.position.x - position.x) if is_instance_valid(_target) else 1.0

func _art_alpha() -> float:
	return clampf(_death_remaining / DEATH_ANIMATION_DURATION, 0, 1) if _is_defeated else 1.0

func get_impact_height() -> float:
	return 90.0
