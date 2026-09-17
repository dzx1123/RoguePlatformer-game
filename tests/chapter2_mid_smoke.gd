extends SceneTree

func _initialize() -> void:
	call_deferred("run_test")

func clear_enemies(scene: Node) -> void:
	for enemy in scene.living_enemies():
		enemy.receive_player_attack(enemy.position, 1.0, 9999)
		assert(enemy.get_current_health() == 0)
		enemy._physics_process(2)
	await process_frame
	assert(scene.living_enemies().is_empty())

func open_exit(scene: Node) -> void:
	scene.player.position = scene.EXIT_POSITION
	assert(scene.try_exit())
	scene.player.set_physics_process(false)

func run_test() -> void:
	var scene = load("res://scenes/Chapter2MidSlice.tscn").instantiate()
	root.add_child(scene)
	scene.set_physics_process(false)
	assert(scene.rooms.size() == 15 and scene.SLICE.validate(scene.rooms).is_empty())
	for weapon in [WeaponCatalog.SWORD, WeaponCatalog.TWIN_BLADES, WeaponCatalog.GREATSWORD]:
		scene.restart_slice()
		scene.player.configure_weapon(weapon)
		for index in range(15):
			assert(scene.room_index == index)
			scene.player.set_physics_process(false)
			var number := 21 + index
			if number == 26:
				assert(is_instance_valid(scene.guard) and scene.guard.lane_left == 580)
			if number == 31:
				assert(is_instance_valid(scene.beetle) and scene.heat_zones.is_empty())
			if number == 33:
				open_exit(scene)
				assert(scene.choose_mid_option(0) and scene.trial_active)
				scene.player.set_physics_process(false)
			await clear_enemies(scene)
			while scene._waves_pending():
				scene.player.position = scene.EXIT_POSITION
				assert(not scene.try_exit(), "Pending wave must block exit")
				scene._physics_process(0.01)
				var before: float = scene.wave_delay
				scene.paused = true
				scene._physics_process(3)
				assert(scene.wave_delay == before)
				scene.paused = false
				scene._physics_process(1.21)
				assert(scene.living_enemies().size() == 2)
				await clear_enemies(scene)
			open_exit(scene)
			if scene.ritual_open:
				match scene.choice_kind:
					&"ritual": assert(scene.choose_ritual(true))
					&"upgrade": assert(scene.choose_upgrade(&"tempered_edge"))
					&"toll", &"rare", &"shop":
						assert(not scene.offered.is_empty())
						assert(scene.choose_mid_option(0))
						assert(not scene.choose_mid_option(0), "Reward cannot be repeated")
		assert(scene.route_complete and scene.claimed.has(&"forge_35"))
	# Insufficient health is atomic; refusal is always available.
	scene.restart_slice()
	scene._load_layout(7)
	scene.player.set_current_health(20)
	open_exit(scene)
	var upgrades: int = scene.player.get_total_run_upgrade_count()
	assert(not scene.choose_mid_option(0))
	assert(scene.player.get_current_health() == 20 and scene.player.get_total_run_upgrade_count() == upgrades)
	assert(scene.choose_mid_option(scene.offered.size()) and scene.room_index == 8)
	# High chest requires proximity and cannot be farmed through retry.
	scene.player.position = Vector2(650, 590)
	assert(not scene.try_exit())
	scene.player.position = scene.rooms[8].chest
	assert(scene.try_exit() and scene.gold == 15)
	scene.retry_room()
	scene.player.position = scene.rooms[8].chest
	assert(not scene.try_exit() and scene.gold == 15)
	# Accepted challenge restarts from the choice on death, with no reward.
	scene._load_layout(12)
	open_exit(scene)
	assert(scene.choose_mid_option(0))
	scene._physics_process(1.3)
	assert(scene.living_enemies().size() == 2)
	scene.player._die(Vector2.ZERO, &"test")
	scene._physics_process(1.1)
	assert(not scene.trial_active and scene.living_enemies().is_empty() and not scene.claimed.has(&"forge_33"))
	open_exit(scene)
	assert(scene.choose_mid_option(1) and scene.room_index == 13)
	scene.gold = 0
	open_exit(scene)
	assert(not scene.choose_mid_option(0) and scene.gold == 0)
	assert(scene.choose_mid_option(scene.offered.size()) and scene.room_index == 14)
	# Alternate whole heat cycles, never two dangerous lanes at once.
	scene.player.set_physics_process(false)
	scene.elapsed = 0
	scene._physics_process(2.5)
	assert(scene.heat_zones.size() == 1 and scene.heat_zones[0].position.x == 390)
	scene.elapsed = 3
	scene._physics_process(2.5)
	assert(scene.heat_zones.size() == 1 and scene.heat_zones[0].position.x == 810)
	# A player camping a marked spawn postpones spawning until the marker is clear.
	scene._load_layout(9)
	await clear_enemies(scene)
	scene.player.position = scene.rooms[9].waves[0][0].position
	scene._physics_process(0.01)
	scene._physics_process(1.3)
	assert(scene.living_enemies().is_empty() and scene._waves_pending())
	scene.player.position = scene.EXIT_POSITION
	scene._physics_process(0.01)
	assert(scene.living_enemies().size() == 2)
	scene.queue_free()
	await process_frame
	print("chapter2_mid_smoke: PASS")
	quit()
