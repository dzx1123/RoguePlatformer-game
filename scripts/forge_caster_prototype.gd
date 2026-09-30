extends "res://scripts/rogue_enemy.gd"

## Forge enemy movement and shared rendering; retains existing hit geometry.
const ART := preload("res://scripts/forge_character_art.gd")
var cast_pose_time := 0.0
var animation_time := 0.0
var walk_direction := -1.0
var walk_origin := 0.0
var _ledge_turn_remaining := 0.0
var actor_motion := preload("res://scripts/forge_actor_motion.gd").new()
var _cast_facing := 1.0
var _was_casting := false

func _process(delta: float) -> void:
	# Follow combat processing so menu pauses and event choices freeze animation too.
	if is_physics_processing() and _hitstop_remaining <= 0.0:
		animation_time += delta
		var visual := _visual_state()
		actor_motion.advance(delta, velocity.x, is_on_floor(), int(visual.pose) == 0 and not _is_defeated and _hurt_remaining <= 0, _pose_motion(int(visual.pose), float(visual.progress)), float(visual.facing), get_impact_height() * 0.65)
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

func _visual_state() -> Dictionary:
	var pose := 3 if _is_defeated else (1 if cast_pose_time > 0.8 else (2 if cast_pose_time > 0.18 else 0))
	return {"pose": pose, "progress": clampf((1.52 - cast_pose_time) / 0.72, 0, 1), "facing": _cast_facing if cast_pose_time > 0 else _art_facing()}

func _draw_actor(row: int) -> void:
	var visual := _visual_state()
	ART.draw_actor(self, row, int(visual.pose), float(visual.facing), get_impact_height(), _hurt_remaining > 0, _art_alpha(), actor_motion.shape, actor_motion.phase, actor_motion.weight)

func _ready() -> void:
	super._ready()
	walk_origin = position.x
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
	if _consume_forge_hitstop(delta):
		return
	_hurt_remaining = maxf(0, _hurt_remaining - delta)
	if cast_pose_time > 0 and not _was_casting:
		_cast_facing = signf(_target.position.x - position.x) if is_instance_valid(_target) else _art_facing()
		if is_zero_approx(_cast_facing):
			_cast_facing = actor_motion.facing
	cast_pose_time = maxf(0, cast_pose_time - delta)
	_was_casting = cast_pose_time > 0
	_hurt_invulnerability_remaining = maxf(0, _hurt_invulnerability_remaining - delta)
	if cast_pose_time <= 0 and _hurt_remaining <= 0:
		velocity.x = _walk_velocity(walk_origin - 140, walk_origin + 140, 52)
	else:
		velocity.x = move_toward(velocity.x, 0, 900 * delta)
	velocity.y += 1800 * delta
	move_and_slide()
	queue_redraw()

func _consume_forge_hitstop(delta: float) -> bool:
	if _hitstop_remaining <= 0.0:
		return false
	_hitstop_remaining = maxf(0.0, _hitstop_remaining - delta)
	return true

func _draw() -> void:
	_draw_actor(0)
	_draw_forge_health()

func get_health_bar_rect() -> Rect2:
	var width := clampf(get_impact_height() * 0.65, 42, 100)
	return Rect2(-width * 0.5, 24 - get_impact_height() - 13, width, 5)

func _draw_forge_health() -> void:
	if _is_defeated:
		return
	var bar := get_health_bar_rect()
	draw_rect(bar.grow(1), Color("#10151d"))
	draw_rect(bar, Color("#39252b"))
	bar.size.x *= get_health_fraction()
	draw_rect(bar, Color("#f5b562"))

func get_health_fraction() -> float:
	return clampf(float(_current_health) / maxf(_max_health, 1), 0, 1)

func _walk_velocity(left: float, right: float, speed: float) -> float:
	_ledge_turn_remaining = maxf(0.0, _ledge_turn_remaining - get_physics_process_delta_time())
	if not is_on_floor() or _hurt_remaining > 0:
		return 0.0
	if _ledge_turn_remaining <= 0 and is_instance_valid(_target) and not _target.is_dead() and absf(_target.position.y - position.y) < 85 and absf(_target.position.x - position.x) < 520:
		if absf(_target.position.x - position.x) < 75:
			return 0.0
		walk_direction = signf(_target.position.x - position.x)
	if position.x <= left + 8:
		walk_direction = 1
	elif position.x >= right - 8:
		walk_direction = -1
	var start := global_position + Vector2(walk_direction * 30, 0)
	var ray := PhysicsRayQueryParameters2D.create(start, start + Vector2(0, 65), 1, [get_rid()])
	if get_world_2d().direct_space_state.intersect_ray(ray).is_empty() or is_on_wall():
		walk_direction *= -1
		# Finish stepping away before pursuit can turn us toward the same ledge again.
		_ledge_turn_remaining = 0.6
		return 0.0
	return walk_direction * speed

func _art_facing() -> float:
	if absf(velocity.x) > 1:
		return signf(velocity.x)
	if is_instance_valid(_target) and absf(_target.position.x - position.x) > 8:
		return signf(_target.position.x - position.x)
	return actor_motion.facing

func _art_alpha() -> float:
	return clampf(_death_remaining / DEATH_ANIMATION_DURATION, 0, 1) if _is_defeated else 1.0

func get_impact_height() -> float:
	return 90.0
