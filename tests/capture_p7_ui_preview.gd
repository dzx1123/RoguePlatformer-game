extends SceneTree

const PREVIEW_SIZE := Vector2i(1280, 840)


func _initialize() -> void:
	call_deferred(&"_capture_preview")


func _capture_preview() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("P7 UI preview requires a rendered compatibility window")
		quit(1)
		return
	root.content_scale_size = PREVIEW_SIZE
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_IGNORE
	root.size = PREVIEW_SIZE
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	var mode: String = "menu"
	var output_path: String = "user://p7_ui_preview.png"
	if not arguments.is_empty():
		mode = String(arguments[0])
	if arguments.size() >= 2:
		output_path = String(arguments[1])

	var main_scene: PackedScene = load("res://scenes/Main.tscn")
	var main: Node2D = main_scene.instantiate() as Node2D
	if mode in ["portal", "upgrade"]:
		main.set("save_enabled", false)
	root.add_child(main)
	await physics_frame
	await process_frame

	match mode:
		"difficulty":
			main.call(&"_show_difficulty_selection")
		"portal", "upgrade":
			main.call(&"_clear_enemies")
			main.call(&"_on_room_cleared")
			await process_frame
			if mode == "upgrade":
				main.call(&"_activate_room_exit")
				await create_timer(0.30).timeout
		_:
			pass

	await create_timer(0.72).timeout
	var viewport_texture: Texture2D = root.get_texture()
	if viewport_texture == null:
		push_error("P7 UI preview could not read the rendered viewport")
		quit(1)
		return
	var image: Image = viewport_texture.get_image()
	var save_error: Error = image.save_png(output_path)
	if save_error != OK:
		push_error("Could not save P7 UI preview: %s" % error_string(save_error))
		quit(1)
		return
	print("capture_p7_ui_preview: PASS %s" % output_path)
	quit(0)
