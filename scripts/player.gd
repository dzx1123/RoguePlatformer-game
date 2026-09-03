extends CharacterBody2D

class_name RoguePlayer

signal attack_hit(origin: Vector2, facing: float)
signal skill_hit(origin: Vector2, facing: float, damage: int, reach_scale: float)
signal health_changed(current_health: int, maximum_health: int)
signal damage_received(amount: int, cause: StringName)
signal weapon_changed(weapon_id: StringName, weapon_name: String, skill_name: String)
signal died
signal action_started(action: StringName)
signal vocal_requested(cue: StringName)

enum VisualState {
	IDLE,
	RUN,
	JUMP_RISE,
	JUMP_FALL,
	LAND,
	TURN,
	ATTACK,
	ATTACK_RECOVERY,
	SKILL,
	SKILL_RECOVERY,
	DASH,
	DASH_RECOVERY,
	HURT,
	DEAD,
}

enum AttackType {
	FORWARD,
	UPWARD,
	DOWNWARD,
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
const HERO_SLASH_FOLLOWTHROUGH: Texture2D = preload("res://assets/characters/frames_polished/hero_slash_followthrough.png")
const HERO_RECOVERY: Texture2D = preload("res://assets/characters/frames_polished/hero_recovery.png")
const HERO_SLASH_UP_WINDUP: Texture2D = preload("res://assets/characters/frames_polished/hero_slash_up_windup.png")
const HERO_SLASH_UP: Texture2D = preload("res://assets/characters/frames_polished/hero_slash_up.png")
const HERO_SLASH_UP_FOLLOWTHROUGH: Texture2D = preload("res://assets/characters/frames_polished/hero_slash_up_followthrough.png")
const HERO_SLASH_DOWN_WINDUP: Texture2D = preload("res://assets/characters/frames_polished/hero_slash_down_windup.png")
const HERO_SLASH_DOWN: Texture2D = preload("res://assets/characters/frames_polished/hero_slash_down.png")
const HERO_SLASH_DOWN_FOLLOWTHROUGH: Texture2D = preload("res://assets/characters/frames_polished/hero_slash_down_followthrough.png")
const DASH_ECHO_SCRIPT := preload("res://scripts/dash_echo.gd")
const MOON_WHEEL_GEOMETRY := preload("res://scripts/moon_wheel_geometry.gd")
const UPGRADE_CATALOG := preload("res://scripts/upgrade_catalog.gd")

const HERO_FRAME_SIZE := Vector2(640.0, 416.0)
const HERO_SCALE := 0.22
const RUN_FRAME_COUNT := 8.0
const RUN_PIXELS_PER_FRAME := 19.0
const RUN_SETTLE_FRAMES_PER_SECOND := 20.0
const LANDING_SQUASH_DURATION := 0.20
const TURN_BLEND_DURATION := 0.10
const ATTACK_HIT_PROGRESS := 0.38
const ATTACK_FAILSAFE_MARGIN := 0.08
const ATTACK_EXIT_BLEND_DURATION := 0.085
const SKILL_HIT_PROGRESS := 0.70
const SKILL_FAILSAFE_MARGIN := 0.10
const SKILL_EXIT_BLEND_DURATION := 0.11
const SKILL_POSE_ECHO_DURATION := 0.075
const DEATH_DURATION := 0.85
const RESPAWN_INVULNERABILITY := 1.0
const DASH_COOLDOWN := 2.0
const DASH_EXIT_BLEND_DURATION := 0.065
const DROP_THROUGH_DURATION := 0.20

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
@export var dash_cooldown_duration := DASH_COOLDOWN
@export var attack_duration := 0.30
@export var attack_cooldown_duration := 0.38

@export_category("Combat")
@export var max_health: int = 100
@export var attack_damage: int = 34
@export var auto_respawn: bool = true

@onready var hero_sprite: Sprite2D = $HeroSprite
@onready var skill_pose_echo: Sprite2D = $SkillPoseEcho
@onready var skill_effect: MoonWheelEffect = $MoonWheelEffect
@onready var weapon_skill_effect: WeaponSkillEffect = $WeaponSkillEffect

var _air_jumps_used: int = 0
var _facing: float = 1.0
var _dash_remaining: float = 0.0
var _dash_cooldown_remaining: float = 0.0
var _dash_echo_remaining: float = 0.0
var _dash_exit_blend_remaining: float = 0.0
var _attack_remaining: float = 0.0
var _attack_cooldown_remaining: float = 0.0
var _attack_elapsed: float = 0.0
var _attack_exit_blend_remaining: float = 0.0
var _attack_button_latched: bool = false
var _attack_hit_emitted: bool = false
var _attack_type: int = AttackType.FORWARD
var _downslash_bounce_applied: bool = false
var _skill_remaining: float = 0.0
var _skill_cooldown_remaining: float = 0.0
var _skill_elapsed: float = 0.0
var _skill_hit_emitted: bool = false
var _skill_hit_index: int = 0
var _skill_last_emitted_index: int = -1
var _skill_hit_progresses: Array[float] = [SKILL_HIT_PROGRESS]
var _skill_hit_weights: Array[float] = [1.0]
var _skill_exit_blend_remaining: float = 0.0
var _skill_pose_echo_remaining: float = 0.0
var _skill_pose_echo_origin := Vector2.ZERO
var _spawn_point := Vector2.ZERO
var _visual_time: float = 0.0
var _run_cycle: float = 0.0
var _run_settle_target: float = 0.0
var _run_is_settling: bool = false
var _run_has_settled: bool = true
var _movement_blend: float = 0.0
var _turn_remaining: float = 0.0
var _turn_from_facing: float = 1.0
var _landing_squash_remaining: float = 0.0
var _airborne_time: float = 0.0
var _hurt_remaining: float = 0.0
var _hurt_invulnerability_remaining: float = 0.0
var _drop_through_remaining: float = 0.0
var _base_ground_surface_y: float = INF
var _current_health: int = 100
var _is_dead: bool = false
var _last_death_reason: StringName = &"unknown"
var _death_remaining: float = 0.0
var _input_enabled: bool = true
var _reduced_effects_enabled: bool = false
var _base_max_health: int = 100
var _base_attack_damage: int = 34
var _base_run_speed: float = 320.0
var _base_dash_speed: float = 800.0
var _base_attack_cooldown: float = 0.38
var _weapon_id: StringName = WeaponCatalog.SWORD
var _weapon_name: String = "月弧长剑"
var _weapon_reach: float = 1.0
var _weapon_accent: Color = Color("#78d9ef")
var _weapon_base_damage: int = 34
var _weapon_base_cooldown: float = 0.46
var _run_damage_bonus: int = 0
var _run_attack_cooldown_multiplier: float = 1.0
var _run_upgrade_counts: Dictionary = {}
var _skill_name: String = "月轮斩"
var _skill_duration: float = 0.68
var _skill_cooldown_duration: float = 2.80
var _skill_damage_multiplier: float = 1.90
var _skill_reach: float = 1.62
var _skill_lunge: float = 105.0
var _visual_state: int = VisualState.IDLE
var _visual_state_elapsed: float = 0.0
var _sprite_pose_initialized: bool = false
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
	elif _dash_remaining <= 0.0:
		velocity.y += gravity * delta

	var input_direction: float = 0.0
	if _input_enabled:
		input_direction = Input.get_axis(&"move_left", &"move_right")
	var requested_facing: float = 0.0
	if not is_zero_approx(input_direction):
		requested_facing = signf(input_direction)
		# During a ground reversal the body keeps facing its actual travel direction
		# until it has nearly stopped. This removes the brief moonwalk before turning.
		if (
			_skill_remaining <= 0.0
			and _attack_remaining <= 0.0
			and _dash_remaining <= 0.0
			and (
				not was_on_floor
				or absf(velocity.x) <= 52.0
				or signf(velocity.x) == requested_facing
			)
		):
			var previous_facing: float = _facing
			_facing = requested_facing
			if was_on_floor and not is_equal_approx(previous_facing, _facing):
				_begin_ground_turn(previous_facing)

	if (
		_input_enabled
		and Input.is_action_just_pressed(&"jump")
		and _hurt_remaining <= 0.0
	):
		var holding_down: bool = InputMap.has_action(&"aim_down") and Input.is_action_pressed(&"aim_down")
		if was_on_floor and holding_down and _can_drop_through_platform():
			_start_drop_through()
		elif was_on_floor:
			_jump()
		elif _air_jumps_used < extra_jumps:
			_air_jumps_used += 1
			_jump()

	if (
		_input_enabled
		and Input.is_action_just_pressed(&"dash")
		and _dash_cooldown_remaining <= 0.0
		and _attack_remaining <= 0.0
		and _skill_remaining <= 0.0
		and _hurt_remaining <= 0.0
	):
		if not is_zero_approx(requested_facing):
			_facing = requested_facing
		_start_dash()

	if _input_enabled and Input.is_action_just_pressed(&"skill"):
		if not is_zero_approx(requested_facing):
			_facing = requested_facing
		_start_skill()

	var attack_button_pressed: bool = _input_enabled and Input.is_action_pressed(&"attack")
	if not attack_button_pressed:
		_attack_button_latched = false
	elif not _attack_button_latched:
		_attack_button_latched = true
		if not is_zero_approx(requested_facing):
			_facing = requested_facing
		_start_attack(_get_directional_attack_type())

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
		if _skill_remaining > 0.0:
			var skill_progress := clampf(
				1.0 - _skill_remaining / maxf(_skill_duration, 0.001),
				0.0,
				1.0
			)
			target_speed += _facing * _get_skill_lunge_speed(skill_progress)
		var acceleration: float = ground_acceleration if was_on_floor else air_acceleration
		velocity.x = move_toward(velocity.x, target_speed, acceleration * delta)

	move_and_slide()
	_update_dash_echoes(delta)

	var now_on_floor: bool = is_on_floor()
	if now_on_floor:
		if not was_on_floor:
			_landing_squash_remaining = LANDING_SQUASH_DURATION
		_airborne_time = 0.0
	else:
		_airborne_time += delta

	if global_position.y > 820.0:
		var fall_damage: int = _current_health
		_current_health = 0
		health_changed.emit(_current_health, maxi(1, max_health))
		if fall_damage > 0:
			damage_received.emit(fall_damage, &"fall")
		_die(global_position + Vector2(0.0, -20.0), &"fall")
		return

	var speed_ratio: float = clampf(absf(velocity.x) / maxf(run_speed, 1.0), 0.0, 1.0)
	var target_visual_motion: float = speed_ratio
	if _dash_remaining > 0.0:
		target_visual_motion = 1.15
	var movement_blend_rate: float = 14.0 if target_visual_motion > _movement_blend else 5.0
	_movement_blend = move_toward(
		_movement_blend,
		target_visual_motion,
		delta * movement_blend_rate
	)

	if (
		now_on_floor
		and speed_ratio > 0.04
		and _attack_remaining <= 0.0
		and _skill_remaining <= 0.0
		and _dash_remaining <= 0.0
		and _skill_exit_blend_remaining <= 0.0
		and _attack_exit_blend_remaining <= 0.0
		and _dash_exit_blend_remaining <= 0.0
	):
		_run_cycle = fposmod(
			_run_cycle + delta * absf(velocity.x) / RUN_PIXELS_PER_FRAME,
			RUN_FRAME_COUNT
		)
		_run_is_settling = false
		_run_has_settled = false
	elif now_on_floor and _movement_blend > 0.03:
		_settle_run_cycle(delta)

	_update_hero_visuals(delta)
	queue_redraw()


func respawn() -> void:
	global_position = _spawn_point
	velocity = Vector2.ZERO
	_is_dead = false
	_last_death_reason = &"unknown"
	_death_remaining = 0.0
	_current_health = maxi(1, max_health)
	_dash_remaining = 0.0
	_dash_cooldown_remaining = 0.0
	_dash_echo_remaining = 0.0
	_dash_exit_blend_remaining = 0.0
	_attack_remaining = 0.0
	_attack_cooldown_remaining = 0.0
	_attack_elapsed = 0.0
	_attack_exit_blend_remaining = 0.0
	_attack_button_latched = false
	_attack_hit_emitted = false
	_attack_type = AttackType.FORWARD
	_downslash_bounce_applied = false
	_skill_remaining = 0.0
	_skill_cooldown_remaining = 0.0
	_skill_elapsed = 0.0
	_skill_hit_emitted = false
	_skill_hit_index = 0
	_skill_last_emitted_index = -1
	_skill_exit_blend_remaining = 0.0
	_skill_pose_echo_remaining = 0.0
	skill_pose_echo.visible = false
	_air_jumps_used = 0
	_run_cycle = 0.0
	_run_settle_target = 0.0
	_run_is_settling = false
	_run_has_settled = true
	_movement_blend = 0.0
	_turn_remaining = 0.0
	_turn_from_facing = _facing
	_landing_squash_remaining = 0.0
	_airborne_time = 0.0
	_hurt_remaining = 0.0
	_hurt_invulnerability_remaining = RESPAWN_INVULNERABILITY
	_drop_through_remaining = 0.0
	_visual_state = VisualState.IDLE
	_visual_state_elapsed = 0.0
	_sprite_pose_initialized = false
	set_collision_mask_value(1, true)
	health_changed.emit(_current_health, maxi(1, max_health))
	_update_hero_visuals()
	queue_redraw()


func reset_run_progression() -> void:
	max_health = _base_max_health
	run_speed = _base_run_speed
	dash_speed = _base_dash_speed
	_run_damage_bonus = 0
	_run_attack_cooldown_multiplier = 1.0
	_run_upgrade_counts.clear()
	configure_weapon(_weapon_id)
	respawn()


func enter_room(spawn_position: Vector2, recovery: int = 10) -> void:
	var carried_health: int = maxi(1, _current_health)
	_spawn_point = spawn_position
	respawn()
	_current_health = mini(maxi(1, max_health), carried_health + maxi(0, recovery))
	health_changed.emit(_current_health, maxi(1, max_health))


func set_base_ground_surface_y(surface_y: float) -> void:
	_base_ground_surface_y = surface_y


func apply_run_upgrade(upgrade_id: StringName) -> bool:
	var upgrade: Dictionary = UPGRADE_CATALOG.get_upgrade(upgrade_id)
	if upgrade.is_empty():
		return false
	var required_weapon: StringName = upgrade.get("weapon", &"")
	if not required_weapon.is_empty() and required_weapon != _weapon_id:
		return false
	var current_stacks: int = get_run_upgrade_count(upgrade_id)
	var max_stacks: int = int(upgrade.get("max_stacks", 1))
	if current_stacks >= max_stacks:
		return false
	_run_upgrade_counts[upgrade_id] = current_stacks + 1

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
		&"second_wind":
			heal(35)
		&"resonant_focus", &"extended_guard":
			configure_weapon(_weapon_id)
		&"moon_expansion", &"moon_rupture", &"lunar_cycle", &"eclipse_guard":
			configure_weapon(_weapon_id)
		&"woven_momentum", &"threaded_edge", &"quicksilver", &"shadowstep":
			configure_weapon(_weapon_id)
		&"fault_line", &"starfall_core", &"meteor_rhythm", &"adamant_stance":
			configure_weapon(_weapon_id)
		_:
			_run_upgrade_counts.erase(upgrade_id)
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
	attack_duration = float(weapon.get("attack_duration", 0.30))
	attack_cooldown_duration = maxf(
		0.20,
		_weapon_base_cooldown * _run_attack_cooldown_multiplier
	)
	_weapon_reach = (
		float(weapon.get("reach", 1.0))
		* (1.0 + 0.10 * float(get_run_upgrade_count(&"extended_guard")))
	)
	_skill_name = String(weapon.get("skill_name", "月轮斩"))
	_skill_duration = float(weapon.get("skill_duration", 0.50))
	var skill_cooldown_multiplier: float = pow(
		0.86,
		float(get_run_upgrade_count(&"resonant_focus"))
	)
	var skill_damage_bonus: float = 0.0
	var skill_reach_bonus: float = 0.0
	var skill_lunge_bonus: float = 0.0
	match _weapon_id:
		WeaponCatalog.SWORD:
			skill_cooldown_multiplier *= pow(
				0.84,
				float(get_run_upgrade_count(&"lunar_cycle"))
			)
			skill_damage_bonus = 0.18 * float(
				get_run_upgrade_count(&"moon_rupture")
			)
			skill_reach_bonus = 0.12 * float(
				get_run_upgrade_count(&"moon_expansion")
			)
		WeaponCatalog.TWIN_BLADES:
			skill_cooldown_multiplier *= pow(
				0.86,
				float(get_run_upgrade_count(&"quicksilver"))
			)
			skill_damage_bonus = 0.12 * float(
				get_run_upgrade_count(&"threaded_edge")
			)
			skill_lunge_bonus = 0.18 * float(
				get_run_upgrade_count(&"woven_momentum")
			)
		WeaponCatalog.GREATSWORD:
			skill_cooldown_multiplier *= pow(
				0.88,
				float(get_run_upgrade_count(&"meteor_rhythm"))
			)
			skill_damage_bonus = 0.20 * float(
				get_run_upgrade_count(&"starfall_core")
			)
			skill_reach_bonus = 0.12 * float(
				get_run_upgrade_count(&"fault_line")
			)
	_skill_cooldown_duration = maxf(
		0.60,
		float(weapon.get("skill_cooldown", 2.80)) * skill_cooldown_multiplier
	)
	_skill_damage_multiplier = (
		float(weapon.get("skill_multiplier", 1.90))
		* (1.0 + skill_damage_bonus)
	)
	_skill_reach = (
		float(weapon.get("skill_reach", 1.62))
		* (1.0 + skill_reach_bonus)
	)
	_skill_lunge = (
		float(weapon.get("skill_lunge", 105.0))
		* (1.0 + skill_lunge_bonus)
	)
	_configure_skill_hit_sequence(weapon)
	_weapon_accent = weapon.get("accent", Color("#78d9ef"))
	_finish_attack()
	_finish_skill()
	_skill_cooldown_remaining = 0.0
	weapon_changed.emit(_weapon_id, _weapon_name, _skill_name)
	_update_hero_visuals()
	queue_redraw()
	return true


func _configure_skill_hit_sequence(weapon: Dictionary) -> void:
	_skill_hit_progresses.clear()
	_skill_hit_weights.clear()
	var progress_values: Array = weapon.get(
		"skill_hit_progresses",
		[SKILL_HIT_PROGRESS]
	) as Array
	var weight_values: Array = weapon.get("skill_hit_weights", [1.0]) as Array
	for progress_value: Variant in progress_values:
		_skill_hit_progresses.append(clampf(float(progress_value), 0.01, 0.99))
	for weight_value: Variant in weight_values:
		_skill_hit_weights.append(maxf(0.01, float(weight_value)))
	if _skill_hit_progresses.is_empty():
		_skill_hit_progresses.append(SKILL_HIT_PROGRESS)
	if _skill_hit_weights.size() != _skill_hit_progresses.size():
		_skill_hit_weights.clear()
		var equal_weight: float = 1.0 / float(_skill_hit_progresses.size())
		for _hit_index in range(_skill_hit_progresses.size()):
			_skill_hit_weights.append(equal_weight)


func _get_skill_lunge_speed(skill_progress: float) -> float:
	var safe_progress: float = clampf(skill_progress, 0.0, 1.0)
	match _weapon_id:
		WeaponCatalog.TWIN_BLADES:
			var burst_strength: float = maxf(
				_skill_motion_pulse(safe_progress, 0.18, 0.16),
				maxf(
					_skill_motion_pulse(safe_progress, 0.48, 0.16),
					_skill_motion_pulse(safe_progress, 0.78, 0.16)
				)
			)
			var exit_fade: float = 1.0 - smoothstep(
				0.0,
				1.0,
				clampf((safe_progress - 0.82) / 0.16, 0.0, 1.0)
			)
			return _skill_lunge * (0.34 + burst_strength * 1.04) * exit_fade
		WeaponCatalog.GREATSWORD:
			var commit: float = smoothstep(
				0.0,
				1.0,
				clampf((safe_progress - 0.38) / 0.18, 0.0, 1.0)
			)
			var recovery_fade: float = 1.0 - smoothstep(
				0.0,
				1.0,
				clampf((safe_progress - 0.66) / 0.18, 0.0, 1.0)
			)
			return _skill_lunge * commit * recovery_fade
		_:
			var lunge_envelope: float = 1.0 - smoothstep(
				0.0,
				1.0,
				clampf((safe_progress - 0.10) / 0.58, 0.0, 1.0)
			)
			return _skill_lunge * lunge_envelope


func _skill_motion_pulse(
	skill_progress: float,
	pulse_center: float,
	pulse_radius: float
) -> float:
	var distance: float = absf(skill_progress - pulse_center)
	return 1.0 - smoothstep(
		0.0,
		1.0,
		clampf(distance / maxf(pulse_radius, 0.001), 0.0, 1.0)
	)


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


func set_reduced_effects_enabled(enabled: bool) -> void:
	_reduced_effects_enabled = enabled
	if enabled:
		_skill_pose_echo_remaining = 0.0
		skill_pose_echo.visible = false


func get_reduced_effects_enabled() -> bool:
	return _reduced_effects_enabled


func get_run_stats() -> Dictionary:
	return {
		"max_health": max_health,
		"attack_damage": attack_damage,
		"run_speed": run_speed,
		"dash_speed": dash_speed,
		"attack_cooldown": attack_cooldown_duration,
		"attack_reach": _weapon_reach,
		"skill_cooldown": _skill_cooldown_duration,
		"skill_damage_multiplier": _skill_damage_multiplier,
		"skill_reach": _skill_reach,
		"skill_lunge": _skill_lunge,
		"run_upgrade_count": get_total_run_upgrade_count(),
		"weapon_id": _weapon_id,
	}


func get_run_upgrade_count(upgrade_id: StringName) -> int:
	return maxi(0, int(_run_upgrade_counts.get(upgrade_id, 0)))


func get_run_upgrade_counts() -> Dictionary:
	return _run_upgrade_counts.duplicate(true)


func get_total_run_upgrade_count() -> int:
	var total: int = 0
	for count_value: Variant in _run_upgrade_counts.values():
		total += maxi(0, int(count_value))
	return total


func _begin_ground_turn(previous_facing: float) -> void:
	_turn_from_facing = previous_facing
	_turn_remaining = TURN_BLEND_DURATION


func _clear_turn_transition() -> void:
	_turn_remaining = 0.0
	_turn_from_facing = _facing


func _get_display_facing() -> float:
	if _turn_remaining > TURN_BLEND_DURATION * 0.5:
		return _turn_from_facing
	return _facing


func _jump() -> void:
	_clear_turn_transition()
	_attack_exit_blend_remaining = 0.0
	_dash_exit_blend_remaining = 0.0
	_skill_exit_blend_remaining = 0.0
	velocity.y = jump_velocity
	_landing_squash_remaining = 0.0
	_airborne_time = 0.0
	action_started.emit(&"jump")


func _can_drop_through_platform() -> bool:
	# The base floor remains solid.  Raised room platforms are intentionally one-way.
	# A height check is stable even on frames where Godot has already cleared slide data.
	if _base_ground_surface_y < INF:
		return global_position.y < _base_ground_surface_y - 32.0
	return _is_standing_on_droppable_platform()


func _is_standing_on_droppable_platform() -> bool:
	for collision_index in range(get_slide_collision_count()):
		var slide_collision := get_slide_collision(collision_index)
		if slide_collision.get_normal().y > -0.70:
			continue
		var collider := slide_collision.get_collider() as Node
		if is_instance_valid(collider) and collider.is_in_group(&"drop_through_platform"):
			return true
	return false


func _start_drop_through() -> void:
	_drop_through_remaining = DROP_THROUGH_DURATION
	set_collision_mask_value(1, false)
	velocity.y = maxf(100.0, velocity.y)
	_landing_squash_remaining = 0.0
	_airborne_time = 0.0


func _start_dash() -> void:
	if _is_dead:
		return
	_dash_remaining = dash_duration
	_dash_cooldown_remaining = maxf(0.01, dash_cooldown_duration)
	_dash_echo_remaining = 0.0
	_dash_exit_blend_remaining = 0.0
	_attack_exit_blend_remaining = 0.0
	_skill_exit_blend_remaining = 0.0
	_clear_turn_transition()
	velocity.y = 0.0
	action_started.emit(&"dash")


func _finish_dash() -> void:
	_dash_remaining = 0.0
	if _is_dead or _hurt_remaining > 0.0:
		return
	# Dash uses the same planted-foot handoff as the other committed actions.
	# It prevents its travel pose from snapping into a mid-stride run frame.
	_dash_exit_blend_remaining = DASH_EXIT_BLEND_DURATION
	_run_cycle = 0.0
	_run_settle_target = 0.0
	_run_is_settling = false
	_run_has_settled = true


func _start_attack(attack_type: int = AttackType.FORWARD) -> void:
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
	_attack_exit_blend_remaining = 0.0
	_dash_exit_blend_remaining = 0.0
	_skill_exit_blend_remaining = 0.0
	_clear_turn_transition()
	_attack_hit_emitted = false
	_attack_type = clampi(attack_type, AttackType.FORWARD, AttackType.DOWNWARD)
	_downslash_bounce_applied = false
	action_started.emit(&"attack")


func _get_directional_attack_type() -> int:
	# Hollow Knight-style input: direction held when J is pressed selects the slash.
	if InputMap.has_action(&"aim_up") and Input.is_action_pressed(&"aim_up"):
		return AttackType.UPWARD
	if InputMap.has_action(&"aim_down") and Input.is_action_pressed(&"aim_down"):
		return AttackType.DOWNWARD
	return AttackType.FORWARD


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
	_skill_exit_blend_remaining = 0.0
	_attack_exit_blend_remaining = 0.0
	_dash_exit_blend_remaining = 0.0
	_clear_turn_transition()
	_skill_pose_echo_remaining = 0.0
	skill_pose_echo.visible = false
	_skill_remaining = maxf(_skill_duration, 0.01)
	_skill_cooldown_remaining = _skill_cooldown_duration
	_skill_elapsed = 0.0
	_skill_hit_emitted = false
	_skill_hit_index = 0
	_skill_last_emitted_index = -1
	velocity.x = _facing * _get_skill_lunge_speed(0.0)
	action_started.emit(&"skill")


func _finish_skill() -> void:
	var should_blend_out: bool = (
		_skill_elapsed > 0.0
		and not _is_dead
		and _hurt_remaining <= 0.0
	)
	_skill_remaining = 0.0
	_skill_elapsed = 0.0
	_skill_hit_emitted = false
	_skill_hit_index = 0
	if should_blend_out:
		_skill_exit_blend_remaining = SKILL_EXIT_BLEND_DURATION
		_run_cycle = 0.0
		_run_settle_target = 0.0
		_run_is_settling = false
		_run_has_settled = true


func _finish_attack() -> void:
	var should_blend_out: bool = (
		_attack_elapsed > 0.0
		and not _is_dead
		and _hurt_remaining <= 0.0
	)
	_attack_remaining = 0.0
	_attack_elapsed = 0.0
	_attack_hit_emitted = false
	_attack_type = AttackType.FORWARD
	_downslash_bounce_applied = false
	if should_blend_out:
		# Resume from the same planted-foot anchor used by skill recovery. Without
		# this hold, a moving attack jumps back to the arbitrary run frame captured
		# when the attack started, which reads as a one-frame character twitch.
		_attack_exit_blend_remaining = ATTACK_EXIT_BLEND_DURATION
		_run_cycle = 0.0
		_run_settle_target = 0.0
		_run_is_settling = false
		_run_has_settled = true


func receive_enemy_attack(
	attacker_position: Vector2,
	damage: int = 20,
	cause: StringName = &"enemy_attack"
) -> bool:
	# The dash is an intentional i-frame window: enemy contact and projectiles do no damage.
	if _is_dead or _dash_remaining > 0.0 or _hurt_invulnerability_remaining > 0.0:
		return false
	if (
		_skill_remaining > 0.0
		and _weapon_id == WeaponCatalog.TWIN_BLADES
		and get_run_upgrade_count(&"shadowstep") > 0
	):
		return false

	var attack_in_progress: bool = _attack_remaining > 0.0 or _skill_remaining > 0.0
	var damage_multiplier: float = 1.0
	var skill_knockback_multiplier: float = 1.0
	if _skill_remaining > 0.0:
		if (
			_weapon_id == WeaponCatalog.SWORD
			and get_run_upgrade_count(&"eclipse_guard") > 0
		):
			damage_multiplier = 0.65
		elif (
			_weapon_id == WeaponCatalog.GREATSWORD
			and get_run_upgrade_count(&"adamant_stance") > 0
		):
			damage_multiplier = 0.55
			skill_knockback_multiplier = 0.55
	var resolved_damage: int = maxi(
		0,
		int(round(float(maxi(0, damage)) * damage_multiplier))
	)
	var health_before: int = _current_health
	_current_health = maxi(0, _current_health - resolved_damage)
	var damage_taken: int = health_before - _current_health
	health_changed.emit(_current_health, maxi(1, max_health))
	if damage_taken > 0:
		damage_received.emit(damage_taken, cause)
	if _current_health <= 0:
		_die(attacker_position, cause)
		return true

	vocal_requested.emit(&"hurt")
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
		velocity = Vector2(
			knockback_direction * 90.0 * skill_knockback_multiplier,
			minf(velocity.y, -70.0 * skill_knockback_multiplier)
		)
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


func get_attack_type() -> int:
	return _attack_type


func get_skill_hit_center() -> Vector2:
	return MOON_WHEEL_GEOMETRY.get_world_center(global_position, _facing)


func get_skill_hit_radii() -> Vector2:
	return MOON_WHEEL_GEOMETRY.get_radii(_skill_reach)


func confirm_attack_connected() -> void:
	if _attack_type != AttackType.DOWNWARD or _downslash_bounce_applied or _attack_remaining <= 0.0:
		return
	_downslash_bounce_applied = true
	# A confirmed downslash turns into a pogo-style rebound, even if cast from the ground.
	velocity.y = minf(velocity.y, -460.0)
	_air_jumps_used = 0
	_airborne_time = 0.0
	_landing_squash_remaining = 0.0
	queue_redraw()


func get_weapon_id() -> StringName:
	return _weapon_id


func get_weapon_name() -> String:
	return _weapon_name


func get_attack_cooldown_remaining() -> float:
	return _attack_cooldown_remaining


func get_attack_cooldown_duration() -> float:
	return maxf(0.01, attack_cooldown_duration)


func get_skill_name() -> String:
	return _skill_name


func get_skill_cooldown_remaining() -> float:
	return _skill_cooldown_remaining


func get_skill_cooldown_duration() -> float:
	return maxf(0.01, _skill_cooldown_duration)


func get_skill_hit_index() -> int:
	return _skill_last_emitted_index


func get_skill_hit_count() -> int:
	return _skill_hit_progresses.size()


func get_skill_impact_scale() -> float:
	match _weapon_id:
		WeaponCatalog.TWIN_BLADES:
			return 0.72
		WeaponCatalog.GREATSWORD:
			return 1.48
		_:
			return 1.20


func get_dash_cooldown_remaining() -> float:
	return _dash_cooldown_remaining


func get_dash_cooldown_duration() -> float:
	return maxf(0.01, dash_cooldown_duration)


func is_dead() -> bool:
	return _is_dead


func get_last_death_reason() -> StringName:
	return _last_death_reason


func _die(attacker_position: Vector2, reason: StringName = &"unknown") -> void:
	if _is_dead:
		return
	_is_dead = true
	_last_death_reason = reason if not reason.is_empty() else &"unknown"
	_death_remaining = DEATH_DURATION
	_dash_remaining = 0.0
	_finish_attack()
	_finish_skill()
	_skill_exit_blend_remaining = 0.0
	_skill_pose_echo_remaining = 0.0
	skill_pose_echo.visible = false
	_hurt_remaining = 0.0
	_hurt_invulnerability_remaining = DEATH_DURATION
	var death_direction: float = signf(global_position.x - attacker_position.x)
	if is_zero_approx(death_direction):
		death_direction = -_facing
	velocity = Vector2(death_direction * 190.0, -250.0)
	vocal_requested.emit(&"defeat")
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
	var was_dropping: bool = _drop_through_remaining > 0.0
	_drop_through_remaining = maxf(0.0, _drop_through_remaining - delta)
	if was_dropping and _drop_through_remaining <= 0.0:
		set_collision_mask_value(1, true)
	var was_dashing: bool = _dash_remaining > 0.0
	_dash_remaining = maxf(0.0, _dash_remaining - delta)
	if was_dashing and _dash_remaining <= 0.0:
		_finish_dash()
	_dash_cooldown_remaining = maxf(0.0, _dash_cooldown_remaining - delta)
	_dash_exit_blend_remaining = maxf(0.0, _dash_exit_blend_remaining - delta)
	_attack_cooldown_remaining = maxf(0.0, _attack_cooldown_remaining - delta)
	_attack_exit_blend_remaining = maxf(0.0, _attack_exit_blend_remaining - delta)
	_turn_remaining = maxf(0.0, _turn_remaining - delta)
	_skill_cooldown_remaining = maxf(0.0, _skill_cooldown_remaining - delta)
	_skill_exit_blend_remaining = maxf(0.0, _skill_exit_blend_remaining - delta)
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
		while (
			_skill_hit_index < _skill_hit_progresses.size()
			and skill_progress >= _skill_hit_progresses[_skill_hit_index]
		):
			_skill_last_emitted_index = _skill_hit_index
			_skill_hit_emitted = true
			var hit_weight: float = _skill_hit_weights[_skill_hit_index]
			var skill_damage: int = maxi(
				1,
				int(round(
					float(get_attack_damage())
					* _skill_damage_multiplier
					* hit_weight
				))
			)
			skill_hit.emit(global_position, _facing, skill_damage, _skill_reach)
			_skill_hit_index += 1
		if (
			_skill_remaining <= 0.0
			or _skill_elapsed >= maxf(_skill_duration, 0.01) + SKILL_FAILSAFE_MARGIN
		):
			_finish_skill()
	elif _skill_elapsed > 0.0 or _skill_hit_emitted:
		_finish_skill()


func _update_dash_echoes(delta: float) -> void:
	if _dash_remaining <= 0.0:
		return
	_dash_echo_remaining = maxf(0.0, _dash_echo_remaining - delta)
	if _dash_echo_remaining > 0.0:
		return
	_dash_echo_remaining = 0.035
	var echo: Sprite2D = DASH_ECHO_SCRIPT.new() as Sprite2D
	get_parent().add_child(echo)
	echo.global_position = hero_sprite.global_position
	echo.z_index = hero_sprite.z_index - 1
	echo.call(&"setup", hero_sprite.texture, _facing, hero_sprite.global_scale)


func _settle_run_cycle(delta: float) -> void:
	if _run_has_settled:
		return
	if not _run_is_settling:
		var current_cycle: float = fposmod(_run_cycle, RUN_FRAME_COUNT)
		_run_settle_target = ceil(current_cycle / 4.0) * 4.0
		if _run_settle_target - current_cycle < 0.08:
			_run_settle_target += 4.0
		_run_is_settling = true
	_run_cycle = move_toward(
		_run_cycle,
		_run_settle_target,
		delta * RUN_SETTLE_FRAMES_PER_SECOND
	)
	if is_equal_approx(_run_cycle, _run_settle_target):
		_run_cycle = fposmod(_run_settle_target, RUN_FRAME_COUNT)
		_run_is_settling = false
		_run_has_settled = true


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
	if _dash_exit_blend_remaining > 0.0:
		return VisualState.DASH_RECOVERY
	if _attack_exit_blend_remaining > 0.0:
		return VisualState.ATTACK_RECOVERY
	if _skill_exit_blend_remaining > 0.0:
		return VisualState.SKILL_RECOVERY
	if not is_on_floor():
		return VisualState.JUMP_RISE if velocity.y < 0.0 else VisualState.JUMP_FALL
	if _landing_squash_remaining > 0.0:
		return VisualState.LAND
	if _turn_remaining > 0.0:
		return VisualState.TURN
	if _movement_blend > 0.04:
		return VisualState.RUN
	return VisualState.IDLE


func _update_hero_visuals(delta: float = 1.0 / 60.0) -> void:
	_update_skill_pose_echo(delta)
	var previous_visual_state: int = _visual_state
	var next_visual_state: int = _resolve_visual_state()
	var state_changed: bool = next_visual_state != _visual_state
	if state_changed:
		_visual_state = next_visual_state
		_visual_state_elapsed = 0.0
	else:
		_visual_state_elapsed += maxf(0.0, delta)

	var previous_position: Vector2 = hero_sprite.position
	var previous_scale: Vector2 = hero_sprite.scale
	var previous_rotation: float = hero_sprite.rotation
	var previous_texture: Texture2D = _current_texture
	var previous_flip_h: bool = hero_sprite.flip_h
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
		VisualState.TURN:
			_animate_turn()
		VisualState.ATTACK:
			_animate_attack()
		VisualState.ATTACK_RECOVERY:
			_animate_attack_recovery()
		VisualState.SKILL:
			_animate_skill()
		VisualState.SKILL_RECOVERY:
			_animate_skill_recovery()
		VisualState.DASH:
			_animate_dash()
		VisualState.DASH_RECOVERY:
			_animate_dash_recovery()
		VisualState.HURT:
			_animate_hurt()
		VisualState.DEAD:
			_animate_dead()
		_:
			_animate_idle()

	var target_position: Vector2 = hero_sprite.position
	var target_scale: Vector2 = hero_sprite.scale
	var target_rotation: float = hero_sprite.rotation
	if _sprite_pose_initialized:
		var smoothing_rate: float = _get_pose_smoothing_rate(_visual_state)
		var pose_blend: float = 1.0 - exp(-smoothing_rate * maxf(delta, 0.0001))
		if state_changed:
			var minimum_transition_blend: float = (
				0.56
				if _visual_state in [
					VisualState.TURN,
					VisualState.ATTACK,
					VisualState.ATTACK_RECOVERY,
					VisualState.SKILL,
					VisualState.SKILL_RECOVERY,
					VisualState.DASH,
					VisualState.DASH_RECOVERY,
				]
				else 0.40
			)
			pose_blend = maxf(pose_blend, minimum_transition_blend)
		hero_sprite.position = previous_position.lerp(target_position, pose_blend)
		hero_sprite.scale = previous_scale.lerp(target_scale, pose_blend)
		hero_sprite.rotation = lerp_angle(previous_rotation, target_rotation, pose_blend)
	else:
		_sprite_pose_initialized = true

	if (
		(
			_visual_state in [VisualState.SKILL, VisualState.SKILL_RECOVERY]
			or previous_visual_state == VisualState.SKILL_RECOVERY
		)
		and previous_texture != null
		and previous_texture != _current_texture
	):
		_start_skill_pose_echo(
			previous_texture,
			previous_position,
			previous_scale,
			previous_rotation,
			previous_flip_h
		)

	var visual_modulate := Color.WHITE
	if _is_dead:
		visual_modulate = Color(0.56, 0.64, 0.72, 0.72)
	elif _hurt_remaining > 0.0:
		visual_modulate = (
			Color(1.0, 0.76, 0.76, 1.0)
			if _reduced_effects_enabled
			else Color(1.0, 0.42, 0.42, 1.0)
		)
	elif _hurt_invulnerability_remaining > 0.0:
		# A hard on/off blink made otherwise smooth movement read as dropped frames.
		# Keep the protection readable with a continuous cool pulse instead.
		var pulse_speed: float = 2.0 if _reduced_effects_enabled else 4.2
		var invulnerability_pulse: float = 0.5 + 0.5 * sin(_visual_time * TAU * pulse_speed)
		var minimum_alpha: float = 0.90 if _reduced_effects_enabled else 0.78
		visual_modulate = Color(
			lerpf(0.82, 1.0, invulnerability_pulse),
			lerpf(0.92, 1.0, invulnerability_pulse),
			1.0,
			lerpf(minimum_alpha, 0.96, invulnerability_pulse)
		)
	hero_sprite.modulate = visual_modulate
	_update_skill_effect()


func _get_pose_smoothing_rate(visual_state: int) -> float:
	match visual_state:
		VisualState.ATTACK, VisualState.ATTACK_RECOVERY, VisualState.SKILL, VisualState.SKILL_RECOVERY, VisualState.DASH, VisualState.DASH_RECOVERY:
			return 36.0
		VisualState.LAND, VisualState.TURN, VisualState.HURT:
			return 32.0
		VisualState.RUN:
			return 25.0
		VisualState.JUMP_RISE, VisualState.JUMP_FALL:
			return 23.0
		_:
			return 18.0


func _reset_sprite_pose() -> void:
	hero_sprite.visible = true
	hero_sprite.region_enabled = false
	hero_sprite.position = Vector2(0.0, -15.0)
	hero_sprite.scale = Vector2(HERO_SCALE, HERO_SCALE)
	hero_sprite.rotation = 0.0
	hero_sprite.flip_h = _get_display_facing() < 0.0


func _set_texture(texture: Texture2D) -> void:
	if texture == _current_texture:
		return
	_current_texture = texture
	hero_sprite.texture = texture


func _run_texture(frame_index: int = -1) -> Texture2D:
	var resolved_index := int(floor(_run_cycle)) if frame_index < 0 else frame_index
	match posmod(resolved_index, 8):
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
	var current_frame := int(floor(_run_cycle))
	_set_texture(_run_texture(current_frame))
	var cycle_phase: float = _run_cycle / RUN_FRAME_COUNT * TAU
	var speed_ratio: float = clampf(_movement_blend, 0.0, 1.0)
	var step_lift: float = absf(sin(cycle_phase)) * 1.05 * speed_ratio
	var contact_weight: float = 0.5 + 0.5 * cos(cycle_phase * 2.0)
	hero_sprite.position.y -= step_lift
	hero_sprite.rotation = -_facing * (
		lerpf(0.003, 0.017, speed_ratio)
		+ sin(cycle_phase) * 0.005 * speed_ratio
	)
	hero_sprite.scale = Vector2(
		HERO_SCALE * (1.0 + contact_weight * 0.006 * speed_ratio),
		HERO_SCALE * (1.0 - contact_weight * 0.005 * speed_ratio)
	)


func _animate_turn() -> void:
	var turn_progress: float = clampf(
		1.0 - _turn_remaining / maxf(TURN_BLEND_DURATION, 0.001),
		0.0,
		1.0
	)
	var braking_weight: float = sin(turn_progress * PI)
	# Frames 0 and 4 are the planted poses used for walk-stop settling, so a
	# reversal keeps the feet grounded while the torso shifts through the turn.
	_set_texture(HERO_RUN_0 if turn_progress < 0.5 else HERO_RUN_4)
	hero_sprite.position += Vector2(
		-_turn_from_facing * braking_weight * 1.4,
		braking_weight * 0.35
	)
	hero_sprite.rotation = -_turn_from_facing * braking_weight * 0.038
	hero_sprite.scale = Vector2(
		HERO_SCALE * (1.0 + braking_weight * 0.012),
		HERO_SCALE * (1.0 - braking_weight * 0.010)
	)


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
	var dash_progress: float = clampf(
		1.0 - _dash_remaining / maxf(dash_duration, 0.001),
		0.0,
		1.0
	)
	if dash_progress < 0.24:
		_set_texture(HERO_RUN_2)
	elif dash_progress < 0.74:
		_set_texture(HERO_RUN_4)
	else:
		_set_texture(HERO_RUN_6)
	var dash_punch: float = sin(dash_progress * PI)
	hero_sprite.position += Vector2(_facing * (4.0 + dash_punch * 3.0), 1.0)
	hero_sprite.rotation = -_facing * lerpf(0.018, 0.034, dash_punch)
	hero_sprite.scale = Vector2(
		HERO_SCALE * (1.10 + dash_punch * 0.08),
		HERO_SCALE * (0.90 - dash_punch * 0.05)
	)


func _animate_dash_recovery() -> void:
	# Rejoin locomotion on a planted pose instead of displaying a single frozen
	# travel frame between the dash and the next run cycle.
	_set_texture(HERO_RUN_0)


func _animate_hurt() -> void:
	_set_texture(HERO_IDLE)
	var hurt_progress: float = clampf(1.0 - _hurt_remaining / 0.18, 0.0, 1.0)
	var recoil_weight: float = 1.0 - smoothstep(0.0, 1.0, hurt_progress)
	hero_sprite.position += Vector2(-_facing * 4.0 * recoil_weight, recoil_weight)
	hero_sprite.rotation = _facing * 0.085 * recoil_weight
	hero_sprite.scale = Vector2(
		HERO_SCALE * (1.0 + 0.05 * recoil_weight),
		HERO_SCALE * (1.0 - 0.04 * recoil_weight)
	)


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
	match _attack_type:
		AttackType.UPWARD:
			_animate_up_attack(attack_progress)
			return
		AttackType.DOWNWARD:
			_animate_down_attack(attack_progress)
			return

	if attack_progress < 0.28:
		var windup_time: float = smoothstep(0.0, 1.0, attack_progress / 0.28)
		_set_texture(HERO_WINDUP)
		hero_sprite.position += Vector2(-_facing * 3.0 * windup_time, windup_time)
		hero_sprite.rotation = -_facing * 0.055 * windup_time
		hero_sprite.scale = Vector2(
			HERO_SCALE * (1.0 - 0.02 * windup_time),
			HERO_SCALE * (1.0 + 0.025 * windup_time)
		)
	elif attack_progress < 0.58:
		var strike_time: float = smoothstep(0.0, 1.0, (attack_progress - 0.28) / 0.30)
		var strike_punch: float = sin(strike_time * PI)
		_set_texture(HERO_SLASH)
		hero_sprite.position += Vector2(_facing * lerpf(-2.0, 6.0, strike_time), 0.5)
		hero_sprite.rotation = _facing * lerpf(-0.035, 0.045, strike_time)
		hero_sprite.scale = Vector2(
			HERO_SCALE * (1.0 + 0.035 * strike_punch),
			HERO_SCALE * (1.0 - 0.025 * strike_punch)
		)
	elif attack_progress < 0.80:
		var followthrough_time: float = smoothstep(0.0, 1.0, (attack_progress - 0.58) / 0.22)
		_set_texture(HERO_SLASH_FOLLOWTHROUGH)
		hero_sprite.position += Vector2(_facing * lerpf(6.0, 4.0, followthrough_time), lerpf(0.5, 1.5, followthrough_time))
		hero_sprite.rotation = _facing * lerpf(0.045, 0.018, followthrough_time)
		hero_sprite.scale = Vector2(
			HERO_SCALE * lerpf(1.025, 1.01, followthrough_time),
			HERO_SCALE * lerpf(0.98, 1.01, followthrough_time)
		)
	else:
		var recovery_time: float = smoothstep(0.0, 1.0, (attack_progress - 0.80) / 0.20)
		_set_texture(HERO_RECOVERY)
		hero_sprite.position += Vector2(_facing * lerpf(5.0, 0.0, recovery_time), 0.0)
		hero_sprite.rotation = _facing * lerpf(0.045, 0.0, recovery_time)
		hero_sprite.scale = Vector2(
			HERO_SCALE * lerpf(1.025, 1.0, recovery_time),
			HERO_SCALE * lerpf(0.98, 1.0, recovery_time)
		)


func _animate_attack_recovery() -> void:
	# Keep a stable recovery pose for a few display frames, then resume running
	# from a known planted-foot pose. This is visual-only and never delays input.
	_set_texture(HERO_RECOVERY)


func _animate_up_attack(attack_progress: float) -> void:
	if attack_progress < 0.30:
		var windup: float = smoothstep(0.0, 1.0, attack_progress / 0.30)
		_set_texture(HERO_SLASH_UP_WINDUP)
		hero_sprite.position += Vector2(-_facing * 2.0 * windup, 2.0 * windup)
		hero_sprite.rotation = -_facing * 0.05 * windup
		hero_sprite.scale = Vector2(HERO_SCALE * 0.98, HERO_SCALE * 1.03)
	elif attack_progress < 0.62:
		var strike: float = smoothstep(0.0, 1.0, (attack_progress - 0.30) / 0.32)
		var impact: float = sin(strike * PI)
		_set_texture(HERO_SLASH_UP)
		hero_sprite.position += Vector2(_facing * lerpf(-1.0, 4.0, strike), -lerpf(0.0, 6.0, strike))
		hero_sprite.rotation = _facing * lerpf(-0.045, 0.035, strike)
		hero_sprite.scale = Vector2(HERO_SCALE * (1.0 + impact * 0.045), HERO_SCALE * (1.0 - impact * 0.02))
	elif attack_progress < 0.82:
		var followthrough: float = smoothstep(0.0, 1.0, (attack_progress - 0.62) / 0.20)
		_set_texture(HERO_SLASH_UP_FOLLOWTHROUGH)
		hero_sprite.position += Vector2(_facing * lerpf(4.0, 2.5, followthrough), -lerpf(6.0, 3.0, followthrough))
		hero_sprite.rotation = _facing * lerpf(0.035, 0.012, followthrough)
		hero_sprite.scale = Vector2(HERO_SCALE * lerpf(1.02, 1.0, followthrough), HERO_SCALE * lerpf(0.99, 1.01, followthrough))
	else:
		var recovery: float = smoothstep(0.0, 1.0, (attack_progress - 0.82) / 0.18)
		_set_texture(HERO_RECOVERY)
		hero_sprite.position += Vector2(_facing * lerpf(3.5, 0.0, recovery), -lerpf(2.0, 0.0, recovery))
		hero_sprite.rotation = _facing * lerpf(0.035, 0.0, recovery)


func _animate_down_attack(attack_progress: float) -> void:
	if attack_progress < 0.30:
		var windup: float = smoothstep(0.0, 1.0, attack_progress / 0.30)
		_set_texture(HERO_SLASH_DOWN_WINDUP)
		hero_sprite.position += Vector2(-_facing * 1.5 * windup, -2.5 * windup)
		hero_sprite.rotation = _facing * 0.035 * windup
		hero_sprite.scale = Vector2(HERO_SCALE * 0.985, HERO_SCALE * 1.035)
	elif attack_progress < 0.62:
		var strike: float = smoothstep(0.0, 1.0, (attack_progress - 0.30) / 0.32)
		var impact: float = sin(strike * PI)
		_set_texture(HERO_SLASH_DOWN)
		hero_sprite.position += Vector2(_facing * lerpf(-1.0, 3.0, strike), lerpf(-1.0, 5.0, strike))
		hero_sprite.rotation = _facing * lerpf(0.025, -0.045, strike)
		hero_sprite.scale = Vector2(HERO_SCALE * (1.0 + impact * 0.05), HERO_SCALE * (1.0 - impact * 0.035))
	elif attack_progress < 0.82:
		var followthrough: float = smoothstep(0.0, 1.0, (attack_progress - 0.62) / 0.20)
		_set_texture(HERO_SLASH_DOWN_FOLLOWTHROUGH)
		hero_sprite.position += Vector2(_facing * lerpf(3.0, 2.0, followthrough), lerpf(5.0, 2.0, followthrough))
		hero_sprite.rotation = _facing * lerpf(-0.045, -0.012, followthrough)
		hero_sprite.scale = Vector2(HERO_SCALE * lerpf(1.025, 1.0, followthrough), HERO_SCALE * lerpf(0.985, 1.01, followthrough))
	else:
		var recovery: float = smoothstep(0.0, 1.0, (attack_progress - 0.82) / 0.18)
		_set_texture(HERO_RECOVERY)
		hero_sprite.position += Vector2(_facing * lerpf(3.0, 0.0, recovery), lerpf(2.0, 0.0, recovery))
		hero_sprite.rotation = _facing * lerpf(-0.035, 0.0, recovery)


func _animate_skill() -> void:
	var skill_progress: float = clampf(
		1.0 - _skill_remaining / maxf(_skill_duration, 0.001),
		0.0,
		1.0
	)
	match _weapon_id:
		WeaponCatalog.TWIN_BLADES:
			_animate_twin_blades_skill(skill_progress)
		WeaponCatalog.GREATSWORD:
			_animate_greatsword_skill(skill_progress)
		_:
			_animate_moon_wheel_skill(skill_progress)


func _animate_moon_wheel_skill(skill_progress: float) -> void:
	# DNF-inspired cadence: one-handed rising slash draws the moon, a brief turn
	# darkens it, then a committed downward cut shatters it at the hit frame.
	# Every pose still comes from the canonical hero set, so the body never swaps.
	if skill_progress < 0.15:
		var anticipation := smoothstep(0.0, 1.0, skill_progress / 0.15)
		_set_texture(HERO_WINDUP)
		hero_sprite.position += Vector2(
			-_facing * 4.0 * anticipation,
			1.5 * anticipation
		)
		hero_sprite.rotation = -_facing * 0.07 * anticipation
		hero_sprite.scale = Vector2(
			HERO_SCALE * lerpf(1.0, 0.975, anticipation),
			HERO_SCALE * lerpf(1.0, 1.035, anticipation)
		)
	elif skill_progress < 0.30:
		var coil := smoothstep(0.0, 1.0, (skill_progress - 0.15) / 0.15)
		_set_texture(HERO_SLASH_UP_WINDUP)
		hero_sprite.position += Vector2(
			_facing * lerpf(-4.0, -2.0, coil),
			lerpf(1.5, 2.5, coil)
		)
		hero_sprite.rotation = -_facing * lerpf(0.07, 0.035, coil)
		hero_sprite.scale = Vector2(HERO_SCALE * 0.975, HERO_SCALE * 1.035)
	elif skill_progress < 0.47:
		var rising_cut := smoothstep(0.0, 1.0, (skill_progress - 0.30) / 0.17)
		var rising_impact := sin(rising_cut * PI)
		_set_texture(HERO_SLASH_UP)
		hero_sprite.position += Vector2(
			_facing * lerpf(-2.0, 4.0, rising_cut),
			lerpf(2.5, -5.5, rising_cut)
		)
		hero_sprite.rotation = _facing * lerpf(-0.035, 0.04, rising_cut)
		hero_sprite.scale = Vector2(
			HERO_SCALE * (0.98 + rising_impact * 0.06),
			HERO_SCALE * (1.03 - rising_impact * 0.05)
		)
	elif skill_progress < 0.55:
		var moon_followthrough := smoothstep(
			0.0,
			1.0,
			(skill_progress - 0.47) / 0.08
		)
		_set_texture(HERO_SLASH_UP_FOLLOWTHROUGH)
		hero_sprite.position += Vector2(
			_facing * lerpf(4.0, 3.0, moon_followthrough),
			lerpf(-5.5, -4.2, moon_followthrough)
		)
		hero_sprite.rotation = _facing * lerpf(0.04, 0.018, moon_followthrough)
		hero_sprite.scale = Vector2(
			HERO_SCALE * lerpf(1.015, 1.0, moon_followthrough),
			HERO_SCALE * lerpf(0.985, 1.01, moon_followthrough)
		)
	elif skill_progress < 0.64:
		var dark_moon_turn := smoothstep(0.0, 1.0, (skill_progress - 0.55) / 0.09)
		_set_texture(HERO_SLASH_DOWN_WINDUP)
		hero_sprite.position += Vector2(
			_facing * lerpf(3.0, -1.0, dark_moon_turn),
			lerpf(-4.2, -3.0, dark_moon_turn)
		)
		hero_sprite.rotation = _facing * lerpf(0.018, 0.025, dark_moon_turn)
		hero_sprite.scale = Vector2(
			HERO_SCALE * lerpf(1.0, 0.985, dark_moon_turn),
			HERO_SCALE * lerpf(1.0, 1.035, dark_moon_turn)
		)
	elif skill_progress < 0.76:
		var shatter_cut := smoothstep(0.0, 1.0, (skill_progress - 0.64) / 0.12)
		var shatter_impact := sin(shatter_cut * PI)
		_set_texture(HERO_SLASH_DOWN)
		hero_sprite.position += Vector2(
			_facing * lerpf(-1.0, 5.0, shatter_cut),
			lerpf(-3.0, 4.0, shatter_cut)
		)
		hero_sprite.rotation = _facing * lerpf(0.025, -0.05, shatter_cut)
		hero_sprite.scale = Vector2(
			HERO_SCALE * (0.985 + shatter_impact * 0.075),
			HERO_SCALE * (1.035 - shatter_impact * 0.065)
		)
	elif skill_progress < 0.88:
		var followthrough := smoothstep(0.0, 1.0, (skill_progress - 0.76) / 0.12)
		_set_texture(HERO_SLASH_DOWN_FOLLOWTHROUGH)
		hero_sprite.position += Vector2(
			_facing * lerpf(5.0, 3.0, followthrough),
			lerpf(4.0, 2.0, followthrough)
		)
		hero_sprite.rotation = _facing * lerpf(-0.05, -0.016, followthrough)
		hero_sprite.scale = Vector2(
			HERO_SCALE * lerpf(1.02, 1.0, followthrough),
			HERO_SCALE * lerpf(0.98, 1.01, followthrough)
		)
	else:
		var recovery := smoothstep(0.0, 1.0, (skill_progress - 0.88) / 0.12)
		_set_texture(HERO_RECOVERY)
		hero_sprite.position += Vector2(
			_facing * lerpf(3.0, 0.0, recovery),
			lerpf(2.0, 0.0, recovery)
		)
		hero_sprite.rotation = _facing * lerpf(-0.016, 0.0, recovery)


func _animate_twin_blades_skill(skill_progress: float) -> void:
	if skill_progress < 0.10:
		var anticipation: float = smoothstep(0.0, 1.0, skill_progress / 0.10)
		_set_texture(HERO_WINDUP)
		hero_sprite.position += Vector2(
			-_facing * 2.5 * anticipation,
			1.0 * anticipation
		)
		hero_sprite.rotation = -_facing * 0.035 * anticipation
	elif skill_progress < 0.30:
		var first_cut: float = smoothstep(
			0.0,
			1.0,
			(skill_progress - 0.10) / 0.20
		)
		var first_impact: float = sin(first_cut * PI)
		_set_texture(HERO_SLASH)
		hero_sprite.position += Vector2(
			_facing * lerpf(-2.5, 5.0, first_cut),
			lerpf(1.0, -1.0, first_cut)
		)
		hero_sprite.rotation = _facing * lerpf(-0.035, 0.045, first_cut)
		hero_sprite.scale = Vector2(
			HERO_SCALE * (1.0 + first_impact * 0.055),
			HERO_SCALE * (1.0 - first_impact * 0.045)
		)
	elif skill_progress < 0.42:
		var first_follow: float = smoothstep(
			0.0,
			1.0,
			(skill_progress - 0.30) / 0.12
		)
		_set_texture(HERO_SLASH_FOLLOWTHROUGH)
		hero_sprite.position += Vector2(
			_facing * lerpf(5.0, 2.0, first_follow),
			lerpf(-1.0, 1.0, first_follow)
		)
		hero_sprite.rotation = _facing * lerpf(0.045, -0.018, first_follow)
	elif skill_progress < 0.60:
		var second_cut: float = smoothstep(
			0.0,
			1.0,
			(skill_progress - 0.42) / 0.18
		)
		var second_impact: float = sin(second_cut * PI)
		_set_texture(HERO_SLASH_UP)
		hero_sprite.position += Vector2(
			_facing * lerpf(-1.0, 6.0, second_cut),
			lerpf(2.0, -3.5, second_cut)
		)
		hero_sprite.rotation = _facing * lerpf(-0.03, 0.052, second_cut)
		hero_sprite.scale = Vector2(
			HERO_SCALE * (1.0 + second_impact * 0.06),
			HERO_SCALE * (1.0 - second_impact * 0.05)
		)
	elif skill_progress < 0.72:
		var second_follow: float = smoothstep(
			0.0,
			1.0,
			(skill_progress - 0.60) / 0.12
		)
		_set_texture(HERO_SLASH_UP_FOLLOWTHROUGH)
		hero_sprite.position += Vector2(
			_facing * lerpf(6.0, 2.0, second_follow),
			lerpf(-3.5, -1.0, second_follow)
		)
		hero_sprite.rotation = _facing * lerpf(0.052, 0.012, second_follow)
	elif skill_progress < 0.86:
		var third_cut: float = smoothstep(
			0.0,
			1.0,
			(skill_progress - 0.72) / 0.14
		)
		var third_impact: float = sin(third_cut * PI)
		_set_texture(HERO_SLASH_DOWN)
		hero_sprite.position += Vector2(
			_facing * lerpf(-1.0, 7.0, third_cut),
			lerpf(-2.0, 3.5, third_cut)
		)
		hero_sprite.rotation = _facing * lerpf(0.03, -0.065, third_cut)
		hero_sprite.scale = Vector2(
			HERO_SCALE * (1.0 + third_impact * 0.07),
			HERO_SCALE * (1.0 - third_impact * 0.055)
		)
	elif skill_progress < 0.94:
		var final_follow: float = smoothstep(
			0.0,
			1.0,
			(skill_progress - 0.86) / 0.08
		)
		_set_texture(HERO_SLASH_DOWN_FOLLOWTHROUGH)
		hero_sprite.position += Vector2(
			_facing * lerpf(7.0, 3.0, final_follow),
			lerpf(3.5, 2.0, final_follow)
		)
		hero_sprite.rotation = _facing * lerpf(-0.065, -0.018, final_follow)
	else:
		var recovery: float = smoothstep(
			0.0,
			1.0,
			(skill_progress - 0.94) / 0.06
		)
		_set_texture(HERO_RECOVERY)
		hero_sprite.position += Vector2(
			_facing * lerpf(3.0, 0.0, recovery),
			lerpf(2.0, 0.0, recovery)
		)
		hero_sprite.rotation = _facing * lerpf(-0.018, 0.0, recovery)


func _animate_greatsword_skill(skill_progress: float) -> void:
	if skill_progress < 0.18:
		var brace: float = smoothstep(0.0, 1.0, skill_progress / 0.18)
		_set_texture(HERO_WINDUP)
		hero_sprite.position += Vector2(
			-_facing * 4.0 * brace,
			2.0 * brace
		)
		hero_sprite.rotation = -_facing * 0.08 * brace
		hero_sprite.scale = Vector2(
			HERO_SCALE * lerpf(1.0, 0.96, brace),
			HERO_SCALE * lerpf(1.0, 1.05, brace)
		)
	elif skill_progress < 0.44:
		var raise_blade: float = smoothstep(
			0.0,
			1.0,
			(skill_progress - 0.18) / 0.26
		)
		_set_texture(HERO_SLASH_UP_WINDUP)
		hero_sprite.position += Vector2(
			_facing * lerpf(-4.0, -1.0, raise_blade),
			lerpf(2.0, -4.0, raise_blade)
		)
		hero_sprite.rotation = _facing * lerpf(-0.08, 0.04, raise_blade)
		hero_sprite.scale = Vector2(HERO_SCALE * 0.96, HERO_SCALE * 1.05)
	elif skill_progress < 0.60:
		var overhead_hold: float = smoothstep(
			0.0,
			1.0,
			(skill_progress - 0.44) / 0.16
		)
		_set_texture(HERO_SLASH_DOWN_WINDUP)
		hero_sprite.position += Vector2(
			_facing * lerpf(-1.0, -2.0, overhead_hold),
			lerpf(-4.0, -3.0, overhead_hold)
		)
		hero_sprite.rotation = _facing * lerpf(0.04, 0.055, overhead_hold)
		hero_sprite.scale = Vector2(
			HERO_SCALE * lerpf(0.96, 0.95, overhead_hold),
			HERO_SCALE * lerpf(1.05, 1.065, overhead_hold)
		)
	elif skill_progress < 0.74:
		var ground_cut: float = smoothstep(
			0.0,
			1.0,
			(skill_progress - 0.60) / 0.14
		)
		var heavy_impact: float = sin(ground_cut * PI)
		_set_texture(HERO_SLASH_DOWN)
		hero_sprite.position += Vector2(
			_facing * lerpf(-2.0, 6.0, ground_cut),
			lerpf(-3.0, 5.0, ground_cut)
		)
		hero_sprite.rotation = _facing * lerpf(0.055, -0.072, ground_cut)
		hero_sprite.scale = Vector2(
			HERO_SCALE * (0.95 + heavy_impact * 0.12),
			HERO_SCALE * (1.065 - heavy_impact * 0.10)
		)
	elif skill_progress < 0.88:
		var followthrough: float = smoothstep(
			0.0,
			1.0,
			(skill_progress - 0.74) / 0.14
		)
		_set_texture(HERO_SLASH_DOWN_FOLLOWTHROUGH)
		hero_sprite.position += Vector2(
			_facing * lerpf(6.0, 3.0, followthrough),
			lerpf(5.0, 2.0, followthrough)
		)
		hero_sprite.rotation = _facing * lerpf(-0.072, -0.018, followthrough)
		hero_sprite.scale = Vector2(
			HERO_SCALE * lerpf(1.03, 1.0, followthrough),
			HERO_SCALE * lerpf(0.98, 1.01, followthrough)
		)
	else:
		var recovery: float = smoothstep(
			0.0,
			1.0,
			(skill_progress - 0.88) / 0.12
		)
		_set_texture(HERO_RECOVERY)
		hero_sprite.position += Vector2(
			_facing * lerpf(3.0, 0.0, recovery),
			lerpf(2.0, 0.0, recovery)
		)
		hero_sprite.rotation = _facing * lerpf(-0.018, 0.0, recovery)


func _animate_skill_recovery() -> void:
	# Hold the planted recovery anchor for a few frames. Even sub-pixel rebound
	# reads as a one-pixel shake with nearest-filtered character art.
	_set_texture(HERO_RECOVERY)


func _start_skill_pose_echo(
	texture: Texture2D,
	pose_position: Vector2,
	pose_scale: Vector2,
	pose_rotation: float,
	pose_flip_h: bool
) -> void:
	if _reduced_effects_enabled:
		return
	skill_pose_echo.texture = texture
	skill_pose_echo.region_enabled = false
	skill_pose_echo.position = pose_position
	skill_pose_echo.scale = pose_scale
	skill_pose_echo.rotation = pose_rotation
	skill_pose_echo.flip_h = pose_flip_h
	skill_pose_echo.modulate = Color(
		_weapon_accent.r,
		_weapon_accent.g,
		_weapon_accent.b,
		0.14
	)
	skill_pose_echo.visible = true
	_skill_pose_echo_origin = pose_position
	_skill_pose_echo_remaining = SKILL_POSE_ECHO_DURATION


func _update_skill_pose_echo(delta: float) -> void:
	if _skill_pose_echo_remaining <= 0.0:
		skill_pose_echo.visible = false
		return
	_skill_pose_echo_remaining = maxf(0.0, _skill_pose_echo_remaining - delta)
	var echo_progress: float = clampf(
		1.0 - _skill_pose_echo_remaining / SKILL_POSE_ECHO_DURATION,
		0.0,
		1.0
	)
	var echo_alpha: float = 0.14 * pow(1.0 - echo_progress, 1.7)
	skill_pose_echo.position = _skill_pose_echo_origin + Vector2(
		-_facing * echo_progress * 2.0,
		-echo_progress * 0.6
	)
	skill_pose_echo.modulate = Color(
		_weapon_accent.r,
		_weapon_accent.g,
		_weapon_accent.b,
		echo_alpha
	)
	if _skill_pose_echo_remaining <= 0.0:
		skill_pose_echo.visible = false


func _update_skill_effect() -> void:
	var active: bool = _skill_remaining > 0.0 and not _is_dead
	var progress: float = 0.0
	if active:
		progress = clampf(
			1.0 - _skill_remaining / maxf(_skill_duration, 0.001),
			0.0,
			1.0
		)
	var moon_wheel_active: bool = active and _weapon_id == WeaponCatalog.SWORD
	skill_effect.set_skill_state(
		moon_wheel_active,
		progress,
		_facing,
		get_skill_hit_radii(),
		_weapon_accent
	)
	weapon_skill_effect.set_skill_state(
		active,
		progress,
		_facing,
		_weapon_id,
		_skill_reach,
		_weapon_accent
	)


func _draw() -> void:
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
