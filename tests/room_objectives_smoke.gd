extends SceneTree

var _saw_time_trial: bool = false
var _saw_holdout: bool = false
var _saw_elite_hunt: bool = false
var _saw_branch_reward: bool = false


func _initialize() -> void:
	call_deferred(&"_run_test")


func _run_test() -> void:
	var main_scene: PackedScene = load("res://scenes/Main.tscn")
	var main: Node2D = main_scene.instantiate() as Node2D
	main.set("save_enabled", false)
	root.add_child(main)
	var player: RoguePlayer = main.get_node("Player") as RoguePlayer
	player.set_physics_process(false)
	await _wait_physics_frames(12)

	var safety_steps: int = 0
	while safety_steps < 28 and not bool(main.call(&"is_run_complete")):
		safety_steps += 1
		if bool(main.call(&"is_event_active")):
			if not bool(main.call(&"choose_upgrade", 0)):
				_fail("Event room could not resolve")
				return
			await _wait_physics_frames(6)
			continue
		if bool(main.call(&"is_shopping")):
			main.call(&"_leave_shop")
			await _wait_physics_frames(6)
			continue

		var objective_name: String = String(main.call(&"get_current_objective_name"))
		if objective_name == "branch_reward":
			_saw_branch_reward = true
			if not bool(main.call(&"is_awaiting_chest")):
				_fail("Branch reward room did not start with a risk chest")
				return
			if not bool(main.call(&"open_current_chest_for_test")):
				_fail("Risk chest could not be opened")
				return
			await _wait_physics_frames(3)
			_defeat_current_room(main)
		else:
			if objective_name == "time_trial":
				if not _verify_time_trial(main, player):
					return
				_saw_time_trial = true
			elif objective_name == "holdout":
				if not _verify_holdout(main, player):
					return
				_saw_holdout = true
			elif objective_name == "elite_hunt":
				var hunt_snapshot: Dictionary = main.call(&"get_room_objective_snapshot") as Dictionary
				if not bool(hunt_snapshot.get("has_hunt_target", false)):
					_fail("Elite hunt room had no marked captain")
					return
				_saw_elite_hunt = true
			_defeat_current_room(main)

		await _wait_physics_frames(40)
		if bool(main.call(&"is_awaiting_chest")):
			if not bool(main.call(&"open_current_chest_for_test")):
				_fail("Reward chest could not be opened")
				return
			await _wait_physics_frames(6)
		if bool(main.call(&"is_awaiting_exit")):
			player.global_position = (main.get_node("RoomExitPortal") as Node2D).global_position
			if not bool(main.call(&"_activate_room_exit")):
				_fail("Room objective exit portal could not be activated")
				return
			await _wait_physics_frames(20)
		if bool(main.call(&"is_choosing_upgrade")):
			if not bool(main.call(&"choose_upgrade", 0)):
				_fail("Room objective did not return to the upgrade flow")
				return
			await _wait_physics_frames(6)

	if not (_saw_time_trial and _saw_holdout and _saw_elite_hunt and _saw_branch_reward):
		_fail(
			"Missing objective types (time %s, holdout %s, hunt %s, branch %s)"
			% [_saw_time_trial, _saw_holdout, _saw_elite_hunt, _saw_branch_reward]
		)
		return
	print("room_objectives_smoke: PASS")
	quit(0)


func _verify_time_trial(main: Node2D, player: RoguePlayer) -> bool:
	var snapshot: Dictionary = main.call(&"get_room_objective_snapshot") as Dictionary
	if float(snapshot.get("timer_remaining", 0.0)) <= 0.0 or int(snapshot.get("trap_count", 0)) <= 0:
		_fail("Time trial did not configure timer/traps: %s" % [snapshot])
		return false
	var trap_zones: Array = main.get("_objective_trap_zones") as Array
	if trap_zones.is_empty():
		_fail("Time trial exposed no trap geometry")
		return false
	var first_trap: Rect2 = trap_zones[0] as Rect2
	player.global_position = first_trap.get_center()
	player.set("_hurt_invulnerability_remaining", 0.0)
	main.set("_objective_trap_pulse_remaining", 0.0)
	var health_before: int = player.get_current_health()
	main.call(&"_update_room_objective", 0.02)
	if player.get_current_health() >= health_before:
		_fail("Trap pulse did not use the player damage interface")
		return false
	return true


func _verify_holdout(main: Node2D, player: RoguePlayer) -> bool:
	var snapshot: Dictionary = main.call(&"get_room_objective_snapshot") as Dictionary
	if float(snapshot.get("hold_duration", 0.0)) <= 0.0 or int(snapshot.get("trap_count", 0)) <= 0:
		_fail("Holdout did not configure a beacon duration and trap zones")
		return false
	var anchor: Vector2 = main.get("_objective_anchor") as Vector2
	player.global_position = anchor
	var progress_before: float = float(snapshot.get("hold_progress", 0.0))
	main.call(&"_update_room_objective", 0.25)
	var progressed_snapshot: Dictionary = main.call(&"get_room_objective_snapshot") as Dictionary
	if float(progressed_snapshot.get("hold_progress", 0.0)) <= progress_before:
		_fail("Holdout did not gain progress while the player held the beacon")
		return false
	if not bool(main.call(&"complete_room_objective_for_test")):
		_fail("Holdout objective could not be completed for regression testing")
		return false
	return true


func _defeat_current_room(main: Node2D) -> void:
	var enemies: Array = (main.get("_enemies") as Array).duplicate()
	for enemy_value: Variant in enemies:
		var enemy: RogueEnemy = enemy_value as RogueEnemy
		if is_instance_valid(enemy):
			enemy.defeat()


func _wait_physics_frames(frame_count: int) -> void:
	for _frame_index in range(frame_count):
		await physics_frame


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
