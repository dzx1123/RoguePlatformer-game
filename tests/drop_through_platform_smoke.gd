extends SceneTree


func _initialize() -> void:
	call_deferred(&"_run_test")


func _run_test() -> void:
	for action_name in [&"restart", &"move_left", &"move_right", &"jump", &"dash", &"attack", &"skill", &"aim_up", &"aim_down"]:
		_ensure_action(action_name)
	_create_platform(Rect2(-140.0, 260.0, 280.0, 20.0), true)
	_create_platform(Rect2(-240.0, 520.0, 480.0, 40.0), false)

	var player_scene: PackedScene = load("res://scenes/Player.tscn")
	var player: RoguePlayer = player_scene.instantiate() as RoguePlayer
	player.auto_respawn = false
	player.position = Vector2(0.0, 185.0)
	player.set_base_ground_surface_y(520.0)
	root.add_child(player)
	for _frame in range(36):
		await physics_frame
	if not player.is_on_floor() or player.global_position.y > 244.0:
		_fail("Player did not land on the upper one-way platform")
		return

	Input.action_press(&"aim_down")
	Input.action_press(&"jump")
	await physics_frame
	await physics_frame
	Input.action_release(&"jump")
	Input.action_release(&"aim_down")
	for _frame in range(42):
		await physics_frame
	if player.global_position.y < 455.0 or not player.is_on_floor():
		_fail("Down plus jump did not drop through the upper platform onto the lower floor")
		return
	if not player.get_collision_mask_value(1):
		_fail("Player collision mask did not restore after dropping through")
		return

	player.queue_free()
	print("drop_through_platform_smoke: PASS")
	quit(0)


func _create_platform(rect: Rect2, one_way: bool) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.position = rect.get_center()
	if one_way:
		body.add_to_group(&"drop_through_platform")
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	collision.shape = shape
	collision.one_way_collision = one_way
	body.add_child(collision)
	root.add_child(body)


func _ensure_action(action_name: StringName) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
