extends SceneTree
func _initialize():
	call_deferred("run_test")
func run_test():
	var scene = load("res://scenes/Chapter2Journey.tscn").instantiate()
	scene.persistence_enabled = false
	root.add_child(scene)
	await create_timer(1.8).timeout
	scene._load_layout(3)
	scene.player.set_current_health(90)
	scene._open_choice(&"ritual")
	await create_timer(0.6).timeout
	var left: Button = scene.reward_view._upgrade_buttons[0]
	var right: Button = scene.reward_view._upgrade_buttons[1]
	assert(not scene.reward_view._upgrade_buttons[2].visible)
	assert(is_equal_approx((left.position.x + right.get_rect().end.x) / 2.0, left.get_parent().size.x / 2.0))
	assert(left.get_node(left.focus_neighbor_right) == right and right.get_node(right.focus_neighbor_right) == left)
	assert(right.get_node("CardTitle").text == "恢复生命")
	assert(right.get_node("CardDescription").text == "当前可恢复 10 生命")
	right.pressed.emit()
	assert(scene.room_index == 4 and scene.player.get_current_health() == 100)
	for weapon in WeaponCatalog.all_weapon_ids():
		scene._load_layout(4)
		scene.claimed.erase(scene.rooms[4].id)
		scene.player.configure_weapon(weapon)
		scene._open_choice(&"upgrade")
		assert(scene.reward_cards.size() == 3)
		assert(not scene.ritual_panel.visible)
		for card in scene.reward_cards:
			assert(str(card.get("weapon", "")).is_empty() or card.weapon == weapon)
		var before: int = scene.player.get_total_run_upgrade_count()
		if "capture" in OS.get_cmdline_user_args():
			await create_timer(0.7).timeout
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://test_output/chapter2_shared_cards.png")
		scene.reward_view._upgrade_buttons[0].pressed.emit()
		assert(scene.player.get_total_run_upgrade_count() == before + 1)
		assert(scene.room_index == 5 and not scene.ritual_open)
		scene._select_reward_card(0)
		assert(scene.player.get_total_run_upgrade_count() == before + 1)
	scene._load_layout(13)
	scene.claimed.erase(scene.rooms[13].id)
	scene.gold = 0
	scene._open_choice(&"shop")
	assert(scene.reward_cards.size() == 3)
	for button in scene.reward_view._upgrade_buttons:
		assert(button.disabled)
	assert(scene.choose_mid_option(scene.offered.size()))
	assert(scene.room_index == 14)
	scene.queue_free()
	await process_frame
	print("chapter2_reward_cards_smoke: PASS")
	quit()
