extends SceneTree
const GUARD := preload("res://scripts/forge_guard_prototype.gd")

func _initialize() -> void:
	call_deferred("run_test")

func release_inputs() -> void:
	for action in [&"move_left", &"move_right", &"jump", &"attack", &"skill", &"dash", &"aim_down"]:
		Input.action_release(action)

func run_test() -> void:
	Engine.time_scale = 1.0
	var scene = load("res://scenes/Chapter2Journey.tscn").instantiate()
	scene.persistence_enabled = false
	root.add_child(scene)
	var indices := [12, 14] if "late_rooms" in OS.get_cmdline_user_args() else [4, 6, 9, 11]
	if "final_rooms" in OS.get_cmdline_user_args():
		indices = [15, 17]
	var weapons := WeaponCatalog.all_weapon_ids()
	for argument in OS.get_cmdline_user_args():
		if StringName(argument) in weapons:
			weapons = [StringName(argument)]
			break
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
		var cleared := false
		for frame in range(6000):
			release_inputs()
			if scene.player.is_dead():
				push_error("Mixed room %d / %s: player died" % [index + 21, weapon])
				quit(1)
				return
			var enemies: Array = scene.living_enemies()
			if "diagnose" in OS.get_cmdline_user_args() and frame % 600 == 0:
				print("frame=", frame, " player=", scene.player.position, " health=", scene.player.get_current_health())
				for foe in enemies:
					print("enemy=", foe.position, " hp=", foe.get_current_health())
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
				if offset.y > 60 and scene.player.is_on_floor() and frame % 24 == 0:
					Input.action_press(&"aim_down")
					Input.action_press(&"jump")
				if absf(offset.x) > 40 or frame % 36 == 0:
					Input.action_press(&"move_right" if offset.x > 0 else &"move_left")
				if offset.y < -45 and frame % 24 == 0:
					Input.action_press(&"jump")
				if target is GUARD and target.charge_state == GUARD.ChargeState.WINDUP and absf(offset.x) < 200 and scene.player.is_on_floor():
					Input.action_press(&"jump")
				for heat: Rect2 in scene.heat_zones:
					if scene.player.is_on_floor() and scene.player.position.y > heat.position.y - 35 and scene.player.position.x > heat.position.x - 55 and scene.player.position.x < heat.end.x + 55:
						Input.action_press(&"jump")
				if absf(offset.x) < 130 and absf(offset.y) < 65:
					# Release for whole physics ticks between taps; a held button is one swing.
					if frame % 6 == 0:
						Input.action_press(&"attack")
					if frame % 60 == 0:
						Input.action_press(&"skill")
			await physics_frame
			# Keep synthetic presses alive through a complete player physics update.
			# SceneTree.physics_frame fires before nodes run their physics callbacks.
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

