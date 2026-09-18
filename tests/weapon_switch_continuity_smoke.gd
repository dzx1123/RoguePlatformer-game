extends SceneTree

func _initialize() -> void:
	call_deferred("run_test")

func run_test() -> void:
	for action: StringName in [&"restart", &"move_left", &"move_right", &"jump", &"dash", &"attack", &"skill"]:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
	var p = load("res://scenes/Player.tscn").instantiate()
	root.add_child(p)
	p.set_physics_process(false)
	for weapon in WeaponCatalog.all_weapon_ids():
		p.configure_weapon(weapon)
		for facing in [-1.0, 1.0]:
			p._facing = facing
			for index in range(12):
				p._run_cycle = index
				p._run_start_remaining = 0
				p._reset_sprite_pose()
				p._animate_run()
				p._apply_weapon_pose_calibration()
				var expected: float = p._get_boot_baseline(p._run_reference_texture(index))
				var actual: float = p._get_boot_baseline(p._current_texture) + p.hero_sprite.offset.y
				assert(absf(expected - actual) < 0.01, "Run feet must follow canonical ground line")
	for source in WeaponCatalog.all_weapon_ids():
		for destination in WeaponCatalog.all_weapon_ids():
			p.configure_weapon(source)
			p._run_cycle = 7.25
			p._skill_cooldown_remaining = 2.0
			p._attack_remaining = 0.2
			assert(p.request_weapon_switch(destination))
			assert(p.get_weapon_id() == source and p._attack_remaining == 0.2)
			p._attack_remaining = 0
			p._attack_exit_blend_remaining = 0.1
			assert(not p._can_switch_weapon_now())
			p._attack_exit_blend_remaining = 0
			assert(p._can_switch_weapon_now())
			p.configure_weapon(p._pending_weapon_id)
			assert(p.get_weapon_id() == destination)
			assert(p._run_cycle == 7.25 and p._skill_cooldown_remaining == 2.0)
			assert(p._pending_weapon_id.is_empty() and not p.skill_pose_echo.visible)
	for timer in ["_skill_remaining", "_dash_remaining", "_hurt_remaining", "_skill_exit_blend_remaining", "_dash_exit_blend_remaining"]:
		p.configure_weapon(WeaponCatalog.SWORD)
		p.set(timer, 0.2)
		assert(p.request_weapon_switch(WeaponCatalog.GREATSWORD))
		assert(p.get_weapon_id() == WeaponCatalog.SWORD and not p._can_switch_weapon_now())
		p.set(timer, 0.0)
		assert(p._can_switch_weapon_now())
		p.configure_weapon(p._pending_weapon_id)
		assert(p.get_weapon_id() == WeaponCatalog.GREATSWORD)
	# Exercise the real physics path, including deferred switch completion.
	var floor_body := StaticBody2D.new()
	var collider := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(10000, 40)
	collider.shape = shape
	floor_body.add_child(collider)
	floor_body.position = Vector2(0, 400)
	root.add_child(floor_body)
	p.position = Vector2(0, 340)
	p.set_physics_process(true)
	for frame in range(40):
		await physics_frame
	Input.action_press(&"move_right")
	for weapon in WeaponCatalog.all_weapon_ids():
		assert(p.request_weapon_switch(weapon))
		for frame in range(90):
			await physics_frame
			assert(p.is_on_floor())
		assert(p.get_weapon_id() == weapon)
		var old_weapon: StringName = p.get_weapon_id()
		Input.action_press(&"attack")
		await physics_frame
		await physics_frame
		Input.action_release(&"attack")
		var next_weapon: StringName = WeaponCatalog.all_weapon_ids()[(WeaponCatalog.all_weapon_ids().find(weapon) + 1) % 3]
		assert(p.request_weapon_switch(next_weapon))
		assert(p.get_weapon_id() == old_weapon)
		for frame in range(100):
			await physics_frame
		assert(p.get_weapon_id() == next_weapon and p._pending_weapon_id.is_empty())
	Input.action_release(&"move_right")
	floor_body.queue_free()
	p.queue_free()
	print("weapon_switch_continuity_smoke: PASS")
	quit()
