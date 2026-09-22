extends SceneTree
func _initialize():
	call_deferred("run_test")
func run_test():
	var scene = load("res://scenes/Chapter2Journey.tscn").instantiate()
	scene.persistence_enabled = false
	root.add_child(scene)
	for index in [2, 5, 10]:
		scene._load_layout(index)
		await create_timer(0.4).timeout
		var enemy = scene.living_enemies()[0]
		var origin: Vector2 = enemy.position
		await create_timer(0.7).timeout
		assert(absf(enemy.position.x - origin.x) > 8, "Enemy must patrol")
		assert(absf(enemy.position.y - origin.y) < 3, "Patrol must stay on platform")
		assert(enemy.get_health_bar_rect().end.y < 24 - enemy.get_impact_height())
		enemy._max_health *= 2
		enemy._current_health = enemy._max_health / 2
		assert(is_equal_approx(enemy.get_health_fraction(), 0.5))
		scene._toggle_pause()
		origin = enemy.position
		await create_timer(0.25).timeout
		assert(enemy.position == origin)
		scene._toggle_pause()
	scene._load_layout(2)
	await create_timer(6).timeout
	assert(scene.caster.is_on_floor() and scene.caster.position.y < 520)
	# A same-height target beyond a platform must not pin pursuit at the ledge.
	scene.set_physics_process(false)
	scene.player.set_physics_process(false)
	scene.player.position = Vector2(1230, 498)
	scene.caster.position = Vector2(1060, 498)
	scene.caster.walk_origin = 1060
	scene.caster.cast_pose_time = 0
	var ledge_x: float = scene.caster.position.x
	await create_timer(0.7).timeout
	assert(scene.caster.position.x < ledge_x - 8, "Ledge turn must persist while target remains beyond platform")
	assert(scene.caster.is_on_floor() and scene.caster.position.y < 520)
	scene.set_physics_process(true)
	scene.player.set_physics_process(true)
	scene._load_layout(19)
	await create_timer(0.3).timeout
	scene.overseer.engaged = true
	scene.overseer.remaining = 1.0
	var origin: Vector2 = scene.overseer.position
	await create_timer(0.4).timeout
	assert(absf(scene.overseer.position.x - origin.x) > 8)
	scene.overseer._max_health = 1040
	scene.overseer._current_health = 520
	assert(is_equal_approx(scene.overseer.get_health_fraction(), 0.5))
	scene.queue_free()
	await process_frame
	print("chapter2_enemy_patrol_smoke: PASS")
	quit()
