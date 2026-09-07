extends SceneTree

const REPORT_PATH := "res://tests/artifacts/mouse-hit-target/report.json"
const WINDOW_SIZE := Vector2i(1280, 720)

var _click_records: Array[Dictionary] = []


func _initialize() -> void:
	call_deferred(&"_run_test")


func _run_test() -> void:
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(WINDOW_SIZE)
		await _wait_frames(8)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	root.content_scale_size = WINDOW_SIZE

	var main_scene := load("res://scenes/Main.tscn") as PackedScene
	var main := main_scene.instantiate() as Node2D
	main.set("save_enabled", false)
	root.add_child(main)
	await physics_frame
	await _wait_frames(3)
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(WINDOW_SIZE)
		await _wait_frames(8)
	main.call(&"_show_start_screen")
	await process_frame

	var entry := main.get_node("HUD/EntryFlow") as Control
	var settings := main.get_node("HUD/SettingsMenu") as Control
	var pause_menu := main.get_node("HUD/PauseMenu") as Control
	var death_recap := main.get_node("HUD/DeathRecap") as Control
	var start_button := entry.get_node("StartGame") as Button
	var entry_settings := entry.get_node("EntrySettings") as Button
	var difficulty_back := entry.get_node("DifficultyBack") as Button
	var difficulty_normal := entry.get_node("Difficulty_1") as Button

	if not await _click_target(entry_settings, "title.settings"):
		return
	if not settings.visible:
		return _fail("Clicking the title Settings button did not open Settings")
	if not await _click_target(settings.get_node("CloseSettings") as Button, "settings.back_to_title"):
		return
	if settings.visible or not entry.visible:
		return _fail("Clicking Settings Back did not restore the title screen")

	if not await _click_target(start_button, "title.start"):
		return
	if not difficulty_normal.visible or not difficulty_back.visible:
		return _fail("Clicking Start Game did not expose the difficulty cards")
	if not await _click_target(difficulty_back, "difficulty.back"):
		return
	if difficulty_back.visible or not start_button.visible:
		return _fail("Clicking difficulty Back did not restore the start actions")
	if not await _click_target(start_button, "title.start_again"):
		return
	if not await _click_target(difficulty_normal, "difficulty.normal"):
		return
	if bool(main.get("_entry_flow_active")) or String(main.call(&"get_selected_difficulty_name")) != "中等":
		return _fail("Clicking the Normal difficulty card did not start the selected run")

	main.call(&"_pause_game")
	await process_frame
	if not pause_menu.visible or not paused:
		return _fail("Pause menu was not ready for mouse checks")
	if not await _click_target(pause_menu.get_node("PauseSettings") as Button, "pause.settings"):
		return
	if pause_menu.visible or not settings.visible or not paused:
		return _fail("Clicking Pause Settings did not replace the pause layer")
	if not await _click_target(settings.get_node("CloseSettings") as Button, "settings.back_to_pause"):
		return
	if settings.visible or not pause_menu.visible or not paused:
		return _fail("Clicking Settings Back did not restore the pause layer")
	if not await _click_target(pause_menu.get_node("Resume") as Button, "pause.resume"):
		return
	if pause_menu.visible or paused:
		return _fail("Clicking Resume did not return to gameplay")

	main.call(&"_show_upgrade_choice")
	await process_frame
	var upgrade_buttons: Array = main.get("_upgrade_buttons") as Array
	if upgrade_buttons.is_empty():
		return _fail("Upgrade cards were not available for mouse checks")
	if not await _click_target(upgrade_buttons[0] as Button, "reward.first_card"):
		return
	if bool(main.get("_flow_state").choosing_upgrade):
		return _fail("Clicking a reward card did not close the choice state")

	main.call(&"_on_player_died")
	await process_frame
	if not death_recap.visible or not paused:
		return _fail("Death recap was not ready for mouse checks")
	if not await _click_target(death_recap.get_node("Sheet/Retry") as Button, "death.retry"):
		return
	if death_recap.visible or paused or int(main.get("_lives_remaining")) != 2:
		return _fail("Clicking Retry did not resume with the expected remaining lives")

	main.call(&"_on_player_died")
	await process_frame
	if not await _click_target(death_recap.get_node("Sheet/ReturnTitle") as Button, "death.return_title"):
		return
	if death_recap.visible or not entry.visible or not bool(main.get("_entry_flow_active")):
		return _fail("Clicking Return Title did not restore the title screen")

	start_button = entry.get_node("StartGame") as Button
	if not await _click_target(start_button, "title.start_after_death"):
		return
	if not await _click_target(entry.get_node("Difficulty_1") as Button, "difficulty.normal_after_death"):
		return
	main.call(&"_complete_run")
	await process_frame
	var victory_restart := main.get("_victory_restart_button") as Button
	if victory_restart == null or not victory_restart.visible:
		return _fail("Victory action was not ready for mouse checks")
	if not await _click_target(victory_restart, "victory.restart"):
		return
	if bool(main.get("_flow_state").run_complete):
		return _fail("Clicking Victory Restart did not start a fresh run")

	main.queue_free()
	await process_frame
	_write_report(true, "")
	print(
		"mouse_hit_target_smoke: PASS clicks=%d display=%s"
		% [_click_records.size(), DisplayServer.get_name()]
	)
	quit(0)


func _click_target(target: Control, label: String) -> bool:
	await process_frame
	if target == null or not is_instance_valid(target):
		_fail("Mouse target is missing: %s" % label)
		return false
	if not target.is_visible_in_tree():
		_fail("Mouse target is not visible: %s" % label)
		return false
	if target.mouse_filter == Control.MOUSE_FILTER_IGNORE:
		_fail("Mouse target ignores pointer input: %s" % label)
		return false
	if target is BaseButton and (target as BaseButton).disabled:
		_fail("Mouse target is disabled: %s" % label)
		return false
	var target_rect: Rect2 = target.get_global_rect()
	var viewport_rect := Rect2(Vector2.ZERO, Vector2(WINDOW_SIZE))
	if target_rect.size.x < 32.0 or target_rect.size.y < 32.0:
		_fail("Mouse target is smaller than 32px: %s %s" % [label, target_rect])
		return false
	if not viewport_rect.encloses(target_rect.grow(-0.5)):
		_fail("Mouse target leaves the 1280x720 canvas: %s %s" % [label, target_rect])
		return false
	var click_position: Vector2 = target_rect.get_center()
	var observed_mouse_events: Array[String] = []
	var observed_pressed_signal: Array[bool] = [false]
	var observe_mouse := func(event: InputEvent):
		if event is InputEventMouseButton:
			var mouse_button := event as InputEventMouseButton
			observed_mouse_events.append(
				"%s@%s" % ["down" if mouse_button.pressed else "up", mouse_button.position]
			)
	var observe_pressed := func(): observed_pressed_signal[0] = true
	target.gui_input.connect(observe_mouse)
	if target is BaseButton:
		(target as BaseButton).pressed.connect(observe_pressed)
	var motion := InputEventMouseMotion.new()
	motion.position = click_position
	motion.global_position = click_position
	motion.relative = Vector2(1.0, 0.0)
	root.push_input(motion, true)
	var hovered: Control = root.gui_get_hovered_control()
	var hovered_path: String = str(hovered.get_path()) if hovered != null else ""
	var target_received_pointer: bool = (
		hovered == target
		or (hovered != null and target.is_ancestor_of(hovered))
	)
	var pressed := InputEventMouseButton.new()
	pressed.position = click_position
	pressed.global_position = click_position
	pressed.button_index = MOUSE_BUTTON_LEFT
	pressed.button_mask = MOUSE_BUTTON_MASK_LEFT
	pressed.pressed = true
	root.push_input(pressed, true)
	var pressed_state: bool = (target as BaseButton).button_pressed if target is BaseButton else false
	var released := InputEventMouseButton.new()
	released.position = click_position
	released.global_position = click_position
	released.button_index = MOUSE_BUTTON_LEFT
	released.button_mask = 0
	released.pressed = false
	root.push_input(released, true)
	await process_frame
	if target.gui_input.is_connected(observe_mouse):
		target.gui_input.disconnect(observe_mouse)
	if target is BaseButton and (target as BaseButton).pressed.is_connected(observe_pressed):
		(target as BaseButton).pressed.disconnect(observe_pressed)
	_click_records.append({
		"label": label,
		"rect": [target_rect.position.x, target_rect.position.y, target_rect.size.x, target_rect.size.y],
		"center": [click_position.x, click_position.y],
		"rect_has_point": target_rect.has_point(click_position),
		"hovered_path": hovered_path,
		"target_received_pointer": target_received_pointer,
		"observed_mouse_events": observed_mouse_events,
		"observed_pressed_signal": observed_pressed_signal[0],
		"pressed_state_after_down": pressed_state,
	})
	return true


func _wait_frames(frame_count: int) -> void:
	for _frame_index: int in range(frame_count):
		await process_frame


func _write_report(success: bool, failure: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(REPORT_PATH.get_base_dir()))
	var report := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if report == null:
		return
	report.store_string(JSON.stringify({
		"success": success,
		"failure": failure,
		"display_server": DisplayServer.get_name(),
		"window_size": [DisplayServer.window_get_size().x, DisplayServer.window_get_size().y],
		"viewport_size": [root.get_visible_rect().size.x, root.get_visible_rect().size.y],
		"click_count": _click_records.size(),
		"clicks": _click_records,
	}, "\t"))
	report.close()


func _fail(message: String) -> void:
	if paused:
		paused = false
	_write_report(false, message)
	push_error(message)
	quit(1)
