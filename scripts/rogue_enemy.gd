extends CharacterBody2D

## Runtime controller for melee and ranged enemies.
class_name RogueEnemy

signal defeated
signal health_changed(current_health: int, maximum_health: int)
signal projectile_requested(
	origin: Vector2,
	projectile_velocity: Vector2,
	damage: int,
	projectile_style: int
)
signal sound_requested(cue: StringName, is_boss: bool)

const MELEE_SLIME_SHEET := preload("res://assets/enemies/red_crystal_slime_melee_sheet.png")
const RANGED_SLIME_SHEET := preload("res://assets/enemies/red_crystal_slime_ranged_sheet.png")
const BOSS_SLIME_SHEET := preload("res://assets/enemies/red_crystal_slime_boss_sheet.png")
const GOBLIN_CLUB_SHEET := preload("res://assets/enemies/red_fang_goblin_club_sheet.png")
const GOBLIN_ELITE_SHEET := preload("res://assets/enemies/red_fang_goblin_elite_sheet.png")
const GOBLIN_ARCHER_SHEET := preload("res://assets/enemies/red_fang_goblin_archer_sheet.png")
const GOBLIN_CLUB_RUN_SHEET := preload("res://assets/enemies/red_fang_goblin_club_run_sheet_v2.png")
const GOBLIN_ELITE_RUN_SHEET := preload("res://assets/enemies/red_fang_goblin_elite_run_sheet_v2.png")
const GOBLIN_ARCHER_RUN_SHEET := preload("res://assets/enemies/red_fang_goblin_archer_run_sheet_v2.png")

enum EnemyRole {
	MELEE,
	RANGED,
}

enum EnemyRank {
	NORMAL,
	ELITE,
	BOSS,
}

enum EnemyFamily {
	SLIME,
	GOBLIN,
}

enum ProjectileStyle {
	CRYSTAL_ORB,
	ARROW,
}

const GRAVITY := 1800.0
const PATROL_SPEED := 72.0
const MELEE_CHASE_SPEED := 145.0
const RANGED_MOVE_SPEED := 112.0
const ACCELERATION := 900.0
const MELEE_DETECTION_RANGE_X := 390.0
const RANGED_DETECTION_RANGE_X := 530.0
const BOSS_DETECTION_RANGE_X := 1400.0
const DETECTION_RANGE_Y := 280.0
const MELEE_ATTACK_REACH_X := 100.0
const MELEE_ATTACK_REACH_Y := 62.0
const RANGED_ATTACK_RANGE_X := 430.0
const RANGED_ATTACK_RANGE_Y := 110.0
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
const GOBLIN_IDLE_FPS := 4.5
const GOBLIN_RUN_FPS := 11.0
const GOBLIN_RUN_COLUMNS := 4.0
const GOBLIN_RUN_ROWS := 2.0
const GOBLIN_RUN_FRAME_COUNT := 8
const PURSUIT_JUMP_SPEED := 690.0
const PURSUIT_JUMP_MIN_HEIGHT := 36.0
const PURSUIT_JUMP_MAX_HEIGHT := 420.0

var _variant: int = 0
var _role: int = EnemyRole.MELEE
var _rank: int = EnemyRank.NORMAL
var _family: int = EnemyFamily.SLIME
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
var _difficulty_speed_multiplier: float = 1.0
var _difficulty_aggression_multiplier: float = 1.0
var _pursuit_jump_cooldown_remaining: float = 0.0
var _death_remaining: float = 0.0
var _enemy_sprite: Sprite2D


func _ready() -> void:
	collision_layer = 4
	collision_mask = 1

	var body_collision := CollisionShape2D.new()
	var body_shape := CapsuleShape2D.new()
	body_shape.radius = 44.0 if is_boss() else (24.0 if is_elite() else 18.0)
	body_shape.height = 104.0 if is_boss() else (58.0 if is_elite() else 44.0)
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
		Vector2(144.0, 124.0)
		if is_boss()
		else (Vector2(72.0, 64.0) if is_elite() else Vector2(58.0, 52.0))
	)
	hurtbox_collision.position = Vector2(0.0, -12.0 if is_boss() else -3.0)
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
	difficulty_damage_multiplier: float = 1.0,
	family: int = EnemyFamily.SLIME,
	difficulty_speed_multiplier: float = 1.0,
	difficulty_aggression_multiplier: float = 1.0
) -> void:
	_role = clampi(role, EnemyRole.MELEE, EnemyRole.RANGED)
	_rank = clampi(rank, EnemyRank.NORMAL, EnemyRank.BOSS)
	_family = clampi(family, EnemyFamily.SLIME, EnemyFamily.GOBLIN)
	_difficulty_health_multiplier = maxf(0.1, difficulty_health_multiplier)
	_difficulty_damage_multiplier = maxf(0.1, difficulty_damage_multiplier)
	_difficulty_speed_multiplier = clampf(difficulty_speed_multiplier, 0.55, 2.20)
	_difficulty_aggression_multiplier = clampf(difficulty_aggression_multiplier, 0.55, 2.40)
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
	# Low aggression now includes a readable reaction pause instead of attacking on
	# the very first physics frame. Later rooms naturally shorten this delay.
	var aggression_progress: float = inverse_lerp(
		0.55,
		2.20,
		clampf(_difficulty_aggression_multiplier, 0.55, 2.20)
	)
	_attack_cooldown_remaining = (
		lerpf(1.25, 0.10, aggression_progress)
		+ fposmod(absf(_phase), 0.28)
	)
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


func get_enemy_family() -> int:
	return _family


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


func get_speed_multiplier() -> float:
	return _difficulty_speed_multiplier


func get_aggression_multiplier() -> float:
	return _difficulty_aggression_multiplier


func get_hurtbox_rect() -> Rect2:
	if is_boss():
		return Rect2(global_position - Vector2(72.0, 74.0), Vector2(144.0, 124.0))
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
	_pursuit_jump_cooldown_remaining = maxf(0.0, _pursuit_jump_cooldown_remaining - delta)
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
		ACCELERATION * _difficulty_speed_multiplier * acceleration_scale * delta
	)
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	else:
		velocity.y = 0.0
		_try_pursuit_jump()

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
			var target_height: float = global_position.y - _target.global_position.y
			if target_height > RANGED_ATTACK_RANGE_Y:
				return _facing * _get_ranged_move_speed()
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
	return _patrol_direction * PATROL_SPEED * patrol_multiplier * _difficulty_speed_multiplier


func _target_is_visible() -> bool:
	if not is_instance_valid(_target):
		return false
	if _target.has_method(&"is_dead") and bool(_target.call(&"is_dead")):
		return false

	var offset: Vector2 = _target.global_position - global_position
	var detection_x: float = RANGED_DETECTION_RANGE_X if is_ranged_enemy() else MELEE_DETECTION_RANGE_X
	if is_boss():
		detection_x = BOSS_DETECTION_RANGE_X
	detection_x *= clampf(_difficulty_aggression_multiplier, 0.55, 2.20)
	return absf(offset.x) <= detection_x and absf(offset.y) <= _get_detection_range_y()


func _get_detection_range_y() -> float:
	if is_boss():
		return 760.0
	var vertical_scale: float = clampf(
		0.55 + _difficulty_aggression_multiplier * 0.45,
		0.72,
		1.60
	)
	return DETECTION_RANGE_Y * vertical_scale


func _try_pursuit_jump() -> void:
	if not is_boss() and _difficulty_aggression_multiplier < 0.68:
		return
	if (
		_pursuit_jump_cooldown_remaining > 0.0
		or _attack_remaining > 0.0
		or _hurt_remaining > 0.0
		or not _target_is_visible()
	):
		return
	var target_offset: Vector2 = _target.global_position - global_position
	var height_to_target: float = -target_offset.y
	if height_to_target < PURSUIT_JUMP_MIN_HEIGHT or height_to_target > PURSUIT_JUMP_MAX_HEIGHT:
		return
	var aggression_progress: float = clampf(
		(_difficulty_aggression_multiplier - 0.8) / 1.4,
		0.0,
		1.0
	)
	var horizontal_reach: float = lerpf(260.0, 560.0, aggression_progress)
	if absf(target_offset.x) > horizontal_reach:
		return
	var jump_speed_scale: float = clampf(sqrt(_difficulty_speed_multiplier), 0.90, 1.16)
	if is_boss():
		jump_speed_scale *= 1.18
	elif is_elite():
		jump_speed_scale *= 1.08
	velocity.y = -PURSUIT_JUMP_SPEED * jump_speed_scale
	_pursuit_jump_cooldown_remaining = clampf(
		1.25 / _difficulty_aggression_multiplier,
		0.48,
		1.30
	)


func _target_in_attack_range() -> bool:
	if not _target_is_visible():
		return false

	var offset: Vector2 = _target.global_position - global_position
	if not is_zero_approx(offset.x):
		_facing = signf(offset.x)
	if is_boss():
		if _family == EnemyFamily.GOBLIN:
			return absf(offset.x) <= 168.0 and absf(offset.y) <= 96.0
		return absf(offset.x) <= 250.0 and absf(offset.y) <= 96.0
	if is_ranged_enemy():
		return (
			absf(offset.x) <= RANGED_ATTACK_RANGE_X
			and absf(offset.y) <= RANGED_ATTACK_RANGE_Y
		)
	return (
		absf(offset.x) <= MELEE_ATTACK_REACH_X
		and absf(offset.y) <= MELEE_ATTACK_REACH_Y
	)


func _start_attack() -> void:
	if is_boss() and is_instance_valid(_target):
		_boss_attack_uses_projectile = (
			_family == EnemyFamily.SLIME
			and absf(_target.global_position.x - global_position.x) > 125.0
		)
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
	var base_cooldown: float
	if is_boss():
		base_cooldown = 0.82
	elif is_elite():
		base_cooldown = (
			(RANGED_ATTACK_COOLDOWN if is_ranged_enemy() else MELEE_ATTACK_COOLDOWN) * 0.78
		)
	else:
		base_cooldown = RANGED_ATTACK_COOLDOWN if is_ranged_enemy() else MELEE_ATTACK_COOLDOWN
	var aggression_scale: float = clampf(_difficulty_aggression_multiplier, 0.55, 2.20)
	return maxf(
		0.40 if is_boss() else 0.46,
		base_cooldown / pow(aggression_scale, 1.35)
	)


func _get_melee_chase_speed() -> float:
	if is_boss():
		return MELEE_CHASE_SPEED * 1.18 * _difficulty_speed_multiplier
	return MELEE_CHASE_SPEED * (1.16 if is_elite() else 1.0) * _difficulty_speed_multiplier


func _get_ranged_move_speed() -> float:
	return RANGED_MOVE_SPEED * (1.18 if is_elite() else 1.0) * _difficulty_speed_multiplier


func _hit_target_if_still_close() -> void:
	if not is_instance_valid(_target):
		return
	if is_boss():
		var boss_melee_offset: Vector2 = _target.global_position - global_position
		if absf(boss_melee_offset.x) > 166.0 or absf(boss_melee_offset.y) > 100.0:
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
	var projectile_speed: float = (
		RANGED_PROJECTILE_SPEED
		* (1.12 if is_boss() else 1.0)
		* clampf(_difficulty_speed_multiplier, 0.80, 1.65)
	)
	var projectile_style := (
		ProjectileStyle.ARROW
		if _family == EnemyFamily.GOBLIN and is_ranged_enemy()
		else ProjectileStyle.CRYSTAL_ORB
	)
	if is_boss():
		for spread_angle in [-0.16, 0.0, 0.16]:
			projectile_requested.emit(
				global_position + Vector2(_facing * 28.0, -12.0),
				projectile_direction.rotated(float(spread_angle)) * projectile_speed,
				projectile_damage,
				projectile_style
			)
	else:
		projectile_requested.emit(
			global_position + Vector2(_facing * 18.0, -8.0),
			projectile_direction * projectile_speed,
			projectile_damage,
			projectile_style
		)


func _get_scaled_damage(base_damage: int) -> int:
	return maxi(1, int(round(float(base_damage) * _difficulty_damage_multiplier)))


func _get_sprite_sheet() -> Texture2D:
	if _family == EnemyFamily.GOBLIN:
		if is_ranged_enemy():
			return GOBLIN_ARCHER_SHEET
		if is_elite() or is_boss():
			return GOBLIN_ELITE_SHEET
		return GOBLIN_CLUB_SHEET
	if is_boss():
		return BOSS_SLIME_SHEET
	if is_ranged_enemy():
		return RANGED_SLIME_SHEET
	return MELEE_SLIME_SHEET


func _get_goblin_run_sheet() -> Texture2D:
	if is_ranged_enemy():
		return GOBLIN_ARCHER_RUN_SHEET
	if is_elite() or is_boss():
		return GOBLIN_ELITE_RUN_SHEET
	return GOBLIN_CLUB_RUN_SHEET


func _get_sprite_scale() -> float:
	if _family == EnemyFamily.GOBLIN:
		if is_boss():
			return 0.54
		if is_elite():
			return 0.30
		return 0.25 if is_ranged_enemy() else 0.26
	if is_boss():
		return 0.60
	if is_elite():
		return 0.36
	return 0.29


func _get_goblin_run_scale() -> float:
	if is_boss():
		return 0.54
	if is_elite():
		return 0.25
	return 0.21 if is_ranged_enemy() else 0.23


func _get_sprite_baseline_offset() -> float:
	# The generated sheets have a 313.5px cell. Align their opaque idle bottoms with
	# the collision body's floor contact so every platform uses the same visual baseline.
	if _family == EnemyFamily.GOBLIN:
		if is_boss():
			return -28.0
		if is_elite():
			return -14.0
		return -14.0 if is_ranged_enemy() else -15.0
	if is_boss():
		return -30.0
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


func _set_goblin_run_frame(frame_index: int) -> void:
	var sheet := _get_goblin_run_sheet()
	if _enemy_sprite.texture != sheet:
		_enemy_sprite.texture = sheet
	var cell_size := Vector2(
		float(sheet.get_width()) / GOBLIN_RUN_COLUMNS,
		float(sheet.get_height()) / GOBLIN_RUN_ROWS
	)
	var resolved_frame: int = posmod(frame_index, GOBLIN_RUN_FRAME_COUNT)
	var column: int = resolved_frame % int(GOBLIN_RUN_COLUMNS)
	var row: int = floori(float(resolved_frame) / GOBLIN_RUN_COLUMNS)
	_enemy_sprite.region_rect = Rect2(Vector2(column, row) * cell_size, cell_size)


func _get_goblin_loop_column(is_running: bool) -> int:
	var frames_per_second: float = GOBLIN_RUN_FPS if is_running else GOBLIN_IDLE_FPS
	var frame_number: int = int(floor(_elapsed * frames_per_second + _phase))
	if is_running:
		return posmod(frame_number, GOBLIN_RUN_FRAME_COUNT)

	# Idle breathes through the neutral pose instead of snapping from frame 3 to 0.
	var idle_cycle_index: int = posmod(frame_number, 4)
	match idle_cycle_index:
		0:
			return 0
		1:
			return 1
		2:
			return 2
		_:
			return 1


func _get_goblin_attack_column(attack_progress: float) -> int:
	if is_ranged_enemy():
		# Hold the drawn bow until the projectile is emitted at roughly 48%.
		if attack_progress < 0.18:
			return 0
		if attack_progress < 0.48:
			return 1
		if attack_progress < 0.70:
			return 2
		return 3

	# Club attacks get a readable anticipation, impact and recovery pose.
	if attack_progress < 0.20:
		return 0
	if attack_progress < 0.40:
		return 1
	if attack_progress < 0.68:
		return 2
	return 3


func _apply_goblin_sprite_motion(
	animation_row: int,
	attack_progress: float,
	hurt_progress: float,
	death_progress: float
) -> void:
	var sprite_scale: float = _get_sprite_scale()
	if animation_row == 0:
		var breath_phase: float = _elapsed * TAU * 1.05 + _phase
		var breath: float = sin(breath_phase)
		_enemy_sprite.scale = Vector2(
			sprite_scale * (1.0 - breath * 0.008),
			sprite_scale * (1.0 + breath * 0.008)
		)
		_enemy_sprite.position.y -= breath * 0.28
	elif animation_row == 1:
		var run_cycle: float = fposmod(
			_elapsed * GOBLIN_RUN_FPS + _phase,
			float(GOBLIN_RUN_FRAME_COUNT)
		) / float(GOBLIN_RUN_FRAME_COUNT)
		var run_phase: float = run_cycle * TAU
		# The eight authored poses already carry the arm/leg weight shift. Keep the
		# runtime motion as restrained as the hero run to avoid jitter and wobble.
		_enemy_sprite.position.y -= absf(sin(run_phase)) * 0.28
		_enemy_sprite.rotation = -_facing * 0.010
	elif animation_row == 2:
		if is_ranged_enemy():
			var bow_draw: float = smoothstep(0.02, 0.45, attack_progress)
			var bow_release: float = (
				smoothstep(0.46, 0.55, attack_progress)
				* (1.0 - smoothstep(0.60, 0.88, attack_progress))
			)
			_enemy_sprite.position.x = _facing * (-1.8 * bow_draw + 4.0 * bow_release)
			_enemy_sprite.position.y -= bow_release * 0.8
			_enemy_sprite.rotation = _facing * (-0.012 * bow_draw + 0.028 * bow_release)
		else:
			var windup: float = (
				smoothstep(0.0, 0.16, attack_progress)
				* (1.0 - smoothstep(0.22, 0.40, attack_progress))
			)
			var strike: float = (
				smoothstep(0.28, 0.48, attack_progress)
				* (1.0 - smoothstep(0.64, 1.0, attack_progress))
			)
			var lunge_distance: float = 13.0 if is_boss() else (10.5 if is_elite() else 9.0)
			_enemy_sprite.position.x = _facing * (-2.4 * windup + lunge_distance * strike)
			_enemy_sprite.position.y -= strike * 1.1
			_enemy_sprite.rotation = _facing * (-0.022 * windup + 0.034 * strike)
	elif animation_row == 3:
		if _is_defeated:
			_enemy_sprite.position.y += smoothstep(0.0, 0.72, death_progress) * 1.4
		else:
			var hurt_weight: float = 1.0 - smoothstep(0.0, 1.0, hurt_progress)
			_enemy_sprite.position.x -= _facing * hurt_weight * 2.4
			_enemy_sprite.rotation = -_facing * hurt_weight * 0.045


func _update_sprite_animation() -> void:
	if not is_instance_valid(_enemy_sprite):
		return

	var animation_row: int = 0
	var animation_column: int = (
		_get_goblin_loop_column(false)
		if _family == EnemyFamily.GOBLIN
		else int(floor(_elapsed * 6.0 + _phase)) % 4
	)
	var attack_progress: float = 0.0
	var hurt_progress: float = 0.0
	var death_progress: float = 0.0
	var using_goblin_run_sheet: bool = false
	if _is_defeated:
		animation_row = 3
		death_progress = 1.0 - _death_remaining / DEATH_ANIMATION_DURATION
		animation_column = 2 + mini(1, int(floor(death_progress * 2.0)))
	elif _hurt_remaining > 0.0:
		animation_row = 3
		hurt_progress = 1.0 - _hurt_remaining / HURT_ANIMATION_DURATION
		animation_column = mini(1, int(floor(hurt_progress * 2.0)))
	elif _attack_remaining > 0.0:
		animation_row = 2
		attack_progress = clampf(
			1.0 - _attack_remaining / maxf(_get_attack_duration(), 0.001),
			0.0,
			0.999
		)
		if _family == EnemyFamily.GOBLIN:
			animation_column = _get_goblin_attack_column(attack_progress)
		elif is_boss():
			animation_column = (
				2 + mini(1, int(floor(attack_progress * 2.0)))
				if _boss_attack_uses_projectile
				else mini(1, int(floor(attack_progress * 2.0)))
			)
		else:
			animation_column = mini(3, int(floor(attack_progress * 4.0)))
	elif absf(velocity.x) > 8.0:
		animation_row = 1
		using_goblin_run_sheet = _family == EnemyFamily.GOBLIN
		animation_column = (
			_get_goblin_loop_column(true)
			if _family == EnemyFamily.GOBLIN
			else int(floor(_elapsed * 10.0 + _phase)) % 4
		)

	if using_goblin_run_sheet:
		_set_goblin_run_frame(animation_column)
	else:
		_set_sprite_cell(animation_column, animation_row)
	_enemy_sprite.flip_h = _facing > 0.0
	var sprite_scale := (
		_get_goblin_run_scale()
		if using_goblin_run_sheet
		else _get_sprite_scale()
	)
	_enemy_sprite.scale = Vector2.ONE * sprite_scale
	_enemy_sprite.position = Vector2(0.0, _get_sprite_baseline_offset())
	_enemy_sprite.rotation = 0.0
	_enemy_sprite.modulate = Color.WHITE
	if _family == EnemyFamily.GOBLIN:
		_apply_goblin_sprite_motion(
			animation_row,
			attack_progress,
			hurt_progress,
			death_progress
		)
	elif _attack_remaining > 0.0:
		var lunge_distance: float = 5.0 if is_ranged_enemy() else (13.0 if is_boss() else 9.0)
		_enemy_sprite.position.x = sin(attack_progress * PI) * _facing * lunge_distance
	if _is_defeated:
		var fade_progress: float = 1.0 - _death_remaining / DEATH_ANIMATION_DURATION
		_enemy_sprite.modulate.a = 1.0 - smoothstep(0.72, 1.0, fade_progress)


func _draw() -> void:
	if is_boss():
		draw_circle(Vector2(0.0, -22.0), 76.0 + sin(_elapsed * 3.0) * 2.5, Color(0.98, 0.12, 0.20, 0.10))
		draw_arc(Vector2(0.0, -22.0), 73.0, 0.0, TAU, 38, Color(0.98, 0.28, 0.22, 0.44), 2.4)
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
		var bar_width: float = 126.0 if is_boss() else (64.0 if is_elite() else 48.0)
		var bar_y: float = -112.0 if is_boss() else (-56.0 if is_elite() else -43.0)
		draw_rect(Rect2(-bar_width * 0.5, bar_y, bar_width, 6.0), Color(0.03, 0.07, 0.10, 0.88))
		draw_rect(
			Rect2(-bar_width * 0.5 + 2.0, bar_y + 2.0, (bar_width - 4.0) * health_ratio, 2.0),
			Color(0.96, 0.20, 0.22, 0.96)
		)
