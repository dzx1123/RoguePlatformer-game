extends SceneTree


func _initialize() -> void:
	call_deferred(&"_run_test")


func _run_test() -> void:
	var main_scene: PackedScene = load("res://scenes/Main.tscn")
	var main: Node2D = main_scene.instantiate() as Node2D
	main.set("save_enabled", false)
	root.add_child(main)
	await physics_frame
	await process_frame

	main.call(&"_clear_enemies")
	main.call(&"_on_room_cleared")
	await process_frame
	var portal: RoomExitPortal = main.get_node_or_null("RoomExitPortal") as RoomExitPortal
	var portal_flow: Dictionary = main.call(&"get_run_flow_snapshot") as Dictionary
	if portal == null or portal.get_node_or_null("PromptBubble") == null:
		_fail("Clearing a room did not create a visible room-exit portal")
		return
	if not bool(portal_flow.get("awaiting_exit", false)):
		_fail("Clearing a room did not enter the room-exit flow phase")
		return
	var player: RoguePlayer = main.get_node("Player") as RoguePlayer
	if not bool(player.get("_input_enabled")):
		_fail("The player cannot walk to the room exit")
		return
	player.set_physics_process(false)
	player.global_position = portal.global_position + Vector2(-300.0, 0.0)
	if bool(main.call(&"_activate_room_exit")):
		_fail("Exit activated outside interaction range")
		return
	player.global_position = portal.global_position + Vector2(0.0, 120.0)
	if bool(main.call(&"_activate_room_exit")):
		_fail("Exit activated through a different platform level")
		return
	player.global_position = portal.global_position

	var key_event := InputEventKey.new()
	key_event.keycode = KEY_J
	key_event.pressed = true
	main.call(&"_on_always_key_pressed", key_event)
	await process_frame
	if not bool(main.call(&"is_awaiting_exit")):
		_fail("An attack key entered the portal without interaction")
		return
	main.call(&"_pause_game")
	if bool(main.call(&"_activate_room_exit")):
		_fail("Exit activated while paused")
		return
	main.call(&"_resume_game")
	key_event.keycode = KEY_E
	main.call(&"_on_always_key_pressed", key_event)
	await create_timer(0.32).timeout
	var next_flow: Dictionary = main.call(&"get_run_flow_snapshot") as Dictionary
	var upgrade_overlay: Control = main.get_node("HUD/UpgradeChoice") as Control
	if (
		not bool(next_flow.get("choosing_upgrade", false))
		or not upgrade_overlay.visible
		or main.get_node_or_null("RoomExitPortal") != null
	):
		_fail("Activating the room exit did not transition cleanly into the reward choice")
		return

	main.queue_free()
	await process_frame
	print("room_exit_portal_smoke: PASS")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
