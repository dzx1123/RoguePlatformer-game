extends SceneTree

func _initialize() -> void:
	call_deferred("run_test")

func enter_portal(scene: Node, opens_choice: bool = true) -> bool:
	var room_index: int = scene.room_index
	if scene.player.position.x < 1180.0:
		Input.action_press(&"move_right")
	for frame in range(600):
		if scene.player.position.x >= 1180.0 and is_instance_valid(scene.room_portal):
			break
		await physics_frame
	Input.action_release(&"move_right")
	if not is_instance_valid(scene.room_portal) or not scene.room_portal.is_in_range(scene.player.global_position):
		return fail("Room %d: player did not reach an active portal" % (room_index + 21))
	Input.action_press(&"interact")
	await physics_frame
	await physics_frame
	Input.action_release(&"interact")
	for frame in range(45):
		if opens_choice and scene.ritual_open:
			return true
		if not opens_choice and scene.room_index == room_index + 1:
			return true
		await physics_frame
	return fail("Room %d: portal did not resolve as expected" % (room_index + 21))

func click_option(scene: Node, index: int) -> bool:
	var button: Button = scene.reward_view._upgrade_buttons[index]
	if not button.visible or button.disabled:
		return fail("Choice %d is not available" % index)
	button.pressed.emit()
	return true

func clear_trial(scene: Node) -> bool:
	scene.claimed.erase(&"forge_33")
	scene._load_layout(12, true)
	if not await enter_portal(scene):
		return false
	if scene.choice_kind != &"trial":
		return fail("The trial did not offer its accept option")
	if not click_option(scene, 0):
		return false
	for wave in range(2):
		# physics_frame is emitted before room physics, so wait for the requested
		# wave number instead of accepting the previous wave's dying actors.
		for frame in range(180):
			if scene.next_wave == wave + 1:
				break
			await physics_frame
		var enemies: Array = scene.living_enemies()
		if scene.next_wave != wave + 1 or enemies.size() != 2:
			return fail("Trial wave %d was not spawned (next=%d, enemies=%d)" % [wave + 1, scene.next_wave, enemies.size()])
		for enemy: RogueEnemy in enemies:
			enemy.defeat()
	if not await enter_portal(scene):
		return false
	if scene.choice_kind != &"rare":
		return fail("Both trial waves cleared, but the reward choice is missing")
	return true

func verify_trial_rewards(scene: Node) -> bool:
	var weapon := WeaponCatalog.TWIN_BLADES
	scene.player.configure_weapon(weapon)
	var maxed: Dictionary = {}
	for upgrade in UpgradeCatalog.all_upgrades():
		if upgrade.weapon == weapon and upgrade.rarity == UpgradeCatalog.Rarity.RARE:
			maxed[upgrade.id] = upgrade.max_stacks
	if maxed.size() != 3:
		return fail("Test requires the three twin-blades rare upgrades")
	# One capped reward must not appear among the remaining weapon-specific rares.
	var capped: StringName = maxed.keys()[0]
	scene.player.restore_run_progression({capped: maxed[capped]}, 100)
	if not await clear_trial(scene):
		return false
	if scene.reward_cards.size() != maxed.size() - 1:
		return fail("A capped rare must be removed from the offered rewards")
	for card in scene.reward_cards:
		if card.get("weapon") != weapon or card.get("rarity") != UpgradeCatalog.Rarity.RARE or card.id == capped:
			return fail("The trial offered an ineligible upgrade: %s" % card)
	var chosen: StringName = scene.reward_cards[0].id
	var before_gold: int = scene.gold
	if not click_option(scene, 0):
		return false
	if scene.room_index != 13 or scene.player.get_run_upgrade_count(chosen) != 1 or scene.gold != before_gold:
		return fail("The trial did not award exactly one selected rare")

	scene.player.restore_run_progression(maxed, 100)
	if not await clear_trial(scene):
		return false
	if scene.reward_cards.size() != 1 or not scene.offered.is_empty() or scene.reward_view._upgrade_buttons[0].get_node("CardTitle").text != "领取金币" or scene.reward_view._upgrade_buttons[1].visible:
		return fail("A maxed build must see exactly one gold reward card")
	if not click_option(scene, 0):
		return false
	if scene.room_index != 13 or scene.gold != before_gold + 20 or not scene.claimed.has(&"forge_33") or scene.player.get_run_upgrade_counts() != maxed:
		return fail("The fallback must award exactly 20 gold and leave the build untouched")
	scene._select_reward_card(0)
	scene._load_layout(12, true)
	if not await enter_portal(scene, false):
		return false
	if scene.ritual_open or scene.gold != before_gold + 20:
		return fail("Revisit or repeated card input paid the reward twice")
	return true

func run_test() -> void:
	create_timer(65.0).timeout.connect(func(): fail("Trial and shop verification timed out"))
	var scene = load("res://scenes/Chapter2Journey.tscn").instantiate()
	scene.persistence_enabled = false
	root.add_child(scene)
	scene._load_layout(12)
	if scene._choice_title(&"trial").contains("重试"):
		fail("The trial must not promise a free retry")
		return
	if not await enter_portal(scene) or not click_option(scene, 1):
		return
	if scene.room_index != 13 or scene.claimed.get(&"forge_33") != &"declined" or not scene.living_enemies().is_empty():
		fail("Declining the trial must skip the waves and proceed to the shop")
		return
	scene.gold = 0
	if not await enter_portal(scene):
		return
	var upgrades: int = scene.player.get_total_run_upgrade_count()
	if not scene.reward_view._upgrade_buttons[0].disabled:
		fail("Unaffordable shop offers must be disabled")
		return
	scene._select_reward_card(0)
	if not scene.ritual_open or scene.gold != 0 or scene.room_index != 13 or scene.player.get_total_run_upgrade_count() != upgrades:
		fail("An unaffordable choice must leave the shop, gold and build unchanged")
		return
	var leave_button: Button = scene.reward_view.shop_exit_button
	if root.gui_get_focus_owner() != leave_button or not leave_button.visible or leave_button.disabled:
		fail("An unaffordable shop must focus the explicit Leave Shop action")
		return
	scene._toggle_pause()
	leave_button.pressed.emit()
	if not scene.ritual_open or not leave_button.disabled:
		fail("The shop exit must not run while the journey is paused")
		return
	scene._toggle_pause()
	if root.gui_get_focus_owner() != leave_button:
		fail("The leave button did not regain focus on resume")
		return
	var confirm := InputEventKey.new()
	confirm.keycode = KEY_ENTER
	confirm.pressed = true
	Input.parse_input_event(confirm)
	await process_frame
	confirm = confirm.duplicate() as InputEventKey
	confirm.pressed = false
	Input.parse_input_event(confirm)
	await process_frame
	if scene.room_index != 14 or scene.gold != 0 or scene.player.get_total_run_upgrade_count() != upgrades:
		fail("The player could not leave the shop without buying")
		return
	# A fresh room checks a successful purchase exactly once through its button.
	scene.claimed.erase(&"forge_34")
	scene._load_layout(13)
	scene.gold = 100
	if not await enter_portal(scene):
		return
	var cost: int = scene.offered[0].cost
	if not click_option(scene, 0):
		return
	if scene.room_index != 14 or scene.gold != 100 - cost or scene.player.get_total_run_upgrade_count() != upgrades + 1:
		fail("The shop did not charge for one purchase and advance")
		return
	if scene.choose_mid_option(0) or not is_instance_valid(scene.entry_beam):
		fail("The shop purchase repeated or missed the next room arrival")
		return
	if not await verify_trial_rewards(scene):
		return
	scene.queue_free()
	await process_frame
	print("chapter2_trial_shop_smoke: PASS")
	quit()

func fail(message: String) -> bool:
	push_error(message)
	quit(1)
	return false
