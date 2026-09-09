extends SceneTree

func _initialize() -> void:
	call_deferred(&"_run")

func _run() -> void:
	for action: StringName in [&"restart", &"move_left", &"move_right", &"jump", &"dash", &"attack", &"skill"]:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
	root.size = Vector2i(1100, 680)
	RenderingServer.set_default_clear_color(Color("#152b39"))
	var scene := load("res://scenes/Player.tscn") as PackedScene
	var weapons := [WeaponCatalog.SWORD, WeaponCatalog.TWIN_BLADES, WeaponCatalog.GREATSWORD]
	for column in range(3):
		var label := Label.new()
		label.text = ["ONE-HAND SWORD", "TWIN BLADES", "GREATSWORD"][column]
		label.position = Vector2(70 + column * 360, 20)
		root.add_child(label)
		for row in range(2):
			var player := scene.instantiate() as RoguePlayer
			root.add_child(player)
			player.set_physics_process(false)
			player.configure_weapon(weapons[column])
			player.position = Vector2(180 + column * 360, 220 + row * 240)
			player.scale = Vector2.ONE * 2.0
			player.set("_facing", 1.0)
			player.set("_run_cycle", 0.0)
			player.set("_run_start_remaining", 0.0)
			player.call(&"_reset_sprite_pose")
			player.call(&"_animate_idle" if row == 0 else &"_animate_run")
			player.call(&"_apply_weapon_pose_calibration")
			var line := Line2D.new()
			line.points = PackedVector2Array([Vector2(-170, 0), Vector2(170, 0)])
			line.position = Vector2(player.position.x, player.position.y + 55.36)
			line.width = 1.0
			line.default_color = Color("#d8b26b")
			root.add_child(line)
	for index in range(4):
		var bat := RogueEnemy.new()
		bat.position = Vector2(160 + index * 250, 610)
		bat.setup(0, 0.0, 0.0, 1100.0, 0, 0, 1.0, 1.0, RogueEnemy.EnemyFamily.NIGHT_BAT)
		root.add_child(bat)
		bat.set_physics_process(false)
		bat.set("_elapsed", (index + 0.02) / RogueEnemy.NIGHT_BAT_FLAP_FPS)
		if index == 2:
			bat.set("_hurt_remaining", 0.1)
		elif index == 3:
			bat.set("_attack_remaining", float(bat.call(&"_get_attack_duration")) * 0.55)
			bat.velocity = Vector2(320, 380)
		bat.call(&"_update_sprite_animation", 1.0)
	await process_frame
	await process_frame
	RenderingServer.force_draw()
	await RenderingServer.frame_post_draw
	var result := root.get_texture().get_image().save_png("res://test_output/visual_cleanup_preview.png")
	print("capture_visual_cleanup: ", error_string(result))
	quit(result)
