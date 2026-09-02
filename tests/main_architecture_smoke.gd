extends SceneTree


func _initialize() -> void:
	call_deferred(&"_run_test")


func _run_test() -> void:
	var scene: PackedScene = load("res://scenes/Main.tscn")
	var main: Node2D = scene.instantiate() as Node2D
	main.set("save_enabled", false)
	root.add_child(main)
	for _frame_index: int in range(10):
		await physics_frame
	var presenter: RunHUDPresenter = main.get("_hud_presenter") as RunHUDPresenter
	if presenter == null or not presenter.is_bound():
		_fail("Main did not bind the extracted HUD presenter")
		return
	var flow_snapshot: Dictionary = main.call(&"get_run_flow_snapshot") as Dictionary
	if (
		not bool(flow_snapshot.get("run_active", false))
		or bool(flow_snapshot.get("choosing_upgrade", true))
		or bool(flow_snapshot.get("run_complete", true))
	):
		_fail("Main did not enter a consistent combat flow state")
		return
	if presenter.status_label != main.get_node("HUD/CombatStatus"):
		_fail("HUD presenter changed the public node contract")
		return
	main.queue_free()
	print("main_architecture_smoke: PASS")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
