extends SceneTree

const OUTPUT := "res://tests/artifacts/ui-fixes"

func _initialize() -> void:
	call_deferred(&"_capture")

func _capture() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	root.content_scale_size = Vector2i(1280, 840)
	root.size = Vector2i(1280, 840)
	var main := (load("res://scenes/Main.tscn") as PackedScene).instantiate() as Node2D
	main.set("save_enabled", false)
	root.add_child(main)
	await process_frame
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	root.size = Vector2i(1280, 840)
	main.call(&"_pause_game")
	main.call(&"_open_settings", true)
	for controller: bool in [false, true]:
		main.call(&"_on_input_device_changed", controller)
		await _save("settings_controller" if controller else "settings_keyboard")
	main.call(&"_close_settings")
	main.call(&"_resume_game")
	main.set("_current_objective", 2)
	main.set("_objective_anchor", Vector2(640, 620))
	main.set("_objective_radius", 92.0)
	main.set("_objective_hold_duration", 8.0)
	main.set("_objective_hold_progress", 3.0)
	main.call(&"_configure_objective_traps", Rect2(0, 638, 1280, 80))
	(main.get_node("Player") as Node2D).position = Vector2(640, 618)
	main.set_process(false)
	main.queue_redraw()
	await _save("objective")
	main.call(&"_clear_enemies")
	main.set("_current_objective", 0)
	main.call(&"_on_room_cleared")
	await process_frame
	var portal := main.get_node("RoomExitPortal") as RoomExitPortal
	var player := main.get_node("Player") as RoguePlayer
	player.set_physics_process(false)
	player.global_position = portal.global_position + Vector2(-280.0, 0.0)
	portal.set_opener_position(player.global_position)
	await _save("portal_far")
	player.global_position = portal.global_position + Vector2(-44.0, 0.0)
	portal.set_opener_position(player.global_position)
	await _save("portal_near")
	main.queue_free()
	await process_frame
	var canvas := Node2D.new()
	root.add_child(canvas)
	var background := ColorRect.new()
	background.size = Vector2(1280, 840)
	background.color = Color("#142c40")
	canvas.add_child(background)
	var paths := [
		"res://assets/enemies/red_fang_goblin_club_run_sheet_v2.png",
		"res://assets/enemies/red_fang_goblin_elite_run_sheet_v2.png",
		"res://assets/enemies/red_fang_goblin_archer_run_sheet_v2.png",
	]
	for row in range(3):
		var texture := load(paths[row]) as Texture2D
		for col in range(4):
			var sprite := Sprite2D.new()
			sprite.texture = texture
			sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			sprite.region_enabled = true
			sprite.region_rect = Rect2(0, 0, texture.get_width() / 4.0, texture.get_height() / 2.0)
			sprite.centered = false
			sprite.position = Vector2(40 + col * 300, 60 + row * 250)
			sprite.scale = Vector2.ONE * (0.47 if col < 2 else 0.20)
			if col % 2 == 1:
				sprite.material = RogueEnemy.GOBLIN_EDGE_MATERIAL
			canvas.add_child(sprite)
			var caption := Label.new()
			caption.position = Vector2(40 + col * 300, 30 + row * 250)
			caption.text = ("原始边缘" if col % 2 == 0 else "修正边缘") + (" · 放大" if col < 2 else " · 游戏尺寸")
			canvas.add_child(caption)
	await _save("goblin_edge_comparison")
	print("capture_ui_fixes_preview: PASS")
	quit()

func _save(name_value: String) -> void:
	await process_frame
	await process_frame
	RenderingServer.force_draw(false)
	await process_frame
	var result := root.get_texture().get_image().save_png(OUTPUT + "/" + name_value + ".png")
	assert(result == OK)
