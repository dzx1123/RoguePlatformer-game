extends SceneTree

func check(condition: bool, message: String) -> bool:
	if not condition:
		push_error(message)
		quit(1)
	return condition

func _initialize():
	call_deferred("run_test")
func interact():
	Input.action_press(&"interact")
	await physics_frame
	await physics_frame
	Input.action_release(&"interact")
	await create_timer(0.3).timeout
func walk_to(scene, x: float):
	for frame in range(600):
		if absf(scene.player.position.x - x) < 12:
			break
		Input.action_press(&"move_right" if scene.player.position.x < x else &"move_left")
		await physics_frame
		Input.action_release(&"move_right")
		Input.action_release(&"move_left")
	assert(absf(scene.player.position.x - x) < 15)

func tap(event: InputEvent) -> void:
	event.set("pressed", true)
	Input.parse_input_event(event)
	await process_frame
	event.set("pressed", false)
	Input.parse_input_event(event)
	await process_frame

func verify_full_health_supply(scene: Node) -> bool:
	for capped in [false, true]:
		scene._load_layout(18)
		scene.claimed.erase(&"forge_39")
		var vitality := UpgradeCatalog.get_upgrade(&"vitality_rune")
		scene.player.restore_run_progression({&"vitality_rune": int(vitality.max_stacks)} if capped else {}, 10000)
		var starting_health: int = scene.player.get_current_health()
		var starting_gold: int = scene.gold
		await create_timer(1.8).timeout
		await walk_to(scene, 1180)
		await interact()
		if not check(scene.choice_kind == &"supply" and scene.reward_cards.size() == 2, "The full-health player must open both supply choices"):
			return false
		var heal_button: Button = scene.reward_view._upgrade_buttons[0]
		var useful_button: Button = scene.reward_view._upgrade_buttons[1]
		if not check(heal_button.disabled and heal_button.get_node("CardCost").text == "生命已满" and root.gui_get_focus_owner() == useful_button, "The available supply must get focus and the blocked healing card must explain why"):
			return false
		var expected_description := "金币 +15" if capped else "补给后 %d/%d 生命" % [starting_health + 20, starting_health + 20]
		if not check(useful_button.get_node("CardDescription").text.contains(expected_description), "The useful card must forecast its actual reward"):
			return false
		var heal_key := InputEventKey.new()
		heal_key.keycode = KEY_1
		await tap(heal_key)
		var heal_button_event := InputEventJoypadButton.new()
		heal_button_event.button_index = JOY_BUTTON_X
		await tap(heal_button_event)
		if not check(scene.ritual_open and scene.room_index == 18 and not scene.claimed.has(&"forge_39") and not scene.choose_final_option(0), "Full-health healing must not consume supply through any shortcut"):
			return false
		scene._toggle_pause()
		scene._toggle_pause()
		if not check(heal_button.disabled and root.gui_get_focus_owner() == useful_button, "Resuming must still focus the useful supply"):
			return false
		if capped:
			var confirm := InputEventJoypadButton.new()
			confirm.button_index = JOY_BUTTON_Y
			await tap(confirm)
		else:
			var confirm := InputEventKey.new()
			confirm.keycode = KEY_2
			await tap(confirm)
		var expected_health := starting_health if capped else starting_health + 20
		if not check(scene.room_index == 19 and scene.checkpoint.health == expected_health and scene.player.get_current_health() == expected_health and scene.checkpoint.claimed.has(&"forge_39") and not scene.choose_final_option(1), "The chosen supply must be recorded exactly once before entering room 40"):
			return false
		if not check(scene.gold == starting_gold + (15 if capped else 0), "The capped vitality card must grant the stated gold"):
			return false
	return true

func run_test():
	var scene = load("res://scenes/Chapter2Journey.tscn").instantiate()
	scene.persistence_enabled = false
	root.add_child(scene)
	scene.tutorial_enabled = true
	if not check(not scene.route_hint_panel.visible, "The early rooms should not add a second guidance panel"):
		return
	for branch in [0, 1]:
		scene.branch_choices.clear()
		scene._load_layout(16)
		if not check(scene.route_hint_panel.visible and scene.route_hint_label.text.contains("在左侧路标"), "Room 37 must point to the route sign"):
			return
		scene.using_controller = true
		if not check(scene._branch_interaction_prompt().begins_with(scene.input_settings.get_action_prompt(&"interact", true)), "The sign must show the configured controller interact button"):
			return
		scene.using_controller = false
		scene.tutorial_enabled = false
		await process_frame
		await process_frame
		if not check(not scene.route_hint_panel.visible, "The route hints must follow the tutorial toggle"):
			return
		scene.tutorial_enabled = true
		await create_timer(1.8).timeout
		await walk_to(scene, 300)
		await interact()
		assert(scene.choice_kind == &"branch" and scene.reward_cards.size() == 2)
		if not check(not scene.route_hint_panel.visible, "The route hint should hide during the branch choice"):
			return
		scene.reward_view._upgrade_buttons[branch].pressed.emit()
		if not check(scene.route_hint_panel.visible and scene.route_hint_label.text.contains("已选上路" if branch == 0 else "已选下路"), "The hint must reflect the selected branch"):
			return
		assert(scene.branch_choices[37] == branch)
		assert(scene.living_enemies().size() == (1 if branch == 0 else 2))
		assert(scene.restore_checkpoint(scene.checkpoint.duplicate(true)))
		assert(scene.branch_choices[37] == branch)
		assert(scene.living_enemies().size() == (1 if branch == 0 else 2))
		await create_timer(1.8).timeout
		assert(not is_instance_valid(scene.room_portal))
		scene._update_route_hint(scene.ROUTE_HINT_DURATION)
		if not check(not scene.route_hint_panel.visible, "Late route guidance must expire while playing"):
			return
		# Opening a shared card overlay freezes enemies, including after pause.
		scene._open_choice(&"supply")
		var enemy = scene.living_enemies()[0]
		var position: Vector2 = enemy.position
		await create_timer(0.3).timeout
		assert(enemy.position == position)
		scene._toggle_pause()
		scene._toggle_pause()
		await create_timer(0.3).timeout
		assert(enemy.position == position and not enemy.is_physics_processing())
		scene._close_choice()
	for choice in [0, 1]:
		scene._load_layout(18)
		scene.claimed.erase(scene.rooms[18].id)
		scene.player.set_current_health(30)
		await create_timer(1.8).timeout
		await walk_to(scene, 1180)
		if not check(scene.route_hint_label.text.contains("战前补给") and scene.room_portal.get_meta(&"prompt_text").ends_with("选择战前补给") and scene.room_portal.get_meta(&"badge_text") == "补给", "Room 39 portal must advertise the supply choice"):
			return
		await interact()
		assert(scene.choice_kind == &"supply")
		var maximum: int = scene.player.get_max_health()
		if not check(scene.reward_cards[0].description.contains("补给后 70/%d 生命" % maximum) and scene.reward_cards[1].description.contains("补给后 50/%d 生命" % (maximum + 20)), "Both supply cards must forecast health when the player is wounded"):
			return
		scene.reward_view._upgrade_buttons[choice].pressed.emit()
		assert(scene.room_index == 19 and scene.claimed.has(&"forge_39"))
		if not check(scene.route_hint_label.text.contains("过载") and not is_instance_valid(scene.room_portal), "Room 40 must replace the supply hint and wait for the boss before offering the exit"):
			return
		assert(scene.player.get_current_health() == (70 if choice == 0 else 50))
		assert(scene.player.get_max_health() == maximum + (20 if choice == 1 else 0))
		assert(not scene.choose_final_option(choice))
	if not await verify_full_health_supply(scene):
		return
	scene.queue_free()
	await process_frame
	print("chapter2_final_choices_smoke: PASS")
	quit()
