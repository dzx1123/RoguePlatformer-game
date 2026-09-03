extends SceneTree


func _initialize() -> void:
	call_deferred(&"_run_test")


func _run_test() -> void:
	var enemy := RogueEnemy.new()
	enemy.setup(
		0,
		0.0,
		-100.0,
		100.0,
		RogueEnemy.EnemyRole.MELEE,
		RogueEnemy.EnemyRank.NORMAL,
		1.0,
		1.0,
		RogueEnemy.EnemyFamily.GOBLIN
	)
	root.add_child(enemy)
	await process_frame
	enemy.set_physics_process(false)
	enemy.set("_facing", -1.0)
	enemy.set("_locomotion_blend", 0.0)
	enemy.call(&"_begin_ground_turn", 1.0)
	var turn_duration: float = float(enemy.get("_turn_remaining"))
	var sprite := enemy.get_node("EnemySprite") as Sprite2D
	enemy.set("_sprite_pose_initialized", false)
	enemy.call(&"_update_sprite_animation")
	var outgoing_foot_y: float = _get_club_foot_y(sprite)
	if not sprite.flip_h:
		_fail("Enemy turn anticipation did not retain the outgoing-facing sprite")
		return

	enemy.set("_turn_remaining", turn_duration * 0.40)
	enemy.set("_sprite_pose_initialized", false)
	enemy.call(&"_update_sprite_animation")
	var incoming_foot_y: float = _get_club_foot_y(sprite)
	if sprite.flip_h:
		_fail("Enemy turn completion did not switch to the incoming-facing sprite")
		return
	if absf(incoming_foot_y - outgoing_foot_y) > 0.80:
		_fail(
			"Enemy turn moved its club-goblin foot anchor by %.3fpx"
			% absf(incoming_foot_y - outgoing_foot_y)
		)
		return

	enemy.queue_free()
	await process_frame
	print("enemy_turn_motion_smoke: PASS")
	quit(0)


func _get_club_foot_y(sprite: Sprite2D) -> float:
	var cell_height: float = float(sprite.texture.get_height()) / 2.0
	return sprite.position.y + (415.0 - cell_height * 0.5) * absf(sprite.scale.y)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
