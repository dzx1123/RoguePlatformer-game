extends SceneTree

var _player_actions: Array[StringName] = []


func _initialize() -> void:
	call_deferred(&"_run_test")


func _run_test() -> void:
	var main_scene: PackedScene = load("res://scenes/Main.tscn")
	var main: Node2D = main_scene.instantiate() as Node2D
	main.set("save_enabled", false)
	root.add_child(main)
	await physics_frame

	var player: RoguePlayer = main.get_node("Player") as RoguePlayer
	player.action_started.connect(_on_player_action_started)
	var input_bridge: Node = main.get("_pause_input_handler") as Node
	var weapon_switch_label: Label = main.get_node(
		"HUD/WeaponPanel/WeaponSwitch/Label"
	) as Label
	# Keep device switching deterministic even when this test is run on a host
	# that already has a controller attached.
	input_bridge.call(&"set_initial_device", true)
	await process_frame
	input_bridge.call(&"set_initial_device", false)
	await process_frame
	await _move_joy_axis(JOY_AXIS_LEFT_X, 0.54)
	if bool(main.get("_using_controller_input")) or weapon_switch_label.text.contains("LB"):
		return _fail("Sub-threshold stick drift incorrectly switched controller prompts")
	await _move_joy_axis(JOY_AXIS_LEFT_X, 0.75)
	if not bool(main.get("_using_controller_input")) or not weapon_switch_label.text.contains("LB"):
		return _fail("Intentional stick motion did not switch to controller prompts")
	await _tap_key(KEY_SHIFT)
	if bool(main.get("_using_controller_input")) or weapon_switch_label.text.contains("LB"):
		return _fail("Keyboard input did not switch back from controller prompts")
	input_bridge.call(&"set_initial_device", true)
	await process_frame
	if not weapon_switch_label.text.contains("LB"):
		return _fail("Weapon-switch HUD did not change from Q to LB")

	main.call(&"_show_upgrade_choice")
	await process_frame
	var choice_overlay: Control = main.get_node("HUD/UpgradeChoice") as Control
	var choice_hint: Label = main.get("_upgrade_hint") as Label
	var choice_buttons: Array = main.get("_upgrade_buttons") as Array
	if (
		not choice_overlay.visible
		or not choice_hint.text.contains("X / Y / B")
		or not ((choice_buttons[0] as Button).get_node("CardRarity") as Label).text.begins_with("[X]")
		or not ((choice_buttons[1] as Button).get_node("CardRarity") as Label).text.begins_with("[Y]")
		or not ((choice_buttons[2] as Button).get_node("CardRarity") as Label).text.begins_with("[B]")
	):
		return _fail("Card-choice overlay did not expose controller prompts")
	var focus_owner: Control = root.gui_get_focus_owner()
	if focus_owner == null or not choice_overlay.is_ancestor_of(focus_owner):
		return _fail("Card-choice overlay did not acquire controller focus")

	await _tap_joy_button(JOY_BUTTON_Y)
	await process_frame
	if bool(main.get("_flow_state").choosing_upgrade):
		return _fail("Y did not directly choose the second reward card")

	await _tap_joy_button(JOY_BUTTON_START)
	var pause_menu := main.get_node("HUD/PauseMenu") as Control
	var resume_button := pause_menu.get_node("Resume") as Button
	var pause_overview := pause_menu.get_node("PauseBuildOverview") as Button
	if not paused or not pause_menu.visible:
		return _fail("Menu/Start did not open and pause the game")
	var pause_focus: Control = root.gui_get_focus_owner()
	if pause_focus != null:
		pause_focus.release_focus()
	await process_frame
	if Input.get_connected_joypads().is_empty():
		Input.emit_signal(&"joy_connection_changed", 0, false)
	else:
		input_bridge.call(&"set_initial_device", false)
	await process_frame
	if (
		bool(main.get("_using_controller_input"))
		or root.gui_get_focus_owner() != resume_button
		or pause_overview.text.contains("RS")
	):
		return _fail("Simulated controller disconnect did not restore keyboard prompts and pause focus")
	resume_button.release_focus()
	Input.emit_signal(&"joy_connection_changed", 0, true)
	await process_frame
	if (
		not bool(main.get("_using_controller_input"))
		or root.gui_get_focus_owner() != resume_button
		or not pause_overview.text.contains("RS")
	):
		return _fail("Simulated controller reconnect did not restore controller prompts and pause focus")
	await _tap_joy_button(JOY_BUTTON_B)
	if paused:
		return _fail("B did not close the pause menu and resume gameplay")

	main.call(&"_clear_enemies")
	main.call(&"_spawn_reward_chest")
	await process_frame
	var chest: RewardChest = main.get("_chest") as RewardChest
	var prompt_key: Label = chest.get_node("PromptBubble/PromptKey/KeyText") as Label
	if prompt_key.text != "RB":
		return _fail("Reward chest prompt did not change from E to RB")
	player.global_position = chest.global_position
	await physics_frame
	await _tap_joy_button(JOY_BUTTON_RIGHT_SHOULDER)
	await process_frame
	await process_frame
	if not bool(main.get("_flow_state").awaiting_exit):
		return _fail("RB did not open the reward chest and reveal the room-exit portal")
	await _tap_joy_button(JOY_BUTTON_A)
	if not bool(main.get("_flow_state").awaiting_exit):
		return _fail("A unexpectedly entered the portal instead of the interaction key")
	player.global_position = (main.get_node("RoomExitPortal") as Node2D).global_position
	await _tap_joy_button(JOY_BUTTON_RIGHT_SHOULDER)
	for _frame_index: int in range(20):
		await physics_frame
	if not bool(main.get("_flow_state").choosing_upgrade):
		return _fail("RB near the portal did not advance to card choice")

	main.call(&"_return_to_main_menu")
	await process_frame
	var entry: Control = main.get_node("HUD/EntryFlow") as Control
	var start_button: Button = entry.get_node("StartGame") as Button
	var continue_button: Button = entry.get_node("ContinueRun") as Button
	var primary_button: Button = continue_button if continue_button.visible else start_button
	if root.gui_get_focus_owner() != primary_button:
		return _fail("Main menu did not focus its primary action for controller input")
	if continue_button.visible:
		await _tap_joy_button(JOY_BUTTON_DPAD_DOWN)
		if root.gui_get_focus_owner() != start_button:
			return _fail("D-pad could not navigate from Continue to Start Game")
	await _tap_joy_button(JOY_BUTTON_DPAD_DOWN)
	if root.gui_get_focus_owner() != entry.get_node("EntrySettings"):
		return _fail("D-pad could not navigate from Start Game to Settings")
	await _tap_joy_button(JOY_BUTTON_A)
	if not (main.get_node("HUD/SettingsMenu") as Control).visible:
		return _fail("A did not confirm the focused Settings button")
	await _tap_joy_button(JOY_BUTTON_B)
	if (main.get_node("HUD/SettingsMenu") as Control).visible:
		return _fail("B did not return from Settings to the main menu")
	if continue_button.visible:
		await _tap_joy_button(JOY_BUTTON_DPAD_DOWN)
	await _tap_joy_button(JOY_BUTTON_A)
	var difficulty_buttons: Array = main.get("_difficulty_buttons") as Array
	if not (difficulty_buttons[0] as Button).visible:
		return _fail("A did not open difficulty selection from Start Game")
	await _tap_joy_button(JOY_BUTTON_DPAD_RIGHT)
	if root.gui_get_focus_owner() != difficulty_buttons[1]:
		return _fail("D-pad could not navigate between difficulty cards")
	await _tap_joy_button(JOY_BUTTON_B)
	if (difficulty_buttons[0] as Button).visible or not start_button.visible:
		return _fail("B did not return from difficulty without starting a run")
	start_button.grab_focus()
	await _tap_joy_button(JOY_BUTTON_A)
	await _tap_joy_button(JOY_BUTTON_DPAD_DOWN)
	var back_button: Button = entry.get_node("DifficultyBack") as Button
	if root.gui_get_focus_owner() != back_button:
		return _fail("D-pad down did not reach the explicit difficulty return button")
	await _tap_joy_button(JOY_BUTTON_A)
	if back_button.visible or not start_button.visible:
		return _fail("A did not activate the explicit difficulty return button")
	start_button.grab_focus()
	await _tap_joy_button(JOY_BUTTON_A)
	await _tap_joy_button(JOY_BUTTON_DPAD_RIGHT)
	await _tap_joy_button(JOY_BUTTON_A)
	if bool(main.get("_entry_flow_active")):
		return _fail("A did not confirm the focused difficulty")

	main.call(&"_clear_enemies")
	var ground_deadline: int = 120
	while not player.is_on_floor() and ground_deadline > 0:
		await physics_frame
		ground_deadline -= 1
	if not player.is_on_floor():
		return _fail("Player did not reach the floor before controller gameplay checks")
	_player_actions.clear()
	var player_x_before: float = player.global_position.x
	await _hold_joy_axis(JOY_AXIS_LEFT_X, 1.0, 8)
	if not _player_actions.has(&"move") or player.global_position.x <= player_x_before + 1.0:
		return _fail("Left-stick motion did not move the player")
	await _tap_gameplay_button(JOY_BUTTON_A)
	if not _player_actions.has(&"jump"):
		return _fail("Controller A did not start a gameplay jump")
	await _tap_gameplay_button(JOY_BUTTON_X)
	if not _player_actions.has(&"attack"):
		return _fail("Controller X did not start a gameplay attack")
	await _wait_physics_frames(30)
	await _tap_gameplay_button(JOY_BUTTON_B)
	if not _player_actions.has(&"dash"):
		return _fail("Controller B did not start a gameplay dash")
	await _wait_physics_frames(18)
	await _tap_gameplay_button(JOY_BUTTON_Y)
	if not _player_actions.has(&"skill"):
		return _fail("Controller Y did not start the weapon skill")
	await _wait_physics_frames(45)
	var progression: ProgressionStore = main.get("_progression") as ProgressionStore
	progression.bank_run(ProgressionStore.TWIN_BLADES_UNLOCK_SHARDS, false)
	var weapon_before: StringName = player.get_weapon_id()
	await _tap_gameplay_button(JOY_BUTTON_LEFT_SHOULDER)
	if player.get_weapon_id() == weapon_before:
		return _fail("Controller LB did not cycle to an unlocked weapon")
	await _tap_joy_button(JOY_BUTTON_RIGHT_STICK)
	var build_overview := main.get("_build_overview") as Control
	if not paused or not build_overview.visible:
		return _fail("Controller RS did not open the build overview")
	await _tap_joy_button(JOY_BUTTON_RIGHT_STICK)
	if paused or build_overview.visible:
		return _fail("Controller RS did not close the build overview")
	player.set_current_health(40)
	await _tap_gameplay_button(JOY_BUTTON_BACK)
	await _wait_physics_frames(4)
	if player.get_current_health() != player.get_max_health():
		return _fail("Controller View did not restart the active run")

	main.call(&"_show_shop")
	await process_frame
	if not (main.get("_upgrade_hint") as Label).text.contains("RB 离开"):
		return _fail("Shop did not show the controller interaction prompt")
	await _tap_joy_button(JOY_BUTTON_RIGHT_SHOULDER)
	if bool(main.get("_flow_state").shopping):
		return _fail("RB did not leave the shop")

	main.call(&"_complete_run")
	await process_frame
	var victory_button: Button = main.get("_victory_restart_button") as Button
	if (
		victory_button == null
		or not victory_button.visible
		or victory_button.disabled
		or root.gui_get_focus_owner() != victory_button
	):
		return _fail("Victory summary did not focus its primary controller action")
	await _tap_joy_button(JOY_BUTTON_A)
	if (
		bool(main.get("_flow_state").run_complete)
		or (main.get_node("HUD/UpgradeChoice") as Control).visible
	):
		return _fail("A did not start a new run from the focused victory action")

	main.queue_free()
	print("controller_interaction_smoke: PASS")
	quit(0)


func _tap_joy_button(button_index: int) -> void:
	var pressed_event := InputEventJoypadButton.new()
	pressed_event.device = 0
	pressed_event.button_index = button_index
	pressed_event.pressed = true
	Input.parse_input_event(pressed_event)
	await process_frame
	var released_event := InputEventJoypadButton.new()
	released_event.device = 0
	released_event.button_index = button_index
	released_event.pressed = false
	Input.parse_input_event(released_event)
	await process_frame


func _tap_gameplay_button(button_index: int) -> void:
	var pressed_event := InputEventJoypadButton.new()
	pressed_event.device = 0
	pressed_event.button_index = button_index
	pressed_event.pressed = true
	Input.parse_input_event(pressed_event)
	# Keep the action down across a complete physics tick; SceneTree frame signals
	# may resume before or after individual nodes depending on connection order.
	await _wait_physics_frames(2)
	var released_event := InputEventJoypadButton.new()
	released_event.device = 0
	released_event.button_index = button_index
	released_event.pressed = false
	Input.parse_input_event(released_event)
	await _wait_physics_frames(2)


func _move_joy_axis(axis: int, value: float) -> void:
	var motion_event := InputEventJoypadMotion.new()
	motion_event.device = 0
	motion_event.axis = axis
	motion_event.axis_value = value
	Input.parse_input_event(motion_event)
	await process_frame
	motion_event = InputEventJoypadMotion.new()
	motion_event.device = 0
	motion_event.axis = axis
	motion_event.axis_value = 0.0
	Input.parse_input_event(motion_event)
	await process_frame


func _hold_joy_axis(axis: int, value: float, frame_count: int) -> void:
	var motion_event := InputEventJoypadMotion.new()
	motion_event.device = 0
	motion_event.axis = axis
	motion_event.axis_value = value
	Input.parse_input_event(motion_event)
	await _wait_physics_frames(frame_count)
	motion_event = InputEventJoypadMotion.new()
	motion_event.device = 0
	motion_event.axis = axis
	motion_event.axis_value = 0.0
	Input.parse_input_event(motion_event)
	await physics_frame


func _tap_key(keycode: Key) -> void:
	var pressed_event := InputEventKey.new()
	pressed_event.keycode = keycode
	pressed_event.pressed = true
	Input.parse_input_event(pressed_event)
	await process_frame
	var released_event := InputEventKey.new()
	released_event.keycode = keycode
	released_event.pressed = false
	Input.parse_input_event(released_event)
	await process_frame


func _wait_physics_frames(frame_count: int) -> void:
	for _frame_index: int in range(frame_count):
		await physics_frame


func _on_player_action_started(action: StringName) -> void:
	_player_actions.append(action)


func _fail(message: String) -> void:
	if paused:
		paused = false
	push_error(message)
	quit(1)
