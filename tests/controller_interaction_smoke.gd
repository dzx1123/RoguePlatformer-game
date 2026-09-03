extends SceneTree


func _initialize() -> void:
	call_deferred(&"_run_test")


func _run_test() -> void:
	var main_scene: PackedScene = load("res://scenes/Main.tscn")
	var main: Node2D = main_scene.instantiate() as Node2D
	main.set("save_enabled", false)
	root.add_child(main)
	await physics_frame

	var input_bridge: Node = main.get("_pause_input_handler") as Node
	input_bridge.call(&"set_initial_device", true)
	await process_frame
	var weapon_switch_label: Label = main.get_node(
		"HUD/WeaponPanel/WeaponSwitch/Label"
	) as Label
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
	if not paused or not (main.get_node("HUD/PauseMenu") as Control).visible:
		return _fail("Menu/Start did not open and pause the game")
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
	var player: RoguePlayer = main.get_node("Player") as RoguePlayer
	player.global_position = chest.global_position
	await physics_frame
	await _tap_joy_button(JOY_BUTTON_RIGHT_SHOULDER)
	await process_frame
	await process_frame
	if not bool(main.get("_flow_state").awaiting_exit):
		return _fail("RB did not open the reward chest and reveal the room-exit portal")
	await _tap_joy_button(JOY_BUTTON_A)
	for _frame_index: int in range(20):
		await physics_frame
	if not bool(main.get("_flow_state").choosing_upgrade):
		return _fail("A did not enter the room-exit portal and advance to card choice")

	main.call(&"_return_to_main_menu")
	await process_frame
	var entry: Control = main.get_node("HUD/EntryFlow") as Control
	var start_button: Button = entry.get_node("StartGame") as Button
	if root.gui_get_focus_owner() != start_button:
		return _fail("Main menu did not focus Start Game for controller input")
	await _tap_joy_button(JOY_BUTTON_DPAD_DOWN)
	if root.gui_get_focus_owner() != entry.get_node("EntrySettings"):
		return _fail("D-pad could not navigate from Start Game to Settings")
	await _tap_joy_button(JOY_BUTTON_A)
	if not (main.get_node("HUD/SettingsMenu") as Control).visible:
		return _fail("A did not confirm the focused Settings button")
	await _tap_joy_button(JOY_BUTTON_B)
	if (main.get_node("HUD/SettingsMenu") as Control).visible:
		return _fail("B did not return from Settings to the main menu")
	await _tap_joy_button(JOY_BUTTON_A)
	var difficulty_buttons: Array = main.get("_difficulty_buttons") as Array
	if not (difficulty_buttons[0] as Button).visible:
		return _fail("A did not open difficulty selection from Start Game")
	await _tap_joy_button(JOY_BUTTON_DPAD_RIGHT)
	if root.gui_get_focus_owner() != difficulty_buttons[1]:
		return _fail("D-pad could not navigate between difficulty cards")
	await _tap_joy_button(JOY_BUTTON_A)
	if bool(main.get("_entry_flow_active")):
		return _fail("A did not confirm the focused difficulty")

	main.call(&"_show_shop")
	await process_frame
	if not (main.get("_upgrade_hint") as Label).text.contains("RB 离开"):
		return _fail("Shop did not show the controller interaction prompt")
	await _tap_joy_button(JOY_BUTTON_RIGHT_SHOULDER)
	if bool(main.get("_flow_state").shopping):
		return _fail("RB did not leave the shop")

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


func _fail(message: String) -> void:
	if paused:
		paused = false
	push_error(message)
	quit(1)
