extends CharacterBody2D

class_name RogueEnemy

signal defeated

const GRAVITY := 1800.0
const PATROL_SPEED := 72.0
const CHASE_SPEED := 145.0
const ACCELERATION := 900.0
const DETECTION_RANGE_X := 270.0
const DETECTION_RANGE_Y := 110.0
const ATTACK_REACH_X := 105.0
const ATTACK_REACH_Y := 58.0
const ATTACK_DURATION := 0.38
const ATTACK_HIT_DELAY := 0.14
const ATTACK_COOLDOWN := 0.92

var _variant := 0
var _phase := 0.0
var _elapsed := 0.0
var _patrol_left := 0.0
var _patrol_right := 0.0
var _patrol_direction := 1.0
var _facing := 1.0
var _target: Node2D
var _attack_remaining := 0.0
var _attack_cooldown_remaining := 0.0
var _attack_hit_landed := false
var _is_defeated := false


func _ready() -> void:
	collision_layer = 4
	collision_mask = 1

	var collision := CollisionShape2D.new()
	var shape := CapsuleShape2D.new()
	shape.radius = 16.0
	shape.height = 42.0
	collision.shape = shape
	add_child(collision)
	queue_redraw()


func setup(variant: int, phase: float, patrol_left: float, patrol_right: float) -> void:
	_variant = variant % 3
	_phase = phase
	_patrol_left = patrol_left
	_patrol_right = patrol_right
	_patrol_direction = -1.0 if sin(phase) < 0.0 else 1.0
	_facing = _patrol_direction
	queue_redraw()


func set_target(target: Node2D) -> void:
	_target = target


func is_hit_by_attack(attack_origin: Vector2, facing: float) -> bool:
	if _is_defeated:
		return false

	var offset: Vector2 = global_position - attack_origin
	if offset.x * facing < -18.0:
		return false

	return absf(offset.x) <= ATTACK_REACH_X and absf(offset.y) <= ATTACK_REACH_Y


func defeat() -> void:
	if _is_defeated:
		return

	_is_defeated = true
	defeated.emit()
	queue_free()


func _physics_process(delta: float) -> void:
	_elapsed += delta
	_attack_cooldown_remaining = maxf(0.0, _attack_cooldown_remaining - delta)

	var desired_speed := 0.0
	if _attack_remaining > 0.0:
		_attack_remaining = maxf(0.0, _attack_remaining - delta)
		if not _attack_hit_landed and _attack_remaining <= ATTACK_DURATION - ATTACK_HIT_DELAY:
			_attack_hit_landed = true
			_hit_target_if_still_close()
	else:
		if _target_in_attack_range() and _attack_cooldown_remaining <= 0.0:
			_start_attack()
		else:
			desired_speed = _get_desired_speed()

	velocity.x = move_toward(velocity.x, desired_speed, ACCELERATION * delta)
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	else:
		velocity.y = 0.0

	move_and_slide()
	queue_redraw()


func _get_desired_speed() -> float:
	if _target_is_visible():
		var target_delta := _target.global_position.x - global_position.x
		if absf(target_delta) > ATTACK_REACH_X:
			_facing = sign(target_delta)
			return _facing * CHASE_SPEED
		return 0.0

	if global_position.x <= _patrol_left:
		_patrol_direction = 1.0
	elif global_position.x >= _patrol_right:
		_patrol_direction = -1.0

	_facing = _patrol_direction
	return _patrol_direction * PATROL_SPEED


func _target_is_visible() -> bool:
	if not is_instance_valid(_target):
		return false

	var offset: Vector2 = _target.global_position - global_position
	return absf(offset.x) <= DETECTION_RANGE_X and absf(offset.y) <= DETECTION_RANGE_Y


func _target_in_attack_range() -> bool:
	if not _target_is_visible():
		return false

	var offset: Vector2 = _target.global_position - global_position
	if absf(offset.x) > ATTACK_REACH_X or absf(offset.y) > ATTACK_REACH_Y:
		return false

	if not is_zero_approx(offset.x):
		_facing = sign(offset.x)
	return true


func _start_attack() -> void:
	_attack_remaining = ATTACK_DURATION
	_attack_cooldown_remaining = ATTACK_COOLDOWN
	_attack_hit_landed = false


func _hit_target_if_still_close() -> void:
	if not _target_in_attack_range():
		return

	if _target.has_method(&"receive_enemy_attack"):
		_target.call(&"receive_enemy_attack", global_position)


func _draw() -> void:
	var motion_blend := clampf(absf(velocity.x) / CHASE_SPEED, 0.0, 1.0)
	var gait_time := _elapsed * (2.4 + 7.0 * motion_blend) + _phase
	var bob: float = sin(gait_time) * (0.7 + 1.4 * motion_blend)
	var attack_progress := 0.0
	if _attack_remaining > 0.0:
		attack_progress = 1.0 - _attack_remaining / ATTACK_DURATION
	var lunge := sin(attack_progress * PI) * _facing * 9.0
	var center := Vector2(lunge, -4.0 + bob)

	draw_circle(Vector2(0.0, 21.0), 20.0, Color(0.02, 0.05, 0.08, 0.42))
	match _variant:
		0:
			_draw_slime(center)
		1:
			_draw_bat(center)
		_:
			_draw_stalker(center)

	if _attack_remaining > 0.0:
		var start_angle := -1.2 if _facing > 0.0 else PI - 0.4
		var end_angle := 0.4 if _facing > 0.0 else PI + 1.2
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


func _draw_stalker(center: Vector2) -> void:
	draw_rect(Rect2(center + Vector2(-17.0, -17.0), Vector2(34.0, 32.0)), Color("#10242d"))
	draw_rect(Rect2(center + Vector2(-13.0, -14.0), Vector2(26.0, 25.0)), Color("#3e998d"))
	draw_line(center + Vector2(-11.0, 13.0), center + Vector2(-14.0, 24.0), Color("#10242d"), 4.0)
	draw_line(center + Vector2(11.0, 13.0), center + Vector2(14.0, 24.0), Color("#10242d"), 4.0)
	draw_circle(center + Vector2(-6.0, -4.0), 3.2, Color("#d9ff8a"))
	draw_circle(center + Vector2(6.0, -4.0), 3.2, Color("#d9ff8a"))
