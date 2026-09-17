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
	var scene = load("res://scenes/Chapter2FullSlice.tscn").instantiate()
	root.add_child(scene)
	scene.set_physics_process(false)
	scene._load_layout(19)
	scene.player.set_physics_process(false)
	var boss = scene.overseer
	boss.set_physics_process(false)
	var target := Target.new()
	scene.add_child(target)
	boss.set_target(target)
	target.position = Vector2(100, 590)
	await physics_frame
	boss._physics_process(1)
	assert(not boss.engaged and scene.embers.get_child_count() == 0, "Safe entrance")
	boss.engaged = true
	target.position = Vector2(800, 590)
	boss._begin_attack(0)
	var locked: Rect2 = boss.hammer_rect
	boss._physics_process(0.5)
	assert(target.hits == 0 and boss.state == boss.State.HAMMER_WARNING)
	target.position = Vector2(300, 590)
	boss._physics_process(0.41)
	assert(boss.hammer_rect == locked and target.hits == 0, "Hammer must lock and remain dodgeable")
	boss._physics_process(0.16)
	assert(boss.state == boss.State.RECOVER and boss.remaining >= 1.1)
	target.position = Vector2(800, 590)
	boss._begin_attack(0)
	target.position = boss.hammer_rect.get_center()
	boss._physics_process(0.91)
	assert(target.hits == 1)
	boss._physics_process(0.01)
	assert(target.hits == 1, "Hammer hits once")
	boss.position = Vector2(870, 590)
	target.position = Vector2(700, 590)
	boss._begin_attack(2)
	var facing: float = boss.locked_facing
	target.position = Vector2(1000, 590)
	boss._physics_process(0.79)
	assert(target.hits == 1 and boss.locked_facing == facing)
	boss._physics_process(0.02)
	assert(boss.state == boss.State.CHARGE)
	target.position = boss.position + Vector2(-5, 0)
	boss._physics_process(0.01)
	assert(target.hits == 2)
	boss._physics_process(0.01)
	assert(target.hits == 2)
	boss.position.x = boss.LEFT
	boss._physics_process(0.01)
	assert(boss.state == boss.State.RECOVER and boss.position.x >= boss.LEFT)
	boss._begin_attack(1)
	assert(scene.embers.get_child_count() == 1)
	boss._physics_process(0.46)
	assert(scene.embers.get_child_count() == 2)
	boss._current_health = 260
	boss._physics_process(0.01)
	assert(boss.state == boss.State.SHIFT and scene.embers.get_child_count() == 0)
	assert(not scene.overheat and boss.phase == 2)
	boss._physics_process(1.21)
	assert(scene.overheat and scene.cycle == 0 and boss.state == boss.State.RECOVER)
	scene.elapsed = 2.5
	scene._physics_process(0.01)
	assert(scene.heat_zones.size() == 1 and scene.heat_zones[0].position.x == 290)
	scene.elapsed = 5.5
	scene._physics_process(0.01)
	assert(scene.heat_zones.size() == 1 and scene.heat_zones[0].position.x == 860)
	# Scene pause must freeze boss as well as projectiles and heat.
	var key := InputEventKey.new()
	key.pressed = true
	key.keycode = KEY_P
	scene._unhandled_key_input(key)
	assert(scene.paused and not boss.is_physics_processing())
	var before: float = scene.elapsed
	scene._physics_process(10)
	assert(scene.elapsed == before)
	scene._unhandled_key_input(key)
	boss.set_physics_process(false)
	boss._begin_attack(1)
	assert(scene.embers.get_child_count() == 1)
	boss.receive_player_attack(boss.position, 1, 9999)
	assert(boss.get_current_health() == 0 and scene.embers.get_child_count() == 0 and not scene.overheat)
	boss._physics_process(2)
	await process_frame
	assert(scene.living_enemies().is_empty())
	scene.queue_free()
	await process_frame
	print("forge_overseer_smoke: PASS")
	quit()
