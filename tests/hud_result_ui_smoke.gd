extends SceneTree

const UI := preload("res://scripts/ui_theme.gd")

func _initialize() -> void:
	call_deferred(&"_run_test")

func _run_test() -> void:
	var main := (load("res://scenes/Main.tscn") as PackedScene).instantiate() as Node2D
	main.set("save_enabled", false)
	root.add_child(main)
	await process_frame
	main.call(&"_clear_enemies")
	var player := main.get_node("Player") as RoguePlayer
	player.set_physics_process(false)
	var dock := main.get_node("HUD/BottomHUD") as Panel
	var presenter := main.get("_hud_presenter") as RunHUDPresenter
	presenter.set_status("一二三四五六七八九十一二三四五六七八九十一二三四五六七八九十")
	if presenter.status_label.text.length() != 28 or not presenter.status_label.text.ends_with("…"):
		return _fail("Status chip did not enforce a readable single-line limit")
	await create_timer(3.2).timeout
	if presenter.status_label.modulate.a > 0.01:
		return _fail("Status chip did not fade after three seconds")
	presenter.update_health(100, 100)
	presenter.update_health(80, 100)
	if presenter.health_fill.color != UI.ACCENT_RISK or presenter.health_label.text != "80 / 100":
		return _fail("Health damage flash or short number format missing")
	await create_timer(0.2).timeout
	if presenter.health_fill.color == UI.ACCENT_RISK:
		return _fail("Health damage flash did not restore its resting color")
	presenter.update_health(70, 100, true)
	await create_timer(0.07).timeout
	if presenter.health_fill.color == UI.ACCENT_RISK:
		return _fail("Reduced-effects health flash lasted too long")
	main.call(&"_show_upgrade_choice")
	if dock.visible:
		return _fail("Combat HUD leaked underneath reward modal")
	main.call(&"_hide_upgrade_overlay")
	if not dock.visible:
		return _fail("HUD did not return after closing reward modal")
	# Start a valid fresh combat state before testing death actions.
	main.call(&"_start_new_run")
	main.call(&"_on_player_died")
	var recap := main.get_node("HUD/DeathRecap") as Control
	var retry := recap.get_node("Sheet/Retry") as Button
	if not paused or not recap.visible or root.gui_get_focus_owner() != retry or dock.visible:
		return _fail("Death screen did not freeze combat and focus Retry")
	await _key(KEY_ENTER)
	if paused or recap.visible or int(main.get("_lives_remaining")) != 2:
		return _fail("Keyboard Enter did not retry while preserving two lives")
	main.call(&"_on_player_died")
	await _joy(JOY_BUTTON_DPAD_RIGHT)
	if root.gui_get_focus_owner() != recap.get_node("Sheet/ReturnTitle"):
		return _fail("Controller could not navigate death actions")
	await _joy(JOY_BUTTON_DPAD_LEFT)
	await _joy(JOY_BUTTON_A)
	if recap.visible or paused or int(main.get("_lives_remaining")) != 1:
		return _fail("Controller A did not confirm Retry")
	main.call(&"_on_player_died")
	await _joy(JOY_BUTTON_B)
	if recap.visible or not bool(main.get("_entry_flow_active")) or not (main.get_node("HUD/EntryFlow") as Control).visible:
		return _fail("Controller B did not return to title from death")
	if bool(main.call(&"has_continue_snapshot")):
		return _fail("Returning from death created an invalid continue save")
	main.queue_free()
	await process_frame
	print("hud_result_ui_smoke: PASS")
	quit(0)

func _key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = InputEventKey.new()
	event.keycode = code
	Input.parse_input_event(event)
	await process_frame

func _joy(button: JoyButton) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = InputEventJoypadButton.new()
	event.button_index = button
	Input.parse_input_event(event)
	await process_frame

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
