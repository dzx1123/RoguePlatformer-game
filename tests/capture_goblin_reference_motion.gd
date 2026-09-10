extends SceneTree

const OUTPUT_PATH := "res://test_output/goblin_reference_motion.png"
const PREVIEW_SCALE := 1.35


func _initialize() -> void:
	call_deferred(&"_capture")


func _capture() -> void:
	root.content_scale_size = Vector2i(1440, 900)
	root.size = Vector2i(1440, 900)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	root.size = Vector2i(1440, 900)

	var canvas := Node2D.new()
	root.add_child(canvas)
	var background := ColorRect.new()
	background.size = Vector2(1440.0, 900.0)
	background.color = Color("#101a26")
	canvas.add_child(background)
	_add_label(canvas, "RED FANG GOBLIN / REFERENCE-MOTION RUNTIME FRAMES", Vector2(34.0, 20.0), 24)
	_add_label(canvas, "IDLE / LOW GUARD", Vector2(34.0, 92.0), 17)
	_add_label(canvas, "ATTACK / GUARD - WINDUP - LUNGE - RECOVERY", Vector2(34.0, 272.0), 17)
	_add_label(canvas, "HURT + DEATH / STAGGER - FALL - LAND - PRONE", Vector2(34.0, 452.0), 17)
	_add_label(canvas, "6-FRAME REFERENCE WALK", Vector2(34.0, 632.0), 17)

	for row_y in [238.0, 418.0, 598.0, 836.0]:
		var ground := Line2D.new()
		ground.add_point(Vector2(32.0, row_y))
		ground.add_point(Vector2(1408.0, row_y))
		ground.width = 2.0
		ground.default_color = Color("#395168")
		canvas.add_child(ground)

	for index in range(4):
		var idle := await _make_goblin(canvas, Vector2(230.0 + index * 315.0, 238.0))
		idle.set("_elapsed", (float(index) + 0.01) / RogueEnemy.GOBLIN_IDLE_FPS)
		idle.call(&"_update_sprite_animation", 1.0 / 60.0)
		_add_frame_number(canvas, index, Vector2(idle.position.x, 252.0))

	var attack_progresses: Array[float] = [0.08, 0.26, 0.48, 0.82]
	for index in range(4):
		var attacker := await _make_goblin(canvas, Vector2(230.0 + index * 315.0, 418.0))
		var attack_duration: float = float(attacker.call(&"_get_attack_duration"))
		attacker.set("_attack_remaining", attack_duration * (1.0 - attack_progresses[index]))
		attacker.call(&"_update_sprite_animation", 1.0 / 60.0)
		_add_frame_number(canvas, index, Vector2(attacker.position.x, 432.0))

	var death_progresses: Array[float] = [0.08, 0.32, 0.58, 0.84]
	for index in range(4):
		var defeated := await _make_goblin(canvas, Vector2(230.0 + index * 315.0, 598.0))
		defeated.set("_is_defeated", true)
		defeated.set(
			"_death_remaining",
			RogueEnemy.DEATH_ANIMATION_DURATION * (1.0 - death_progresses[index])
		)
		defeated.call(&"_update_sprite_animation", 1.0 / 60.0)
		(defeated.get_node("EnemySprite") as Sprite2D).modulate.a = 1.0
		_add_frame_number(canvas, index, Vector2(defeated.position.x, 612.0))

	for index in range(6):
		var walker := await _make_goblin(canvas, Vector2(150.0 + index * 225.0, 836.0))
		walker.velocity.x = -145.0
		walker.set("_locomotion_active", true)
		walker.set("_locomotion_cycle", float(index) + 0.01)
		walker.call(&"_update_sprite_animation", 1.0 / 60.0)
		_add_frame_number(canvas, index, Vector2(walker.position.x, 850.0))

	await process_frame
	await process_frame
	RenderingServer.force_draw(false)
	await process_frame
	var viewport_texture := root.get_texture()
	if viewport_texture == null:
		push_error("Runtime capture requires an active renderer")
		quit(1)
		return
	var capture_image := viewport_texture.get_image()
	if capture_image == null:
		push_error("Runtime capture did not produce an image")
		quit(1)
		return
	var result := capture_image.save_png(OUTPUT_PATH)
	assert(result == OK)
	print("capture_goblin_reference_motion: PASS")
	quit(0)


func _make_goblin(parent: Node, position_value: Vector2) -> RogueEnemy:
	var enemy := RogueEnemy.new()
	enemy.setup(
		0,
		0.0,
		-100.0,
		100.0,
		RogueEnemy.EnemyRole.MELEE,
		RogueEnemy.EnemyRank.NORMAL,
		1.0,
		1.0,
		RogueEnemy.EnemyFamily.GOBLIN
	)
	parent.add_child(enemy)
	await process_frame
	enemy.set_physics_process(false)
	enemy.set_process(false)
	enemy.position = position_value
	enemy.scale = Vector2.ONE * PREVIEW_SCALE
	enemy.velocity = Vector2.ZERO
	enemy.set("_facing", -1.0)
	enemy.set("_turn_remaining", 0.0)
	enemy.set("_locomotion_active", false)
	enemy.set("_locomotion_blend", 0.0)
	enemy.set("_sprite_pose_initialized", false)
	return enemy


func _add_label(parent: Node, text_value: String, position_value: Vector2, size_value: int) -> void:
	var label := Label.new()
	label.text = text_value
	label.position = position_value
	label.add_theme_font_size_override("font_size", size_value)
	label.add_theme_color_override("font_color", Color("#dbeeff"))
	parent.add_child(label)


func _add_frame_number(parent: Node, frame_index: int, position_value: Vector2) -> void:
	var label := Label.new()
	label.text = "%02d" % frame_index
	label.position = position_value - Vector2(13.0, 0.0)
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color("#79a9c9"))
	parent.add_child(label)
