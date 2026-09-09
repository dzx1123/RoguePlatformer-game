extends SceneTree

func _initialize() -> void:
	call_deferred(&"_run")

func _run() -> void:
	for action: StringName in [&"restart", &"move_left", &"move_right", &"jump", &"dash", &"attack", &"skill"]:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
	root.size = Vector2i(1100, 340)
	root.content_scale_size = root.size
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_IGNORE
	RenderingServer.set_default_clear_color(Color("#132c3c"))
	var players: Array[RoguePlayer] = []
	var weapons := [WeaponCatalog.SWORD, WeaponCatalog.TWIN_BLADES, WeaponCatalog.GREATSWORD]
	for column in range(3):
		var player := (load("res://scenes/Player.tscn") as PackedScene).instantiate() as RoguePlayer
		(player.get_node("Camera2D") as Camera2D).enabled = false
		root.add_child(player)
		player.set_physics_process(false)
		player.configure_weapon(weapons[column])
		player.position = Vector2(180 + column * 360, 240)
		player.scale = Vector2.ONE * 2.0
		players.append(player)
		var label := Label.new()
		label.text = ["ONE-HAND", "TWIN BLADES", "GREATSWORD"][column]
		label.position = Vector2(80 + column * 360, 24)
		root.add_child(label)
	var white_samples := 0
	for index in range(24):
		var frame := index % 12
		var facing := 1.0 if index < 12 else -1.0
		for player: RoguePlayer in players:
			player.set("_facing", facing)
			player.set("_turn_remaining", 0.0)
			player.set("_run_start_remaining", 0.0)
			player.set("_run_cycle", float(frame))
			player.call(&"_reset_sprite_pose")
			player.call(&"_animate_run")
			player.call(&"_apply_weapon_pose_calibration")
			var sprite := player.get_node("HeroSprite") as Sprite2D
			if absf(sprite.position.y + 15.0) > 0.001:
				push_error("Run frame moves the entire character vertically")
				quit(1)
				return
		await process_frame
		await process_frame
		RenderingServer.force_draw()
		await RenderingServer.frame_post_draw
		var rendered := root.get_texture().get_image()
		rendered.save_png("res://test_output/run_cutout_%02d.png" % index)
		for column in [1, 2]:
			var sprite := players[column].get_node("HeroSprite") as Sprite2D
			var source := sprite.texture.get_image()
			if source.is_compressed():
				source.decompress()
			for y in range(int(source.get_height() * 0.52), source.get_height(), 2):
				for x in range(0, source.get_width(), 2):
					var color := source.get_pixel(x, y)
					if color.a < 0.95 or minf(color.r, minf(color.g, color.b)) < 0.90:
						continue
					var local := Vector2(x + 0.5, y + 0.5) - Vector2(source.get_size()) * 0.5
					if sprite.flip_h:
						local.x = -local.x
					var point := Vector2i(sprite.to_global(local).floor())
					if not Rect2i(Vector2i.ZERO, rendered.get_size()).has_point(point):
						continue
					var output := rendered.get_pixelv(point)
					white_samples += 1
					if minf(output.r, minf(output.g, output.b)) > 0.82:
						push_error("White matte survived: weapon=%d frame=%d source=%s" % [column, index, Vector2i(x, y)])
						quit(1)
						return
	print("run_cutout_render_smoke: PASS 24 frames, matte samples=", white_samples)
	quit(0)
