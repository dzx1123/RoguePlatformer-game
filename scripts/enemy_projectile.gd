extends Area2D

signal removed(projectile: Area2D)

const LIFETIME := 3.0

var _velocity: Vector2 = Vector2.ZERO
var _damage: int = 1
var _target: Node2D
var _remaining_lifetime: float = LIFETIME
var _is_removing: bool = false
var _style: int = RogueEnemy.ProjectileStyle.CRYSTAL_ORB


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


func setup(
	projectile_velocity: Vector2,
	damage: int,
	target: Node2D,
	projectile_style: int = RogueEnemy.ProjectileStyle.CRYSTAL_ORB
) -> void:
	_velocity = projectile_velocity
	_damage = maxi(1, damage)
	_target = target
	_style = clampi(
		projectile_style,
		RogueEnemy.ProjectileStyle.CRYSTAL_ORB,
		RogueEnemy.ProjectileStyle.ARROW
	)
	queue_redraw()


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
	if _style == RogueEnemy.ProjectileStyle.ARROW:
		_draw_arrow()
		return
	var trail_direction: Vector2 = -_velocity.normalized()
	if trail_direction.is_zero_approx():
		trail_direction = Vector2.LEFT
	draw_line(
		trail_direction * 5.0,
		trail_direction * 20.0,
		Color(0.96, 0.12, 0.28, 0.42),
		6.0,
		true
	)
	draw_circle(Vector2.ZERO, 9.0, Color(0.62, 0.02, 0.12, 0.82))
	draw_circle(Vector2.ZERO, 6.0, Color(0.16, 0.84, 0.96, 0.96))
	draw_arc(Vector2.ZERO, 8.0, 0.0, TAU, 18, Color(1.0, 0.22, 0.34, 0.94), 2.0)
	draw_circle(Vector2(-2.0, -2.0), 2.0, Color.WHITE)


func _draw_arrow() -> void:
	var direction := _velocity.normalized()
	if direction.is_zero_approx():
		direction = Vector2.LEFT
	var normal := direction.orthogonal()
	var tip := direction * 15.0
	var tail := -direction * 16.0
	draw_line(tail, tip - direction * 4.0, Color("#8c5528"), 3.0, false)
	draw_line(tail + direction * 2.0, tip - direction * 5.0, Color("#d49a45"), 1.0, false)
	draw_colored_polygon(
		PackedVector2Array([
			tip,
			tip - direction * 8.0 + normal * 4.0,
			tip - direction * 6.0,
			tip - direction * 8.0 - normal * 4.0,
		]),
		Color("#d5e9ec")
	)
	draw_line(tail, tail + direction * 7.0 + normal * 5.0, Color("#5fd6e8"), 2.0, false)
	draw_line(tail, tail + direction * 7.0 - normal * 5.0, Color("#5fd6e8"), 2.0, false)
