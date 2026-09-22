extends SceneTree

# Render actual physics poses at input/transition boundaries, using runtime materials.
var sheet: Node2D

func _initialize() -> void:
	call_deferred("run_capture")

func frames(count: int) -> void:
	for i in range(count):
		await physics_frame

func sample(player: RoguePlayer, column: int, row: int, label_text: String) -> void:
	var origin := Vector2(100 + column * 170, 165 + row * 180)
	var sprite := player.hero_sprite.duplicate() as Sprite2D
	sheet.add_child(sprite)
	sprite.position += origin
	var label := Label.new()
	label.text = label_text
	label.position = origin + Vector2(-75, 45)
	label.add_theme_font_size_override("font_size", 13)
	sheet.add_child(label)
	var line := Line2D.new()
	line.points = PackedVector2Array([origin + Vector2(-75, 28), origin + Vector2(75, 28)])
	line.width = 1
	line.default_color = Color("#37516a")
	sheet.add_child(line)

func run_capture() -> void:
	root.size = Vector2i(1380, 650)
	root.content_scale_size = root.size
	RenderingServer.set_default_clear_color(Color("#101b29"))
	for action in [&"restart", &"move_left", &"move_right", &"jump", &"attack", &"skill", &"dash"]:
		if not InputMap.has_action(action): InputMap.add_action(action)
	sheet = Node2D.new()
	root.add_child(sheet)
	var title := Label.new()
	title.text = "PLAYER RHYTHM / PHYSICS CAPTURE    Rows: Moon sword - Twin blades - Greatsword"
	title.position = Vector2(24, 18)
	sheet.add_child(title)
	var floor_body := StaticBody2D.new()
	var collider := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(10000, 100)
	collider.shape = shape
	floor_body.add_child(collider)
	floor_body.position = Vector2(0, 550)
	root.add_child(floor_body)
	for row in range(3):
		var p: RoguePlayer = load("res://scenes/Player.tscn").instantiate()
		p.position = Vector2(100, 470)
		root.add_child(p)
		p.hide()
		p.get_node("Camera2D").enabled = false
		p.configure_weapon(WeaponCatalog.all_weapon_ids()[row])
		await frames(20)
		Input.action_press(&"move_right")
		await frames(4)
		sample(p, 0, row, "START +50ms")
		await frames(15)
		sample(p, 1, row, "RUN")
		Input.action_press(&"attack")
		await frames(2)
		Input.action_release(&"attack")
		while p._attack_remaining > p.attack_duration * 0.60: await physics_frame
		sample(p, 2, row, "ATTACK / IMPACT")
		while p._attack_remaining > 0: await physics_frame
		await frames(2)
		sample(p, 3, row, "ATTACK -> RUN")
		Input.action_press(&"skill")
		await frames(2)
		Input.action_release(&"skill")
		while p._skill_remaining > p._skill_duration * 0.30: await physics_frame
		sample(p, 4, row, "SKILL / IMPACT")
		while p._skill_remaining > 0: await physics_frame
		await frames(2)
		sample(p, 5, row, "SKILL -> RUN")
		Input.action_release(&"move_right")
		Input.action_press(&"move_left")
		await frames(9)
		sample(p, 6, row, "TURN +150ms")
		Input.action_release(&"move_left")
		await frames(15)
		sample(p, 7, row, "STOP")
		p.queue_free()
		await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png("res://test_output/player_rhythm_preview.png")
	assert(error == OK)
	print("capture_player_rhythm: PASS")
	quit()
