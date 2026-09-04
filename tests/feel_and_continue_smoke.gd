extends SceneTree

const CONTINUE_STORE := preload("res://scripts/run_continue_store.gd")
const EVENT_CATALOG := preload("res://scripts/event_catalog.gd")
const TEMP_SAVE_PATH := "res://tests/feel_and_continue_smoke_temp.json"


func _initialize() -> void:
	call_deferred(&"_run_test")


func _run_test() -> void:
	_remove_temporary_save()
	if not _verify_event_tradeoffs():
		return
	if not _verify_continue_store():
		return
	if not await _verify_combat_feel_and_recap():
		return
	_remove_temporary_save()
	print("feel_and_continue_smoke: PASS")
	quit(0)


func _verify_event_tradeoffs() -> bool:
	var choices: Array[Dictionary] = EVENT_CATALOG.create_choices()
	if choices.size() != 3:
		return _fail_bool("Event catalog no longer offers three responses")
	var gold_choice: Dictionary = choices[1]
	if int(gold_choice.get("amount", 0)) != 28 or int(gold_choice.get("damage", 0)) <= 0:
		return _fail_bool("Gold event is no longer a tradeoff that still grants 28 gold")
	var rest_choice: Dictionary = choices[0]
	if int(rest_choice.get("gold", 0)) >= 0 or int(rest_choice.get("heal", 0)) <= 0:
		return _fail_bool("Rest event is no longer a heal-for-gold tradeoff")
	var shard_choice: Dictionary = choices[2]
	if int(shard_choice.get("max_health", 0)) >= 0:
		return _fail_bool("Shard event no longer reduces maximum health")
	return true


func _verify_continue_store() -> bool:
	var store = CONTINUE_STORE.new(TEMP_SAVE_PATH, true)
	var snapshot := {
		"version": 1,
		"seed": 4242,
		"room_index": 3,
		"room_sequence": [0, 1, 2, 3],
		"encounter_sequence": [0, 1, 2, 4],
		"upgrade_counts": {"tempered_edge": 1},
		"weapon_id": String(WeaponCatalog.SWORD),
		"health": 72,
	}
	if store.save_snapshot(snapshot) != OK or not store.has_snapshot():
		return _fail_bool("Continue store did not retain a valid snapshot")
	var loaded = CONTINUE_STORE.new(TEMP_SAVE_PATH, true)
	if not loaded.load_snapshot():
		return _fail_bool("Continue store could not reload the snapshot")
	if int(loaded.get_snapshot().get("seed", 0)) != 4242:
		return _fail_bool("Continue store round-trip changed the seed")
	if loaded.clear_snapshot() != OK or loaded.has_snapshot():
		return _fail_bool("Continue store did not clear the snapshot")
	return true


func _verify_combat_feel_and_recap() -> bool:
	var main_scene: PackedScene = load("res://scenes/Main.tscn")
	var main: Node2D = main_scene.instantiate() as Node2D
	main.set("save_enabled", false)
	main.call(&"set_next_run_seed", 424242)
	root.add_child(main)
	var player: RoguePlayer = main.get_node("Player") as RoguePlayer
	for _settle_frame in range(18):
		await physics_frame

	if int(main.call(&"get_music_state")) != RogueSoundscape.MusicState.COMBAT:
		return _fail_main(main, "Combat rooms did not switch the soundtrack state")

	var tutorial: Dictionary = main.call(&"get_tutorial_snapshot") as Dictionary
	if bool(tutorial.get("visible", true)):
		return _fail_main(main, "Tutorial appeared in a save-disabled smoke run")

	player.set("_attack_remaining", 0.20)
	player.set("_attack_hit_emitted", false)
	player.set("_dash_cooldown_remaining", 0.0)
	player.set("_dash_remaining", 0.0)
	player.set("_hurt_remaining", 0.0)
	if bool(player.can_cancel_into_dash()):
		return _fail_main(main, "Dash cancel was allowed before the attack connected")
	player.set("_attack_hit_emitted", true)
	if not bool(player.can_cancel_into_dash()):
		return _fail_main(main, "Dash cancel was blocked after the attack connected")
	player.set("_attack_remaining", 0.0)
	player.set("_attack_hit_emitted", false)

	var enemies: Array = main.get("_enemies") as Array
	var target: RogueEnemy
	for enemy_value: Variant in enemies:
		var enemy: RogueEnemy = enemy_value as RogueEnemy
		if is_instance_valid(enemy) and not enemy.is_ranged_enemy():
			target = enemy
			break
	if target == null:
		return _fail_main(main, "No melee enemy was available for hitstop")
	main.call(&"_apply_hitstop", target, false)
	if player.get_hitstop_remaining() <= 0.0 or target.get_hitstop_remaining() <= 0.0:
		return _fail_main(main, "Confirmed hits did not apply hitstop")

	main.call(&"_show_event_choice")
	var event_choices: Array = main.call(&"get_upgrade_choices") as Array
	if event_choices.size() != 3:
		return _fail_main(main, "Forced event overlay did not present three tradeoffs")
	var health_before_event: int = player.get_current_health()
	var gold_before_event: int = int(main.call(&"get_gold"))
	if not bool(main.call(&"choose_upgrade", 1)):
		return _fail_main(main, "Gold event tradeoff could not be selected")
	if int(main.call(&"get_gold")) < gold_before_event + 28:
		return _fail_main(main, "Gold event no longer grants 28 gold")
	if player.get_current_health() >= health_before_event:
		return _fail_main(main, "Gold event did not apply its health cost")

	var gold_before_save: int = int(main.call(&"get_gold"))
	if not bool(main.call(&"persist_continue_snapshot_for_test")):
		return _fail_main(main, "In-memory continue snapshot was not created")
	main.set("_gold", gold_before_save + 50)
	if not bool(main.call(&"continue_saved_run_for_test")):
		return _fail_main(main, "Continue restore failed")
	if int(main.call(&"get_gold")) != gold_before_save:
		return _fail_main(main, "Continue restore did not keep the saved gold total")

	player.set("_hurt_invulnerability_remaining", 0.0)
	player.receive_enemy_attack(player.global_position + Vector2(40.0, 0.0), 999)
	await process_frame
	var recap: Dictionary = main.call(&"get_death_recap_snapshot") as Dictionary
	if not bool(recap.get("visible", false)) or not String(recap.get("body", "")).contains("死因"):
		return _fail_main(main, "Death recap did not appear after a lethal hit")

	main.queue_free()
	return true


func _fail_main(main: Node2D, message: String) -> bool:
	main.queue_free()
	return _fail_bool(message)


func _fail_bool(message: String) -> bool:
	push_error(message)
	quit(1)
	return false


func _remove_temporary_save() -> void:
	for path in [
		TEMP_SAVE_PATH,
		TEMP_SAVE_PATH + ".tmp",
		TEMP_SAVE_PATH + ".bak",
	]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
