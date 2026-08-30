extends SceneTree


func _initialize() -> void:
	call_deferred(&"_run_test")


func _run_test() -> void:
	var main_scene: PackedScene = load("res://scenes/Main.tscn")
	var main: Node2D = main_scene.instantiate() as Node2D
	main.set("save_enabled", false)
	root.add_child(main)
	var player: RoguePlayer = main.get_node("Player") as RoguePlayer
	await _wait_physics_frames(12)

	var sequence_ids: Array[StringName] = main.call(&"get_room_sequence_ids") as Array[StringName]
	if sequence_ids.size() != 5:
		_fail("Run did not assemble exactly five rooms")
		return
	var unique_ids: Dictionary = {}
	for room_id in sequence_ids:
		unique_ids[room_id] = true
	if unique_ids.size() < 4:
		_fail("Random room route repeated too many layouts")
		return
	if int(main.call(&"get_current_room_number")) != 1:
		_fail("A new run did not begin in room one")
		return
	if (main.get("platform_rects") as Array).size() < 4:
		_fail("The current handcrafted room did not create its platforms")
		return

	var baseline_stats: Dictionary = player.call(&"get_run_stats") as Dictionary
	_defeat_current_room(main)
	await _wait_physics_frames(32)
	if not bool(main.call(&"is_choosing_upgrade")):
		_fail("Clearing a non-final room did not open the upgrade choice")
		return
	var choices: Array[Dictionary] = main.call(&"get_upgrade_choices") as Array[Dictionary]
	if choices.size() != 3:
		_fail("Room clear did not provide three upgrade choices")
		return
	var choice_ids: Dictionary = {}
	for choice in choices:
		choice_ids[choice.get("id", &"")] = true
	if choice_ids.size() != 3:
		_fail("Upgrade choices contained duplicates")
		return
	if not bool(main.call(&"choose_upgrade", 0)):
		_fail("A valid upgrade choice was rejected")
		return
	await _wait_physics_frames(8)
	if int(main.call(&"get_current_room_number")) != 2:
		_fail("Choosing an upgrade did not advance to room two")
		return
	var upgraded_stats: Dictionary = player.call(&"get_run_stats") as Dictionary
	if not _stats_changed(baseline_stats, upgraded_stats):
		_fail("Selected upgrade did not change any persistent run stat")
		return

	_disable_current_enemies(main)
	player.set("_hurt_invulnerability_remaining", 0.0)
	var generation_before_death: int = int(main.get("_run_generation"))
	player.receive_enemy_attack(player.global_position + Vector2(60.0, 0.0), 999)
	if not player.is_dead():
		_fail("Lethal damage did not begin the run-death flow")
		return
	await _wait_physics_frames(82)
	if int(main.get("_run_generation")) <= generation_before_death:
		_fail("Death did not generate a fresh run")
		return
	if player.is_dead() or int(main.call(&"get_current_room_number")) != 1:
		_fail("Fresh run did not restore the player in room one")
		return
	var reset_stats: Dictionary = player.call(&"get_run_stats") as Dictionary
	if _stats_changed(baseline_stats, reset_stats):
		_fail("Run upgrades were not reset after death")
		return

	for room_number in range(1, 6):
		_defeat_current_room(main)
		await _wait_physics_frames(32)
		if bool(main.call(&"is_awaiting_chest")):
			if not bool(main.call(&"open_current_chest_for_test")):
				_fail("Treasure room chest could not be opened")
				return
			await _wait_physics_frames(5)
		if room_number < 5:
			if not bool(main.call(&"is_choosing_upgrade")):
				_fail("Room %d did not lead to an upgrade choice" % room_number)
				return
			if not bool(main.call(&"choose_upgrade", 0)):
				_fail("Room %d upgrade choice failed" % room_number)
				return
			await _wait_physics_frames(5)
			if int(main.call(&"get_current_room_number")) != room_number + 1:
				_fail("Run did not advance after room %d" % room_number)
				return
		else:
			if not bool(main.call(&"is_run_complete")):
				_fail("Clearing the fifth room did not complete the run")
				return

	main.queue_free()
	print("run_structure_smoke: PASS")
	quit(0)


func _defeat_current_room(main: Node2D) -> void:
	var enemies: Array = (main.get("_enemies") as Array).duplicate()
	for enemy_value in enemies:
		var enemy: RogueEnemy = enemy_value as RogueEnemy
		if is_instance_valid(enemy):
			enemy.defeat()


func _disable_current_enemies(main: Node2D) -> void:
	var enemies: Array = main.get("_enemies") as Array
	for enemy_value in enemies:
		var enemy: RogueEnemy = enemy_value as RogueEnemy
		enemy.set_physics_process(false)


func _stats_changed(before: Dictionary, after: Dictionary) -> bool:
	for stat_name in before:
		if before[stat_name] != after.get(stat_name):
			return true
	return false


func _wait_physics_frames(frame_count: int) -> void:
	for _frame_index in range(frame_count):
		await physics_frame


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
