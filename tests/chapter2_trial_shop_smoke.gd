extends SceneTree

func _initialize() -> void:
	call_deferred("run_test")

func enter_portal(scene: Node) -> void:
	await create_timer(1.8).timeout
	Input.action_press(&"move_right")
	for frame in range(600):
		await physics_frame
		if scene.player.position.x >= 1180:
			break
	Input.action_release(&"move_right")
	Input.action_press(&"interact")
	await physics_frame
	await physics_frame
	Input.action_release(&"interact")
	await create_timer(0.3).timeout
	assert(scene.ritual_open)

func click_option(scene: Node, index: int) -> void:
	var button: Button = scene.reward_view._upgrade_buttons[index]
	assert(not button.disabled)
	button.pressed.emit()

func run_test() -> void:
	var scene = load("res://scenes/Chapter2Journey.tscn").instantiate()
	scene.persistence_enabled = false
	root.add_child(scene)
	scene._load_layout(12)
	assert(not scene._choice_title(&"trial").contains("重试"))
	await enter_portal(scene)
	click_option(scene, 1)
	assert(scene.room_index == 13 and scene.claimed[&"forge_33"] == &"declined")
	assert(scene.living_enemies().is_empty())
	scene.gold = 0
	await enter_portal(scene)
	var upgrades: int = scene.player.get_total_run_upgrade_count()
	assert(scene.reward_view._upgrade_buttons[0].disabled)
	scene._select_reward_card(0)
	assert(scene.ritual_open and scene.gold == 0 and scene.room_index == 13)
	assert(scene.player.get_total_run_upgrade_count() == upgrades)
	assert(scene.choose_mid_option(scene.offered.size()))
	assert(scene.room_index == 14)
	# A fresh room checks a successful purchase exactly once through its button.
	scene.claimed.erase(&"forge_34")
	scene._load_layout(13)
	scene.gold = 100
	await enter_portal(scene)
	var cost: int = scene.offered[0].cost
	click_option(scene, 0)
	assert(scene.room_index == 14 and scene.gold == 100 - cost)
	assert(scene.player.get_total_run_upgrade_count() == upgrades + 1)
	assert(not scene.choose_mid_option(0))
	assert(is_instance_valid(scene.entry_beam))
	scene.queue_free()
	await process_frame
	print("chapter2_trial_shop_smoke: PASS")
	quit()
