extends CharacterBody2D

class_name RoguePlayer

signal attack_hit(origin: Vector2, facing: float)
signal skill_hit(origin: Vector2, facing: float, damage: int, reach_scale: float)
signal health_changed(current_health: int, maximum_health: int)
signal weapon_changed(weapon_id: StringName, weapon_name: String, skill_name: String)
signal died

enum VisualState {
	IDLE,
	RUN,
	JUMP_RISE,
	JUMP_FALL,
	LAND,
	ATTACK,
	SKILL,
	DASH,
	HURT,
	DEAD,
}

const HERO_IDLE: Texture2D = preload("res://assets/characters/frames_polished/hero_idle.png")
const HERO_RUN_0: Texture2D = preload("res://assets/characters/frames_polished/hero_run_0.png")
const HERO_RUN_1: Texture2D = preload("res://assets/characters/frames_polished/hero_run_1.png")
const HERO_RUN_2: Texture2D = preload("res://assets/characters/frames_polished/hero_run_2.png")
const HERO_RUN_3: Texture2D = preload("res://assets/characters/frames_polished/hero_run_3.png")
const HERO_RUN_4: Texture2D = preload("res://assets/characters/frames_polished/hero_run_4.png")
const HERO_RUN_5: Texture2D = preload("res://assets/characters/frames_polished/hero_run_5.png")
const HERO_RUN_6: Texture2D = preload("res://assets/characters/frames_polished/hero_run_6.png")
const HERO_RUN_7: Texture2D = preload("res://assets/characters/frames_polished/hero_run_7.png")
const HERO_JUMP_TAKEOFF: Texture2D = preload("res://assets/characters/frames_polished/hero_jump_takeoff.png")
const HERO_JUMP_TUCK: Texture2D = preload("res://assets/characters/frames_polished/hero_jump_tuck.png")
const HERO_JUMP_FALL: Texture2D = preload("res://assets/characters/frames_polished/hero_jump_fall.png")
const HERO_LAND: Texture2D = preload("res://assets/characters/frames_polished/hero_land.png")
const HERO_WINDUP: Texture2D = preload("res://assets/characters/frames_polished/hero_windup.png")
const HERO_SLASH: Texture2D = preload("res://assets/characters/frames_polished/hero_slash.png")
const HERO_RECOVERY: Texture2D = preload("res://assets/characters/frames_polished/hero_recovery.png")

const HERO_FRAME_SIZE := Vector2(640.0, 416.0)
const HERO_SCALE := 0.22
const RUN_FRAME_COUNT := 8.0
const LANDING_SQUASH_DURATION := 0.20
const ATTACK_HIT_PROGRESS := 0.38
const ATTACK_FAILSAFE_MARGIN := 0.08
const SKILL_HIT_PROGRESS := 0.42
const SKILL_FAILSAFE_MARGIN := 0.10
const DEATH_DURATION := 0.85
const RESPAWN_INVULNERABILITY := 1.0

@export_category("Movement")
@export var run_speed := 320.0
@export var ground_acceleration := 2600.0
@export var air_acceleration := 1800.0
@export var gravity := 1800.0
@export var jump_velocity := -640.0
@export var extra_jumps := 1

@export_category("Action")
@export var dash_speed := 800.0
@export var dash_duration := 0.16
@export var attack_duration := 0.36
@export var attack_cooldown_duration := 0.46

@export_category("Combat")
@export var max_health: int = 100
@export var attack_damage: int = 34
@export var auto_respawn: bool = true

@onready var hero_sprite: Sprite2D = $HeroSprite

var _air_jumps_used: int = 0
var _facing: float = 1.0
var _dash_remaining: float = 0.0
var _dash_available: bool = true
var _attack_remaining: float = 0.0
var _attack_cooldown_remaining: float = 0.0
var _attack_elapsed: float = 0.0
var _attack_button_latched: bool = false
var _attack_hit_emitted: bool = false
var _skill_remaining: float = 0.0
var _skill_cooldown_remaining: float = 0.0
var _skill_elapsed: float = 0.0
var _skill_hit_emitted: bool = false
var _spawn_point := Vector2.ZERO
var _visual_time: float = 0.0
var _run_cycle: float = 0.0
var _movement_blend: float = 0.0
var _landing_squash_remaining: float = 0.0
var _airborne_time: float = 0.0
var _hurt_remaining: float = 0.0
var _hurt_invulnerability_remaining: float = 0.0
var _current_health: int = 100
var _is_dead: bool = false
var _death_remaining: float = 0.0
var _input_enabled: bool = true
var _base_max_health: int = 100
var _base_attack_damage: int = 34
var _base_run_speed: float = 320.0
var _base_dash_speed: float = 800.0
var _base_attack_cooldown: float = 0.46
var _weapon_id: StringName = WeaponCatalog.SWORD
var _weapon_name: String = "月弧长剑"
var _weapon_reach: float = 1.0
var _weapon_accent: Color = Color("#78d9ef")
var _weapon_base_damage: int = 34
var _weapon_base_cooldown: float = 0.46
var _run_damage_bonus: int = 0
var _run_attack_cooldown_multiplier: float = 1.0
var _skill_name: String = "月轮斩"
var _skill_duration: float = 0.50
var _skill_cooldown_duration: float = 2.80
var _skill_damage_multiplier: float = 1.90
var _skill_reach: float = 1.62
var _skill_lunge: float = 105.0
var _visual_state: int = VisualState.IDLE
var _current_texture: Texture2D


func _ready() -> void:
	_spawn_point = global_position
	_base_max_health = maxi(1, max_health)
	_base_attack_damage = maxi(1, attack_damage)
	_base_run_speed = run_speed
	_base_dash_speed = dash_speed
	_base_attack_cooldown = attack_cooldown_duration
	_current_health = maxi(1, max_health)
	configure_weapon(WeaponCatalog.SWORD)
	_set_texture(HERO_IDLE)
	_update_hero_visuals()
	queue_redraw()


func _physics_process(delta: float) -> void:
	_visual_time += delta

	if auto_respawn and Input.is_action_just_pressed(&"restart"):
		respawn()
		return
	if _is_dead:
		_process_death(delta)
		return

	var was_on_floor: bool = is_on_floor()
	_update_timers(delta)

	if was_on_floor:
		_air_jumps_used = 0
		_dash_available = true
	elif _dash_remaining <= 0.0:
		velocity.y += gravity * delta

	var input_direction: float = 0.0
	if _input_enabled:
		input_direction = Input.get_axis(&"move_left", &"move_right")
	if not is_zero_approx(input_direction):
		_facing = signf(input_direction)

	if (
		_input_enabled
		and Input.is_action_just_pressed(&"jump")
		and _hurt_remaining <= 0.0
	):
		if was_on_floor:
			_jump()
		elif _air_jumps_used < extra_jumps:
			_air_jumps_used += 1
			_jump()

	if (
		_input_enabled
		and Input.is_action_just_pressed(&"dash")
		and _dash_available
		and _attack_remaining <= 0.0
		and _skill_remaining <= 0.0
		and _hurt_remaining <= 0.0
	):
		_start_dash()

	if _input_enabled and Input.is_action_just_pressed(&"skill"):
		_start_skill()

	var attack_button_pressed: bool = _input_enabled and Input.is_action_pressed(&"attack")
	if not attack_button_pressed:
		_attack_button_latched = false
	elif not _attack_button_latched:
		_attack_button_latched = true
		_start_attack()

	if _dash_remaining > 0.0:
		velocity = Vector2(_facing * dash_speed, 0.0)
	else:
		var movement_scale: float = 1.0
		if _skill_remaining > 0.0:
			movement_scale = 0.28
		elif _attack_remaining > 0.0:
			movement_scale = 0.78
		elif _hurt_remaining > 0.0:
			movement_scale = 0.15
		var target_speed: float = input_direction * run_speed * movement_scale
		var acceleration: float = ground_acceleration if was_on_floor else air_acceleration
		velocity.x = move_toward(velocity.x, target_speed, acceleration * delta)

	move_and_slide()

	var now_on_floor: bool = is_on_floor()
	if now_on_floor:
		if not was_on_floor:
			_landing_squash_remaining = LANDING_SQUASH_DURATION
		_airborne_time = 0.0
	else:
		_airborne_time += delta

	if global_position.y > 820.0:
		_current_health = 0
		health_changed.emit(_current_health, maxi(1, max_health))
		_die(global_position + Vector2(0.0, -20.0))
		return

	var speed_ratio: float = clampf(absf(velocity.x) / maxf(run_speed, 1.0), 0.0, 1.0)
	var target_visual_motion: float = speed_ratio
	if _dash_remaining > 0.0:
		target_visual_motion = 1.15
	_movement_blend = move_toward(_movement_blend, target_visual_motion, delta * 10.0)

	if (
		now_on_floor
		and speed_ratio > 0.04
		and _attack_remaining <= 0.0
		and _skill_remaining <= 0.0
	):
		var run_frames_per_second: float = lerpf(8.0, 16.0, speed_ratio)
		_run_cycle = fposmod(_run_cycle + delta * run_frames_per_second, RUN_FRAME_COUNT)

	_update_hero_visuals()
	queue_redraw()


func respawn() -> void:
	global_position = _spawn_point
	velocity = Vector2.ZERO
	_is_dead = false
	_death_remaining = 0.0
	_current_health = maxi(1, max_health)
	_dash_remaining = 0.0
	_dash_available = true
	_attack_remaining = 0.0
	_attack_cooldown_remaining = 0.0
	_attack_elapsed = 0.0
	_attack_button_latched = false
	_attack_hit_emitted = false
	_skill_remaining = 0.0
	_skill_cooldown_remaining = 0.0
	_skill_elapsed = 0.0
	_skill_hit_emitted = false
	_air_jumps_used = 0
	_run_cycle = 0.0
	_movement_blend = 0.0
	_landing_squash_remaining = 0.0
	_airborne_time = 0.0
	_hurt_remaining = 0.0
	_hurt_invulnerability_remaining = RESPAWN_INVULNERABILITY
	health_changed.emit(_current_health, maxi(1, max_health))
	_update_hero_visuals()
	queue_redraw()


func reset_run_progression() -> void:
	max_health = _base_max_health
	run_speed = _base_run_speed
	dash_speed = _base_dash_speed
	_run_damage_bonus = 0
	_run_attack_cooldown_multiplier = 1.0
	configure_weapon(_weapon_id)
	respawn()


func enter_room(spawn_position: Vector2, recovery: int = 10) -> void:
	var carried_health: int = maxi(1, _current_health)
	_spawn_point = spawn_position
	respawn()
	_current_health = mini(maxi(1, max_health), carried_health + maxi(0, recovery))
	health_changed.emit(_current_health, maxi(1, max_health))


func apply_run_upgrade(upgrade_id: StringName) -> bool:
	match upgrade_id:
		&"tempered_edge":
			_run_damage_bonus += 8
			attack_damage = _weapon_base_damage + _run_damage_bonus
		&"vitality_rune":
			max_health += 20
			_current_health = mini(max_health, _current_health + 20)
			health_changed.emit(_current_health, maxi(1, max_health))
		&"swift_step":
			run_speed += 32.0
		&"dash_core":
			dash_speed += 90.0
		&"battle_rhythm":
			_run_attack_cooldown_multiplier *= 0.88
			attack_cooldown_duration = maxf(
				0.20,
				_weapon_base_cooldown * _run_attack_cooldown_multiplier
			)
		_:
			return false
	return true


func configure_weapon(weapon_id: StringName) -> bool:
	if not WeaponCatalog.all_weapon_ids().has(weapon_id):
		return false
	var weapon: Dictionary = WeaponCatalog.get_weapon(weapon_id)
	_weapon_id = weapon.get("id", WeaponCatalog.SWORD)
	_weapon_name = String(weapon.get("name", "月弧长剑"))
	_weapon_base_damage = int(weapon.get("damage", _base_attack_damage))
	_weapon_base_cooldown = float(weapon.get("attack_cooldown", _base_attack_cooldown))
	attack_damage = _weapon_base_damage + _run_damage_bonus
	attack_duration = float(weapon.get("attack_duration", 0.36))
	attack_cooldown_duration = maxf(
		0.20,
		_weapon_base_cooldown * _run_attack_cooldown_multiplier
	)
	_weapon_reach = float(weapon.get("reach", 1.0))
	_skill_name = String(weapon.get("skill_name", "月轮斩"))
	_skill_duration = float(weapon.get("skill_duration", 0.50))
	_skill_cooldown_duration = float(weapon.get("skill_cooldown", 2.80))
	_skill_damage_multiplier = float(weapon.get("skill_multiplier", 1.90))
	_skill_reach = float(weapon.get("skill_reach", 1.62))
	_skill_lunge = float(weapon.get("skill_lunge", 105.0))
	_weapon_accent = weapon.get("accent", Color("#78d9ef"))
	_finish_attack()
	_finish_skill()
	_skill_cooldown_remaining = 0.0
	weapon_changed.emit(_weapon_id, _weapon_name, _skill_name)
	_update_hero_visuals()
	queue_redraw()
	return true


func heal(amount: int) -> int:
	if _is_dead or amount <= 0:
		return 0
	var health_before: int = _current_health
	_current_health = mini(maxi(1, max_health), _current_health + amount)
	if _current_health != health_before:
		health_changed.emit(_current_health, maxi(1, max_health))
	return _current_health - health_before


func set_input_enabled(enabled: bool) -> void:
	_input_enabled = enabled
	if not enabled:
		_attack_button_latched = false
		_dash_remaining = 0.0
		if not _is_dead:
			_finish_attack()
			_finish_skill()


func get_run_stats() -> Dictionary:
	return {
		"max_health": max_health,
		"attack_damage": attack_damage,
		"run_speed": run_speed,
		"dash_speed": dash_speed,
		"attack_cooldown": attack_cooldown_duration,
		"weapon_id": _weapon_id,
	}


func _jump() -> void:
	velocity.y = jump_velocity
	_landing_squash_remaining = 0.0
	_airborne_time = 0.0


func _start_dash() -> void:
	if _is_dead:
		return
	_dash_available = false
	_dash_remaining = dash_duration
	velocity.y = 0.0


func _start_attack() -> void:
	if (
		_attack_remaining > 0.0
		or _attack_cooldown_remaining > 0.0
		or _dash_remaining > 0.0
		or _skill_remaining > 0.0
		or _hurt_remaining > 0.0
		or _is_dead
	):
		return

	_attack_remaining = maxf(attack_duration, 0.01)
	_attack_cooldown_remaining = attack_cooldown_duration
	_attack_elapsed = 0.0
	_attack_hit_emitted = false


func _start_skill() -> void:
	if (
		_skill_remaining > 0.0
		or _skill_cooldown_remaining > 0.0
		or _attack_remaining > 0.0
		or _dash_remaining > 0.0
		or _hurt_remaining > 0.0
		or _is_dead
	):
		return
	_skill_remaining = maxf(_skill_duration, 0.01)
	_skill_cooldown_remaining = _skill_cooldown_duration
	_skill_elapsed = 0.0
	_skill_hit_emitted = false
	velocity.x = _facing * _skill_lunge


func _finish_skill() -> void:
	_skill_remaining = 0.0
	_skill_elapsed = 0.0
	_skill_hit_emitted = false


func _finish_attack() -> void:
	_attack_remaining = 0.0
	_attack_elapsed = 0.0
	_attack_hit_emitted = false


func receive_enemy_attack(attacker_position: Vector2, damage: int = 20) -> bool:
	if _is_dead or _hurt_invulnerability_remaining > 0.0:
		return false

	var attack_in_progress: bool = _attack_remaining > 0.0 or _skill_remaining > 0.0
	_current_health = maxi(0, _current_health - maxi(0, damage))
	health_changed.emit(_current_health, maxi(1, max_health))
	if _current_health <= 0:
		_die(attacker_position)
		return true

	_hurt_remaining = 0.0 if attack_in_progress else 0.18
	_hurt_invulnerability_remaining = 0.72
	_dash_remaining = 0.0
	if not attack_in_progress:
		_finish_attack()
		_finish_skill()
	var knockback_direction: float = signf(global_position.x - attacker_position.x)
	if is_zero_approx(knockback_direction):
		knockback_direction = -_facing
	if attack_in_progress:
		velocity = Vector2(knockback_direction * 90.0, minf(velocity.y, -70.0))
	else:
		velocity = Vector2(knockback_direction * 270.0, -220.0)
	_movement_blend = 0.0
	_update_hero_visuals()
	queue_redraw()
	return true


func get_current_health() -> int:
	return _current_health


func get_max_health() -> int:
	return maxi(1, max_health)


func get_attack_damage() -> int:
	return maxi(1, attack_damage)


func get_attack_reach() -> float:
	return maxf(0.5, _weapon_reach)


func get_weapon_id() -> StringName:
	return _weapon_id


func get_weapon_name() -> String:
	return _weapon_name


func get_skill_name() -> String:
	return _skill_name


func get_skill_cooldown_remaining() -> float:
	return _skill_cooldown_remaining


func get_skill_cooldown_duration() -> float:
	return maxf(0.01, _skill_cooldown_duration)


func is_dead() -> bool:
	return _is_dead


func _die(attacker_position: Vector2) -> void:
	if _is_dead:
		return
	_is_dead = true
	_death_remaining = DEATH_DURATION
	_dash_remaining = 0.0
	_finish_attack()
	_finish_skill()
	_hurt_remaining = 0.0
	_hurt_invulnerability_remaining = DEATH_DURATION
	var death_direction: float = signf(global_position.x - attacker_position.x)
	if is_zero_approx(death_direction):
		death_direction = -_facing
	velocity = Vector2(death_direction * 190.0, -250.0)
	died.emit()
	_update_hero_visuals()
	queue_redraw()


func _process_death(delta: float) -> void:
	_death_remaining = maxf(0.0, _death_remaining - delta)
	velocity.x = move_toward(velocity.x, 0.0, ground_acceleration * 0.35 * delta)
	if not is_on_floor():
		velocity.y += gravity * delta
	move_and_slide()
	_update_hero_visuals()
	queue_redraw()
	if auto_respawn and (_death_remaining <= 0.0 or global_position.y > 820.0):
		respawn()


func _update_timers(delta: float) -> void:
	_dash_remaining = maxf(0.0, _dash_remaining - delta)
	_attack_cooldown_remaining = maxf(0.0, _attack_cooldown_remaining - delta)
	_skill_cooldown_remaining = maxf(0.0, _skill_cooldown_remaining - delta)
	_hurt_remaining = maxf(0.0, _hurt_remaining - delta)
	_hurt_invulnerability_remaining = maxf(0.0, _hurt_invulnerability_remaining - delta)
	_landing_squash_remaining = maxf(0.0, _landing_squash_remaining - delta)

	if _attack_remaining > 0.0:
		_attack_elapsed += delta
		_attack_remaining = maxf(0.0, _attack_remaining - delta)
		var attack_progress: float = 1.0 - _attack_remaining / maxf(attack_duration, 0.001)
		if not _attack_hit_emitted and attack_progress >= ATTACK_HIT_PROGRESS:
			_attack_hit_emitted = true
			attack_hit.emit(global_position, _facing)
		if (
			_attack_remaining <= 0.0
			or _attack_elapsed >= maxf(attack_duration, 0.01) + ATTACK_FAILSAFE_MARGIN
		):
			_finish_attack()
	elif _attack_elapsed > 0.0 or _attack_hit_emitted:
		_finish_attack()

	if _skill_remaining > 0.0:
		_skill_elapsed += delta
		_skill_remaining = maxf(0.0, _skill_remaining - delta)
		var skill_progress: float = 1.0 - _skill_remaining / maxf(_skill_duration, 0.001)
		if not _skill_hit_emitted and skill_progress >= SKILL_HIT_PROGRESS:
			_skill_hit_emitted = true
			var skill_damage: int = maxi(
				1,
				int(round(float(get_attack_damage()) * _skill_damage_multiplier))
			)
			skill_hit.emit(global_position, _facing, skill_damage, _skill_reach)
		if (
			_skill_remaining <= 0.0
			or _skill_elapsed >= maxf(_skill_duration, 0.01) + SKILL_FAILSAFE_MARGIN
		):
			_finish_skill()
	elif _skill_elapsed > 0.0 or _skill_hit_emitted:
		_finish_skill()


func _resolve_visual_state() -> int:
	if _is_dead:
		return VisualState.DEAD
	if _hurt_remaining > 0.0:
		return VisualState.HURT
	if _skill_remaining > 0.0:
		return VisualState.SKILL
	if _attack_remaining > 0.0:
		return VisualState.ATTACK
	if _dash_remaining > 0.0:
		return VisualState.DASH
	if not is_on_floor():
		return VisualState.JUMP_RISE if velocity.y < 0.0 else VisualState.JUMP_FALL
	if _landing_squash_remaining > 0.0:
		return VisualState.LAND
	if _movement_blend > 0.08:
		return VisualState.RUN
	return VisualState.IDLE


func _update_hero_visuals() -> void:
	_visual_state = _resolve_visual_state()
	_reset_sprite_pose()

	match _visual_state:
		VisualState.RUN:
			_animate_run()
		VisualState.JUMP_RISE:
			_animate_jump_rise()
		VisualState.JUMP_FALL:
			_animate_jump_fall()
		VisualState.LAND:
			_animate_land()
		VisualState.ATTACK:
			_animate_attack()
		VisualState.SKILL:
			_animate_skill()
		VisualState.DASH:
			_animate_dash()
		VisualState.HURT:
			_animate_hurt()
		VisualState.DEAD:
			_animate_dead()
		_:
			_animate_idle()

	if _is_dead:
		hero_sprite.modulate = Color(0.56, 0.64, 0.72, 0.72)
	elif _hurt_remaining > 0.0:
		hero_sprite.modulate = Color(1.0, 0.42, 0.42, 1.0)
	elif _skill_remaining > 0.0:
		hero_sprite.modulate = _weapon_accent.lightened(0.18)
	elif _hurt_invulnerability_remaining > 0.0 and int(_visual_time * 20.0) % 2 == 0:
		hero_sprite.modulate = Color(1.0, 1.0, 1.0, 0.52)
	else:
		hero_sprite.modulate = Color.WHITE


func _reset_sprite_pose() -> void:
	hero_sprite.visible = true
	hero_sprite.position = Vector2(0.0, -15.0)
	hero_sprite.scale = Vector2(HERO_SCALE, HERO_SCALE)
	hero_sprite.rotation = 0.0
	hero_sprite.flip_h = _facing < 0.0


func _set_texture(texture: Texture2D) -> void:
	if texture == _current_texture:
		return
	_current_texture = texture
	hero_sprite.texture = texture


func _run_texture() -> Texture2D:
	var frame_index: int = int(floor(_run_cycle))
	match frame_index:
		0:
			return HERO_RUN_0
		1:
			return HERO_RUN_1
		2:
			return HERO_RUN_2
		3:
			return HERO_RUN_3
		4:
			return HERO_RUN_4
		5:
			return HERO_RUN_5
		6:
			return HERO_RUN_6
		_:
			return HERO_RUN_7


func _animate_idle() -> void:
	_set_texture(HERO_IDLE)
	var breath: float = sin(_visual_time * 2.2)
	hero_sprite.position.y += breath * 0.45
	hero_sprite.scale = Vector2(
		HERO_SCALE * (1.0 - breath * 0.003),
		HERO_SCALE * (1.0 + breath * 0.006)
	)


func _animate_run() -> void:
	_set_texture(_run_texture())
	var cycle_phase: float = _run_cycle / RUN_FRAME_COUNT * TAU
	var speed_ratio: float = clampf(_movement_blend, 0.0, 1.0)
	var step_lift: float = absf(sin(cycle_phase * 2.0)) * 0.45 * speed_ratio
	hero_sprite.position += Vector2(_facing * 0.7 * speed_ratio, -step_lift)
	hero_sprite.rotation = -_facing * lerpf(0.004, 0.014, speed_ratio)
	hero_sprite.scale.y *= 1.0 + step_lift * 0.004


func _animate_jump_rise() -> void:
	if _airborne_time < 0.11:
		_set_texture(HERO_JUMP_TAKEOFF)
		hero_sprite.position += Vector2(-_facing * 0.4, 1.0)
		hero_sprite.scale = Vector2(HERO_SCALE * 1.035, HERO_SCALE * 0.965)
	else:
		_set_texture(HERO_JUMP_TUCK)
		hero_sprite.position += Vector2(_facing * 1.0, -2.0)
		hero_sprite.scale = Vector2(HERO_SCALE * 0.98, HERO_SCALE * 1.025)
	hero_sprite.rotation = -_facing * 0.032


func _animate_jump_fall() -> void:
	if velocity.y < 150.0:
		_set_texture(HERO_JUMP_TUCK)
		hero_sprite.position += Vector2(_facing * 0.4, -1.0)
	else:
		_set_texture(HERO_JUMP_FALL)
		hero_sprite.position += Vector2(-_facing * 0.5, 0.6)
	hero_sprite.rotation = _facing * 0.02
	var fall_blend: float = clampf((velocity.y - 80.0) / 520.0, 0.0, 1.0)
	hero_sprite.scale = Vector2(
		HERO_SCALE * lerpf(0.99, 1.025, fall_blend),
		HERO_SCALE * lerpf(1.015, 0.985, fall_blend)
	)


func _animate_land() -> void:
	var landing_progress: float = 1.0 - _landing_squash_remaining / LANDING_SQUASH_DURATION
	landing_progress = clampf(landing_progress, 0.0, 1.0)
	if landing_progress < 0.58:
		var crouch_recovery: float = smoothstep(0.0, 1.0, landing_progress / 0.58)
		_set_texture(HERO_LAND)
		hero_sprite.position.y += lerpf(2.2, 0.3, crouch_recovery)
		hero_sprite.scale = Vector2(
			HERO_SCALE * lerpf(1.055, 1.01, crouch_recovery),
			HERO_SCALE * lerpf(0.93, 0.995, crouch_recovery)
		)
	else:
		var stand_up: float = smoothstep(0.0, 1.0, (landing_progress - 0.58) / 0.42)
		_set_texture(HERO_IDLE)
		hero_sprite.position.y += lerpf(1.0, 0.0, stand_up)
		hero_sprite.scale = Vector2(
			HERO_SCALE * lerpf(1.025, 1.0, stand_up),
			HERO_SCALE * lerpf(0.975, 1.0, stand_up)
		)


func _animate_dash() -> void:
	_set_texture(HERO_RUN_4)
	hero_sprite.position += Vector2(_facing * 5.0, 1.0)
	hero_sprite.rotation = -_facing * 0.025
	hero_sprite.scale = Vector2(HERO_SCALE * 1.14, HERO_SCALE * 0.86)


func _animate_hurt() -> void:
	_set_texture(HERO_IDLE)
	hero_sprite.position += Vector2(-_facing * 3.0, 1.0)
	hero_sprite.rotation = _facing * 0.07
	hero_sprite.scale = Vector2(HERO_SCALE * 1.04, HERO_SCALE * 0.96)


func _animate_dead() -> void:
	_set_texture(HERO_IDLE)
	var death_progress: float = 1.0 - _death_remaining / DEATH_DURATION
	death_progress = clampf(death_progress, 0.0, 1.0)
	hero_sprite.position += Vector2(-_facing * 4.0, lerpf(1.0, 7.0, death_progress))
	hero_sprite.rotation = _facing * lerpf(0.18, 1.34, death_progress)
	hero_sprite.scale = Vector2(
		HERO_SCALE * lerpf(1.0, 1.07, death_progress),
		HERO_SCALE * lerpf(1.0, 0.88, death_progress)
	)


func _animate_attack() -> void:
	var attack_progress: float = 1.0 - _attack_remaining / maxf(attack_duration, 0.001)

	if attack_progress < 0.28:
		var windup_time: float = smoothstep(0.0, 1.0, attack_progress / 0.28)
		_set_texture(HERO_WINDUP)
		hero_sprite.position += Vector2(-_facing * 3.0 * windup_time, windup_time)
		hero_sprite.rotation = -_facing * 0.055 * windup_time
		hero_sprite.scale = Vector2(
			HERO_SCALE * (1.0 - 0.02 * windup_time),
			HERO_SCALE * (1.0 + 0.025 * windup_time)
		)
	elif attack_progress < 0.68:
		var strike_time: float = smoothstep(0.0, 1.0, (attack_progress - 0.28) / 0.40)
		var strike_punch: float = sin(strike_time * PI)
		_set_texture(HERO_SLASH)
		hero_sprite.position += Vector2(_facing * lerpf(-2.0, 6.0, strike_time), 0.5)
		hero_sprite.rotation = _facing * lerpf(-0.035, 0.045, strike_time)
		hero_sprite.scale = Vector2(
			HERO_SCALE * (1.0 + 0.035 * strike_punch),
			HERO_SCALE * (1.0 - 0.025 * strike_punch)
		)
	else:
		var recovery_time: float = smoothstep(0.0, 1.0, (attack_progress - 0.68) / 0.32)
		_set_texture(HERO_RECOVERY)
		hero_sprite.position += Vector2(_facing * lerpf(5.0, 0.0, recovery_time), 0.0)
		hero_sprite.rotation = _facing * lerpf(0.045, 0.0, recovery_time)
		hero_sprite.scale = Vector2(
			HERO_SCALE * lerpf(1.025, 1.0, recovery_time),
			HERO_SCALE * lerpf(0.98, 1.0, recovery_time)
		)


func _animate_skill() -> void:
	var skill_progress: float = 1.0 - _skill_remaining / maxf(_skill_duration, 0.001)
	if skill_progress < 0.30:
		_set_texture(HERO_WINDUP)
		var charge: float = smoothstep(0.0, 1.0, skill_progress / 0.30)
		hero_sprite.position += Vector2(-_facing * 5.0 * charge, 1.5 * charge)
		hero_sprite.rotation = -_facing * 0.10 * charge
		hero_sprite.scale = Vector2(HERO_SCALE * 0.96, HERO_SCALE * 1.06)
	elif skill_progress < 0.76:
		_set_texture(HERO_SLASH)
		var strike: float = smoothstep(0.0, 1.0, (skill_progress - 0.30) / 0.46)
		hero_sprite.position += Vector2(_facing * lerpf(-4.0, 10.0, strike), -1.0)
		hero_sprite.rotation = _facing * lerpf(-0.08, 0.10, strike)
		var impact: float = sin(strike * PI)
		hero_sprite.scale = Vector2(
			HERO_SCALE * (1.0 + impact * 0.10),
			HERO_SCALE * (1.0 - impact * 0.05)
		)
	else:
		_set_texture(HERO_RECOVERY)
		var recovery: float = smoothstep(0.0, 1.0, (skill_progress - 0.76) / 0.24)
		hero_sprite.position += Vector2(_facing * lerpf(7.0, 0.0, recovery), 0.0)
		hero_sprite.rotation = _facing * lerpf(0.08, 0.0, recovery)


func _draw() -> void:
	if _skill_remaining > 0.0:
		var skill_progress: float = 1.0 - _skill_remaining / maxf(_skill_duration, 0.001)
		var arc_alpha: float = sin(clampf(skill_progress, 0.0, 1.0) * PI)
		draw_arc(
			_p(22.0, -8.0),
			52.0 * _skill_reach,
			-1.35 if _facing > 0.0 else PI - 0.35,
			0.35 if _facing > 0.0 else PI + 1.35,
			24,
			Color(_weapon_accent.r, _weapon_accent.g, _weapon_accent.b, arc_alpha * 0.75),
			7.0,
			true
		)
		draw_circle(Vector2(0.0, -6.0), 28.0 + arc_alpha * 8.0, Color(
			_weapon_accent.r,
			_weapon_accent.g,
			_weapon_accent.b,
			arc_alpha * 0.12
		))
	if _dash_remaining > 0.0:
		_draw_dash_afterimages()
		draw_line(_p(-58.0, -8.0), _p(-15.0, -8.0), Color(0.38, 0.92, 1.0, 0.50), 7.0)
		draw_line(_p(-48.0, 7.0), _p(-12.0, 7.0), Color(0.38, 0.92, 1.0, 0.25), 4.0)

	if _landing_squash_remaining > 0.0 and is_on_floor():
		var landing_time: float = 1.0 - _landing_squash_remaining / LANDING_SQUASH_DURATION
		var dust_alpha: float = 0.28 * (1.0 - clampf(landing_time, 0.0, 1.0))
		draw_circle(Vector2(-17.0, 24.0), 5.0 + landing_time * 5.0, Color(0.50, 0.78, 0.82, dust_alpha))
		draw_circle(Vector2(17.0, 24.0), 4.0 + landing_time * 4.0, Color(0.50, 0.78, 0.82, dust_alpha))


func _draw_dash_afterimages() -> void:
	for ghost_index in range(1, 4):
		var ghost_distance: float = float(ghost_index) * 18.0
		var ghost_alpha: float = 0.18 / float(ghost_index)
		draw_set_transform(
			Vector2(-_facing * ghost_distance, -15.0),
			0.0,
			Vector2(HERO_SCALE * _facing, HERO_SCALE)
		)
		draw_texture(
			HERO_RUN_4,
			-HERO_FRAME_SIZE * 0.5,
			Color(0.35, 0.92, 1.0, ghost_alpha)
		)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _p(x: float, y: float) -> Vector2:
	return Vector2(x * _facing, y)
