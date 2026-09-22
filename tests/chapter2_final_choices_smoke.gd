extends SceneTree
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
func run_test():
	var scene = load("res://scenes/Chapter2Journey.tscn").instantiate()
	scene.persistence_enabled = false
	root.add_child(scene)
	for branch in [0, 1]:
		scene.branch_choices.clear()
		scene._load_layout(16)
		await create_timer(1.8).timeout
		await walk_to(scene, 300)
		await interact()
		assert(scene.choice_kind == &"branch" and scene.reward_cards.size() == 2)
		scene.reward_view._upgrade_buttons[branch].pressed.emit()
		assert(scene.branch_choices[37] == branch)
		assert(scene.living_enemies().size() == (1 if branch == 0 else 2))
		assert(scene.restore_checkpoint(scene.checkpoint.duplicate(true)))
		assert(scene.branch_choices[37] == branch)
		assert(scene.living_enemies().size() == (1 if branch == 0 else 2))
		await create_timer(1.8).timeout
		assert(not is_instance_valid(scene.room_portal))
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
		await interact()
		assert(scene.choice_kind == &"supply")
		var maximum: int = scene.player.get_max_health()
		scene.reward_view._upgrade_buttons[choice].pressed.emit()
		assert(scene.room_index == 19 and scene.claimed.has(&"forge_39"))
		assert(scene.player.get_current_health() == (70 if choice == 0 else 50))
		assert(scene.player.get_max_health() == maximum + (20 if choice == 1 else 0))
		assert(not scene.choose_final_option(choice))
	scene.queue_free()
	await process_frame
	print("chapter2_final_choices_smoke: PASS")
	quit()
