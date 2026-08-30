extends SceneTree


func _initialize() -> void:
	call_deferred(&"_run_test")


func _run_test() -> void:
	for action_name in [&"restart", &"move_left", &"move_right", &"jump", &"aim_up", &"aim_down", &"dash", &"skill", &"attack"]:
		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name)
	_bind_action_key(&"aim_up", KEY_W)
	_bind_action_key(&"aim_down", KEY_S)
	_bind_action_key(&"attack", KEY_J)
	for frame_name in [
		"hero_slash_up_windup.png",
		"hero_slash_up.png",
		"hero_slash_down_windup.png",
		"hero_slash_down.png",
	]:
		var texture := load("res://assets/characters/frames_polished/%s" % frame_name) as Texture2D
		if texture == null or texture.get_size() != Vector2(640.0, 416.0):
			_fail("Generated attack frame is missing or has wrong size: %s" % frame_name)
			return

	var enemy := RogueEnemy.new()
	enemy.position = Vector2(100.0, 160.0)
	enemy.setup(0, 0.0, 0.0, 200.0)
	if not enemy.is_hit_by_attack(Vector2(100.0, 300.0), 1.0, 1.0, RoguePlayer.AttackType.UPWARD):
		_fail("Up slash did not reach an enemy above the player")
		return
	enemy.position = Vector2(100.0, 400.0)
	if not enemy.is_hit_by_attack(Vector2(100.0, 300.0), 1.0, 1.0, RoguePlayer.AttackType.DOWNWARD):
		_fail("Down slash did not reach an enemy below the player")
		return

	var player_scene: PackedScene = load("res://scenes/Player.tscn")
	var player: RoguePlayer = player_scene.instantiate() as RoguePlayer
	root.add_child(player)
	await process_frame
	player.call(&"_start_attack", RoguePlayer.AttackType.DOWNWARD)
	player.confirm_attack_connected()
	if player.velocity.y > -459.0:
		_fail("Confirmed down slash did not rebound the player")
		return
	player.call(&"_finish_attack")
	player.set("_attack_cooldown_remaining", 0.0)
	Input.action_press(&"aim_up")
	Input.action_press(&"attack")
	await physics_frame
	await physics_frame
	Input.action_release(&"attack")
	Input.action_release(&"aim_up")
	await physics_frame
	if player.get_attack_type() != RoguePlayer.AttackType.UPWARD:
		_fail("Up direction plus attack did not produce an up slash")
		return
	player.call(&"_finish_attack")
	player.set("_attack_cooldown_remaining", 0.0)
	Input.action_press(&"aim_down")
	Input.action_press(&"attack")
	await physics_frame
	await physics_frame
	Input.action_release(&"attack")
	Input.action_release(&"aim_down")
	if player.get_attack_type() != RoguePlayer.AttackType.DOWNWARD:
		_fail("Down direction plus attack did not produce a down slash")
		return
	enemy.queue_free()
	player.queue_free()
	await process_frame
	print("vertical_attack_smoke: PASS")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)


func _bind_action_key(action_name: StringName, keycode: Key) -> void:
	InputMap.action_erase_events(action_name)
	var event := InputEventKey.new()
	event.keycode = keycode
	InputMap.action_add_event(action_name, event)
