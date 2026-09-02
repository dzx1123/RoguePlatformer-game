extends SceneTree

const TELEMETRY_SCRIPT := preload("res://scripts/run_telemetry.gd")
const TEMP_SAVE_PATH := "res://tests/run_telemetry_smoke_temp.json"


func _initialize() -> void:
	call_deferred(&"_run_test")


func _run_test() -> void:
	_remove_temporary_save()
	if not _verify_aggregation_and_persistence():
		return
	if not await _verify_main_signal_integration():
		return
	_remove_temporary_save()
	print("run_telemetry_smoke: PASS")
	quit(0)


func _verify_aggregation_and_persistence() -> bool:
	var telemetry = TELEMETRY_SCRIPT.new(TEMP_SAVE_PATH, true)
	telemetry.begin_run(246810, "简单", WeaponCatalog.SWORD)
	telemetry.begin_room(5, &"moon_gate", "月门", "首领房")
	telemetry.tick(12.5)
	telemetry.record_damage(18, &"boss_slam")
	var offers: Array[Dictionary] = [
		{"id": &"tempered_edge"},
		{"id": &"vitality_rune"},
		{"id": &"swift_step"},
	]
	telemetry.record_upgrade_offers(offers, WeaponCatalog.SWORD)
	telemetry.record_upgrade_choice(&"tempered_edge", WeaponCatalog.SWORD)
	telemetry.record_boss_defeat()
	telemetry.finish_run(true, WeaponCatalog.SWORD, &"victory")

	telemetry.begin_run(135790, "困难", WeaponCatalog.SWORD)
	telemetry.begin_room(2, &"broken_gallery", "断裂回廊", "战斗房")
	telemetry.tick(4.0)
	telemetry.record_damage(100, &"goblin_arrow")
	telemetry.record_death(&"goblin_arrow")
	telemetry.finish_run(false, WeaponCatalog.SWORD, &"goblin_arrow")

	var summary: Dictionary = telemetry.get_summary()
	if int(summary.get("runs_recorded", 0)) != 2:
		return _fail_bool("Telemetry did not retain both completed attempts")
	if int(summary.get("rooms_recorded", 0)) != 2:
		return _fail_bool("Telemetry did not retain room records")
	if int(summary.get("damage_taken", 0)) != 118:
		return _fail_bool("Telemetry damage total was incorrect")
	if int((summary.get("death_reasons", {}) as Dictionary).get("goblin_arrow", 0)) != 1:
		return _fail_bool("Telemetry did not aggregate the projectile death cause")
	if absf(float(summary.get("average_boss_kill_seconds", 0.0)) - 12.5) > 0.001:
		return _fail_bool("Telemetry did not retain the boss kill time")
	var upgrade_rate: Dictionary = (
		(summary.get("upgrade_choice_rates", {}) as Dictionary).get("tempered_edge", {})
		as Dictionary
	)
	if int(upgrade_rate.get("offered", 0)) != 1 or int(upgrade_rate.get("chosen", 0)) != 1:
		return _fail_bool("Telemetry did not calculate upgrade offer/choice counts")
	var weapon_rate: Dictionary = (
		(summary.get("weapon_clear_rates", {}) as Dictionary).get(String(WeaponCatalog.SWORD), {})
		as Dictionary
	)
	if int(weapon_rate.get("runs", 0)) != 2 or int(weapon_rate.get("wins", 0)) != 1:
		return _fail_bool("Telemetry did not calculate weapon clear performance")

	var loaded = TELEMETRY_SCRIPT.new(TEMP_SAVE_PATH, true)
	if not loaded.load_data():
		return _fail_bool("Telemetry save could not be loaded")
	var loaded_summary: Dictionary = loaded.get_summary()
	if (
		int(loaded_summary.get("runs_recorded", 0)) != 2
		or int(loaded_summary.get("damage_taken", 0)) != 118
	):
		return _fail_bool("Telemetry save round-trip changed the recorded totals")
	return true


func _verify_main_signal_integration() -> bool:
	var main_scene: PackedScene = load("res://scenes/Main.tscn")
	var main: Node2D = main_scene.instantiate() as Node2D
	main.set("save_enabled", false)
	root.add_child(main)
	await _wait_physics_frames(4)
	main.call(&"_clear_enemies")
	var player := main.get_node("Player") as RoguePlayer
	player.set_physics_process(false)
	player.set("_hurt_invulnerability_remaining", 0.0)
	if not player.receive_enemy_attack(player.global_position + Vector2.RIGHT, 7, &"enemy_melee"):
		main.queue_free()
		return _fail_bool("Player did not accept the telemetry integration hit")
	var current: Dictionary = main.call(&"get_run_telemetry_snapshot") as Dictionary
	if int(current.get("damage_taken", 0)) != 7:
		main.queue_free()
		return _fail_bool("Main did not forward player damage into telemetry")

	player.set("_hurt_invulnerability_remaining", 0.0)
	player.receive_enemy_attack(player.global_position + Vector2.RIGHT, 999, &"boss_slam")
	var summary: Dictionary = main.call(&"get_run_telemetry_summary") as Dictionary
	var reasons: Dictionary = summary.get("death_reasons", {}) as Dictionary
	if int(reasons.get("boss_slam", 0)) != 1:
		main.queue_free()
		return _fail_bool("Main did not close the failed run with the player's death cause")
	main.queue_free()
	await process_frame
	return true


func _wait_physics_frames(frame_count: int) -> void:
	for _frame in range(frame_count):
		await physics_frame


func _remove_temporary_save() -> void:
	for path: String in [TEMP_SAVE_PATH, TEMP_SAVE_PATH + ".tmp", TEMP_SAVE_PATH + ".bak"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _fail_bool(message: String) -> bool:
	push_error(message)
	quit(1)
	return false
