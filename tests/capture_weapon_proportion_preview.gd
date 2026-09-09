extends SceneTree

const PREVIEW_SIZE := Vector2i(1500, 1560)
const HERO_SCALE := 0.22
const COLUMN_X := [250.0, 750.0, 1250.0]
const COLUMN_LABELS := ["ONE-HAND SWORD / CANON", "TWIN BLADES", "GREATSWORD"]
const ROW_HEIGHT := 112.0
const FIRST_ROW_Y := 176.0
const ACTIONS := [
	{
		"label": "IDLE",
		"sword": "hero_idle.png",
		"twin": "hero_idle.png",
		"great": "hero_idle.png",
	},
	{
		"label": "RUN 00 / CONTACT",
		"sword": "hero_run_0.png",
		"twin": "hero_run_0.png",
		"great": "hero_run_0.png",
	},
	{
		"label": "RUN 07 / AIR",
		"sword": "hero_run_7.png",
		"twin": "hero_run_7.png",
		"great": "hero_run_7.png",
	},
	{
		"label": "JUMP / TAKEOFF",
		"sword": "hero_jump_takeoff.png",
		"twin": "hero_jump_takeoff.png",
		"great": "hero_jump_takeoff.png",
	},
	{
		"label": "JUMP / RISE",
		"sword": "hero_jump_rise_v2.png",
		"twin": "hero_jump_rise.png",
		"great": "hero_jump_rise.png",
	},
	{
		"label": "JUMP / APEX",
		"sword": "hero_jump_apex_v2.png",
		"twin": "hero_jump_apex.png",
		"great": "hero_jump_apex.png",
	},
	{
		"label": "JUMP / FALL",
		"sword": "hero_jump_fall.png",
		"twin": "hero_jump_fall.png",
		"great": "hero_jump_fall.png",
	},
	{
		"label": "LAND",
		"sword": "hero_land.png",
		"twin": "hero_land.png",
		"great": "hero_land.png",
	},
	{
		"label": "FORWARD / WINDUP",
		"sword": "hero_windup.png",
		"twin": "hero_attack_forward_windup.png",
		"great": "hero_attack_forward_windup.png",
	},
	{
		"label": "FORWARD / STRIKE",
		"sword": "hero_slash.png",
		"twin": "hero_attack_forward_strike.png",
		"great": "hero_attack_forward_strike.png",
	},
	{
		"label": "UP / STRIKE",
		"sword": "hero_slash_up.png",
		"twin": "hero_attack_up_strike.png",
		"great": "hero_attack_up_strike.png",
	},
	{
		"label": "DOWN / STRIKE",
		"sword": "hero_slash_down.png",
		"twin": "hero_attack_down_strike.png",
		"great": "hero_attack_down_strike.png",
	},
	{
		"label": "ACTIVE SKILL / HIT",
		"sword": "hero_slash_down.png",
		"twin": "hero_skill_9.png",
		"great": "hero_skill_b.png",
	},
]


func _initialize() -> void:
	call_deferred(&"_capture_preview")


func _capture_preview() -> void:
	for action: StringName in [&"restart", &"move_left", &"move_right", &"jump", &"dash", &"attack", &"skill"]:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
	root.content_scale_size = PREVIEW_SIZE
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_IGNORE
	root.size = PREVIEW_SIZE
	RenderingServer.set_default_clear_color(Color("#08121e"))

	var background := ColorRect.new()
	background.size = Vector2(PREVIEW_SIZE)
	background.color = Color("#08121e")
	root.add_child(background)

	var title := Label.new()
	title.text = "WEAPON CHARACTER PROPORTION / ONE-HAND CANON"
	title.position = Vector2(24.0, 18.0)
	title.size = Vector2(PREVIEW_SIZE.x - 48.0, 36.0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color("#d8f7ff"))
	root.add_child(title)

	for column_index in range(COLUMN_X.size()):
		var column_label := Label.new()
		column_label.text = COLUMN_LABELS[column_index]
		column_label.position = Vector2(COLUMN_X[column_index] - 220.0, 72.0)
		column_label.size = Vector2(440.0, 30.0)
		column_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column_label.add_theme_font_size_override("font_size", 18)
		column_label.add_theme_color_override(
			"font_color",
			Color("#74dff6") if column_index == 0 else Color("#f0c58d")
		)
		root.add_child(column_label)

	for row_index in range(ACTIONS.size()):
		var row_y := FIRST_ROW_Y + float(row_index) * ROW_HEIGHT
		var row_data: Dictionary = ACTIONS[row_index]
		var stripe := ColorRect.new()
		stripe.position = Vector2(0.0, row_y - ROW_HEIGHT * 0.50)
		stripe.size = Vector2(PREVIEW_SIZE.x, ROW_HEIGHT)
		stripe.color = Color("#0d1a38") if row_index % 2 == 0 else Color("#0b1828")
		stripe.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(stripe)

		var row_label := Label.new()
		row_label.text = String(row_data["label"])
		row_label.position = Vector2(14.0, row_y - 50.0)
		row_label.size = Vector2(190.0, 26.0)
		row_label.add_theme_font_size_override("font_size", 13)
		row_label.add_theme_color_override("font_color", Color("#a9cbd8"))
		root.add_child(row_label)

		for column_index in range(COLUMN_X.size()):
			var guide := Line2D.new()
			guide.width = 1.0
			guide.default_color = Color(0.34, 0.72, 0.82, 0.34)
			guide.points = PackedVector2Array([
				Vector2(COLUMN_X[column_index] - 182.0, row_y + 38.0),
				Vector2(COLUMN_X[column_index] + 182.0, row_y + 38.0),
			])
			root.add_child(guide)

		_add_pose(
			_sword_path(String(row_data["sword"])),
			Vector2(COLUMN_X[0], row_y)
		)
		_add_pose(
			_weapon_path("twin_blades", String(row_data["twin"])),
			Vector2(COLUMN_X[1], row_y)
		)
		_add_pose(
			_weapon_path("greatsword", String(row_data["great"])),
			Vector2(COLUMN_X[2], row_y)
		)

	await process_frame
	await process_frame
	RenderingServer.force_draw()
	await RenderingServer.frame_post_draw
	var output_path := "user://weapon_proportion_preview.png"
	var arguments := OS.get_cmdline_user_args()
	if not arguments.is_empty():
		output_path = arguments[0]
	var image := root.get_texture().get_image()
	var save_error := image.save_png(output_path)
	if save_error != OK:
		push_error("Could not save weapon proportion preview: %s" % error_string(save_error))
		quit(1)
		return
	print("capture_weapon_proportion_preview: PASS %s" % output_path)
	quit(0)


func _add_pose(texture_path: String, center: Vector2) -> void:
	var player := (load("res://scenes/Player.tscn") as PackedScene).instantiate() as RoguePlayer
	(player.get_node("Camera2D") as Camera2D).enabled = false
	root.add_child(player)
	player.set_physics_process(false)
	player.position = center
	var weapon: StringName = WeaponCatalog.SWORD
	if texture_path.contains("/twin_blades/"):
		weapon = WeaponCatalog.TWIN_BLADES
	elif texture_path.contains("/greatsword/"):
		weapon = WeaponCatalog.GREATSWORD
	player.configure_weapon(weapon)
	player.call(&"_reset_sprite_pose")
	player.call(&"_set_texture", load(texture_path))
	player.call(&"_apply_weapon_pose_calibration")
	player.get_node("HeroSprite").z_index = 2

func _sword_path(filename: String) -> String:
	return "res://assets/characters/frames_polished/%s" % filename


func _weapon_path(weapon_dir: String, filename: String) -> String:
	return "res://assets/characters/weapon_sets/%s/%s" % [weapon_dir, filename]
