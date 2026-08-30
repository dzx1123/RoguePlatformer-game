extends SceneTree


func _initialize() -> void:
	call_deferred(&"_run_test")


func _run_test() -> void:
	var main_scene: PackedScene = load("res://scenes/Main.tscn")
	var menu_main: Node2D = main_scene.instantiate() as Node2D
	root.add_child(menu_main)
	await process_frame
	var entry: Control = menu_main.get_node("HUD/EntryFlow") as Control
	if not entry.visible or (entry.get_node("EntrySettings") as Button) == null:
		_fail("Main menu did not expose the settings entry")
		return
	(entry.get_node("EntrySettings") as Button).emit_signal("pressed")
	await process_frame
	var settings_menu: Control = menu_main.get_node("HUD/SettingsMenu") as Control
	if (
		not settings_menu.visible
		or (settings_menu.get_node("Bind_dash") as Button) == null
		or (settings_menu.get_node("DamageNumbersToggle") as CheckButton) == null
	):
		_fail("Settings menu did not expose key binding and damage number controls")
		return
	(settings_menu.get_node("CloseSettings") as Button).emit_signal("pressed")
	menu_main.queue_free()

	var game_main: Node2D = main_scene.instantiate() as Node2D
	game_main.set("save_enabled", false)
	root.add_child(game_main)
	await physics_frame
	var escape_event := InputEventKey.new()
	escape_event.keycode = KEY_ESCAPE
	escape_event.pressed = true
	game_main.call(&"_on_always_key_pressed", escape_event)
	if not paused or not (game_main.get_node("HUD/PauseMenu") as Control).visible:
		_fail("Pause menu did not pause the game")
		return
	var paused_player: RoguePlayer = game_main.get_node("Player") as RoguePlayer
	if paused_player.can_process():
		_fail("Player can still process while the pause menu is open")
		return
	var paused_hud: CanvasLayer = game_main.get_node("HUD") as CanvasLayer
	if not paused_hud.can_process():
		_fail("HUD cannot process while the game is paused")
		return
	game_main.call(&"_on_always_key_pressed", escape_event)
	if paused:
		_fail("Pause menu did not resume the game")
		return
	if not InputMap.has_action(&"pause") or not InputMap.has_action(&"aim_up") or not InputMap.has_action(&"aim_down"):
		_fail("Pause or vertical attack input was not registered")
		return
	game_main.queue_free()
	print("menu_settings_smoke: PASS")
	quit(0)


func _fail(message: String) -> void:
	if paused:
		paused = false
	push_error(message)
	quit(1)
