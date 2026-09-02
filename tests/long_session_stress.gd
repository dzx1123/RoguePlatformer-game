extends SceneTree

const DEFAULT_DURATION_SECONDS := 1800.0
const REPORT_DIR := "res://tests/artifacts/stress"

var _duration_seconds: float = DEFAULT_DURATION_SECONDS
var _main: Node2D
var _player: RoguePlayer
var _started_msec: int = 0
var _last_progress_msec: int = 0
var _last_report_msec: int = 0
var _frame_count: int = 0
var _rooms_resolved: int = 0
var _runs_completed: int = 0
var _attack_hits: int = 0
var _skills_started: int = 0
var _deaths_observed: int = 0
var _peak_static_memory: float = 0.0
var _peak_node_count: int = 0


func _initialize() -> void:
	_duration_seconds = _read_duration_argument()
	Engine.max_fps = 120
	call_deferred(&"_run_stress")


func _run_stress() -> void:
	var directory_error: Error = DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(REPORT_DIR)
	)
	if directory_error != OK:
		_fail("Could not create stress-test artifact directory")
		return
	var scene: PackedScene = load("res://scenes/Main.tscn")
	_main = scene.instantiate() as Node2D
	_main.set("save_enabled", false)
	root.add_child(_main)
	_player = _main.get_node("Player") as RoguePlayer
	_player.attack_hit.connect(_on_attack_hit)
	_player.action_started.connect(_on_action_started)
	_player.died.connect(_on_player_died)
	await _wait_physics_frames(20)
	_started_msec = Time.get_ticks_msec()
	_last_progress_msec = _started_msec
	_last_report_msec = _started_msec
	while _elapsed_seconds() < _duration_seconds:
		await physics_frame
		_frame_count += 1
		_drive_player_inputs()
		_keep_player_operational()
		if _frame_count % 90 == 0:
			_advance_run_content()
		if not _sample_runtime_health():
			return
		if Time.get_ticks_msec() - _last_progress_msec > 45000:
			_fail("No room/run progress was observed for 45 seconds")
			return
		if Time.get_ticks_msec() - _last_report_msec >= 60000:
			_print_progress()
			_last_report_msec = Time.get_ticks_msec()
	_release_inputs()
	await _wait_physics_frames(30)
	if not _validate_result():
		return
	if not _write_report(true, ""):
		return
	print("long_session_stress: PASS duration=%.1fs rooms=%d runs=%d attacks=%d" % [
		_elapsed_seconds(), _rooms_resolved, _runs_completed, _attack_hits,
	])
	quit(0)


func _drive_player_inputs() -> void:
	var move_phase: int = posmod(_frame_count, 120)
	if move_phase == 0:
		Input.action_release(&"move_left")
		Input.action_press(&"move_right")
	elif move_phase == 60:
		Input.action_release(&"move_right")
		Input.action_press(&"move_left")
	for action_data: Array in [
		[&"attack", 37],
		[&"jump", 127],
		[&"dash", 173],
		[&"skill", 241],
	]:
		var action_name: StringName = action_data[0]
		var interval: int = int(action_data[1])
		var phase: int = posmod(_frame_count, interval)
		if phase == 0:
			Input.action_press(action_name)
		elif phase == 1:
			Input.action_release(action_name)


func _keep_player_operational() -> void:
	if not is_instance_valid(_player) or _player.is_dead():
		return
	_player.heal(9999)
	# The soak run targets complete-route churn; death/lives have dedicated tests.
	_player.set("_hurt_invulnerability_remaining", 2.00)
	if (
		_player.global_position.x < 60.0
		or _player.global_position.x > 1220.0
		or _player.global_position.y > 700.0
	):
		_player.global_position = Vector2(160.0, 580.0)
		_player.velocity = Vector2.ZERO


func _advance_run_content() -> void:
	if not is_instance_valid(_main):
		return
	if bool(_main.get("_entry_flow_active")):
		var selected_difficulty: int = int(_main.get("_selected_difficulty"))
		_main.call(&"_start_game_with_difficulty", selected_difficulty)
		_mark_progress()
		return
	if bool(_main.call(&"is_run_complete")):
		_runs_completed += 1
		_main.call(&"_start_new_run")
		_mark_progress()
		return
	if bool(_main.call(&"is_event_active")):
		if bool(_main.call(&"choose_upgrade", 0)):
			_mark_progress()
		return
	if bool(_main.call(&"is_awaiting_chest")):
		if bool(_main.call(&"open_current_chest_for_test")):
			_mark_progress()
		return
	if bool(_main.call(&"is_shopping")):
		if not bool(_main.call(&"choose_upgrade", 0)):
			_main.call(&"_leave_shop")
		_mark_progress()
		return
	if bool(_main.call(&"is_choosing_upgrade")):
		if bool(_main.call(&"choose_upgrade", 0)):
			_mark_progress()
		return
	var enemies: Array = (_main.get("_enemies") as Array).duplicate()
	if enemies.is_empty():
		return
	for enemy_value: Variant in enemies:
		var enemy: RogueEnemy = enemy_value as RogueEnemy
		if is_instance_valid(enemy):
			enemy.defeat()
	_rooms_resolved += 1
	_mark_progress()


func _mark_progress() -> void:
	_last_progress_msec = Time.get_ticks_msec()


func _sample_runtime_health() -> bool:
	var static_memory: float = Performance.get_monitor(Performance.MEMORY_STATIC)
	var node_count: int = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	_peak_static_memory = maxf(_peak_static_memory, static_memory)
	_peak_node_count = maxi(_peak_node_count, node_count)
	if static_memory > 1536.0 * 1024.0 * 1024.0:
		_fail("Static memory exceeded the 1.5 GiB stress ceiling")
		return false
	if node_count > 3000:
		_fail("Live node count exceeded the 3000-node stress ceiling")
		return false
	return true


func _print_progress() -> void:
	print("long_session_stress: progress %.0fs/%.0fs rooms=%d runs=%d nodes=%d memory=%.1fMiB" % [
		_elapsed_seconds(),
		_duration_seconds,
		_rooms_resolved,
		_runs_completed,
		_peak_node_count,
		_peak_static_memory / 1048576.0,
	])


func _read_duration_argument() -> float:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--duration="):
			return clampf(argument.trim_prefix("--duration=").to_float(), 10.0, 7200.0)
	return DEFAULT_DURATION_SECONDS


func _elapsed_seconds() -> float:
	if _started_msec <= 0:
		return 0.0
	return float(Time.get_ticks_msec() - _started_msec) / 1000.0


func _release_inputs() -> void:
	for action_name: StringName in [
		&"move_left", &"move_right", &"attack", &"jump", &"dash", &"skill",
	]:
		Input.action_release(action_name)


func _on_attack_hit(_origin: Vector2, _facing: float) -> void:
	_attack_hits += 1


func _on_action_started(action_name: StringName) -> void:
	if action_name == &"skill":
		_skills_started += 1


func _on_player_died() -> void:
	_deaths_observed += 1


func _wait_physics_frames(frame_count: int) -> void:
	for _frame_index: int in range(frame_count):
		await physics_frame


func _validate_result() -> bool:
	var minimum_rooms: int = maxi(3, int(floor(_duration_seconds / 20.0)))
	if _elapsed_seconds() + 0.1 < _duration_seconds:
		_fail("Stress test ended before the requested wall-clock duration")
		return false
	if _rooms_resolved < minimum_rooms:
		_fail("Stress test resolved only %d rooms; expected at least %d" % [
			_rooms_resolved, minimum_rooms,
		])
		return false
	if _attack_hits < 3 or _skills_started < 1:
		_fail("Combat input coverage was too low: attacks=%d skills=%d" % [
			_attack_hits, _skills_started,
		])
		return false
	if _duration_seconds >= 600.0 and _runs_completed < 2:
		_fail("Long soak completed only %d full runs; expected at least 2" % _runs_completed)
		return false
	return true


func _write_report(success: bool, failure_message: String) -> bool:
	var report_path := "%s/soak_report.json" % REPORT_DIR
	var report_file := FileAccess.open(report_path, FileAccess.WRITE)
	if report_file == null:
		push_error("Could not open stress report for writing")
		return false
	var flow_snapshot: Dictionary = {}
	var current_room: int = 0
	var current_encounter := ""
	var enemy_count: int = 0
	var entry_flow_active: bool = false
	var player_dead: bool = false
	if is_instance_valid(_main):
		flow_snapshot = _main.call(&"get_run_flow_snapshot") as Dictionary
		current_room = int(_main.call(&"get_current_room_number"))
		current_encounter = String(_main.call(&"get_current_encounter_name"))
		enemy_count = (_main.get("_enemies") as Array).size()
		entry_flow_active = bool(_main.get("_entry_flow_active"))
	if is_instance_valid(_player):
		player_dead = _player.is_dead()
	report_file.store_string(JSON.stringify({
		"success": success,
		"failure": failure_message,
		"requested_duration_seconds": _duration_seconds,
		"elapsed_seconds": _elapsed_seconds(),
		"frames": _frame_count,
		"rooms_resolved": _rooms_resolved,
		"runs_completed": _runs_completed,
		"attack_hits": _attack_hits,
		"skills_started": _skills_started,
		"deaths_observed": _deaths_observed,
		"peak_static_memory_mib": _peak_static_memory / 1048576.0,
		"peak_node_count": _peak_node_count,
		"current_room": current_room,
		"current_encounter": current_encounter,
		"enemy_count": enemy_count,
		"entry_flow_active": entry_flow_active,
		"player_dead": player_dead,
		"flow": flow_snapshot,
		"completed_at_utc": Time.get_datetime_string_from_system(true),
	}, "\t"))
	report_file.close()
	return true


func _fail(message: String) -> void:
	_release_inputs()
	_write_report(false, message)
	push_error(message)
	quit(1)
