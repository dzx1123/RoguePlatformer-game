extends "res://tests/chapter2_mixed_combat_smoke.gd"

const BOSS_COMBAT := preload("res://tests/chapter2_boss_combat_smoke.gd")
const STORE := preload("res://scripts/campaign_continue_store.gd")
const FIRST_ROOM := 35
const LAST_ROOM := 40
const FIRST_MID_ROOM := 27
const LAST_MID_ROOM := 34
const SEED := 762153
const INITIAL_HEALTH := 120
const INITIAL_MAX_HEALTH := 140
const INITIAL_GOLD := 64
const INITIAL_SHARDS := 18
const INITIAL_LIVES := 2
const INHERITED_UPGRADES := {&"tempered_edge": 2, &"vitality_rune": 2}

var fixture_prefix := "res://test_output/chapter2_late_combat_%d" % OS.get_process_id()
var continue_path := fixture_prefix + "_continue.json"
var progression_path := fixture_prefix + "_progression.json"
var telemetry_path := fixture_prefix + "_telemetry.json"


func run_test() -> void:
	create_timer(560.0).timeout.connect(func(): fail("Campaign combat timed out"); quit(1))
	var test_mid := "mid_rooms" in OS.get_cmdline_user_args()
	var weapons := WeaponCatalog.all_weapon_ids()
	for argument in OS.get_cmdline_user_args():
		if StringName(argument) in weapons:
			weapons = [StringName(argument)]
			break
	for weapon: StringName in weapons:
		var passed := await play_mid_campaign(weapon) if test_mid else await play_late_campaign(weapon)
		if not passed:
			quit(1)
			return
	print("chapter2_mid_campaign_combat_smoke: PASS" if test_mid else "chapter2_late_campaign_combat_smoke: PASS")
	quit()


func start_campaign(weapon: StringName, first_room: int) -> Dictionary:
	var store := STORE.new(continue_path, true, "")
	var progression := ProgressionStore.new(progression_path)
	var telemetry := RunTelemetry.new(telemetry_path)
	if not cleanup_profiles(store):
		return {}
	var snapshot := {
		"version": 1, "chapter": 2, "room_index": first_room - 21,
		"weapon_id": str(weapon), "health": INITIAL_HEALTH,
		"max_health": INITIAL_MAX_HEALTH, "gold": INITIAL_GOLD,
		"upgrade_counts": INHERITED_UPGRADES.duplicate(), "claimed": {},
		"branches": {}, "cooling_room": -1, "completed": false,
		"campaign": {"seed": SEED, "difficulty": CombatBudget.MEDIUM, "lives": INITIAL_LIVES,
			"run_shards": INITIAL_SHARDS, "run_number": 1},
	}
	if store.save_snapshot(snapshot) != OK or not store.load_snapshot():
		fail("Could not prepare the isolated room %d campaign checkpoint" % first_room)
		return {}
	telemetry.begin_run(SEED, "中等", weapon)
	var main := (load("res://scenes/Main.tscn") as PackedScene).instantiate()
	main.save_enabled = false
	main.continue_save_path = continue_path
	root.add_child(main)
	current_scene = main
	main.save_enabled = true
	main._continue_store = store
	main._show_start_screen()
	set_meta(&"campaign_runtime", {"progression": progression, "telemetry": telemetry, "save_enabled": true})
	main._continue_button.pressed.emit()
	await settle_scene()
	var journey := current_scene
	if not is_instance_valid(journey) or not journey.scene_file_path.ends_with("Chapter2Journey.tscn"):
		fail("Title Continue did not open the official chapter two scene")
		return {}
	if not check_room_checkpoint(journey, store, first_room, weapon, INITIAL_HEALTH, INHERITED_UPGRADES):
		return {}
	if journey.gold != INITIAL_GOLD or journey.player.get_max_health() != INITIAL_MAX_HEALTH:
		fail("The starting checkpoint lost inherited gold or maximum health")
		return {}
	print("Campaign / %s: room %d checkpoint, normal difficulty, health=%d/%d, inherited=%s" % [
		weapon, first_room, INITIAL_HEALTH, INITIAL_MAX_HEALTH, INHERITED_UPGRADES])
	return {"journey": journey, "store": store, "progression": progression, "telemetry": telemetry}


func play_late_campaign(weapon: StringName) -> bool:
	var run := await start_campaign(weapon, FIRST_ROOM)
	if run.is_empty():
		return false
	var journey: Node = run.journey
	var store: RunContinueStore = run.store
	var progression: ProgressionStore = run.progression
	var telemetry: RunTelemetry = run.telemetry
	var earned_upgrades := INHERITED_UPGRADES.duplicate()
	for room in range(FIRST_ROOM, LAST_ROOM + 1):
		await create_timer(1.8).timeout
		var starting_health: int = journey.player.get_current_health()
		var upper_caster_id := 0
		var defeat_order: Array[int] = []
		if room == 36:
			var approach_high := weapon == WeaponCatalog.GREATSWORD and "lower_walkway" not in OS.get_cmdline_user_args()
			if approach_high:
				if not await take_upper_route(journey):
					return fail("Room 36: could not climb the four steps to the casting platform")
				if not is_instance_valid(journey.caster) or absf(journey.caster.position.y - journey.player.position.y) > 16.0:
					return fail("Room 36: the upper route did not reach the caster's level")
				upper_caster_id = journey.caster.get_instance_id()
				for enemy: RogueEnemy in journey.living_enemies():
					var enemy_id := enemy.get_instance_id()
					enemy.defeated.connect(func(): defeat_order.append(enemy_id))
			print("Room 36 / %s: %s approach" % [weapon, "upper" if approach_high else "ground"])
		if room == 37 and not await choose_branch(journey, 0 if weapon == WeaponCatalog.SWORD else 1):
			return false
		if room == LAST_ROOM:
			if journey.overseer.get_max_health() <= 520:
				return fail("The formal normal-difficulty profile did not scale the boss")
			if not await BOSS_COMBAT.clear_boss(journey):
				return false
			if journey.overheat or not journey.embers.get_children().is_empty():
				return fail("Boss defeat left its hazards active")
		elif room != 39 and not await clear_encounter(journey, true):
			return false
		if upper_caster_id != 0 and (defeat_order.is_empty() or defeat_order[0] != upper_caster_id):
			return fail("Room 36: the upper approach should let the player defeat the caster first")
		var health_at_exit := await enter_portal(journey)
		if health_at_exit < 1:
			return fail("Room %d: player did not walk to its active exit" % room)
		var expected_health := health_at_exit
		if room == 35:
			if journey.choice_kind != &"upgrade":
				return fail("Room 35: both waves did not lead to the reward choice")
			expected_health = preview_offer_health(journey, health_at_exit, journey.reward_cards[0])
			record_offer(earned_upgrades, journey.reward_cards[0])
			await choose_card(KEY_1)
		elif room == 39:
			if journey.choice_kind != &"supply":
				return fail("Room 39: the portal did not open supplies")
			var old_max_health: int = journey.player.get_max_health()
			if health_at_exit < old_max_health:
				await choose_card(KEY_1)
				expected_health = mini(old_max_health, health_at_exit + 40)
			else:
				var reward := StringName(journey.reward_cards[1].id)
				var gold_before: int = journey.gold
				await choose_card(KEY_2)
				if reward == &"vitality_rune":
					earned_upgrades[reward] = int(earned_upgrades.get(reward, 0)) + 1
					expected_health += 20
				elif reward != &"gold" or journey.gold != gold_before + 15:
					return fail("Room 39: full-health supply did not grant the available reward")
		if room < LAST_ROOM and not check_room_checkpoint(journey, store, room + 1, weapon, expected_health, earned_upgrades):
			return false
		print("Late campaign room %d / %s: health %d -> %d at exit -> %d after reward" % [
			room, weapon, starting_health, health_at_exit, expected_health])
	await settle_scene()
	var main := current_scene
	if not is_instance_valid(main) or not main.scene_file_path.ends_with("Main.tscn") or not main._flow_state.run_complete:
		return fail("Winning the boss and entering its portal did not open official victory")
	if main._lives_remaining != INITIAL_LIVES or main._run_seed != SEED or main.player.get_weapon_id() != weapon:
		return fail("Victory lost the inherited lives, seed, or weapon")
	if FileAccess.file_exists(continue_path) or progression.get_runs_completed() != 1 or progression.get_meta_shards() <= INITIAL_SHARDS:
		return fail("Victory did not consume the same checkpoint and bank progression")
	var history := telemetry.get_history()
	if history.size() != 1 or not history[0].victory or history[0].rooms.size() != LAST_ROOM - FIRST_ROOM + 1:
		return fail("Telemetry did not record one victory through all six rooms")
	if "diagnose" in OS.get_cmdline_user_args():
		for room_result: Dictionary in history[0].rooms:
			if int(room_result.damage_taken) > 0:
				print("Room %d damage / %s: %s" % [room_result.room_number, weapon, room_result.damage_sources])
	print("Late campaign / %s: official victory, took %d damage, retained %d lives" % [
		weapon, history[0].damage_taken, main._lives_remaining])
	main.queue_free()
	await process_frame
	return cleanup_profiles(store)


func play_mid_campaign(weapon: StringName) -> bool:
	var run := await start_campaign(weapon, FIRST_MID_ROOM)
	if run.is_empty():
		return false
	var journey: Node = run.journey
	var store: RunContinueStore = run.store
	var telemetry: RunTelemetry = run.telemetry
	var earned_upgrades := INHERITED_UPGRADES.duplicate()
	for room in range(FIRST_MID_ROOM, LAST_MID_ROOM + 1):
		await create_timer(1.8).timeout
		var starting_health: int = journey.player.get_current_health()
		var expected_gold: int = journey.gold
		var trial_declined := room == 33 and weapon == WeaponCatalog.GREATSWORD
		if room == 29 and weapon == WeaponCatalog.SWORD:
			if not await claim_side_chest(journey, store):
				return false
			expected_gold += 15
		if room == 32 and weapon == WeaponCatalog.GREATSWORD:
			if not await take_upper_route(journey):
				return fail("Room 32: could not reach the caster by its four platforms")
			if not is_instance_valid(journey.caster) or absf(journey.player.position.y - journey.caster.position.y) > 16.0:
				return fail("Room 32: the high route did not reach the caster's level")
			print("Room 32 / %s: upper approach" % weapon)
		if room == 33:
			if await enter_portal(journey) < 1 or journey.choice_kind != &"trial":
				return fail("Room 33: the real portal did not open the trial invitation")
			await choose_card(KEY_2 if trial_declined else KEY_1)
			if not trial_declined and not journey.trial_active:
				return fail("Room 33: accepting the trial did not start its waves")
		var health_at_exit: int = starting_health
		if not trial_declined:
			if not await clear_encounter(journey, true):
				return false
			var room_data: Dictionary = journey.rooms[journey.room_index]
			if room in [30, 33] and journey.next_wave != room_data.waves.size():
				return fail("Room %d: the portal appeared before all waves were finished" % room)
			if room_data.reward == &"gold":
				expected_gold += journey.room_gold
			health_at_exit = await enter_portal(journey)
			if health_at_exit < 1:
				return fail("Room %d: player did not walk to its active exit" % room)
		var expected_health := health_at_exit
		match room:
			28:
				if journey.choice_kind != &"toll":
					return fail("Room 28: portal did not open the forge toll")
				if weapon == WeaponCatalog.GREATSWORD or health_at_exit <= journey.TOLL_COST:
					await choose_card(KEY_1 + journey.offered.size())
				else:
					record_offer(earned_upgrades, journey.offered[0])
					expected_health -= journey.TOLL_COST
					await choose_card(KEY_1)
			30:
				if journey.choice_kind != &"upgrade":
					return fail("Room 30: the two waves did not produce a relic choice")
				expected_health = preview_offer_health(journey, health_at_exit, journey.reward_cards[0])
				record_offer(earned_upgrades, journey.reward_cards[0])
				await choose_card(KEY_1)
			33:
				if not trial_declined:
					if journey.choice_kind != &"rare" or journey.offered.is_empty():
						return fail("Room 33: the completed trial did not offer a weapon rare")
					var offer: Dictionary = journey.offered[0]
					if offer.weapon != weapon or int(offer.rarity) != UpgradeCatalog.Rarity.RARE:
						return fail("Room 33: accepted trial did not offer its promised weapon rare")
					record_offer(earned_upgrades, offer)
					await choose_card(KEY_1)
			34:
				if journey.choice_kind != &"shop":
					return fail("Room 34: portal did not open the merchant")
				if weapon == WeaponCatalog.GREATSWORD:
					await press_interact_event()
				else:
					var offer: Dictionary = journey.offered[0]
					if int(offer.cost) > expected_gold:
						return fail("Room 34: initial shop offer exceeds the funded fixture")
					expected_gold -= int(offer.cost)
					expected_health = preview_offer_health(journey, health_at_exit, offer)
					record_offer(earned_upgrades, offer)
					await choose_card(KEY_1)
		if not check_room_checkpoint(journey, store, room + 1, weapon, expected_health, earned_upgrades):
			return false
		if journey.gold != expected_gold or int(store.get_snapshot().gold) != expected_gold:
			return fail("Room %d: expected %d gold and carried %d" % [room, expected_gold, journey.gold])
		print("Mid campaign room %d / %s: health %d -> %d, gold=%d" % [
			room, weapon, starting_health, expected_health, expected_gold])
	var disk := STORE.new(continue_path, true, "")
	if not disk.load_snapshot() or not check_room_checkpoint(journey, disk, LAST_MID_ROOM + 1, weapon, journey.player.get_current_health(), earned_upgrades):
		return fail("The story checkpoint could not be reloaded after room 34")
	var active_run := telemetry.get_current_run_snapshot()
	if active_run.rooms.size() != LAST_MID_ROOM - FIRST_MID_ROOM + 1:
		return fail("Telemetry did not record the whole mid-campaign segment")
	if "diagnose" in OS.get_cmdline_user_args():
		for room_result: Dictionary in active_run.rooms:
			if int(room_result.damage_taken) > 0:
				print("Room %d damage / %s: %s" % [room_result.room_number, weapon, room_result.damage_sources])
	current_scene = null
	journey.queue_free()
	await settle_scene()
	return cleanup_profiles(store)


func claim_side_chest(journey: Node, store: RunContinueStore) -> bool:
	var room: Dictionary = journey.rooms[journey.room_index]
	if not await take_upper_route(journey, 2, float(room.chest.x)):
		return fail("Room 29: player could not climb to the chain chest")
	var gold_before: int = journey.gold
	await press_interact_event()
	if journey.gold != gold_before + 15 or not store.get_snapshot().claimed.has(&"chain_chest"):
		return fail("Room 29: reached the chest but could not collect and save its reward")
	await press_interact_event()
	if journey.gold != gold_before + 15:
		return fail("Room 29: the same chest rewarded gold twice")
	print("Room 29: chest reached by actual jumps, +15 gold once")
	return true


func press_interact_event() -> void:
	var event := InputEventAction.new()
	event.action = &"interact"
	event.pressed = true
	Input.parse_input_event(event)
	await physics_frame
	await physics_frame
	var release := event.duplicate() as InputEventAction
	release.pressed = false
	Input.parse_input_event(release)
	await process_frame


func record_offer(upgrades: Dictionary, offer: Dictionary) -> void:
	var upgrade := StringName(offer.id)
	upgrades[upgrade] = int(upgrades.get(upgrade, 0)) + 1


func preview_offer_health(journey: Node, health: int, offer: Dictionary) -> int:
	match StringName(offer.id):
		&"vitality_rune": return health + 20
		&"second_wind": return mini(journey.player.get_max_health(), health + 35)
	return health


func check_room_checkpoint(journey: Node, store: RunContinueStore, room: int, weapon: StringName, health: int, build: Dictionary) -> bool:
	if not is_instance_valid(journey) or journey.room_index != room - 21:
		return fail("Did not arrive at room %d" % room)
	if journey.player.get_current_health() != health or journey.player.get_weapon_id() != weapon:
		return fail("Room %d: changed health or weapon during travel" % room)
	if journey.player.get_run_upgrade_counts() != build:
		return fail("Room %d: changed the player's build during travel" % room)
	if journey.campaign.seed != SEED or journey.campaign.difficulty != CombatBudget.MEDIUM or journey.campaign.lives != INITIAL_LIVES:
		return fail("Room %d: changed the official campaign identity or difficulty" % room)
	var snapshot := store.get_snapshot()
	if snapshot.room_index != room - 21 or snapshot.health != health or snapshot.completed:
		return fail("Room %d: failed to save the new room to the shared checkpoint" % room)
	var saved_build := {}
	for id in snapshot.upgrade_counts:
		saved_build[StringName(id)] = int(snapshot.upgrade_counts[id])
	if saved_build != build or int(snapshot.max_health) != journey.player.get_max_health():
		return fail("Room %d: the shared checkpoint did not retain the applied build or health cap" % room)
	return true


func choose_branch(journey: Node, choice: int) -> bool:
	if not await walk_to_x(journey.player, journey.BRANCH_SIGN.x):
		return fail("Room 37: player did not reach the branch sign")
	Input.action_press(&"interact")
	await physics_frame
	await physics_frame
	Input.action_release(&"interact")
	if journey.choice_kind != &"branch":
		return fail("Room 37: branch sign did not open its cards")
	await choose_card(KEY_1 if choice == 0 else KEY_2)
	if journey.branch_choices.get(37, -1) != choice or journey.living_enemies().is_empty():
		return fail("Room 37: selected branch did not start its encounter")
	return true


func settle_scene() -> void:
	for frame in range(5):
		await process_frame


func cleanup_profiles(store: RunContinueStore) -> bool:
	if store.clear_snapshot() != OK or SafeJsonStore.remove_dictionary(progression_path) != OK or SafeJsonStore.remove_dictionary(telemetry_path) != OK:
		return fail("Could not clean the isolated campaign test profiles")
	return true


func fail(message: String) -> bool:
	release_inputs()
	Input.action_release(&"interact")
	push_error(message)
	return false
