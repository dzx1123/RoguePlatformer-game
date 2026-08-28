extends CharacterBody2D

class_name RoguePlayer

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

var _air_jumps_used := 0
var _facing := 1.0
var _dash_remaining := 0.0
var _dash_available := true
var _attack_remaining := 0.0
var _attack_cooldown_remaining := 0.0
var _spawn_point := Vector2.ZERO


func _ready() -> void:
	_spawn_point = global_position
	queue_redraw()


func _physics_process(delta: float) -> void:
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

	queue_redraw()


func respawn() -> void:
	global_position = _spawn_point
	velocity = Vector2.ZERO
	_dash_remaining = 0.0
	_dash_available = true
	_air_jumps_used = 0
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


func _update_timers(delta: float) -> void:
	_dash_remaining = maxf(0.0, _dash_remaining - delta)
	_attack_remaining = maxf(0.0, _attack_remaining - delta)
	_attack_cooldown_remaining = maxf(0.0, _attack_cooldown_remaining - delta)


func _draw() -> void:
	var outline := Color("#081019")
	var armor := Color("#7bd7d3")
	var cloak := Color("#416d9b")
	var glow := Color("#f9d770")

	# Placeholder art deliberately uses primitive shapes so the prototype has
	# no copied or third-party visual assets.
	draw_circle(Vector2(0, -10), 22.0, outline)
	draw_circle(Vector2(0, -10), 18.0, armor)
	draw_rect(Rect2(-16, -28, 32, 26), cloak)
	draw_rect(Rect2(-12, -24, 24, 20), armor)
	draw_circle(Vector2(_facing * 8.0, -12), 3.0, glow)
	draw_line(Vector2(-12, 18), Vector2(-12, 29), outline, 5.0)
	draw_line(Vector2(12, 18), Vector2(12, 29), outline, 5.0)

	if _dash_remaining > 0.0:
		draw_line(Vector2(-_facing * 42.0, -6), Vector2(-_facing * 12.0, -6), Color(0.56, 0.94, 1.0, 0.7), 6.0)

	if _attack_remaining > 0.0:
		var center := Vector2(_facing * 14.0, -8.0)
		var start_angle := -1.25 if _facing > 0.0 else PI - 1.25
		var end_angle := 1.05 if _facing > 0.0 else PI + 1.05
		draw_arc(center, 46.0, start_angle, end_angle, 14, glow, 5.0, true)
		draw_line(center, center + Vector2(_facing * 46.0, -4.0), Color("#fff7c0"), 3.0)
