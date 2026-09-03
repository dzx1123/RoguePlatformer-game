extends SceneTree

const PREVIEW_SIZE := Vector2i(1280, 840)


func _initialize() -> void:
	call_deferred(&"_capture_preview")


func _capture_preview() -> void:
	root.content_scale_size = PREVIEW_SIZE
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_IGNORE
	root.size = PREVIEW_SIZE
	var main_scene: PackedScene = load("res://scenes/Main.tscn")
	var main: Node2D = main_scene.instantiate() as Node2D
	main.set("save_enabled", false)
	root.add_child(main)
	var player: RoguePlayer = main.get_node("Player") as RoguePlayer
	player.set_physics_process(false)
	await process_frame
	await process_frame
	player.apply_run_upgrade(&"tempered_edge")
	player.apply_run_upgrade(&"battle_rhythm")
	player.apply_run_upgrade(&"moon_expansion")
	player.apply_run_upgrade(&"moon_rupture")
	player.apply_run_upgrade(&"lunar_cycle")
	if not bool(main.call(&"open_build_overview_for_test")):
		push_error("Build overview preview could not open")
		quit(1)
		return
	await process_frame
	await process_frame
	var output_path: String = "user://build_overview_preview.png"
	var user_arguments: PackedStringArray = OS.get_cmdline_user_args()
	if not user_arguments.is_empty():
		output_path = user_arguments[0]
	var viewport_texture: Texture2D = root.get_texture()
	if viewport_texture == null:
		push_error("Build overview preview requires a rendered compatibility window")
		quit(1)
		return
	var image: Image = viewport_texture.get_image()
	if image == null:
		push_error("Build overview preview could not read the rendered viewport")
		quit(1)
		return
	var save_error: Error = image.save_png(output_path)
	if save_error != OK:
		push_error("Could not save build overview preview: %s" % error_string(save_error))
		quit(1)
		return
	print("capture_build_overview_preview: PASS %s" % output_path)
	quit(0)
