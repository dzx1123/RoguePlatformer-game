extends SceneTree


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

	if not InputMap.has_action(&"build_overview"):
		_fail("Build overview input action was not registered")
		return
	if not bool(main.call(&"open_build_overview_for_test")):
		_fail("Build overview did not open")
		return
	var initial_snapshot: Dictionary = main.call(&"get_build_overview_snapshot") as Dictionary
	if (
		not bool(initial_snapshot.get("visible", false))
		or String(initial_snapshot.get("weapon_text", "")).is_empty()
		or String(initial_snapshot.get("stats_text", "")).is_empty()
		or String(initial_snapshot.get("synergy_text", "")).is_empty()
	):
		_fail("Build overview did not expose its core sections")
		return
	if not bool(main.call(&"close_build_overview_for_test")):
		_fail("Build overview did not close")
		return

	if not player.apply_run_upgrade(&"tempered_edge"):
		_fail("Could not apply common build upgrade")
		return
	if not player.apply_run_upgrade(&"battle_rhythm"):
		_fail("Could not apply cooldown build upgrade")
		return
	if not player.apply_run_upgrade(&"moon_expansion"):
		_fail("Could not apply weapon-specific build upgrade")
		return
	if not bool(main.call(&"open_build_overview_for_test")):
		_fail("Build overview could not reopen after upgrades")
		return
	var upgraded_snapshot: Dictionary = main.call(&"get_build_overview_snapshot") as Dictionary
	if (
		String(upgraded_snapshot.get("upgrades_text", "")).length()
		<= String(initial_snapshot.get("upgrades_text", "")).length()
		or not String(upgraded_snapshot.get("total_text", "")).contains("3")
	):
		_fail("Build overview did not refresh upgrade stacks")
		return
	if not bool(main.call(&"close_build_overview_for_test")):
		_fail("Build overview did not close after refresh")
		return
	print("build_overview_smoke: PASS")
	quit(0)


func _wait_physics_frames(frame_count: int) -> void:
	for _frame in range(frame_count):
		await physics_frame


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
