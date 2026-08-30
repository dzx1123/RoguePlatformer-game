extends CharacterBody2D

## Runtime controller for melee and ranged enemies.
class_name RogueEnemy

signal defeated
signal health_changed(current_health: int, maximum_health: int)
signal projectile_requested(origin: Vector2, projectile_velocity: Vector2, damage: int)
signal sound_requested(cue: StringName, is_boss: bool)

const MELEE_SLIME_SHEET := preload("res://assets/enemies/red_crystal_slime_melee_sheet.png")
const RANGED_SLIME_SHEET := preload("res://assets/enemies/red_crystal_slime_ranged_sheet.png")
const BOSS_SLIME_SHEET := preload("res://assets/enemies/red_crystal_slime_boss_sheet.png")

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
const HURT_ANIMATION_DURATION := 0.18
const DEATH_ANIMATION_DURATION := 0.42
const SPRITE_COLUMNS := 4.0
const SPRITE_ROWS := 4.0

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
var _difficulty_health_multiplier: float = 1.0
var _difficulty_damage_multiplier: float = 1.0
var _death_remaining: float = 0.0
var _enemy_sprite: Sprite2D


func _ready() -> void:
	collision_layer = 4
	collision_mask = 1

	var body_collision := CollisionShape2D.new()
	var body_shape := CapsuleShape2D.new()
	body_shape.radius = 36.0 if is_boss() else (24.0 if is_elite() else 18.0)
	body_shape.height = 84.0 if is_boss() else (58.0 if is_elite() else 44.0)
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
		Vector2(112.0, 100.0)
		if is_boss()
		else (Vector2(72.0, 64.0) if is_elite() else Vector2(58.0, 52.0))
	)
	hurtbox_collision.position = Vector2(0.0, -10.0 if is_boss() else -3.0)
	hurtbox_collision.shape = hurtbox_shape
	hurtbox.add_child(hurtbox_collision)
	add_child(hurtbox)

	_enemy_sprite = Sprite2D.new()
	_enemy_sprite.name = "EnemySprite"
	_enemy_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_enemy_sprite.region_enabled = true
	_enemy_sprite.region_filter_clip_enabled = true
	_enemy_sprite.z_index = 1
	add_child(_enemy_sprite)
	_update_sprite_animation()
	queue_redraw()


func setup(
	variant: int,
	phase: float,
	patrol_left: float,
	patrol_right: float,
	role: int = EnemyRole.MELEE,
	rank: int = EnemyRank.NORMAL,
	difficulty_health_multiplier: float = 1.0,
	difficulty_damage_multiplier: float = 1.0
) -> void:
	_role = clampi(role, EnemyRole.MELEE, EnemyRole.RANGED)
	_rank = clampi(rank, EnemyRank.NORMAL, EnemyRank.BOSS)
	_difficulty_health_multiplier = maxf(0.1, difficulty_health_multiplier)
	_difficulty_damage_multiplier = maxf(0.1, difficulty_damage_multiplier)
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
	_max_health = maxi(1, int(round(float(_max_health) * _difficulty_health_multiplier)))
	_current_health = _max_health
	if is_instance_valid(_enemy_sprite):
		_update_sprite_animation()
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
		return Rect2(global_position - Vector2(56.0, 60.0), Vector2(112.0, 100.0))
	if is_elite():
		return Rect2(global_position - Vector2(36.0, 35.0), Vector2(72.0, 64.0))
	return Rect2(global_position - Vector2(29.0, 29.0), Vector2(58.0, 52.0))


func is_hit_by_attack(
	attack_origin: Vector2,
	facing: float,
	reach_scale: float = 1.0,
	attack_type: int = 0
) -> bool:
	if _is_defeated or _hurt_invulnerability_remaining > 0.0:
		return false

	var safe_reach: float = maxf(0.5, reach_scale)
	if attack_type == 1:
		var up_rect := Rect2(
			Vector2(attack_origin.x - 48.0 * safe_reach, attack_origin.y - 158.0 * safe_reach),
			Vector2(96.0 * safe_reach, 178.0 * safe_reach)
		)
		return up_rect.intersects(get_hurtbox_rect())
	if attack_type == 2:
		var down_rect := Rect2(
			Vector2(attack_origin.x - 50.0 * safe_reach, attack_origin.y - 22.0 * safe_reach),
			Vector2(100.0 * safe_reach, 170.0 * safe_reach)
		)
		return down_rect.intersects(get_hurtbox_rect())
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
	reach_scale: float = 1.0,
	attack_type: int = 0
) -> bool:
	if not is_hit_by_attack(attack_origin, facing, reach_scale, attack_type):
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
	_death_remaining = DEATH_ANIMATION_DURATION
	_attack_remaining = 0.0
	velocity = Vector2.ZERO
	collision_layer = 0
	collision_mask = 0
	# Death frames must finish even if a room/test temporarily paused this enemy's AI.
	set_physics_process(true)
	_update_sprite_animation()
	queue_redraw()


func _physics_process(delta: float) -> void:
	if _is_defeated:
		_elapsed += delta
		_death_remaining = maxf(0.0, _death_remaining - delta)
		_update_sprite_animation()
		queue_redraw()
		if _death_remaining <= 0.0:
			defeated.emit()
			queue_free()
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
				sound_requested.emit(&"spit", is_boss())
			else:
				_hit_target_if_still_close()
				sound_requested.emit(&"bite", is_boss())
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
	_update_sprite_animation()
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
		var damage: int = _get_scaled_damage(
			32 if is_boss() else (28 if is_elite() else MELEE_DAMAGE)
		)
		_target.call(&"receive_enemy_attack", global_position, damage)


func _fire_projectile() -> void:
	if not is_instance_valid(_target):
		return
	var projectile_direction: Vector2 = (
		_target.global_position - (global_position + Vector2(0.0, -8.0))
	).normalized()
	if projectile_direction.is_zero_approx():
		projectile_direction = Vector2(_facing, 0.0)
	var projectile_damage: int = _get_scaled_damage(
		20 if is_boss() else (18 if is_elite() else RANGED_DAMAGE)
	)
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


func _get_scaled_damage(base_damage: int) -> int:
	return maxi(1, int(round(float(base_damage) * _difficulty_damage_multiplier)))


func _get_sprite_sheet() -> Texture2D:
	if is_boss():
		return BOSS_SLIME_SHEET
	if is_ranged_enemy():
		return RANGED_SLIME_SHEET
	return MELEE_SLIME_SHEET


func _get_sprite_scale() -> float:
	if is_boss():
		return 0.43
	if is_elite():
		return 0.36
	return 0.29


func _get_sprite_baseline_offset() -> float:
	# The generated sheets have a 313.5px cell. Align their opaque idle bottoms with
	# the collision body's floor contact so every platform uses the same visual baseline.
	if is_boss():
		return -13.0
	if is_elite():
		return -19.0 if is_ranged_enemy() else -17.0
	return -17.0 if is_ranged_enemy() else -15.0


func _set_sprite_cell(column: int, row: int) -> void:
	var sheet := _get_sprite_sheet()
	if _enemy_sprite.texture != sheet:
		_enemy_sprite.texture = sheet
	var cell_size := Vector2(
		float(sheet.get_width()) / SPRITE_COLUMNS,
		float(sheet.get_height()) / SPRITE_ROWS
	)
	_enemy_sprite.region_rect = Rect2(
		Vector2(float(clampi(column, 0, 3)), float(clampi(row, 0, 3))) * cell_size,
		cell_size
	)


func _update_sprite_animation() -> void:
	if not is_instance_valid(_enemy_sprite):
		return

	var animation_row: int = 0
	var animation_column: int = int(floor(_elapsed * 6.0 + _phase)) % 4
	var attack_progress: float = 0.0
	if _is_defeated:
		animation_row = 3
		var death_progress: float = 1.0 - _death_remaining / DEATH_ANIMATION_DURATION
		animation_column = 2 + mini(1, int(floor(death_progress * 2.0)))
	elif _hurt_remaining > 0.0:
		animation_row = 3
		var hurt_progress: float = 1.0 - _hurt_remaining / HURT_ANIMATION_DURATION
		animation_column = mini(1, int(floor(hurt_progress * 2.0)))
	elif _attack_remaining > 0.0:
		animation_row = 2
		attack_progress = clampf(
			1.0 - _attack_remaining / maxf(_get_attack_duration(), 0.001),
			0.0,
			0.999
		)
		if is_boss():
			animation_column = (
				2 + mini(1, int(floor(attack_progress * 2.0)))
				if _boss_attack_uses_projectile
				else mini(1, int(floor(attack_progress * 2.0)))
			)
		else:
			animation_column = mini(3, int(floor(attack_progress * 4.0)))
	elif absf(velocity.x) > 8.0:
		animation_row = 1
		animation_column = int(floor(_elapsed * 10.0 + _phase)) % 4

	_set_sprite_cell(animation_column, animation_row)
	_enemy_sprite.flip_h = _facing > 0.0
	var sprite_scale := _get_sprite_scale()
	_enemy_sprite.scale = Vector2.ONE * sprite_scale
	_enemy_sprite.position = Vector2(0.0, _get_sprite_baseline_offset())
	_enemy_sprite.modulate = Color.WHITE
	if _attack_remaining > 0.0:
		var lunge_distance: float = 5.0 if is_ranged_enemy() else (13.0 if is_boss() else 9.0)
		_enemy_sprite.position.x = sin(attack_progress * PI) * _facing * lunge_distance
	elif _is_defeated:
		var fade_progress: float = 1.0 - _death_remaining / DEATH_ANIMATION_DURATION
		_enemy_sprite.modulate.a = 1.0 - smoothstep(0.72, 1.0, fade_progress)


func _draw() -> void:
	if is_boss():
		draw_circle(Vector2(0.0, -13.0), 57.0 + sin(_elapsed * 3.0) * 2.0, Color(0.98, 0.12, 0.20, 0.10))
		draw_arc(Vector2(0.0, -13.0), 55.0, 0.0, TAU, 32, Color(0.98, 0.28, 0.22, 0.44), 2.0)
	elif is_elite():
		draw_circle(Vector2(0.0, -7.0), 37.0 + sin(_elapsed * 4.0), Color(0.68, 0.30, 1.0, 0.10))
		draw_arc(Vector2(0.0, -7.0), 36.0, 0.0, TAU, 26, Color(0.76, 0.44, 1.0, 0.46), 2.0)

	if _attack_remaining > 0.0:
		var attack_progress: float = 1.0 - _attack_remaining / _get_attack_duration()
		if is_ranged_enemy() or (is_boss() and _boss_attack_uses_projectile):
			var charge_radius: float = lerpf(3.0, 9.0, sin(attack_progress * PI))
			draw_circle(
				Vector2(_facing * (42.0 if is_boss() else 25.0), -10.0),
				charge_radius,
				Color(0.38, 0.94, 1.0, 0.66)
			)

	if _current_health < _max_health and not _is_defeated:
		var health_ratio: float = float(_current_health) / float(maxi(_max_health, 1))
		var bar_width: float = 96.0 if is_boss() else (64.0 if is_elite() else 48.0)
		var bar_y: float = -84.0 if is_boss() else (-56.0 if is_elite() else -43.0)
		draw_rect(Rect2(-bar_width * 0.5, bar_y, bar_width, 6.0), Color(0.03, 0.07, 0.10, 0.88))
		draw_rect(
			Rect2(-bar_width * 0.5 + 2.0, bar_y + 2.0, (bar_width - 4.0) * health_ratio, 2.0),
			Color(0.96, 0.20, 0.22, 0.96)
		)
