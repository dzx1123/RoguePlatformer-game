extends SceneTree

const OUTPUT := "res://tests/artifacts/ui-fixes"

func _initialize() -> void:
	call_deferred(&"_capture")

func _capture() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	root.content_scale_size = Vector2i(1280, 720)
	root.size = Vector2i(1280, 720)
	var main := (load("res://scenes/Main.tscn") as PackedScene).instantiate() as Node2D
	main.set("save_enabled", false)
	root.add_child(main)
	await process_frame
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	root.size = Vector2i(1280, 720)
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
	print("capture_ui_fixes_preview: PASS")
	quit()

func _save(name_value: String) -> void:
	await process_frame
	await process_frame
	RenderingServer.force_draw(false)
	await process_frame
	var result := root.get_texture().get_image().save_png(OUTPUT + "/" + name_value + ".png")
	assert(result == OK)
