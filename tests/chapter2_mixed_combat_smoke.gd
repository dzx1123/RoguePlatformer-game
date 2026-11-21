extends SceneTree
const GUARD := preload("res://scripts/forge_guard_prototype.gd")

func _initialize() -> void:
	call_deferred("run_test")

func release_inputs() -> void:
	for action in [&"move_left", &"move_right", &"jump", &"attack", &"skill", &"dash", &"aim_down"]:
		Input.action_release(action)

func run_test() -> void:
	Engine.time_scale = 1.0
	var indices := [12, 14] if "late_rooms" in OS.get_cmdline_user_args() else [4, 6, 9, 11]
	if "final_rooms" in OS.get_cmdline_user_args():
		indices = [15, 17]
	var weapons := WeaponCatalog.all_weapon_ids()
	for argument in OS.get_cmdline_user_args():
		if StringName(argument) in weapons:
			weapons = [StringName(argument)]
			break
	if "sample" in OS.get_cmdline_user_args():
		for weapon: StringName in weapons:
			var sample_scene := start_journey()
			if not await play_continuous_sample(sample_scene, weapon):
				quit(1)
				return
			sample_scene.queue_free()
			await process_frame
		print("chapter2_mixed_combat_smoke continuous sample: PASS")
		quit()
		return
	var scene := start_journey()
	for case_index in range(indices.size() * weapons.size()):
		var index: int = indices[case_index % indices.size()]
		var weapon: StringName = weapons[case_index / indices.size()]
		scene._load_layout(index)
		scene.player.configure_weapon(weapon)
		await create_timer(1.8).timeout
		if index == 12:
			Input.action_press(&"move_right")
			for step in range(600):
				await physics_frame
				if scene.player.position.x >= 1180:
					break
			Input.action_release(&"move_right")
			Input.action_press(&"interact")
			await physics_frame
			await physics_frame
			Input.action_release(&"interact")
			await create_timer(0.3).timeout
			assert(scene.choice_kind == &"trial" and scene.choose_mid_option(0))
		if not await clear_encounter(scene):
			quit(1)
			return
		await physics_frame
		await physics_frame
		assert(is_instance_valid(scene.room_portal), "Clear must create portal")
		print("Mixed room %d / %s: cleared, health=%d" % [index + 21, weapon, scene.player.get_current_health()])
	scene.queue_free()
	await process_frame
	print("chapter2_mixed_combat_smoke: PASS")
	quit()

func start_journey() -> Node:
	var scene := load("res://scenes/Chapter2Journey.tscn").instantiate() as Node
	scene.persistence_enabled = false
	root.add_child(scene)
	return scene

func clear_encounter(scene: Node, avoid_impacts: bool = false) -> bool:
	for frame in range(6000):
		release_inputs()
		if scene.player.is_dead():
			push_error("Room %d / %s: player died" % [scene.room_index + 21, scene.player.get_weapon_id()])
			return false
		var enemies: Array = scene.living_enemies()
		if "diagnose" in OS.get_cmdline_user_args() and frame % 600 == 0:
			print("frame=", frame, " player=", scene.player.position, " health=", scene.player.get_current_health())
			for foe in enemies:
				print("enemy=", foe.position, " hp=", foe.get_current_health())
		if enemies.is_empty():
			if not scene._waves_pending():
				return true
			# Give the announced second wave room to spawn.
			Input.action_press(&"move_left" if scene.player.position.x > 400 else &"move_right")
		else:
			var target = enemies[0]
			for enemy in enemies:
				if enemy.position.distance_to(scene.player.position) < target.position.distance_to(scene.player.position):
					target = enemy
			var offset: Vector2 = target.position - scene.player.position
			if offset.y > 60 and scene.player.is_on_floor() and frame % 24 == 0:
				Input.action_press(&"aim_down")
				Input.action_press(&"jump")
			if absf(offset.x) > 40 or frame % 36 == 0:
				Input.action_press(&"move_right" if offset.x > 0 else &"move_left")
			if offset.y < -45 and frame % 24 == 0:
				Input.action_press(&"jump")
			if target is GUARD and target.charge_state == GUARD.ChargeState.WINDUP and absf(offset.x) < 200 and scene.player.is_on_floor():
				Input.action_press(&"jump")
			var next_ground_x := move_toward(scene.player.position.x, target.position.x, 55.0)
			for heat: Rect2 in scene.heat_zones:
				# Jump when the next step would carry the player into a warming
				# or active vent. Keep safe ground available for melee attacks.
				var phase: int = scene._vent_phase(heat)
				if phase not in [scene.VentPhase.WARNING, scene.VentPhase.ACTIVE]:
					continue
				var on_approach := next_ground_x > heat.position.x - 18.0 and next_ground_x < heat.end.x + 18.0
				if scene.player.is_on_floor() and scene.player.position.y > heat.position.y - 28.0 and on_approach:
					Input.action_press(&"jump")
			if absf(offset.x) < 130 and absf(offset.y) < 65:
				# A fresh tap starts a swing; hold each tap through one complete physics update.
				if frame % 6 == 0:
					Input.action_press(&"attack")
				if frame % 60 == 0:
					Input.action_press(&"skill")
			if avoid_impacts:
				evade_ember(scene)
		await physics_frame
		await physics_frame
	release_inputs()
	push_error("Room %d / %s: combat timed out" % [scene.room_index + 21, scene.player.get_weapon_id()])
	return false

func play_continuous_sample(scene: Node, weapon: StringName) -> bool:
	scene._load_layout(2)
	scene.player.configure_weapon(weapon)
	var acquired_upgrade := StringName()
	var acquired_count := 0
	for room_index in range(2, 6):
		await create_timer(1.8).timeout
		if "capture_sample" in OS.get_cmdline_user_args():
			await RenderingServer.frame_post_draw
			var path := "res://test_output/forge_sample_%02d_%s.png" % [room_index + 21, weapon]
			assert(root.get_texture().get_image().save_png(path) == OK)
		if room_index == 4 and not await take_upper_route(scene):
			push_error("Sample could not reach the casting platform by the upper route")
			return false
		# Dual blades can disengage sooner between strikes, so save the dash for
		# the heavier weapons whose committed swing is harder to leave.
		var dodge_casts := room_index == 4 and weapon != WeaponCatalog.TWIN_BLADES
		if not await clear_encounter(scene, dodge_casts):
			return false
		var max_health: int = scene.player.get_max_health()
		var health := await enter_portal(scene)
		if health < 0:
			push_error("Sample could not reach the portal in room %d" % (room_index + 21))
			return false
		var expected_health := health
		if room_index == 3:
			# Choose healing rather than disabling the next room's environmental challenge.
			assert(scene.choice_kind == &"ritual")
			expected_health = mini(max_health, health + 25)
			await choose_card(KEY_2)
		elif room_index == 4:
			assert(scene.choice_kind == &"upgrade")
			var choice: StringName = scene.reward_cards[0].id
			acquired_upgrade = choice
			acquired_count = scene.player.get_run_upgrade_count(choice) + 1
			await choose_card(KEY_1)
			if choice == &"vitality_rune":
				expected_health += scene.player.get_max_health() - max_health
		assert(scene.room_index == room_index + 1, "The real exit must advance exactly one room")
		assert(scene.player.get_current_health() == expected_health, "Changing rooms must carry health and apply only earned rewards")
		assert(scene.player.get_weapon_id() == weapon, "The run keeps its weapon through every room")
		if not acquired_upgrade.is_empty():
			assert(scene.player.get_run_upgrade_count(acquired_upgrade) == acquired_count, "Earned upgrade must carry into later rooms")
		print("Continuous room %d / %s: cleared, health=%d" % [room_index + 21, weapon, expected_health])
	return true

func evade_ember(scene: Node) -> void:
	for ember in scene.embers.get_children():
		var remaining: float = ember.WARNING + ember.FLIGHT - ember.age
		if remaining <= 0.0 or remaining > 0.24 or scene.player.position.distance_to(ember.landing) > ember.BLAST_RADIUS + 23.0:
			continue
		release_inputs()
		Input.action_press(&"move_left" if scene.player.position.x < ember.landing.x else &"move_right")
		Input.action_press(&"jump")
		Input.action_press(&"dash")
		return

func take_upper_route(scene: Node, last_platform: int = -1, last_x: float = INF) -> bool:
	var player: RoguePlayer = scene.player
	var entry_step: Rect2 = scene.platforms[1]
	var end_index: int = scene.platforms.size() - 1 if last_platform < 0 else last_platform
	if not await walk_to_x(player, entry_step.position.x - 20.0):
		return false
	for index in range(1, end_index + 1):
		var platform: Rect2 = scene.platforms[index]
		Input.action_press(&"jump")
		await physics_frame
		await physics_frame
		Input.action_release(&"jump")
		var landing_x := platform.position.x + (32.0 if index == end_index else 55.0)
		if not await walk_to_x(player, landing_x):
			return false
		for frame in range(60):
			await physics_frame
			if player.is_on_floor():
				break
		if not player.is_on_floor() or absf(player.position.y - (platform.position.y - 28.0)) > 5.0:
			return false
		if index < end_index and not await walk_to_x(player, platform.end.x - 30.0):
			return false
	return is_inf(last_x) or await walk_to_x(player, last_x)

func walk_to_x(player: RoguePlayer, target: float) -> bool:
	for frame in range(120):
		release_inputs()
		if player.is_dead():
			return false
		var distance := target - player.position.x
		if absf(distance) < 8.0:
			return true
		Input.action_press(&"move_right" if distance > 0.0 else &"move_left")
		await physics_frame
	release_inputs()
	return false

func enter_portal(scene: Node) -> int:
	await physics_frame
	for frame in range(450):
		release_inputs()
		if scene.player.is_dead():
			return -1
		if is_instance_valid(scene.room_portal) and scene.room_portal.is_in_range(scene.player.global_position):
			var health: int = scene.player.get_current_health()
			Input.action_press(&"interact")
			await physics_frame
			await physics_frame
			Input.action_release(&"interact")
			await create_timer(0.35).timeout
			return health
		Input.action_press(&"move_right")
		for heat: Rect2 in scene.heat_zones:
			if scene.player.is_on_floor() and scene.heat_is_active() and scene.player.position.x > heat.position.x - 65 and scene.player.position.x < heat.end.x:
				Input.action_press(&"jump")
		await physics_frame
		await physics_frame
	release_inputs()
	return -1

func choose_card(keycode: Key) -> void:
	var press := InputEventKey.new()
	press.keycode = keycode
	press.pressed = true
	Input.parse_input_event(press)
	await process_frame
	var release := press.duplicate() as InputEventKey
	release.pressed = false
	Input.parse_input_event(release)
	await process_frame
