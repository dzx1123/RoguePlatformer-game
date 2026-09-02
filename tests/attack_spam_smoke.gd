extends SceneTree

var _attack_hit_count: int = 0


func _initialize() -> void:
	call_deferred(&"_run_test")


func _run_test() -> void:
	var main_scene: PackedScene = load("res://scenes/Main.tscn")
	var main: Node2D = main_scene.instantiate() as Node2D
	main.set("save_enabled", false)
	root.add_child(main)
	var player: RoguePlayer = main.get_node("Player") as RoguePlayer
	player.attack_hit.connect(_on_attack_hit)
	for _settle_frame in range(20):
		await physics_frame

	var initial_enemies: Array = main.get("_enemies") as Array
	if initial_enemies.size() < 2:
		main.call(
			&"_spawn_enemy",
			Vector2(1180.0, 590.0),
			1120.0,
			1220.0,
			0,
			0,
			0,
			99
		)
		await physics_frame
		initial_enemies = main.get("_enemies") as Array
	var initial_enemy_count: int = initial_enemies.size()
	if initial_enemy_count <= 0:
		_fail("Main scene did not create an enemy for the hit test")
		return
	for enemy_index in range(initial_enemy_count):
		var enemy_node: Node2D = initial_enemies[enemy_index] as Node2D
		enemy_node.set_physics_process(false)
		enemy_node.global_position = Vector2(1500.0 + float(enemy_index) * 55.0, 590.0)
	var target_enemy: Node2D = initial_enemies[0] as Node2D
	target_enemy.global_position = player.global_position + Vector2(70.0, 0.0)
	target_enemy.set("_current_health", 1)

	_send_attack_key(true, false)
	await physics_frame
	_send_attack_key(false, false)
	var enemy_defeat_observed: bool = false
	for _defeat_wait_frame in range(40):
		await physics_frame
		var enemies_after_hit: Array = main.get("_enemies") as Array
		if enemies_after_hit.size() == initial_enemy_count - 1:
			enemy_defeat_observed = true
			break
	if not enemy_defeat_observed:
		_fail("A confirmed sword hit did not remove the target enemy")
		return

	for _room_stability_frame in range(100):
		await physics_frame
	var enemies_after_defeat: Array = main.get("_enemies") as Array
	if enemies_after_defeat.size() != initial_enemy_count - 1:
		_fail(
			"Room enemy count changed unexpectedly: expected %d enemies, found %d"
			% [initial_enemy_count - 1, enemies_after_defeat.size()]
		)
		return

	_send_attack_key(true, false)
	await physics_frame
	_send_attack_key(false, false)
	for _pre_hit_frame in range(3):
		await physics_frame
	player.receive_enemy_attack(player.global_position + Vector2(24.0, 0.0))
	if float(player.get("_attack_remaining")) <= 0.0:
		_fail("An enemy hit cancelled the active player attack")
		return
	for _armored_attack_recovery_frame in range(32):
		await physics_frame
	if int(player.get("_visual_state")) == RoguePlayer.VisualState.ATTACK:
		_fail("Enemy contact left the player stuck in ATTACK")
		return

	player.set("_hurt_invulnerability_remaining", 100.0)
	var held_attack_start_count: int = _attack_hit_count
	_send_attack_key(true, false)
	var late_hold_attack_frames: int = 0
	for hold_frame_index in range(90):
		if hold_frame_index % 3 == 0:
			_send_attack_key(true, true)
		await physics_frame
		if (
			hold_frame_index >= 35
			and int(player.get("_visual_state")) == RoguePlayer.VisualState.ATTACK
		):
			late_hold_attack_frames += 1
	_send_attack_key(false, false)
	for _held_recovery_frame in range(30):
		await physics_frame
	var held_attack_count: int = _attack_hit_count - held_attack_start_count
	if held_attack_count != 1:
		_fail(
			"A held/repeating J key produced %d attacks instead of exactly 1"
			% held_attack_count
		)
		return
	if late_hold_attack_frames > 0:
		_fail("Player returned to ATTACK while J remained held")
		return

	var start_x: float = player.global_position.x
	Input.action_press(&"move_right")
	for _tap_index in range(80):
		_send_attack_key(true, false)
		await physics_frame
		_send_attack_key(false, false)
		await physics_frame
		await physics_frame
	Input.action_release(&"move_right")

	for _recovery_frame in range(60):
		await physics_frame

	var attack_remaining: float = float(player.get("_attack_remaining"))
	var cooldown_remaining: float = float(player.get("_attack_cooldown_remaining"))
	var attack_elapsed: float = float(player.get("_attack_elapsed"))
	var visual_state: int = int(player.get("_visual_state"))
	if attack_remaining > 0.0 or cooldown_remaining > 0.0 or attack_elapsed > 0.0:
		_fail(
			"Attack timers stayed active: attack=%.3f cooldown=%.3f elapsed=%.3f"
			% [attack_remaining, cooldown_remaining, attack_elapsed]
		)
		return
	if visual_state == RoguePlayer.VisualState.ATTACK:
		_fail("Player remained stuck in the attack visual state")
		return
	if player.global_position.x - start_x < 350.0:
		_fail(
			"Repeated attacks blocked movement: moved only %.1f pixels"
			% (player.global_position.x - start_x)
		)
		return
	if _attack_hit_count < 2:
		_fail("Spam input produced only %d attack hits" % _attack_hit_count)
		return

	print("attack_spam_smoke: PASS hits=%d" % _attack_hit_count)
	quit(0)


func _on_attack_hit(_origin: Vector2, _facing: float) -> void:
	_attack_hit_count += 1


func _send_attack_key(pressed: bool, is_echo: bool) -> void:
	var key_event := InputEventKey.new()
	key_event.keycode = KEY_J
	key_event.pressed = pressed
	key_event.echo = is_echo
	Input.parse_input_event(key_event)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
