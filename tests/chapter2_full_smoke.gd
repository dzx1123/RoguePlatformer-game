extends SceneTree

func _initialize() -> void:
	call_deferred("run_test")

func clear_enemies(scene: Node) -> void:
	for enemy in scene.living_enemies():
		enemy.receive_player_attack(enemy.position, 1, 9999)
		assert(enemy.get_current_health() == 0)
		enemy._physics_process(2)
	await process_frame
	assert(scene.living_enemies().is_empty())

func open_exit(scene: Node) -> void:
	scene.player.position = scene.EXIT_POSITION
	assert(scene.try_exit())
	scene.player.set_physics_process(false)

func run_test() -> void:
	var scene = load("res://scenes/Chapter2FullSlice.tscn").instantiate()
	root.add_child(scene)
	scene.set_physics_process(false)
	assert(scene.rooms.size() == 20 and scene.SLICE.validate(scene.rooms).is_empty())
	for weapon in [WeaponCatalog.SWORD, WeaponCatalog.TWIN_BLADES, WeaponCatalog.GREATSWORD]:
		scene.restart_slice()
		scene.player.configure_weapon(weapon)
		for index in range(20):
			assert(scene.room_index == index)
			scene.player.set_physics_process(false)
			if index == 12:
				open_exit(scene)
				assert(scene.choose_mid_option(0))
			if index == 16:
				scene.player.position = scene.EXIT_POSITION
				assert(not scene.try_exit(), "Branch choice required")
				scene.player.position = scene.BRANCH_SIGN
				assert(scene.try_exit())
				assert(scene.choose_final_option(0))
				assert(scene.living_enemies().size() == 1 and is_instance_valid(scene.guard))
			await clear_enemies(scene)
			while scene._waves_pending():
				scene.player.position = scene.EXIT_POSITION
				scene._physics_process(0.01)
				scene._physics_process(1.21)
				await clear_enemies(scene)
			open_exit(scene)
			if scene.ritual_open:
				match scene.choice_kind:
					&"ritual": assert(scene.choose_ritual(true))
					&"upgrade": assert(scene.choose_upgrade(&"tempered_edge"))
					&"toll", &"rare", &"shop": assert(scene.choose_mid_option(0))
					&"supply": assert(scene.choose_final_option(0))
		assert(scene.route_complete and scene.claimed.has(&"forge_40"))
		var settled_gold: int = scene.gold
		assert(not scene.try_exit() and scene.gold == settled_gold)
		assert(scene._completion_text().contains("第三章待开放"))
	# Both branches pay exactly the same reward; retry keeps the selected encounter.
	for choice in [0, 1]:
		scene.restart_slice()
		scene._load_layout(16)
		scene.player.position = scene.BRANCH_SIGN
		assert(scene.try_exit() and scene.choose_final_option(choice))
		scene.retry_room()
		assert(scene.branch_choices[37] == choice and scene.living_enemies().size() == choice + 1)
		await clear_enemies(scene)
		open_exit(scene)
		assert(scene.gold == 12)
	# Preparation carries real health and cannot be collected twice.
	scene.restart_slice()
	scene._load_layout(18)
	scene.player.set_current_health(25)
	open_exit(scene)
	assert(scene.choose_final_option(0) and scene.player.get_current_health() == 65)
	assert(not scene.choose_final_option(1))
	var boss_id: int = scene.overseer.get_instance_id()
	scene.overseer._current_health = 260
	scene.overseer._physics_process(0.01)
	scene.player._die(Vector2.ZERO, &"test")
	scene._physics_process(1.1)
	assert(scene.overseer.get_instance_id() != boss_id and scene.overseer.phase == 1)
	assert(not scene.overheat and scene.embers.get_child_count() == 0)
	scene._load_layout(18)
	open_exit(scene)
	assert(not scene.ritual_open and scene.room_index == 19, "Preparation reward cannot be repeated")
	scene.queue_free()
	await process_frame
	print("chapter2_full_smoke: PASS")
	quit()
