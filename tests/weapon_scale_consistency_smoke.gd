extends SceneTree

func _initialize() -> void:
	call_deferred(&"_run")

func _run() -> void:
	for action: StringName in [&"restart", &"move_left", &"move_right", &"jump", &"dash", &"attack", &"skill"]:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
	var player := (load("res://scenes/Player.tscn") as PackedScene).instantiate() as RoguePlayer
	root.add_child(player)
	player.set_physics_process(false)
	var sprite := player.get_node("HeroSprite") as Sprite2D
	var checked := 0
	for weapon: StringName in [WeaponCatalog.TWIN_BLADES, WeaponCatalog.GREATSWORD]:
		player.configure_weapon(weapon)
		var directory: String = RoguePlayer.WEAPON_POSE_DIRECTORIES[weapon]
		for filename: String in DirAccess.get_files_at(directory):
			if not filename.ends_with(".png"):
				continue
			for facing in [-1.0, 1.0]:
				player.set("_facing", facing)
				player.call(&"_reset_sprite_pose")
				player.call(&"_set_texture", load(directory.path_join(filename)))
				player.call(&"_apply_weapon_pose_calibration")
				if not sprite.scale.is_equal_approx(Vector2.ONE * RoguePlayer.HERO_SCALE):
					push_error("Weapon pose changes canonical character size: " + filename)
					quit(1)
					return
				if not sprite.self_modulate.is_equal_approx(Color.WHITE):
					push_error("Weapon colour changes between poses: " + filename)
					quit(1)
					return
				checked += 1
	player.queue_free()
	print("weapon_scale_consistency_smoke: PASS poses/facings=", checked)
	quit(0)
