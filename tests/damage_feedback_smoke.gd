extends SceneTree


func _initialize() -> void:
	call_deferred(&"_run_test")


func _run_test() -> void:
	var settings := RogueSettingsStore.new()
	if not settings.get_damage_numbers_enabled():
		_fail("Damage numbers were not enabled by default")
		return

	var main_scene: PackedScene = load("res://scenes/Main.tscn")
	var main: Node2D = main_scene.instantiate() as Node2D
	main.set("save_enabled", false)
	root.add_child(main)
	await physics_frame
	main.set("_settings", settings)

	var enemy := RogueEnemy.new()
	enemy.setup(0, 0.0, -100.0, 100.0, RogueEnemy.EnemyRole.MELEE)
	root.add_child(enemy)
	await physics_frame
	main.call(&"_spawn_hit_vfx", Vector2(300.0, 300.0), 1.0, enemy, 1.0, 37)
	await process_frame
	var first_number := _find_damage_number(main)
	if first_number == null:
		_fail("Enabled damage feedback did not create a floating number")
		return
	var label := first_number.get_node("DamageLabel") as Label
	if label.text != "37":
		_fail("Floating damage number did not show the applied damage")
		return

	# Keep this test isolated from the user's persistent settings file.
	settings.set("_damage_numbers_enabled", false)
	var number_count: int = _count_damage_numbers(main)
	main.call(&"_spawn_hit_vfx", Vector2(340.0, 300.0), 1.0, enemy, 1.0, 52)
	await process_frame
	if _count_damage_numbers(main) != number_count:
		_fail("Disabled damage feedback still created a floating number")
		return

	enemy.queue_free()
	main.queue_free()
	print("damage_feedback_smoke: PASS")
	quit(0)


func _find_damage_number(main: Node2D) -> DamageNumber:
	for child in main.get_children():
		if child is DamageNumber:
			return child as DamageNumber
	return null


func _count_damage_numbers(main: Node2D) -> int:
	var count: int = 0
	for child in main.get_children():
		if child is DamageNumber:
			count += 1
	return count


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
