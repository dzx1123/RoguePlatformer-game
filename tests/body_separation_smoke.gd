extends SceneTree

class Target extends Node2D:
	var enabled := true
	func allows_body_separation() -> bool:
		return enabled

func _initialize() -> void:
	call_deferred("run_test")

func run_test() -> void:
	var floor_body := StaticBody2D.new()
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(1000, 100)
	collision.shape = shape
	floor_body.position = Vector2(500, 650)
	floor_body.add_child(collision)
	root.add_child(floor_body)
	var enemy := RogueEnemy.new()
	enemy.position = Vector2(500, 575)
	root.add_child(enemy)
	for i in range(15):
		await physics_frame
	enemy.set_physics_process(false)
	var target := Target.new()
	root.add_child(target)
	target.position = enemy.position + Vector2(-10, -6)
	enemy.set_target(target)
	var start := enemy.position
	enemy._apply_horizontal_body_separation(1.0 / 60.0)
	if enemy.position.x <= start.x or absf(enemy.position.y - start.y) > 0.01:
		push_error("Horizontal separation must move enemy sideways only")
		quit(1)
		return
	target.enabled = false
	start = enemy.position
	enemy._apply_horizontal_body_separation(1.0 / 60.0)
	if enemy.position != start:
		push_error("Dash/hurt opt-out ignored")
		quit(1)
		return
	target.enabled = true
	target.position.y -= 60
	enemy._apply_horizontal_body_separation(1.0 / 60.0)
	if enemy.position != start:
		push_error("Vertical overlap incorrectly separated")
		quit(1)
		return
	print("body_separation_smoke: PASS")
	floor_body.queue_free()
	enemy.queue_free()
	target.queue_free()
	await process_frame
	quit()
