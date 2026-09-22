extends SceneTree

var player: RoguePlayer
var counts := {}
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run_test")

func frames(count: int) -> void:
	for i in range(count):
		await physics_frame

func press(action: StringName) -> void:
	Input.action_press(action)
	await frames(2)
	Input.action_release(action)
	await frames(2)

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func reset(weapon: StringName) -> void:
	for action in [&"attack", &"skill", &"dash", &"jump", &"move_left", &"move_right", &"aim_down"]:
		Input.action_release(action)
	player.respawn()
	player.configure_weapon(weapon)
	await frames(15)
	counts.clear()

func run_test() -> void:
	for action in [&"restart", &"attack", &"skill", &"dash", &"jump", &"move_left", &"move_right", &"aim_down"]:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
	create_timer(30).timeout.connect(func(): push_error("Rhythm test timeout"); quit(1))
	var floor_body := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(10000, 100)
	shape.shape = rectangle
	floor_body.position = Vector2(0, 550)
	floor_body.add_child(shape)
	root.add_child(floor_body)
	player = load("res://scenes/Player.tscn").instantiate()
	player.position = Vector2(400, 470)
	root.add_child(player)
	player.action_started.connect(func(action): counts[action] = int(counts.get(action, 0)) + 1)
	for weapon in WeaponCatalog.all_weapon_ids():
		await reset(weapon)
		await press(&"attack")
		while player.get_attack_cooldown_remaining() > 0.10:
			await physics_frame
		await press(&"attack")
		await frames(20)
		check(counts.get(&"attack", 0) == 2, "%s: early follow-up press lost" % weapon)
		await reset(weapon)
		Input.action_press(&"attack")
		await frames(65)
		Input.action_release(&"attack")
		check(counts.get(&"attack", 0) == 1, "%s: holding attack repeated" % weapon)
		await reset(weapon)
		await press(&"attack")
		while player._attack_remaining > 0.10:
			await physics_frame
		await press(&"skill")
		await frames(16)
		check(counts.get(&"skill", 0) == 1, "%s: attack-to-skill press lost" % weapon)
		while player._skill_remaining > 0.10:
			await physics_frame
		await press(&"attack")
		await frames(15)
		check(counts.get(&"attack", 0) == 2, "%s: skill-to-attack press lost" % weapon)
		await reset(weapon)
		await press(&"attack")
		player.apply_hitstop(0.09)
		var pose := player.hero_sprite.transform
		Input.action_press(&"move_left")
		Input.action_press(&"skill")
		await frames(2)
		Input.action_release(&"skill")
		Input.action_release(&"move_left")
		check(player.hero_sprite.transform == pose, "%s: pose drifted during hitstop" % weapon)
		check(player._facing == 1.0, "%s: blocked skill turned active swing" % weapon)
		await reset(weapon)
		await press(&"attack")
		await press(&"dash")
		await frames(20)
		check(counts.get(&"dash", 0) == 1, "%s: dash pressed before impact was lost" % weapon)
		await reset(weapon)
		await press(&"dash")
		var echo_found := false
		for node in root.get_children():
			if node.get_script() == RoguePlayer.DASH_ECHO_SCRIPT:
				echo_found = true
				check(node.texture.resource_path.contains("hero_run_"), "%s: dash echoes stale idle frame" % weapon)
				if weapon != WeaponCatalog.SWORD:
					check(node.texture.resource_path.begins_with(RoguePlayer.WEAPON_POSE_DIRECTORIES[weapon]), "%s: dash echo shows another weapon" % weapon)
		check(echo_found, "%s: missing world-space dash echo" % weapon)
		await reset(weapon)
		Input.action_press(&"move_right")
		await frames(4)
		check(player.hero_sprite.texture.resource_path.get_file().begins_with("hero_run_"), "%s: idle pose slides at run start" % weapon)
		await press(&"attack")
		while player._attack_remaining > 0.0:
			await physics_frame
		await frames(2)
		check(player._visual_state == RoguePlayer.VisualState.RUN, "%s: moving attack has extra static recovery" % weapon)
		await press(&"skill")
		while player._skill_remaining > 0.0:
			await physics_frame
		await frames(2)
		check(player._visual_state == RoguePlayer.VisualState.RUN, "%s: moving skill has extra static recovery" % weapon)
		Input.action_release(&"move_right")
	# A short cooldown press expires; menu suspension must discard queued intent.
	await reset(WeaponCatalog.SWORD)
	player._skill_cooldown_remaining = 1.0
	await press(&"skill")
	await frames(70)
	check(counts.get(&"skill", 0) == 0, "Expired skill request fired much later")
	player._skill_cooldown_remaining = 0.10
	await press(&"skill")
	player.set_input_enabled(false)
	await frames(3)
	player.set_input_enabled(true)
	await frames(12)
	check(counts.get(&"skill", 0) == 0, "Disabled input retained queued skill")
	# Landing buffer, tested with air jumps exhausted to avoid consuming one.
	await reset(WeaponCatalog.SWORD)
	player.extra_jumps = 0
	player.position.y = 450
	player.velocity.y = 200
	await frames(2)
	await press(&"jump")
	await frames(10)
	check(counts.get(&"jump", 0) == 1 and player.velocity.y < 0, "Pre-landing jump was lost")
	# Step off actual geometry; coyote jump must not consume the aerial jump.
	await reset(WeaponCatalog.SWORD)
	player.extra_jumps = 1
	floor_body.position.x = -4490
	player.position = Vector2(490, 472)
	await frames(4)
	Input.action_press(&"move_right")
	for i in range(50):
		await physics_frame
		if not player.is_on_floor():
			break
	await press(&"jump")
	Input.action_release(&"move_right")
	check(counts.get(&"jump", 0) == 1 and player._air_jumps_used == 0, "Ledge grace jump consumed aerial jump")
	floor_body.position.x = 0
	await reset(WeaponCatalog.SWORD)
	Input.action_press(&"move_right")
	await frames(20)
	Input.action_release(&"move_right")
	await frames(9)
	check(absf(player.velocity.x) < 1, "Ground braking exceeds 150 ms")
	Input.action_press(&"move_right")
	await frames(20)
	Input.action_release(&"move_right")
	Input.action_press(&"move_left")
	await frames(9)
	check(player.velocity.x < 0, "Reversal did not change travel direction within 150 ms")
	Input.action_release(&"move_left")
	player.queue_free()
	floor_body.queue_free()
	await process_frame
	for failure in failures:
		push_error(failure)
	print("player_action_rhythm_smoke: ", "PASS" if failures.is_empty() else "FAIL")
	quit(0 if failures.is_empty() else 1)
