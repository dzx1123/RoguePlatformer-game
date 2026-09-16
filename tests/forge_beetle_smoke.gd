extends SceneTree
class Target extends Node2D:
	var hits := 0
	func is_dead() -> bool:
		return false
	func receive_enemy_attack(_origin: Vector2, _damage: int, _cause: StringName) -> bool:
		hits += 1
		return true

func _initialize() -> void:
	call_deferred("run_test")

func run_test() -> void:
	var enemy = preload("res://scripts/forge_beetle_prototype.gd").new()
	var target := Target.new()
	root.add_child(target)
	root.add_child(enemy)
	enemy.set_physics_process(false)
	enemy.set_target(target)
	enemy.position = Vector2(640, 598)
	target.position = enemy.position
	enemy.state = enemy.State.WARN
	enemy.remaining = 0.45
	enemy._physics_process(0.1)
	assert(target.hits == 0 and enemy.state == enemy.State.WARN)
	enemy._hurt_remaining = 0.18
	enemy._physics_process(0.01)
	assert(enemy.state == enemy.State.REST, "Hit must interrupt warning")
	target.position = enemy.position + Vector2(80, 0)
	enemy._try_burn()
	assert(target.hits == 0, "Outside ring must be safe")
	target.position = enemy.position
	enemy._try_burn()
	enemy._try_burn()
	assert(target.hits == 1, "Burn must not stack within same window")
	enemy._is_defeated = true
	enemy.burn_spent = false
	enemy._try_burn()
	assert(target.hits == 1, "Dead beetle must not burn")
	enemy.queue_free()
	target.queue_free()
	await process_frame
	print("forge_beetle_smoke: PASS")
	quit()
