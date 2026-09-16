extends SceneTree

func _initialize() -> void:
	call_deferred("run_test")

func run_test() -> void:
	var scene = load("res://scenes/Chapter2ForgePrototype.tscn").instantiate()
	root.add_child(scene)
	scene.set_physics_process(false)
	scene.player.set_physics_process(false)
	assert(not scene.try_exit(), "Spawn must not activate exit")
	scene.player.position = scene.EXIT_POSITION
	assert(not scene.try_exit(), "Living caster must lock exit")
	scene.caster.receive_player_attack(scene.caster.position, 1.0, 9999)
	assert(scene.caster.get_current_health() == 0)
	scene.caster._physics_process(2.0)
	await process_frame
	assert(not scene.try_exit(), "Beetle must lock hall exit")
	scene.beetle.receive_player_attack(scene.beetle.position, 1.0, 9999)
	scene.beetle._physics_process(2.0)
	await process_frame
	assert(scene.try_exit() and scene.ritual_open, "Exit must open ritual")
	assert(scene.choose_ritual(true) and scene.room_index == 1, "Choice must load bridge")
	assert(not scene.choose_ritual(false), "Cannot claim second reward")
	scene.cycle = 2.9
	assert(not scene.heat_is_active(), "Cooling must disable heat")
	scene.cycle = 0.0
	assert(scene.terrain.get_child_count() == scene.BRIDGE_PLATFORMS.size(), "Bridge colliders mismatch")
	assert(scene.cycle == 0.0 and not scene.heat_is_active(), "New room must start safe")
	scene.player.position = scene.EXIT_POSITION
	scene.paused = true
	assert(not scene.try_exit(), "Paused exit must be ignored")
	scene.paused = false
	scene.caster.receive_player_weapon_skill(scene.caster.position, 1.0, 9999, 3.0, WeaponCatalog.SWORD, 0, 1)
	assert(scene.caster.get_current_health() == 0, "Skill must kill caster")
	scene.caster._physics_process(2.0)
	await process_frame
	assert(not scene.try_exit(), "Guard must also lock bridge exit")
	scene.guard.receive_player_attack(scene.guard.position, 1.0, 9999)
	scene.guard._physics_process(2.0)
	await process_frame
	assert(scene.try_exit() and scene.route_complete, "Second exit must complete prototype")
	scene._load_layout(0)
	assert(not scene.route_complete, "Replay must clear completion")
	assert(not scene.heat_disabled, "Replay must reset cooling")
	scene.player.apply_event_cost(40)
	var before: int = scene.player.get_current_health()
	scene.ritual_open = true
	assert(scene.choose_ritual(false), "Healing choice failed")
	assert(scene.player.get_current_health() == before + 25, "Health must carry across rooms without full heal")
	scene.cycle = 2.9
	assert(scene.heat_is_active(), "Healing must leave heat enabled")
	scene.queue_free()
	await process_frame
	print("chapter2_route_smoke: PASS")
	quit()
