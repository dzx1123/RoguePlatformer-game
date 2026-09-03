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

	var key_event := InputEventKey.new()
	key_event.keycode = KEY_J
	key_event.pressed = true
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
