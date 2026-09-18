extends SceneTree
const GUARD := preload("res://scripts/forge_guard_prototype.gd")

func _initialize() -> void:
	call_deferred("run_test")

func release_inputs() -> void:
	for action in [&"move_left", &"move_right", &"jump", &"attack", &"skill", &"dash"]:
		Input.action_release(action)

func run_test() -> void:
	Engine.time_scale = 1.0
	var scene = load("res://scenes/Chapter2Journey.tscn").instantiate()
	scene.persistence_enabled = false
	root.add_child(scene)
	var indices := [12, 14] if "late_rooms" in OS.get_cmdline_user_args() else [4, 6, 9, 11]
	for case_index in range(indices.size() * 3):
		var index: int = indices[case_index % indices.size()]
		var weapon: StringName = WeaponCatalog.all_weapon_ids()[case_index / indices.size()]
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
		var cleared := false
		for frame in range(6000):
			release_inputs()
			if scene.player.is_dead():
				push_error("Mixed room %d / %s: player died" % [index + 21, weapon])
				quit(1)
				return
			var enemies: Array = scene.living_enemies()
			if enemies.is_empty():
				if not scene._waves_pending():
					cleared = true
					break
				# Give the announced second wave room to spawn.
				Input.action_press(&"move_left" if scene.player.position.x > 400 else &"move_right")
			else:
				var target = enemies[0]
				for enemy in enemies:
					if enemy.position.distance_to(scene.player.position) < target.position.distance_to(scene.player.position):
						target = enemy
				var offset: Vector2 = target.position - scene.player.position
				if absf(offset.x) > 40 or frame % 36 == 0:
					Input.action_press(&"move_right" if offset.x > 0 else &"move_left")
				if offset.y < -45 and frame % 24 == 0:
					Input.action_press(&"jump")
				if target is GUARD and target.charge_state == GUARD.ChargeState.WINDUP and absf(offset.x) < 200 and scene.player.is_on_floor():
					Input.action_press(&"jump")
				if absf(offset.x) < 130 and absf(offset.y) < 65:
					Input.action_press(&"attack")
					if frame % 60 == 0:
						Input.action_press(&"skill")
			await physics_frame
		release_inputs()
		if not cleared:
			push_error("Mixed room %d / %s: combat timed out" % [index + 21, weapon])
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

