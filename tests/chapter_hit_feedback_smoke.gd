extends SceneTree

func _initialize() -> void:
	call_deferred("run_test")

func run_test() -> void:
	create_timer(20).timeout.connect(func(): push_error("Hit feedback timeout"); quit(1))
	var main = load("res://scenes/Main.tscn").instantiate()
	main.save_enabled = false
	root.add_child(main)
	var journey = load("res://scenes/Chapter2Journey.tscn").instantiate()
	journey.persistence_enabled = false
	root.add_child(journey)
	await create_timer(1.8).timeout
	for weapon in WeaponCatalog.all_weapon_ids():
		main.player.configure_weapon(weapon)
		journey.player.configure_weapon(weapon)
		for skill in [false, true]:
			journey._load_layout(2)
			var enemy = journey.caster
			main.player._hitstop_remaining = 0
			journey.player._hitstop_remaining = 0
			main._apply_hitstop(enemy, skill)
			journey._spawn_impact_slash(enemy, 1, 1.25 if skill else 1.0)
			assert(is_equal_approx(main.player.get_hitstop_remaining(), journey.player.get_hitstop_remaining()), "Both chapters must use identical hitstop")
	for index in [2, 5, 10, 19]:
		journey._load_layout(index)
		await create_timer(0.3).timeout
		var enemy = journey.living_enemies()[0]
		var position_before: Vector2 = enemy.position
		var animation_before: float = enemy.animation_time
		enemy.apply_hitstop(0.10)
		await physics_frame
		await physics_frame
		assert(enemy.position == position_before, "Forge enemy moved during impact stop")
		assert(is_equal_approx(enemy.animation_time, animation_before), "Forge animation moved during impact stop")
	main.queue_free()
	journey.queue_free()
	await process_frame
	print("chapter_hit_feedback_smoke: PASS")
	quit()
