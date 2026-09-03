extends SceneTree


func _initialize() -> void:
	call_deferred(&"_run_test")


func _run_test() -> void:
	var main_scene: PackedScene = load("res://scenes/Main.tscn")
	var main: Node2D = main_scene.instantiate() as Node2D
	root.add_child(main)
	await process_frame

	var entry_flow: Control = main.get_node("HUD/EntryFlow") as Control
	if entry_flow == null or not entry_flow.visible:
		_fail("The start screen was not shown on game entry")
		return
	var profile_summary: Panel = entry_flow.get_node("ProfileSummary") as Panel
	var profile_value: Label = profile_summary.get_node("Value") as Label
	if not profile_summary.visible or not profile_value.text.contains("局外") and not profile_value.text.contains("星屑"):
		_fail("Start screen did not show the autosave/meta-progression summary")
		return
	var start_button: Button = entry_flow.get_node("StartGame") as Button
	start_button.emit_signal("pressed")
	await process_frame
	var easy_button: Button = entry_flow.get_node("Difficulty_0") as Button
	if not easy_button.visible:
		_fail("Difficulty choices were not displayed after starting")
		return
	if profile_summary.visible:
		_fail("Profile summary overlaps difficulty selection")
		return
	easy_button.emit_signal("pressed")
	await physics_frame
	if entry_flow.visible or String(main.call(&"get_selected_difficulty_name")) != "简单":
		_fail("Selecting easy did not start the run with the selected difficulty")
		return
	var enemies: Array = main.get("_enemies") as Array
	if enemies.is_empty() or (enemies[0] as RogueEnemy).get_max_health() >= 72:
		_fail("Easy difficulty did not reduce enemy health")
		return

	main.queue_free()
	print("entry_flow_smoke: PASS")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
