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
	var operation_guide: RichTextLabel = settings_menu.get_node("OperationGuide") as RichTextLabel
	if (
		not settings_menu.visible
		or (settings_menu.get_node("Bind_dash") as Button) == null
		or (settings_menu.get_node("DamageNumbersToggle") as CheckButton) == null
		or (settings_menu.get_node("ResolutionSelector") as OptionButton) == null
		or (settings_menu.get_node("FullscreenToggle") as CheckButton) == null
		or (settings_menu.get_node("VsyncToggle") as CheckButton) == null
		or (settings_menu.get_node("ReducedEffectsToggle") as CheckButton) == null
		or (settings_menu.get_node("MusicVolume") as HSlider) == null
		or (settings_menu.get_node("EffectsVolume") as HSlider) == null
		or (settings_menu.get_node("VoiceVolume") as HSlider) == null
		or settings_menu.get_node_or_null("ControllerStatus") == null
		or settings_menu.get_node_or_null("DisplayStatus") == null
		or operation_guide == null
	):
		_fail("Settings menu did not expose bindings, options, and the operation guide")
		return
	var guide_text: String = operation_guide.get_parsed_text()
	if not guide_text.contains("移动与探索") or not guide_text.contains("开宝箱") or not guide_text.contains("空中可再次跳跃"):
		_fail("Settings operation guide did not contain the moved gameplay instructions")
		return
	var bindings_card: Control = settings_menu.get_node("SettingsBindingsCard") as Control
	var guide_card: Control = settings_menu.get_node("SettingsGuideCard") as Control
	for child: Node in settings_menu.get_children():
		if child is Button and child.name.begins_with("Bind_"):
			var binding_button := child as Button
			if not bindings_card.get_global_rect().encloses(binding_button.get_global_rect()):
				_fail("Binding control escaped its card: %s" % binding_button.name)
				return
			if binding_button.get_global_rect().intersects(guide_card.get_global_rect()):
				_fail("Binding control overlaps the field guide: %s" % binding_button.name)
				return
	var has_controller_jump := false
	for input_event: InputEvent in InputMap.action_get_events(&"jump"):
		if input_event is InputEventJoypadButton:
			has_controller_jump = true
	if not has_controller_jump:
		_fail("Settings did not install the default controller map")
		return
	var attack_binding: Button = settings_menu.get_node("Bind_attack") as Button
	if not attack_binding.text.contains("J") or not attack_binding.text.contains("X"):
		_fail("Settings binding rows do not show keyboard and controller prompts together")
		return
	(settings_menu.get_node("CloseSettings") as Button).emit_signal("pressed")
	menu_main.queue_free()

	var game_main: Node2D = main_scene.instantiate() as Node2D
	game_main.set("save_enabled", false)
	root.add_child(game_main)
	await physics_frame
	var gameplay_title: Label = game_main.get_node("HUD/Title") as Label
	var gameplay_controls: Label = game_main.get_node("HUD/Controls") as Label
	if gameplay_title.visible or gameplay_controls.visible:
		_fail("Gameplay still showed the old title or full-width control instructions")
		return
	if (
		game_main.get_node_or_null("HUD/RoomCard") == null
		or game_main.get_node_or_null("HUD/StatusToast") == null
		or game_main.get_node_or_null("HUD/BottomHUD") == null
		or game_main.get_node_or_null("HUD/WeaponPanel") == null
	):
		_fail("Redesigned top cards and dedicated bottom combat dock were not created")
		return
	var input_bridge: Node = game_main.get("_pause_input_handler") as Node
	input_bridge.call(&"set_initial_device", true)
	await process_frame
	var attack_slot: Control = game_main.get_node("HUD/AbilityBar/AttackAbility") as Control
	if not attack_slot.tooltip_text.contains("[X]"):
		_fail("Combat HUD did not switch to the controller attack prompt")
		return
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
	var pause_menu: Control = game_main.get_node("HUD/PauseMenu") as Control
	var pause_overview: Button = pause_menu.get_node("PauseBuildOverview") as Button
	if not pause_overview.text.contains("RS"):
		_fail("Pause menu did not switch the build overview prompt to controller")
		return
	(pause_menu.get_node("PauseSettings") as Button).emit_signal("pressed")
	await process_frame
	var paused_settings: Control = game_main.get_node("HUD/SettingsMenu") as Control
	if pause_menu.visible or not paused_settings.visible:
		_fail("Settings opened from pause did not replace the pause layer")
		return
	(paused_settings.get_node("CloseSettings") as Button).emit_signal("pressed")
	await process_frame
	if not pause_menu.visible or paused_settings.visible:
		_fail("Closing settings did not restore the pause layer")
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
