extends SceneTree

const PREVIEW_SIZE := Vector2i(1280, 460)
const WEAPON_IDS: Array[StringName] = [
	WeaponCatalog.SWORD,
	WeaponCatalog.TWIN_BLADES,
	WeaponCatalog.GREATSWORD,
]
const SAMPLE_PROGRESS: Array[float] = [0.70, 0.48, 0.62]
const SAMPLE_POSITIONS: Array[Vector2] = [
	Vector2(210.0, 330.0),
	Vector2(640.0, 330.0),
	Vector2(1070.0, 330.0),
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
	RenderingServer.set_default_clear_color(Color("#0a121d"))
	var backdrop_layer := CanvasLayer.new()
	backdrop_layer.layer = -1
	root.add_child(backdrop_layer)
	var backdrop := ColorRect.new()
	backdrop.size = Vector2(PREVIEW_SIZE)
	backdrop.color = Color("#0a121d")
	backdrop_layer.add_child(backdrop)
	var title := Label.new()
	title.text = "THREE WEAPONS / DISTINCT ACTIVE SKILL HIT FRAMES"
	title.position = Vector2(30.0, 22.0)
	title.size = Vector2(1220.0, 32.0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 21)
	title.add_theme_color_override("font_color", Color("#d8f7ff"))
	backdrop_layer.add_child(title)
	var floor_strip := ColorRect.new()
	floor_strip.position = Vector2(0.0, 366.0)
	floor_strip.size = Vector2(float(PREVIEW_SIZE.x), 94.0)
	floor_strip.color = Color("#182c3b")
	backdrop_layer.add_child(floor_strip)
	var floor_edge := ColorRect.new()
	floor_edge.position = Vector2(0.0, 364.0)
	floor_edge.size = Vector2(float(PREVIEW_SIZE.x), 2.0)
	floor_edge.color = Color("#72d9ed")
	backdrop_layer.add_child(floor_edge)

	var player_scene: PackedScene = load("res://scenes/Player.tscn")
	for weapon_index in range(WEAPON_IDS.size()):
		var weapon_id: StringName = WEAPON_IDS[weapon_index]
		var weapon: Dictionary = WeaponCatalog.get_weapon(weapon_id)
		var sample_position: Vector2 = SAMPLE_POSITIONS[weapon_index]
		if weapon_index > 0:
			var divider := ColorRect.new()
			divider.position = Vector2(sample_position.x - 215.0, 74.0)
			divider.size = Vector2(1.0, 288.0)
			divider.color = Color(0.28, 0.53, 0.64, 0.36)
			backdrop_layer.add_child(divider)
		var label := Label.new()
		label.text = "%s  /  %s" % [
			String(weapon.get("name", "武器")),
			String(weapon.get("skill_name", "主动技能")),
		]
		label.position = Vector2(sample_position.x - 190.0, 86.0)
		label.size = Vector2(380.0, 32.0)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 19)
		label.add_theme_color_override(
			"font_color",
			weapon.get("accent", Color.WHITE)
		)
		backdrop_layer.add_child(label)

		var player: RoguePlayer = player_scene.instantiate() as RoguePlayer
		root.add_child(player)
		player.set_physics_process(false)
		(player.get_node("Camera2D") as Camera2D).enabled = false
		player.configure_weapon(weapon_id)
		player.global_position = sample_position
		var skill_duration: float = float(player.get("_skill_duration"))
		player.set(
			"_skill_remaining",
			skill_duration * (1.0 - SAMPLE_PROGRESS[weapon_index])
		)
		player.call(&"_update_hero_visuals", 1.0 / 60.0)
		(player.get_node("SkillPoseEcho") as Sprite2D).visible = false

	await process_frame
	await process_frame
	var output_path := "user://weapon_skill_preview.png"
	var user_arguments := OS.get_cmdline_user_args()
	if not user_arguments.is_empty():
		output_path = user_arguments[0]
	var image: Image = root.get_texture().get_image()
	var save_error: Error = image.save_png(output_path)
	if save_error != OK:
		push_error("Could not save weapon skill preview: %s" % error_string(save_error))
		quit(1)
		return
	print("capture_weapon_skill_preview: PASS %s" % output_path)
	quit(0)
