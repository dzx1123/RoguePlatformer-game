extends SceneTree

const PREVIEW_SIZE := Vector2i(1620, 360)
const SAMPLE_PROGRESS: Array[float] = [0.08, 0.22, 0.40, 0.50, 0.59, 0.70, 0.82, 0.94]
const SAMPLE_LABELS: Array[String] = [
	"ANTICIPATE",
	"UP COIL",
	"RISE CUT",
	"UP FOLLOW",
	"TURN",
	"DOWN CUT",
	"FOLLOW",
	"RECOVER",
	"RELEASE HOLD",
]


func _initialize() -> void:
	call_deferred(&"_capture_preview")


func _capture_preview() -> void:
	for action_name in [
		&"restart",
		&"move_left",
		&"move_right",
		&"jump",
		&"dash",
		&"attack",
		&"skill",
	]:
		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name)

	root.content_scale_size = PREVIEW_SIZE
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_IGNORE
	root.size = PREVIEW_SIZE
	RenderingServer.set_default_clear_color(Color("#0c1520"))
	var backdrop_layer := CanvasLayer.new()
	backdrop_layer.layer = -1
	root.add_child(backdrop_layer)
	var backdrop := ColorRect.new()
	backdrop.size = Vector2(PREVIEW_SIZE)
	backdrop.color = Color("#0c1520")
	backdrop_layer.add_child(backdrop)
	var title := Label.new()
	title.text = "MOON-WHEEL CHARACTER MOTION / 8 KEY POSES + STABLE RELEASE"
	title.position = Vector2(24.0, 18.0)
	title.add_theme_font_size_override("font_size", 19)
	title.add_theme_color_override("font_color", Color("#d8f7ff"))
	backdrop_layer.add_child(title)
	var floor_strip := ColorRect.new()
	floor_strip.position = Vector2(0.0, 286.0)
	floor_strip.size = Vector2(float(PREVIEW_SIZE.x), 74.0)
	floor_strip.color = Color("#182c3b")
	backdrop_layer.add_child(floor_strip)
	var floor_edge := ColorRect.new()
	floor_edge.position = Vector2(0.0, 284.0)
	floor_edge.size = Vector2(float(PREVIEW_SIZE.x), 2.0)
	floor_edge.color = Color("#72d9ed")
	backdrop_layer.add_child(floor_edge)

	var player_scene: PackedScene = load("res://scenes/Player.tscn")
	for sample_index in range(SAMPLE_LABELS.size()):
		var sample_x: float = 90.0 + 180.0 * float(sample_index)
		var divider := ColorRect.new()
		divider.position = Vector2(sample_x - 90.0, 64.0)
		divider.size = Vector2(1.0, 220.0)
		divider.color = Color(0.25, 0.47, 0.58, 0.28)
		backdrop_layer.add_child(divider)
		var label := Label.new()
		label.text = SAMPLE_LABELS[sample_index]
		label.position = Vector2(sample_x - 70.0, 74.0)
		label.size = Vector2(140.0, 24.0)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 13)
		label.add_theme_color_override("font_color", Color("#b8dbe8"))
		backdrop_layer.add_child(label)

		var player: RoguePlayer = player_scene.instantiate() as RoguePlayer
		root.add_child(player)
		player.set_physics_process(false)
		(player.get_node("Camera2D") as Camera2D).enabled = false
		player.global_position = Vector2(sample_x, 250.0)
		var skill_duration: float = float(player.get("_skill_duration"))
		if sample_index < SAMPLE_PROGRESS.size():
			player.set(
				"_skill_remaining",
				skill_duration * (1.0 - SAMPLE_PROGRESS[sample_index])
			)
		else:
			player.set("_skill_elapsed", skill_duration)
			player.call(&"_finish_skill")
		player.call(&"_update_hero_visuals", 1.0 / 60.0)
		(player.get_node("MoonWheelEffect") as Node2D).visible = false
		(player.get_node("SkillPoseEcho") as Sprite2D).visible = false

	await process_frame
	await process_frame
	var output_path := "user://skill_motion_preview.png"
	var user_arguments := OS.get_cmdline_user_args()
	if not user_arguments.is_empty():
		output_path = user_arguments[0]
	var image: Image = root.get_texture().get_image()
	var save_error := image.save_png(output_path)
	if save_error != OK:
		push_error("Could not save skill motion preview: %s" % error_string(save_error))
		quit(1)
		return
	print("capture_skill_motion_preview: PASS %s" % output_path)
	quit(0)
