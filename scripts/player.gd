extends CharacterBody2D

class_name RoguePlayer

signal attack_started(origin: Vector2, facing: float)

const HERO_IDLE: Texture2D = preload("res://assets/characters/frames/hero_idle.png")
const HERO_WALK: Texture2D = preload("res://assets/characters/frames/hero_walk_3.png")
const HERO_WINDUP: Texture2D = preload("res://assets/characters/frames/hero_windup.png")
const HERO_SLASH: Texture2D = preload("res://assets/characters/frames/hero_slash.png")
const HERO_RECOVERY: Texture2D = preload("res://assets/characters/frames/hero_recovery.png")

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
@export var attack_duration := 0.16
@export var attack_cooldown_duration := 0.28

@onready var hero_sprite: Sprite2D = $HeroSprite

var _air_jumps_used := 0
var _facing := 1.0
var _dash_remaining := 0.0
var _dash_available := true
var _attack_remaining := 0.0
var _attack_cooldown_remaining := 0.0
var _spawn_point := Vector2.ZERO
var _visual_time := 0.0
var _movement_blend := 0.0
var _current_sprite_key := ""
var _hurt_remaining := 0.0
var _hurt_invulnerability_remaining := 0.0


func _ready() -> void:
	_spawn_point = global_position
	_update_hero_sprite()
	queue_redraw()


func _physics_process(delta: float) -> void:
	_visual_time += delta

	if Input.is_action_just_pressed(&"restart"):
		respawn()
		return

	var was_on_floor := is_on_floor()
	_update_timers(delta)

	if was_on_floor:
		_air_jumps_used = 0
		_dash_available = true
	elif _dash_remaining <= 0.0:
		velocity.y += gravity * delta

	var input_direction := Input.get_axis(&"move_left", &"move_right")
	if not is_zero_approx(input_direction):
		_facing = sign(input_direction)

	if Input.is_action_just_pressed(&"jump"):
		if was_on_floor:
			_jump()
		elif _air_jumps_used < extra_jumps:
			_air_jumps_used += 1
			_jump()

	if Input.is_action_just_pressed(&"dash") and _dash_available:
		_start_dash()

	if Input.is_action_just_pressed(&"attack") and _attack_cooldown_remaining <= 0.0:
		_start_attack()

	if _dash_remaining > 0.0:
		velocity = Vector2(_facing * dash_speed, 0.0)
	else:
		var target_speed := input_direction * run_speed
		var acceleration := ground_acceleration if was_on_floor else air_acceleration
		velocity.x = move_toward(velocity.x, target_speed, acceleration * delta)

	move_and_slide()

	if global_position.y > 820.0:
		respawn()

	var target_visual_motion := clampf(abs(velocity.x) / run_speed, 0.0, 1.0)
	if _dash_remaining > 0.0:
		target_visual_motion = 1.15
	_movement_blend = move_toward(_movement_blend, target_visual_motion, delta * 9.0)

	_update_hero_sprite()
	queue_redraw()


func respawn() -> void:
	global_position = _spawn_point
	velocity = Vector2.ZERO
	_dash_remaining = 0.0
	_dash_available = true
	_air_jumps_used = 0
	_movement_blend = 0.0
	_update_hero_sprite()
	queue_redraw()


func _jump() -> void:
	velocity.y = jump_velocity


func _start_dash() -> void:
	_dash_available = false
	_dash_remaining = dash_duration
	velocity.y = 0.0


func _start_attack() -> void:
	_attack_remaining = attack_duration
	_attack_cooldown_remaining = attack_cooldown_duration
	attack_started.emit(global_position, _facing)


func receive_enemy_attack(attacker_position: Vector2) -> void:
	if _hurt_invulnerability_remaining > 0.0:
		return

	_hurt_remaining = 0.18
	_hurt_invulnerability_remaining = 0.72
	var knockback_direction: float = signf(global_position.x - attacker_position.x)
	if is_zero_approx(knockback_direction):
		knockback_direction = -_facing
	velocity = Vector2(knockback_direction * 270.0, -220.0)
	_movement_blend = 0.0
	_update_hero_sprite()
	queue_redraw()


func _update_timers(delta: float) -> void:
	_dash_remaining = maxf(0.0, _dash_remaining - delta)
	_attack_remaining = maxf(0.0, _attack_remaining - delta)
	_attack_cooldown_remaining = maxf(0.0, _attack_cooldown_remaining - delta)
	_hurt_remaining = maxf(0.0, _hurt_remaining - delta)
	_hurt_invulnerability_remaining = maxf(0.0, _hurt_invulnerability_remaining - delta)


func _update_hero_sprite() -> void:
	var selected_texture: Texture2D = HERO_IDLE
	var selected_key := "idle"
	var attack_progress := -1.0

	if _attack_remaining > 0.0:
		attack_progress = 1.0 - _attack_remaining / attack_duration
		if attack_progress < 0.25:
			selected_texture = HERO_WINDUP
			selected_key = "windup"
		elif attack_progress < 0.72:
			selected_texture = HERO_SLASH
			selected_key = "slash"
		else:
			selected_texture = HERO_RECOVERY
			selected_key = "recovery"
	elif _movement_blend > 0.12:
		selected_texture = HERO_WALK
		selected_key = "walk"

	if selected_key != _current_sprite_key:
		hero_sprite.texture = selected_texture
		_current_sprite_key = selected_key

	var walk_phase := _visual_time * (3.0 + 9.0 * _movement_blend)
	var bob := absf(sin(walk_phase * 2.0)) * 1.8 * _movement_blend
	hero_sprite.position = Vector2(0.0, -15.0 + bob)
	hero_sprite.flip_h = _facing < 0.0
	hero_sprite.scale = Vector2(0.22, 0.22)
	hero_sprite.rotation = sin(walk_phase) * 0.025 * _movement_blend

	if attack_progress >= 0.0:
		hero_sprite.rotation = lerpf(-0.10, 0.11, attack_progress) * _facing
	if _dash_remaining > 0.0:
		hero_sprite.scale = Vector2(0.25, 0.19)
	hero_sprite.modulate = Color(1.0, 0.65, 0.65, 1.0) if _hurt_remaining > 0.0 else Color.WHITE


func _draw() -> void:
	var walk_phase := _visual_time * (3.0 + 9.0 * _movement_blend)
	var bob := absf(sin(walk_phase * 2.0)) * 1.8 * _movement_blend
	var cape_wave := sin(_visual_time * (4.0 + 4.0 * _movement_blend)) * (2.0 + 5.0 * _movement_blend)
	if _attack_remaining > 0.0:
		cape_wave += 5.0

	# This under-layer gives the pixel cloak a live trailing edge while the
	# actual hero is rendered from the approved sprite texture above it.
	var cape_points := PackedVector2Array([
		_p(-8.0, -34.0 + bob), _p(-24.0, -27.0 + bob),
		_p(-43.0, -6.0 + bob + cape_wave), _p(-35.0, 17.0 + bob + cape_wave * 0.45),
		_p(-13.0, 12.0 + bob), _p(0.0, -9.0 + bob),
	])
	draw_colored_polygon(cape_points, Color(0.05, 0.30, 0.34, 0.75))
	draw_line(
		_p(-23.0, -27.0 + bob),
		_p(-34.0, 15.0 + bob + cape_wave * 0.45),
		Color(0.83, 0.66, 0.26, 0.72),
		2.0
	)

	if _dash_remaining > 0.0:
		draw_line(
			_p(-52.0, -5.0 + bob),
			_p(-14.0, -5.0 + bob),
			Color(0.38, 0.92, 1.0, 0.46),
			7.0
		)
		draw_line(
			_p(-42.0, 8.0 + bob),
			_p(-10.0, 8.0 + bob),
			Color(0.38, 0.92, 1.0, 0.22),
			4.0
		)

	if _attack_remaining > 0.0:
		var sweep_center := _p(10.0, -7.0 + bob)
		var start_angle := -1.85 if _facing > 0.0 else PI - 0.75
		var end_angle := 0.85 if _facing > 0.0 else PI + 1.85
		draw_arc(
			sweep_center,
			58.0,
			start_angle,
			end_angle,
			16,
			Color(0.58, 0.96, 1.0, 0.76),
			4.0,
			true
		)


func _p(x: float, y: float) -> Vector2:
	return Vector2(x * _facing, y)
