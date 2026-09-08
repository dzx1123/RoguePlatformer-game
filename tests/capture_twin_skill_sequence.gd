extends SceneTree

const PREVIEW_SIZE := Vector2i(1440, 900)
const SAMPLE_PROGRESS: Array[float] = [
	0.02,
	0.075,
	0.12,
	0.18,
	0.28,
	0.48,
	0.585,
	0.67,
	0.73,
	0.78,
	0.88,
	0.96,
]
const SAMPLE_LABELS: Array[String] = [
	"READY",
	"PARTIAL DRAW",
	"COIL",
	"CUT 1 / HIT",
	"FOLLOW 1",
	"CUT 2 / HIT",
	"CROSS RISE",
	"RISE FOLLOW",
	"FINISH PREP",
	"CUT 3 / HIT",
	"RE-SHEATH",
	"RECOVER",
]


func _initialize() -> void:
	call_deferred(&"_capture_preview")


func _capture_preview() -> void:
	for action_name: StringName in [
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
	RenderingServer.set_default_clear_color(Color("#09131f"))
	var backdrop_layer := CanvasLayer.new()
	backdrop_layer.layer = -1
	root.add_child(backdrop_layer)
	var backdrop := ColorRect.new()
	backdrop.size = Vector2(PREVIEW_SIZE)
	backdrop.color = Color("#09131f")
	backdrop_layer.add_child(backdrop)

	var title := Label.new()
	title.text = "SHADOW-WEAVE TWIN BLADES / 12-POSE FLASH-CUT SEQUENCE"
	title.position = Vector2(30.0, 18.0)
	title.size = Vector2(1380.0, 34.0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color("#d8f7ff"))
	backdrop_layer.add_child(title)

	var player_scene: PackedScene = load("res://scenes/Player.tscn")
	var cell_size := Vector2(360.0, 270.0)
	for sample_index in range(SAMPLE_PROGRESS.size()):
		var column: int = sample_index % 4
		var row_index: int = sample_index / 4
		var cell_origin := Vector2(column * cell_size.x, 62.0 + row_index * cell_size.y)
		var panel := ColorRect.new()
		panel.position = cell_origin + Vector2(8.0, 4.0)
		panel.size = cell_size - Vector2(16.0, 10.0)
		panel.color = Color("#0d1d2b") if (column + row_index) % 2 == 0 else Color("#102434")
		backdrop_layer.add_child(panel)

		var floor_y := cell_origin.y + 222.0
		var floor_edge := ColorRect.new()
		floor_edge.position = Vector2(cell_origin.x + 18.0, floor_y)
		floor_edge.size = Vector2(cell_size.x - 36.0, 2.0)
		floor_edge.color = Color(0.45, 0.85, 0.93, 0.55)
		backdrop_layer.add_child(floor_edge)

		var label := Label.new()
		label.text = "%02d  %s  /  %.3f" % [
			sample_index,
			SAMPLE_LABELS[sample_index],
			SAMPLE_PROGRESS[sample_index],
		]
		label.position = cell_origin + Vector2(12.0, 12.0)
		label.size = Vector2(cell_size.x - 24.0, 24.0)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 14)
		label.add_theme_color_override("font_color", Color("#b8dbe8"))
		backdrop_layer.add_child(label)

		var player: RoguePlayer = player_scene.instantiate() as RoguePlayer
		root.add_child(player)
		player.set_physics_process(false)
		(player.get_node("Camera2D") as Camera2D).enabled = false
		player.configure_weapon(WeaponCatalog.TWIN_BLADES)
		# Player.tscn's origin is above the rendered sole line.  Keep the same
		# 34 px preview offset used by the other character-motion capture boards.
		player.global_position = Vector2(cell_origin.x + cell_size.x * 0.5, floor_y - 34.0)
		var skill_duration: float = float(player.get("_skill_duration"))
		player.set(
			"_skill_remaining",
			skill_duration * (1.0 - SAMPLE_PROGRESS[sample_index])
		)
		player.call(&"_update_hero_visuals", 1.0 / 60.0)
		(player.get_node("WeaponSkillEffect") as CanvasItem).visible = false
		(player.get_node("SkillPoseEcho") as CanvasItem).visible = false

	await process_frame
	await process_frame
	var output_path := "user://twin_skill_sequence.png"
	var user_arguments := OS.get_cmdline_user_args()
	if not user_arguments.is_empty():
		output_path = user_arguments[0]
	var image: Image = root.get_texture().get_image()
	var save_error := image.save_png(output_path)
	if save_error != OK:
		push_error("Could not save twin skill sequence: %s" % error_string(save_error))
		quit(1)
		return
	print("capture_twin_skill_sequence: PASS %s" % output_path)
	quit(0)
