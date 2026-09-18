extends SceneTree
func _initialize():
	call_deferred("run_test")
func run_test():
	var scene = load("res://scenes/Chapter2Journey.tscn").instantiate()
	scene.persistence_enabled = false
	root.add_child(scene)
	await create_timer(1.8).timeout
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
