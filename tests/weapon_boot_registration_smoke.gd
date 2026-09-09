extends SceneTree

func _initialize() -> void:
	call_deferred(&"_run")

func _run() -> void:
	for action: StringName in [&"restart", &"move_left", &"move_right", &"jump", &"dash", &"attack", &"skill"]:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
	var scene := load("res://scenes/Player.tscn") as PackedScene
	var player := scene.instantiate() as RoguePlayer
	root.add_child(player)
	player.set_physics_process(false)
	var sprite := player.get_node("HeroSprite") as Sprite2D
	var references: Dictionary = {}
	for weapon: StringName in [WeaponCatalog.SWORD, WeaponCatalog.TWIN_BLADES, WeaponCatalog.GREATSWORD]:
		player.configure_weapon(weapon)
		for facing in [-1.0, 1.0]:
			for frame in range(-1, 0):
				player.set("_facing", facing)
				player.set("_run_cycle", float(maxi(0, frame)))
				player.set("_run_start_remaining", 0.0)
				player.call(&"_reset_sprite_pose")
				player.call(&"_animate_idle" if frame == -1 else &"_animate_run")
				player.call(&"_apply_weapon_pose_calibration")
				# Read the PNG independently of the runtime baseline cache.
				var image := Image.load_from_file(ProjectSettings.globalize_path(sprite.texture.resource_path))
				var sole_y := 0
				for y in range(image.get_height() - 1, image.get_height() / 2, -1):
					var count := 0
					for x in range(image.get_width() / 2 - 100, image.get_width() / 2 + 116):
						if image.get_pixel(x, y).a >= 0.5:
							count += 1
					if count >= 6:
						sole_y = y + 1
						break
				var foot_y: float = sprite.position.y + (sole_y - image.get_height() * 0.5) * sprite.scale.y
				var key := "%s/%d" % [facing, frame]
				if weapon == WeaponCatalog.SWORD:
					references[key] = foot_y
				elif absf(foot_y - float(references[key])) > 0.01:
					push_error("Boot registration mismatch: %s %s delta=%f" % [weapon, key, foot_y - float(references[key])])
					quit(1)
					return
	player.queue_free()
	print("weapon_boot_registration_smoke: PASS both facings, idle boot registration (run uses canonical head registration)")
	quit(0)
