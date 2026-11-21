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
		var start_pose := player.hero_sprite.texture.resource_path.get_file()
		check(start_pose.begins_with("hero_run_") or start_pose == "hero_sprint_push.png", "%s: idle pose slides at run start" % weapon)
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
	for weapon in WeaponCatalog.all_weapon_ids():
		await reset(weapon)
		await check_moving_slash(weapon)
		await reset(weapon)
		Input.action_press(&"move_right")
		await frames(20)
		Input.action_release(&"move_right")
		await frames(5)
		check(player._visual_state == RoguePlayer.VisualState.BRAKE, "%s: stop missed its bracing pose" % weapon)
		if weapon == WeaponCatalog.SWORD:
			check(player.hero_sprite.texture == RoguePlayer.HERO_SPRINT_BRACE, "Moon sword stop missed its authored frame")
		else:
			var brace_pose := player.hero_sprite.texture.resource_path
			check(brace_pose.begins_with(RoguePlayer.WEAPON_POSE_DIRECTORIES[weapon]) and brace_pose.get_file() in ["hero_run_0.png", "hero_run_6.png"], "%s: stop missed its own contact frame" % weapon)
		await frames(4)
		check(absf(player.velocity.x) < 1, "%s: ground braking exceeds 150 ms" % weapon)
		Input.action_press(&"move_right")
		await frames(20)
		Input.action_release(&"move_right")
		Input.action_press(&"move_left")
		await frames(9)
		check(player.velocity.x < 0, "%s: reversal did not change travel direction within 150 ms" % weapon)
		Input.action_release(&"move_left")
	player.queue_free()
	floor_body.queue_free()
	await process_frame
	for failure in failures:
		push_error(failure)
	print("player_action_rhythm_smoke: ", "PASS" if failures.is_empty() else "FAIL")
	quit(0 if failures.is_empty() else 1)


func check_moving_slash(weapon: StringName) -> void:
	var hit_progress: Array[float] = []
	var capture_hit := func(_origin: Vector2, _facing: float) -> void:
		hit_progress.append(player._attack_elapsed / player.attack_duration)
	player.attack_hit.connect(capture_hit)
	Input.action_press(&"move_right")
	await frames(22)
	Input.action_press(&"attack")
	await frames(1)
	Input.action_release(&"attack")
	check(player._moving_ground_slash, "%s: moving attack did not select the grounded slash" % weapon)
	var exit_frame := player._moving_slash_exit_frame()
	var visible_poses := {}
	var minimum_speed := player.velocity.x
	var planted_positions: Array[Vector2] = []
	while player._attack_remaining > 0.0:
		visible_poses[player.hero_sprite.texture] = true
		minimum_speed = minf(minimum_speed, player.velocity.x)
		if weapon != WeaponCatalog.SWORD and player._is_planted_strike(player.hero_sprite.texture):
			var boot: Vector2 = RoguePlayer.POSE_ANCHORS.FORWARD_STRIKE_BOOTS[weapon]
			var sprite := player.hero_sprite
			planted_positions.append(sprite.transform * (boot + sprite.offset) + player.global_position)
		await physics_frame
	match weapon:
		WeaponCatalog.SWORD:
			check(visible_poses.has(RoguePlayer.HERO_MOVING_SLASH_LOAD), "Moon sword missed its loading pose")
			check(visible_poses.has(RoguePlayer.HERO_MOVING_SLASH_RELEASE), "Moon sword missed its release pose")
			check(visible_poses.has(RoguePlayer.HERO_SLASH), "Moon sword missed its hit pose")
			check(visible_poses.has(RoguePlayer.HERO_MOVING_SLASH_STEP), "Moon sword missed its recovery step")
		_:
			var strike_pose := player._weapon_pose_texture(&"hero_attack_forward_strike", RoguePlayer.HERO_SLASH)
			check(visible_poses.has(strike_pose), "%s: running swing missed its hit pose" % weapon)
			check(visible_poses.has(player._run_texture(exit_frame)), "%s: running swing missed its recovery step" % weapon)
			check(not planted_positions.is_empty(), "%s: running swing never planted a boot" % weapon)
			if not planted_positions.is_empty():
				for contact in planted_positions:
					check(absf(contact.y - 500.0) < 0.25 and absf(contact.x - planted_positions[0].x) < 1.0, "%s: the planted boot moved during the hit pose (start %s, now %s)" % [weapon, planted_positions[0], contact])
	var minimum_ratio := minimum_speed / player.run_speed
	if weapon == WeaponCatalog.TWIN_BLADES:
		check(minimum_ratio > 0.24 and minimum_ratio < 0.50, "Twin blades should carry some speed through the cut")
	elif weapon == WeaponCatalog.GREATSWORD:
		check(minimum_ratio < 0.14, "Greatsword should plant for the hit")
	else:
		check(minimum_ratio < 0.36, "Moon sword should brake for the hit")
	check(player.velocity.x > player.run_speed * 0.66, "%s: running swing did not reaccelerate on recovery" % weapon)
	check(hit_progress.size() == 1 and absf(hit_progress[0] - RoguePlayer.ATTACK_HIT_PROGRESS) < 0.065, "%s: running swing changed the attack timing" % weapon)
	check(player._run_cycle >= float(exit_frame) and player._run_cycle < float(exit_frame + 2), "%s: running swing did not return to the matching stride" % weapon)
	player.attack_hit.disconnect(capture_hit)
	Input.action_release(&"move_right")
