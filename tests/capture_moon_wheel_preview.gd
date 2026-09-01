extends SceneTree

const PREVIEW_SIZE := Vector2i(1280, 360)
const SAMPLE_PROGRESS: Array[float] = [0.12, 0.44, 0.60, 0.70, 0.82]
const SAMPLE_POSITIONS: Array[Vector2] = [
	Vector2(120.0, 250.0),
	Vector2(380.0, 250.0),
	Vector2(640.0, 250.0),
	Vector2(900.0, 250.0),
	Vector2(1160.0, 250.0),
]


func _initialize() -> void:
	call_deferred(&"_capture_preview")


func _capture_preview() -> void:
	for action_name in [&"restart", &"move_left", &"move_right", &"jump", &"dash", &"attack", &"skill"]:
		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name)

	root.size = PREVIEW_SIZE
	RenderingServer.set_default_clear_color(Color("#101a27"))
	var backdrop_layer := CanvasLayer.new()
	backdrop_layer.layer = -1
	root.add_child(backdrop_layer)
	var backdrop := ColorRect.new()
	backdrop.position = Vector2.ZERO
	backdrop.size = Vector2(PREVIEW_SIZE)
	backdrop.color = Color("#101a27")
	backdrop_layer.add_child(backdrop)
	var floor_strip := ColorRect.new()
	floor_strip.position = Vector2(0.0, 286.0)
	floor_strip.size = Vector2(float(PREVIEW_SIZE.x), 74.0)
	floor_strip.color = Color("#1b3040")
	backdrop_layer.add_child(floor_strip)
	var floor_edge := ColorRect.new()
	floor_edge.position = Vector2(0.0, 284.0)
	floor_edge.size = Vector2(float(PREVIEW_SIZE.x), 2.0)
	floor_edge.color = Color("#72d9ed")
	backdrop_layer.add_child(floor_edge)

	var label_layer := CanvasLayer.new()
	label_layer.layer = 3
	root.add_child(label_layer)
	var labels: Array[String] = [
		"WINDUP 12%",
		"DRAW MOON 44%",
		"DARK MOON 60%",
		"SHATTER HIT 70%",
		"SHARDS 82% / LEFT",
	]
	for label_index in range(labels.size()):
		var label := Label.new()
		label.text = labels[label_index]
		label.position = Vector2(SAMPLE_POSITIONS[label_index].x - 92.0, 24.0)
		label.add_theme_font_size_override("font_size", 16)
		label.add_theme_color_override("font_color", Color("#d8f7ff"))
		label_layer.add_child(label)

	var player_scene: PackedScene = load("res://scenes/Player.tscn")
	for sample_index in range(SAMPLE_PROGRESS.size()):
		var player: RoguePlayer = player_scene.instantiate() as RoguePlayer
		root.add_child(player)
		player.set_physics_process(false)
		(player.get_node("Camera2D") as Camera2D).enabled = false
		player.global_position = SAMPLE_POSITIONS[sample_index]
		if sample_index == SAMPLE_PROGRESS.size() - 1:
			player.set("_facing", -1.0)
		var skill_duration: float = float(player.get("_skill_duration"))
		player.set(
			"_skill_remaining",
			skill_duration * (1.0 - SAMPLE_PROGRESS[sample_index])
		)
		player.call(&"_update_hero_visuals", 1.0 / 60.0)

	await process_frame
	await process_frame
	var output_path := "user://moon_wheel_preview.png"
	var user_arguments := OS.get_cmdline_user_args()
	if not user_arguments.is_empty():
		output_path = user_arguments[0]
	var image: Image = root.get_texture().get_image()
	var save_error := image.save_png(output_path)
	if save_error != OK:
		push_error("Could not save moon-wheel preview: %s" % error_string(save_error))
		quit(1)
		return
	print("capture_moon_wheel_preview: PASS %s" % output_path)
	quit(0)
