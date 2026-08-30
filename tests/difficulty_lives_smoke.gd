extends SceneTree


func _initialize() -> void:
	call_deferred(&"_run_test")


func _run_test() -> void:
	var main_scene: PackedScene = load("res://scenes/Main.tscn")
	var main: Node2D = main_scene.instantiate() as Node2D
	main.set("save_enabled", false)
	root.add_child(main)
	for _settle_frame in range(12):
		await physics_frame

	var lives_label: Label = main.get_node("HUD/Lives") as Label
	var ability_bar: Control = main.get_node("HUD/AbilityBar") as Control
	var status_label: Label = main.get_node("HUD/CombatStatus") as Label
	if lives_label.position.y < 640.0 or lives_label.position.y + lives_label.size.y > 720.0 or ability_bar.position.y < 640.0 or status_label.position.x < 800.0:
		_fail("HUD was not aligned to the bottom band without crossing the viewport")
		return

	main.set("_selected_difficulty", 0)
	main.set("_current_room_index", 0)
	var easy_first_room: float = float(main.call(&"_get_difficulty_health_multiplier"))
	main.set("_current_room_index", 4)
	var easy_boss_room: float = float(main.call(&"_get_difficulty_health_multiplier"))
	main.set("_selected_difficulty", 2)
	var hard_boss_room: float = float(main.call(&"_get_difficulty_health_multiplier"))
	if easy_first_room >= 1.0 or easy_boss_room <= easy_first_room or hard_boss_room <= easy_boss_room:
		_fail("Difficulty strength did not scale progressively by room and difficulty")
		return

	main.set("_current_room_index", 0)
	for life_index in range(3):
		main.call(&"_on_player_died")
		await create_timer(1.15).timeout
		if life_index < 2 and int(main.get("_lives_remaining")) != 2 - life_index:
			_fail("A death did not consume exactly one life")
			return

	var entry_flow: Control = main.get_node("HUD/EntryFlow") as Control
	if int(main.get("_lives_remaining")) != 0 or not entry_flow.visible:
		_fail("Exhausting three lives did not return to difficulty selection")
		return

	main.queue_free()
	print("difficulty_lives_smoke: PASS")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
