extends Node2D

const WORLD_SIZE := Vector2(2200, 720)

var platform_rects := [
	Rect2(-80, 640, 2420, 160),
	Rect2(300, 520, 220, 32),
	Rect2(630, 448, 180, 32),
	Rect2(920, 555, 250, 32),
	Rect2(1280, 475, 200, 32),
	Rect2(1610, 540, 240, 32),
	Rect2(1930, 420, 180, 32),
]


func _ready() -> void:
	_configure_inputs()
	_create_platform_colliders()
	queue_redraw()


func _configure_inputs() -> void:
	_register_action(&"move_left", [KEY_A, KEY_LEFT])
	_register_action(&"move_right", [KEY_D, KEY_RIGHT])
	_register_action(&"jump", [KEY_W, KEY_UP, KEY_SPACE])
	_register_action(&"attack", [KEY_J])
	_register_action(&"dash", [KEY_K])
	_register_action(&"restart", [KEY_R])


func _register_action(action: StringName, key_codes: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)

	for key_code in key_codes:
		var event := InputEventKey.new()
		event.keycode = key_code
		InputMap.action_add_event(action, event)


func _create_platform_colliders() -> void:
	for platform_index in range(platform_rects.size()):
		var rect: Rect2 = platform_rects[platform_index]
		var body := StaticBody2D.new()
		body.name = "Platform_%02d" % platform_index
		body.collision_layer = 1
		body.collision_mask = 2
		body.position = rect.get_center()

		var collision := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = rect.size
		collision.shape = shape

		body.add_child(collision)
		add_child(body)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, WORLD_SIZE), Color("#101924"))

	# Distant silhouettes give the placeholder room a little depth.
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(0, 500), Vector2(260, 310), Vector2(520, 500),
			Vector2(790, 260), Vector2(1090, 500), Vector2(1430, 300),
			Vector2(1780, 500), Vector2(2200, 250), Vector2(2200, 640),
			Vector2(0, 640),
		]),
		Color("#17283a")
	)
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(0, 580), Vector2(370, 390), Vector2(720, 580),
			Vector2(1040, 410), Vector2(1400, 580), Vector2(1760, 360),
			Vector2(2200, 570), Vector2(2200, 640), Vector2(0, 640),
		]),
		Color("#1d3446")
	)

	for rect in platform_rects:
		var platform_rect: Rect2 = rect
		draw_rect(platform_rect, Color("#314f5e"))
		draw_rect(platform_rect, Color("#78bdc3"), false, 2.0)

	for x in range(80, int(WORLD_SIZE.x), 160):
		draw_line(Vector2(x, 120), Vector2(x, 620), Color(0.28, 0.54, 0.62, 0.08), 1.0)

	draw_circle(Vector2(140, 150), 54.0, Color("#ffd587"))
	draw_circle(Vector2(140, 150), 74.0, Color(1.0, 0.76, 0.42, 0.08))
