extends CharacterBody2D

## Runtime controller for melee and ranged enemies.
class_name RogueEnemy

signal defeated
signal health_changed(current_health: int, maximum_health: int)
signal projectile_requested(origin: Vector2, projectile_velocity: Vector2, damage: int)

enum EnemyRole {
	MELEE,
	RANGED,
}

enum EnemyRank {
	NORMAL,
	ELITE,
	BOSS,
}

const GRAVITY := 1800.0
const PATROL_SPEED := 72.0
const MELEE_CHASE_SPEED := 145.0
const RANGED_MOVE_SPEED := 112.0
const ACCELERATION := 900.0
const MELEE_DETECTION_RANGE_X := 300.0
const RANGED_DETECTION_RANGE_X := 470.0
const DETECTION_RANGE_Y := 150.0
const MELEE_ATTACK_REACH_X := 100.0
const MELEE_ATTACK_REACH_Y := 62.0
const RANGED_ATTACK_RANGE_X := 430.0
const RANGED_PREFERRED_MIN_X := 180.0
const RANGED_PREFERRED_MAX_X := 300.0
const MELEE_ATTACK_DURATION := 0.42
const MELEE_ATTACK_HIT_DELAY := 0.17
const MELEE_ATTACK_COOLDOWN := 0.95
const RANGED_ATTACK_DURATION := 0.58
const RANGED_ATTACK_FIRE_DELAY := 0.28
const RANGED_ATTACK_COOLDOWN := 1.35
const RANGED_PROJECTILE_SPEED := 315.0
const MELEE_DAMAGE := 22
const RANGED_DAMAGE := 14
const MELEE_MAX_HEALTH := 72
const RANGED_MAX_HEALTH := 48
const ELITE_HEALTH_MULTIPLIER := 2.1
const BOSS_MAX_HEALTH := 460
const HURT_INVULNERABILITY := 0.10

var _variant: int = 0
var _role: int = EnemyRole.MELEE
var _rank: int = EnemyRank.NORMAL
var _phase: float = 0.0
var _elapsed: float = 0.0
var _patrol_left: float = 0.0
var _patrol_right: float = 0.0
var _patrol_direction: float = 1.0
var _facing: float = 1.0
var _target: Node2D
var _attack_remaining: float = 0.0
var _attack_cooldown_remaining: float = 0.0
var _attack_action_performed: bool = false
var _boss_attack_uses_projectile: bool = false
var _hurt_remaining: float = 0.0
var _hurt_invulnerability_remaining: float = 0.0
var _max_health: int = MELEE_MAX_HEALTH
var _current_health: int = MELEE_MAX_HEALTH
var _is_defeated: bool = false


func _ready() -> void:
	collision_layer = 4
	collision_mask = 1

	var body_collision := CollisionShape2D.new()
	var body_shape := CapsuleShape2D.new()
	body_shape.radius = 27.0 if is_boss() else (20.0 if is_elite() else 16.0)
	body_shape.height = 76.0 if is_boss() else (52.0 if is_elite() else 42.0)
	body_collision.shape = body_shape
	add_child(body_collision)

	var hurtbox := Area2D.new()
	hurtbox.name = "Hurtbox"
	hurtbox.collision_layer = 8
	hurtbox.collision_mask = 0
	hurtbox.monitoring = false
	hurtbox.monitorable = true
	var hurtbox_collision := CollisionShape2D.new()
	var hurtbox_shape := RectangleShape2D.new()
	hurtbox_shape.size = (
		Vector2(76.0, 92.0)
		if is_boss()
		else (Vector2(56.0, 66.0) if is_elite() else Vector2(44.0, 54.0))
	)
	hurtbox_collision.position = Vector2(0.0, -7.0 if is_boss() else -3.0)
	hurtbox_collision.shape = hurtbox_shape
	hurtbox.add_child(hurtbox_collision)
	add_child(hurtbox)
	queue_redraw()


func setup(
	variant: int,
	phase: float,
	patrol_left: float,
	patrol_right: float,
	role: int = EnemyRole.MELEE,
	rank: int = EnemyRank.NORMAL
) -> void:
	_role = clampi(role, EnemyRole.MELEE, EnemyRole.RANGED)
	_rank = clampi(rank, EnemyRank.NORMAL, EnemyRank.BOSS)
	_variant = variant % 3
	if _role == EnemyRole.RANGED:
		_variant = 1
	elif _variant == 1:
		_variant = 0
	_phase = phase
	_patrol_left = patrol_left
	_patrol_right = patrol_right
	_patrol_direction = -1.0 if sin(phase) < 0.0 else 1.0
	_facing = _patrol_direction
	var base_health: int = RANGED_MAX_HEALTH if is_ranged_enemy() else MELEE_MAX_HEALTH
	if is_boss():
		_max_health = BOSS_MAX_HEALTH
	elif is_elite():
		_max_health = int(round(float(base_health) * ELITE_HEALTH_MULTIPLIER))
	else:
		_max_health = base_health
	_current_health = _max_health
	queue_redraw()


func set_target(target: Node2D) -> void:
	_target = target


func is_ranged_enemy() -> bool:
	return _role == EnemyRole.RANGED


func is_elite() -> bool:
	return _rank == EnemyRank.ELITE


func is_boss() -> bool:
	return _rank == EnemyRank.BOSS


func get_gold_reward() -> int:
	if is_boss():
		return 40
	if is_elite():
		return 14
	return 4


func get_essence_reward() -> int:
	if is_boss():
		return 10
	if is_elite():
		return 3
	return 0


func get_current_health() -> int:
	return _current_health


func get_max_health() -> int:
	return _max_health


func get_hurtbox_rect() -> Rect2:
	if is_boss():
		return Rect2(global_position - Vector2(38.0, 53.0), Vector2(76.0, 92.0))
	if is_elite():
		return Rect2(global_position - Vector2(28.0, 36.0), Vector2(56.0, 66.0))
	return Rect2(global_position - Vector2(22.0, 30.0), Vector2(44.0, 54.0))


func is_hit_by_attack(
	attack_origin: Vector2,
	facing: float,
	reach_scale: float = 1.0
) -> bool:
	if _is_defeated or _hurt_invulnerability_remaining > 0.0:
		return false

	var safe_reach: float = maxf(0.5, reach_scale)
	var rear_reach: float = 22.0
	var forward_reach: float = 120.0 * safe_reach
	var attack_left: float = attack_origin.x - rear_reach
	if facing < 0.0:
		attack_left = attack_origin.x - forward_reach
	var attack_rect := Rect2(
		Vector2(attack_left, attack_origin.y - 58.0 * minf(safe_reach, 1.35)),
		Vector2(forward_reach + rear_reach, 116.0 * minf(safe_reach, 1.35))
	)
	return attack_rect.intersects(get_hurtbox_rect())


func receive_player_attack(
	attack_origin: Vector2,
	facing: float,
	damage: int,
	reach_scale: float = 1.0
) -> bool:
	if not is_hit_by_attack(attack_origin, facing, reach_scale):
		return false

	_current_health = maxi(0, _current_health - maxi(1, damage))
	_hurt_remaining = 0.18
	_hurt_invulnerability_remaining = HURT_INVULNERABILITY
	_attack_remaining = 0.0
	_attack_action_performed = false
	var knockback_direction: float = signf(global_position.x - attack_origin.x)
	if is_zero_approx(knockback_direction):
		knockback_direction = facing
	var knockback_scale: float = 0.20 if is_boss() else (0.58 if is_elite() else 1.0)
	velocity = Vector2(knockback_direction * 330.0 * knockback_scale, -180.0 * knockback_scale)
	health_changed.emit(_current_health, _max_health)
	queue_redraw()
	if _current_health <= 0:
		defeat()
	return true


func defeat() -> void:
	if _is_defeated:
		return

	_is_defeated = true
	defeated.emit()
	queue_free()


func _physics_process(delta: float) -> void:
	if _is_defeated:
		return

	_elapsed += delta
	_attack_cooldown_remaining = maxf(0.0, _attack_cooldown_remaining - delta)
	_hurt_remaining = maxf(0.0, _hurt_remaining - delta)
	_hurt_invulnerability_remaining = maxf(0.0, _hurt_invulnerability_remaining - delta)

	var desired_speed: float = 0.0
	if _hurt_remaining > 0.0:
		desired_speed = 0.0
	elif _attack_remaining > 0.0:
		_attack_remaining = maxf(0.0, _attack_remaining - delta)
		var action_time: float = _get_attack_duration() - _get_attack_action_delay()
		if not _attack_action_performed and _attack_remaining <= action_time:
			_attack_action_performed = true
			if is_ranged_enemy() or (is_boss() and _boss_attack_uses_projectile):
				_fire_projectile()
			else:
				_hit_target_if_still_close()
	else:
		if _target_in_attack_range() and _attack_cooldown_remaining <= 0.0:
			_start_attack()
		else:
			desired_speed = _get_desired_speed()

	var acceleration_scale: float = 0.38 if _hurt_remaining > 0.0 else 1.0
	velocity.x = move_toward(
		velocity.x,
		desired_speed,
		ACCELERATION * acceleration_scale * delta
	)
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	else:
		velocity.y = 0.0

	move_and_slide()
	if global_position.y > 820.0:
		defeat()
		return
	queue_redraw()


func _get_desired_speed() -> float:
	if _target_is_visible():
		var target_delta: float = _target.global_position.x - global_position.x
		if not is_zero_approx(target_delta):
			_facing = signf(target_delta)
		var distance_x: float = absf(target_delta)
		if is_ranged_enemy():
			if distance_x < RANGED_PREFERRED_MIN_X:
				return -_facing * _get_ranged_move_speed()
			if distance_x > RANGED_PREFERRED_MAX_X:
				return _facing * _get_ranged_move_speed()
			return 0.0
		if distance_x > MELEE_ATTACK_REACH_X:
			return _facing * _get_melee_chase_speed()
		return 0.0

	if global_position.x <= _patrol_left:
		_patrol_direction = 1.0
	elif global_position.x >= _patrol_right:
		_patrol_direction = -1.0

	_facing = _patrol_direction
	var patrol_multiplier: float = 1.22 if is_elite() else 1.0
	if is_boss():
		patrol_multiplier = 1.35
	return _patrol_direction * PATROL_SPEED * patrol_multiplier


func _target_is_visible() -> bool:
	if not is_instance_valid(_target):
		return false
	if _target.has_method(&"is_dead") and bool(_target.call(&"is_dead")):
		return false

	var offset: Vector2 = _target.global_position - global_position
	var detection_x: float = RANGED_DETECTION_RANGE_X if is_ranged_enemy() else MELEE_DETECTION_RANGE_X
	if is_boss():
		detection_x = 560.0
	return absf(offset.x) <= detection_x and absf(offset.y) <= DETECTION_RANGE_Y


func _target_in_attack_range() -> bool:
	if not _target_is_visible():
		return false

	var offset: Vector2 = _target.global_position - global_position
	if not is_zero_approx(offset.x):
		_facing = signf(offset.x)
	if is_boss():
		return absf(offset.x) <= 450.0 and absf(offset.y) <= 190.0
	if is_ranged_enemy():
		return (
			absf(offset.x) <= RANGED_ATTACK_RANGE_X
			and absf(offset.y) <= DETECTION_RANGE_Y
		)
	return (
		absf(offset.x) <= MELEE_ATTACK_REACH_X
		and absf(offset.y) <= MELEE_ATTACK_REACH_Y
	)


func _start_attack() -> void:
	if is_boss() and is_instance_valid(_target):
		_boss_attack_uses_projectile = absf(_target.global_position.x - global_position.x) > 125.0
	_attack_remaining = _get_attack_duration()
	_attack_cooldown_remaining = _get_attack_cooldown()
	_attack_action_performed = false


func _get_attack_duration() -> float:
	if is_boss():
		return 0.54
	return RANGED_ATTACK_DURATION if is_ranged_enemy() else MELEE_ATTACK_DURATION


func _get_attack_action_delay() -> float:
	if is_boss():
		return 0.25
	return RANGED_ATTACK_FIRE_DELAY if is_ranged_enemy() else MELEE_ATTACK_HIT_DELAY


func _get_attack_cooldown() -> float:
	if is_boss():
		return 0.82
	if is_elite():
		return (RANGED_ATTACK_COOLDOWN if is_ranged_enemy() else MELEE_ATTACK_COOLDOWN) * 0.78
	return RANGED_ATTACK_COOLDOWN if is_ranged_enemy() else MELEE_ATTACK_COOLDOWN


func _get_melee_chase_speed() -> float:
	if is_boss():
		return MELEE_CHASE_SPEED * 1.18
	return MELEE_CHASE_SPEED * (1.16 if is_elite() else 1.0)


func _get_ranged_move_speed() -> float:
	return RANGED_MOVE_SPEED * (1.18 if is_elite() else 1.0)


func _hit_target_if_still_close() -> void:
	if not is_instance_valid(_target):
		return
	if is_boss():
		var boss_melee_offset: Vector2 = _target.global_position - global_position
		if absf(boss_melee_offset.x) > 130.0 or absf(boss_melee_offset.y) > 82.0:
			return
	elif not _target_in_attack_range():
		return
	if _target.has_method(&"receive_enemy_attack"):
		var damage: int = 32 if is_boss() else (28 if is_elite() else MELEE_DAMAGE)
		_target.call(&"receive_enemy_attack", global_position, damage)


func _fire_projectile() -> void:
	if not is_instance_valid(_target):
		return
	var projectile_direction: Vector2 = (
		_target.global_position - (global_position + Vector2(0.0, -8.0))
	).normalized()
	if projectile_direction.is_zero_approx():
		projectile_direction = Vector2(_facing, 0.0)
	var projectile_damage: int = 20 if is_boss() else (18 if is_elite() else RANGED_DAMAGE)
	var projectile_speed: float = RANGED_PROJECTILE_SPEED * (1.12 if is_boss() else 1.0)
	if is_boss():
		for spread_angle in [-0.16, 0.0, 0.16]:
			projectile_requested.emit(
				global_position + Vector2(_facing * 28.0, -12.0),
				projectile_direction.rotated(float(spread_angle)) * projectile_speed,
				projectile_damage
			)
	else:
		projectile_requested.emit(
			global_position + Vector2(_facing * 18.0, -8.0),
			projectile_direction * projectile_speed,
			projectile_damage
		)


func _draw() -> void:
	var movement_speed: float = _get_ranged_move_speed() if is_ranged_enemy() else _get_melee_chase_speed()
	var motion_blend: float = clampf(absf(velocity.x) / movement_speed, 0.0, 1.0)
	var gait_time: float = _elapsed * (2.4 + 7.0 * motion_blend) + _phase
	var bob: float = sin(gait_time) * (0.7 + 1.4 * motion_blend)
	var attack_progress: float = 0.0
	if _attack_remaining > 0.0:
		attack_progress = 1.0 - _attack_remaining / _get_attack_duration()
	var lunge_distance: float = 4.0 if is_ranged_enemy() else 9.0
	var lunge: float = sin(attack_progress * PI) * _facing * lunge_distance
	var center := Vector2(lunge, -4.0 + bob)
	var rank_scale: float = 1.0
	if is_boss():
		rank_scale = 1.72
	elif is_elite():
		rank_scale = 1.24
	draw_set_transform(Vector2(0.0, 6.0 if is_boss() else 0.0), 0.0, Vector2.ONE * rank_scale)
	if is_boss():
		draw_circle(center, 34.0 + sin(_elapsed * 3.0) * 3.0, Color(0.95, 0.22, 0.28, 0.16))
		draw_arc(center, 31.0, 0.0, TAU, 28, Color(1.0, 0.46, 0.24, 0.72), 3.0)
	elif is_elite():
		draw_circle(center, 29.0 + sin(_elapsed * 4.0) * 2.0, Color(0.78, 0.36, 1.0, 0.13))
		draw_arc(center, 27.0, 0.0, TAU, 24, Color(0.72, 0.42, 1.0, 0.62), 2.0)

	draw_circle(Vector2(0.0, 21.0), 20.0, Color(0.02, 0.05, 0.08, 0.42))
	match _variant:
		0:
			_draw_slime(center)
		1:
			_draw_bat(center)
		_:
			_draw_stalker(center)

	if _hurt_remaining > 0.0:
		draw_circle(center, 27.0, Color(1.0, 0.26, 0.20, 0.30))

	if _attack_remaining > 0.0:
		if is_ranged_enemy() or (is_boss() and _boss_attack_uses_projectile):
			var charge_radius: float = lerpf(4.0, 10.0, sin(attack_progress * PI))
			draw_circle(
				center + Vector2(_facing * 22.0, -4.0),
				charge_radius,
				Color(0.48, 0.92, 1.0, 0.74)
			)
		else:
			var start_angle: float = -1.2 if _facing > 0.0 else PI - 0.4
			var end_angle: float = 0.4 if _facing > 0.0 else PI + 1.2
			draw_arc(
				center + Vector2(_facing * 14.0, -3.0),
				31.0,
				start_angle,
				end_angle,
				10,
				Color(1.0, 0.44, 0.32, 0.78),
				3.0,
				true
			)

	if _current_health < _max_health:
		var health_ratio: float = float(_current_health) / float(maxi(_max_health, 1))
		draw_rect(Rect2(-24.0, -42.0, 48.0, 6.0), Color(0.03, 0.07, 0.10, 0.86))
		draw_rect(
			Rect2(-22.0, -40.0, 44.0 * health_ratio, 2.0),
			Color(0.96, 0.28, 0.24, 0.94)
		)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_slime(center: Vector2) -> void:
	draw_circle(center, 22.0, Color("#101a29"))
	draw_circle(center + Vector2(0.0, -2.0), 18.0, Color("#7d59c9"))
	draw_circle(center + Vector2(-7.0, -4.0), 4.0, Color("#f5f1df"))
	draw_circle(center + Vector2(7.0, -4.0), 4.0, Color("#f5f1df"))
	draw_circle(center + Vector2(-6.0, -4.0), 1.8, Color("#17223a"))
	draw_circle(center + Vector2(8.0, -4.0), 1.8, Color("#17223a"))
	draw_line(center + Vector2(-6.0, 8.0), center + Vector2(6.0, 8.0), Color("#d4a8ff"), 2.0)


func _draw_bat(center: Vector2) -> void:
	draw_colored_polygon(
		PackedVector2Array([
			center + Vector2(-7.0, -2.0), center + Vector2(-35.0, -12.0),
			center + Vector2(-25.0, 12.0), center + Vector2(-8.0, 8.0),
			center + Vector2(8.0, 8.0), center + Vector2(25.0, 12.0),
			center + Vector2(35.0, -12.0), center + Vector2(7.0, -2.0),
		]),
		Color("#1e2747")
	)
	draw_circle(center, 15.0, Color("#2f3f70"))
	draw_circle(center + Vector2(-5.0, -2.0), 3.0, Color("#ffda7b"))
	draw_circle(center + Vector2(5.0, -2.0), 3.0, Color("#ffda7b"))
	if is_ranged_enemy():
		draw_arc(center, 23.0, 0.0, TAU, 18, Color(0.35, 0.84, 0.96, 0.42), 2.0)


func _draw_stalker(center: Vector2) -> void:
	draw_rect(Rect2(center + Vector2(-17.0, -17.0), Vector2(34.0, 32.0)), Color("#10242d"))
	draw_rect(Rect2(center + Vector2(-13.0, -14.0), Vector2(26.0, 25.0)), Color("#3e998d"))
	draw_line(center + Vector2(-11.0, 13.0), center + Vector2(-14.0, 24.0), Color("#10242d"), 4.0)
	draw_line(center + Vector2(11.0, 13.0), center + Vector2(14.0, 24.0), Color("#10242d"), 4.0)
	draw_circle(center + Vector2(-6.0, -4.0), 3.2, Color("#d9ff8a"))
	draw_circle(center + Vector2(6.0, -4.0), 3.2, Color("#d9ff8a"))
