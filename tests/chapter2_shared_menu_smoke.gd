extends SceneTree

const SETTINGS_PATH := "D:/Godot/RoguePlatformer-game/test_output/chapter_menu_settings.json"
var failed := false

func check(condition: bool, message: String = "Shared menu check failed") -> void:
	# Exported release packs can disable GDScript assertions.
	if not condition:
		failed = true
		push_error(message)
		quit(1)

func _initialize() -> void:
	call_deferred("run_test")

func ui_snapshot(node: Node) -> Array:
	var result: Array = []
	for child in node.get_children():
		if child is Control:
			var entry: Array = [child.get_class(), child.position, child.size]
			if child is Label or child is BaseButton: entry.append(child.text)
			if child is RichTextLabel: entry.append(child.text)
			result.append(entry)
		result.append_array(ui_snapshot(child))
	return result

func send_key(key: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.physical_keycode = key
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event.pressed = false
	Input.parse_input_event(event)
	await process_frame

func send_button(button: JoyButton) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event.pressed = false
	Input.parse_input_event(event)
	await process_frame

func run_test() -> void:
	create_timer(25).timeout.connect(func(): push_error("Shared menu timeout"); quit(1))
	var main = load("res://scenes/Main.tscn").instantiate()
	main.save_enabled = false
	root.add_child(main)
	await process_frame
	var pause_reference := ui_snapshot(main._pause_overlay)
	var settings_reference := ui_snapshot(main._settings_overlay)
	var original_settings = main._settings
	main.queue_free()
	await process_frame
	var journey = load("res://scenes/Chapter2Journey.tscn").instantiate()
	journey.persistence_enabled = false
	root.add_child(journey)
	journey._load_layout(2)
	await create_timer(1.8).timeout
	var menu = journey.chapter_menu
	journey.input_settings._save_path = SETTINGS_PATH
	if FileAccess.file_exists(SETTINGS_PATH):
		DirAccess.remove_absolute(SETTINGS_PATH)
	check(ui_snapshot(menu._pause_overlay) == pause_reference, "Pause layout/text must match chapter one")
	check(ui_snapshot(menu._settings_overlay) == settings_reference, "Settings layout/text must match chapter one")
	journey._toggle_pause()
	check(paused and journey.paused and menu._pause_overlay.visible)
	check(root.gui_get_focus_owner() == menu._pause_overlay.get_node("Resume"))
	var enemy_position: Vector2 = journey.caster.position
	var elapsed: float = journey.elapsed
	menu._pause_overlay.get_node("PauseSettings").pressed.emit()
	check(menu._settings_overlay.visible and not menu._pause_overlay.visible)
	menu._settings_music_slider.value = 0.35
	check(is_equal_approx(journey.input_settings.get_music_volume(), 0.35))
	menu._settings_reduced_effects_toggle.button_pressed = true
	check(journey.player.get_reduced_effects_enabled())
	menu._settings_key_buttons[&"attack"].pressed.emit()
	await send_key(KEY_U)
	check(journey.input_settings.get_combined_binding_name(&"attack").contains("U"))
	check(menu._awaiting_rebind_action.is_empty() and menu._settings_overlay.visible)
	await create_timer(0.3).timeout
	check(journey.caster.position == enemy_position and journey.elapsed == elapsed, "Settings must freeze combat and hazards")
	menu._settings_overlay.get_node("CloseSettings").pressed.emit()
	check(menu._pause_overlay.visible and paused)
	menu._pause_overview_button.pressed.emit()
	check(menu._build_overview.visible and paused)
	check(menu._build_overview.get_snapshot().visible)
	await send_button(JOY_BUTTON_B)
	check(menu._pause_overlay.visible and paused, "Controller back from overview returns to pause")
	await send_button(JOY_BUTTON_START)
	check(not paused and not journey.paused, "Controller Start resumes exactly once")
	await send_key(KEY_TAB)
	check(menu._build_overview.visible and paused, "Direct overview hotkey pauses combat")
	await send_key(KEY_TAB)
	check(not paused and not menu._build_overview.visible, "Direct overview closes to gameplay")
	# Opening menus above reward cards must preserve their lock and focus after return.
	journey._open_choice(&"supply")
	await send_key(KEY_ESCAPE)
	check(paused and journey.ritual_open)
	check(menu._pause_overlay.get_index() > journey.reward_view.get_index(), "Pause must cover reward cards")
	menu._open_settings(true)
	var heading: Label = menu._settings_overlay.get_node("SettingsGuideCard/Heading")
	check(not Rect2(heading.global_position, Vector2(340, heading.size.y)).intersects(menu._settings_tutorial_toggle.get_global_rect()), "Tutorial toggle must not overlap the guide heading")
	check(menu._settings_overlay.get_index() > journey.reward_view.get_index(), "Settings must cover reward cards")
	menu._close_settings()
	await send_key(KEY_ESCAPE)
	check(not paused and journey.ritual_open and not journey.player.is_physics_processing())
	check(not journey.caster.is_physics_processing())
	check(journey.reward_view.is_ancestor_of(root.gui_get_focus_owner()), "Card focus must be restored")
	journey._close_choice()
	var stored = preload("res://scripts/settings_store.gd").new(SETTINGS_PATH)
	check(stored.load_settings() and is_equal_approx(stored.get_music_volume(), 0.35), "Menu settings must persist")
	original_settings.apply()
	journey.queue_free()
	await process_frame
	if not failed:
		print("chapter2_shared_menu_smoke: PASS")
	quit(1 if failed else 0)
