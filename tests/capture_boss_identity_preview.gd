extends SceneTree

const PREVIEW_SIZE := Vector2i(1280, 520)


func _initialize() -> void:
	call_deferred(&"_capture_preview")


func _capture_preview() -> void:
	root.content_scale_size = PREVIEW_SIZE
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_IGNORE
	root.size = PREVIEW_SIZE
	RenderingServer.set_default_clear_color(Color("#091420"))
	var backdrop_layer: CanvasLayer = CanvasLayer.new()
	backdrop_layer.layer = -1
	root.add_child(backdrop_layer)
	var backdrop: ColorRect = ColorRect.new()
	backdrop.size = Vector2(PREVIEW_SIZE)
	backdrop.color = Color("#091420")
	backdrop_layer.add_child(backdrop)
	var title: Label = Label.new()
	title.text = "BOSS IDENTITIES / RANGE-ALIGNED TELEGRAPHS"
	title.position = Vector2(30.0, 22.0)
	title.size = Vector2(1220.0, 34.0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color("#d8f7ff"))
	backdrop_layer.add_child(title)
	var floor_strip: ColorRect = ColorRect.new()
	floor_strip.position = Vector2(0.0, 403.0)
	floor_strip.size = Vector2(float(PREVIEW_SIZE.x), 117.0)
	floor_strip.color = Color("#192e3d")
	backdrop_layer.add_child(floor_strip)
	var floor_edge: ColorRect = ColorRect.new()
	floor_edge.position = Vector2(0.0, 401.0)
	floor_edge.size = Vector2(float(PREVIEW_SIZE.x), 2.0)
	floor_edge.color = Color("#73d9ed")
	backdrop_layer.add_child(floor_edge)

	var target: Node2D = Node2D.new()
	target.position = Vector2(1140.0, 360.0)
	root.add_child(target)
	var crystal_king: RogueEnemy = _make_boss(
		Vector2(340.0, 350.0),
		RogueEnemy.EnemyFamily.SLIME,
		RogueEnemy.BossAttackPattern.SLAM
	)
	var war_chief: RogueEnemy = _make_boss(
		Vector2(930.0, 350.0),
		RogueEnemy.EnemyFamily.GOBLIN,
		RogueEnemy.BossAttackPattern.LUNGE
	)
	crystal_king.set_target(target)
	war_chief.set_target(target)
	_add_label(backdrop_layer, "CRYSTAL KING / WIDE CRYSTAL SLAM", Vector2(90.0, 82.0), Color("#86dfff"))
	_add_label(backdrop_layer, "WAR CHIEF / FAST CHARGE", Vector2(700.0, 82.0), Color("#ff9c4c"))

	await process_frame
	await process_frame
	var output_path: String = "user://boss_identity_preview.png"
	var user_arguments: PackedStringArray = OS.get_cmdline_user_args()
	if not user_arguments.is_empty():
		output_path = user_arguments[0]
	var viewport_texture: Texture2D = root.get_texture()
	if viewport_texture == null:
		push_error("Boss identity preview requires a rendered compatibility window")
		quit(1)
		return
	var image: Image = viewport_texture.get_image()
	if image == null:
		push_error("Boss identity preview could not read the rendered viewport")
		quit(1)
		return
	var save_error: Error = image.save_png(output_path)
	if save_error != OK:
		push_error("Could not save boss identity preview: %s" % error_string(save_error))
		quit(1)
		return
	print("capture_boss_identity_preview: PASS %s" % output_path)
	quit(0)


func _make_boss(position_value: Vector2, family: int, pattern: int) -> RogueEnemy:
	var boss: RogueEnemy = RogueEnemy.new()
	boss.position = position_value
	boss.setup(
		0,
		0.0,
		position_value.x - 320.0,
		position_value.x + 320.0,
		RogueEnemy.EnemyRole.MELEE,
		RogueEnemy.EnemyRank.BOSS,
		1.0,
		1.0,
		family,
		1.0,
		1.0
	)
	root.add_child(boss)
	boss.set_physics_process(false)
	boss.set("_boss_phase", 3)
	boss.set("_boss_attack_pattern", pattern)
	boss.set("_boss_attack_uses_projectile", pattern == RogueEnemy.BossAttackPattern.VOLLEY)
	boss.set("_attack_remaining", float(boss.call(&"_get_attack_duration")) * 0.52)
	boss.queue_redraw()
	return boss


func _add_label(layer: CanvasLayer, label_text: String, position_value: Vector2, color: Color) -> void:
	var label: Label = Label.new()
	label.text = label_text
	label.position = position_value
	label.size = Vector2(490.0, 30.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", color)
	layer.add_child(label)
