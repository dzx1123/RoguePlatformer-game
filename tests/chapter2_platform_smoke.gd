extends SceneTree

func _initialize() -> void:
	call_deferred("run_test")

func move_to(player: Node, x: float) -> void:
	for frame in range(180):
		var direction := signf(x - player.position.x)
		Input.action_release(&"move_left")
		Input.action_release(&"move_right")
		if absf(player.position.x - x) < 8:
			return
		Input.action_press(&"move_right" if direction > 0 else &"move_left")
		await physics_frame
	assert(false, "Could not reach horizontal waypoint")

func jump_to(player: Node, target: Rect2, x: float) -> void:
	Input.action_press(&"jump")
	await physics_frame
	await physics_frame
	Input.action_release(&"jump")
	await move_to(player, x)
	for frame in range(150):
		await physics_frame
		if player.is_on_floor():
			assert(player.position.y < target.position.y and player.position.y > target.position.y - 80, "Landed on wrong floor")
			return
	assert(false, "Failed to land on upper route")

func run_test() -> void:
	var scene = load("res://scenes/Chapter2FullSlice.tscn").instantiate()
	root.add_child(scene)
	scene.set_physics_process(false)
	var indices := [10, 11] if "new_rooms" in OS.get_cmdline_user_args() else [0, 1, 2, 3, 4, 5, 8, 9, 10, 11, 14, 19]
	for index in indices:
		scene._load_layout(index)
		for enemy in scene.living_enemies():
			enemy.queue_free()
		await process_frame
		for frame in range(20):
			await physics_frame
		# Walk the complete safe lower route with the actual Player controller.
		await move_to(scene.player, 1200)
		assert(not scene.player.is_dead())
		await move_to(scene.player, 230)
		# Climb each upper platform via normal single jumps; no teleports or extra jumps.
		for i in range(1, scene.platforms.size()):
			var target: Rect2 = scene.platforms[i]
			if index == 19 and i == 2:
				# The arena's two low ledges are reached independently from its safe main floor.
				await move_to(scene.player, target.position.x - 30)
				for frame in range(45):
					await physics_frame
			await jump_to(scene.player, target, target.position.x + 55)
			if index == 8 and i == 2:
				await move_to(scene.player, 650)
				assert(scene.try_exit() and scene.gold == 15, "High chest must be reachable")
			await move_to(scene.player, target.end.x - 30)
		await move_to(scene.player, 1200)
		for frame in range(60):
			await physics_frame
		assert(not scene.player.is_dead() and scene.player.is_on_floor())
	scene.queue_free()
	await process_frame
	print("chapter2_platform_smoke: PASS")
	quit()
