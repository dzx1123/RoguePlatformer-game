extends SceneTree


func _initialize() -> void:
	call_deferred(&"_run_test")


func _run_test() -> void:
	for family in [RogueEnemy.EnemyFamily.GOBLIN, RogueEnemy.EnemyFamily.SLIME]:
		var enemy := RogueEnemy.new()
		enemy.setup(0, 0.0, -100.0, 100.0, RogueEnemy.EnemyRole.MELEE,
			RogueEnemy.EnemyRank.NORMAL, 1.0, 1.0, family)
		root.add_child(enemy)
		await process_frame
		enemy.set_physics_process(false)
		enemy.set("_locomotion_cycle", 0.0)
		enemy.velocity = Vector2(30.0, 0.0)
		var frames_seen: Dictionary = {}
		for tick in range(90):
			enemy.call(&"_update_locomotion_animation", 1.0 / 60.0)
			frames_seen[int(floor(float(enemy.get("_locomotion_cycle"))))] = true
		var expected: int = 8 if family == RogueEnemy.EnemyFamily.GOBLIN else 4
		if frames_seen.size() != expected:
			push_error("Slow patrol did not complete its stride cycle")
			quit(1)
			return
		enemy.call(&"_begin_ground_turn", -1.0)
		var previous: float = float(enemy.get("_locomotion_cycle"))
		for tick in range(5):
			enemy.call(&"_update_locomotion_animation", 1.0 / 60.0)
			var current: float = float(enemy.get("_locomotion_cycle"))
			if current <= previous:
				push_error("Turning froze or reset the moving stride")
				quit(1)
				return
			previous = current
		enemy.set("_turn_remaining", 0.0)
		enemy.velocity = Vector2.ZERO
		for tick in range(60):
			enemy.call(&"_update_locomotion_animation", 1.0 / 60.0)
		if bool(enemy.get("_locomotion_active")):
			push_error("Stopped enemy failed to settle back to idle")
			quit(1)
			return
		enemy.queue_free()
		await process_frame
	print("enemy_stride_cadence_smoke: PASS")
	quit(0)
