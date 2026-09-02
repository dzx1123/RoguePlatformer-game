extends SceneTree

const PREVIEW_SIZE := Vector2i(1280, 840)


func _initialize() -> void:
	call_deferred(&"_capture")


func _capture() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Settings preview requires a rendering display; run the window hidden instead of using --headless")
		quit(1)
		return
	root.content_scale_size = PREVIEW_SIZE
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_IGNORE
	root.size = PREVIEW_SIZE
	var main_scene: PackedScene = load("res://scenes/Main.tscn")
	var main: Node2D = main_scene.instantiate() as Node2D
	main.set("save_enabled", false)
	root.add_child(main)
	await process_frame
	await process_frame
	main.call(&"_open_settings", false)
	await process_frame
	await process_frame
	var output_path := "user://settings_preview.png"
	var arguments := OS.get_cmdline_user_args()
	if not arguments.is_empty():
		output_path = String(arguments[0])
	var save_error: Error = root.get_texture().get_image().save_png(output_path)
	if save_error != OK:
		push_error("Could not save settings preview: %s" % error_string(save_error))
		quit(1)
		return
	print("capture_settings_preview: PASS %s" % output_path)
	quit(0)
