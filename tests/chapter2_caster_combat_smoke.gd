extends SceneTree

func _initialize() -> void:
	call_deferred("run_test")

func run_test() -> void:
	var scene = load("res://scenes/Chapter2Slice.tscn").instantiate()
	root.add_child(scene)
	for weapon in WeaponCatalog.all_weapon_ids():
		scene._load_layout(2)
		scene.player.configure_weapon(weapon)
		await create_timer(0.35).timeout
		assert(scene.caster.is_on_floor(), "Caster must stand on its teaching platform")
		assert(absf(scene.caster.position.y - 492) < 12)
		assert(scene.embers.get_child_count() == 0, "Entrance must stay outside engagement range")
		# Isolate close combat: use real attack input and ordinary weapon damage.
		scene.player.position = Vector2(895, 492)
		Input.action_press(&"move_right")
		await physics_frame
		Input.action_release(&"move_right")
		var target = scene.caster
		var initial_health: int = target.get_current_health()
		for attempt in range(30):
			if not is_instance_valid(target) or target.get_current_health() <= 0:
				break
			# Knockback can move the enemy out of reach: approach with real movement.
			for frame in range(90):
				if not is_instance_valid(target) or target.get_current_health() <= 0:
					break
				var distance: float = target.position.x - scene.player.position.x
				if absf(distance) < 52:
					break
				Input.action_press(&"move_right" if distance > 0 else &"move_left")
				await physics_frame
				Input.action_release(&"move_right")
				Input.action_release(&"move_left")
			Input.action_press(&"attack")
			await create_timer(0.10).timeout
			Input.action_release(&"attack")
			await create_timer(0.55).timeout
		assert(not is_instance_valid(target) or target.get_current_health() < initial_health, "Actual attack input must hit the caster")
		assert(not is_instance_valid(target) or target.get_current_health() == 0, "Normal weapon attacks must finish the teaching enemy")
		assert(not scene.player.is_dead())
		await create_timer(0.5).timeout
	scene.queue_free()
	await process_frame
	print("chapter2_caster_combat_smoke: PASS")
	quit()
