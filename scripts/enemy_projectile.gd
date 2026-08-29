extends Area2D

signal removed(projectile: Area2D)

const LIFETIME := 3.0

var _velocity: Vector2 = Vector2.ZERO
var _damage: int = 1
var _target: Node2D
var _remaining_lifetime: float = LIFETIME
var _is_removing: bool = false


func _ready() -> void:
	collision_layer = 16
	collision_mask = 3
	monitoring = true
	monitorable = false

	var collision := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 7.0
	collision.shape = shape
	add_child(collision)
	body_entered.connect(_on_body_entered)
	queue_redraw()


func setup(projectile_velocity: Vector2, damage: int, target: Node2D) -> void:
	_velocity = projectile_velocity
	_damage = maxi(1, damage)
	_target = target


func _physics_process(delta: float) -> void:
	if _is_removing:
		return
	_remaining_lifetime = maxf(0.0, _remaining_lifetime - delta)
	global_position += _velocity * delta
	if _remaining_lifetime <= 0.0:
		_remove_projectile()


func _on_body_entered(body: Node2D) -> void:
	if _is_removing:
		return
	if body == _target and body.has_method(&"receive_enemy_attack"):
		body.call(&"receive_enemy_attack", global_position, _damage)
		_remove_projectile()
		return
	if body.collision_layer & 1 != 0:
		_remove_projectile()


func _remove_projectile() -> void:
	if _is_removing:
		return
	_is_removing = true
	removed.emit(self)
	queue_free()


func _draw() -> void:
	var trail_direction: Vector2 = -_velocity.normalized()
	if trail_direction.is_zero_approx():
		trail_direction = Vector2.LEFT
	draw_line(
		trail_direction * 5.0,
		trail_direction * 20.0,
		Color(0.28, 0.78, 1.0, 0.38),
		6.0,
		true
	)
	draw_circle(Vector2.ZERO, 9.0, Color(0.12, 0.38, 0.56, 0.72))
	draw_circle(Vector2.ZERO, 6.0, Color(0.56, 0.94, 1.0, 0.96))
	draw_circle(Vector2(-2.0, -2.0), 2.0, Color.WHITE)
