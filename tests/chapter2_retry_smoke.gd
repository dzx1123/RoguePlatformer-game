extends SceneTree

func _initialize() -> void:
	call_deferred("run_test")

func run_test() -> void:
	var scene = load("res://scenes/Chapter2ForgePrototype.tscn").instantiate()
	root.add_child(scene)
	scene.set_physics_process(false)
	scene._load_layout(1)
	scene.heat_disabled = true
	scene.player.set_physics_process(false)
	scene._spawn_ember()
	var previous_id: int = scene.caster.get_instance_id()
	scene.player._die(Vector2.ZERO, &"test")
	assert(scene.retry_remaining > 0 and not scene.guard.is_physics_processing())
	scene.paused = true
	scene._physics_process(2.0)
	assert(scene.player.is_dead(), "Pause must freeze retry countdown")
	scene.paused = false
	scene._physics_process(1.1)
	assert(not scene.player.is_dead() and scene.room_index == 1)
	assert(scene.heat_disabled, "Cooling choice must survive retry")
	assert(scene.caster.get_instance_id() != previous_id)
	assert(scene.living_enemies().size() == 2)
	assert(scene.embers.get_child_count() == 0 and scene.cycle == 0)
	assert(scene.guard.is_physics_processing())
	scene._load_layout(0)
	assert(not scene.heat_disabled, "New exploration must reset cooling")
	scene.queue_free()
	await process_frame
	print("chapter2_retry_smoke: PASS")
	quit()
