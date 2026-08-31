extends SceneTree


func _initialize() -> void:
	call_deferred(&"_run_test")


func _run_test() -> void:
	_create_surface(Rect2(-80.0, 640.0, 1440.0, 160.0), false)
	_create_surface(Rect2(400.0, 500.0, 420.0, 28.0), true)

	var target := Node2D.new()
	target.position = Vector2(620.0, 450.0)
	root.add_child(target)
	var far_target := Node2D.new()
	far_target.position = Vector2(1250.0, 300.0)
	root.add_child(far_target)

	var slime: RogueEnemy = _make_enemy(
		Vector2(500.0, 618.0),
		RogueEnemy.EnemyRole.MELEE,
		RogueEnemy.EnemyRank.NORMAL,
		RogueEnemy.EnemyFamily.SLIME
	)
	var goblin: RogueEnemy = _make_enemy(
		Vector2(720.0, 618.0),
		RogueEnemy.EnemyRole.RANGED,
		RogueEnemy.EnemyRank.NORMAL,
		RogueEnemy.EnemyFamily.GOBLIN
	)
	var boss: RogueEnemy = _make_enemy(
		Vector2(330.0, 588.0),
		RogueEnemy.EnemyRole.MELEE,
		RogueEnemy.EnemyRank.BOSS,
		RogueEnemy.EnemyFamily.GOBLIN
	)

	await _wait_physics_frames(8)
	slime.set_target(target)
	goblin.set_target(target)
	boss.set_target(far_target)
	var boss_sprite := boss.get_node("EnemySprite") as Sprite2D
	if boss_sprite.scale.x < 0.52 or boss.get_hurtbox_rect().size.x < 140.0:
		_fail("Boss visual size and combat body were not enlarged together")
		return
	if not bool(boss.call(&"_target_is_visible")):
		_fail("Boss did not lock onto a player-sized target across the room")
		return
	boss.set_target(target)

	var climbers: Array[RogueEnemy] = [slime, goblin, boss]
	var start_heights: Array[float] = []
	var minimum_heights: Array[float] = []
	for climber in climbers:
		start_heights.append(climber.global_position.y)
		minimum_heights.append(climber.global_position.y)

	for _frame_index in range(150):
		await physics_frame
		for climber_index in range(climbers.size()):
			minimum_heights[climber_index] = minf(
				minimum_heights[climber_index],
				climbers[climber_index].global_position.y
			)

	for climber_index in range(climbers.size()):
		var climbed_height: float = start_heights[climber_index] - minimum_heights[climber_index]
		if climbed_height < 105.0 or climbers[climber_index].global_position.y > 525.0:
			_fail(
				"Enemy %d did not reach the pursuit platform (climbed %.1f, final y %.1f)"
				% [
					climber_index,
					climbed_height,
					climbers[climber_index].global_position.y,
				]
			)
			return

	print("enemy_platform_pursuit_smoke: PASS")
	quit(0)


func _make_enemy(
	spawn_position: Vector2,
	role: int,
	rank: int,
	family: int
) -> RogueEnemy:
	var enemy := RogueEnemy.new()
	enemy.position = spawn_position
	enemy.setup(
		0,
		0.0,
		420.0,
		800.0,
		role,
		rank,
		1.0,
		1.0,
		family,
		1.20,
		1.40
	)
	root.add_child(enemy)
	return enemy


func _create_surface(rect: Rect2, one_way: bool) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.position = rect.get_center()
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	collision.shape = shape
	collision.one_way_collision = one_way
	collision.one_way_collision_margin = 8.0 if one_way else 0.0
	body.add_child(collision)
	root.add_child(body)


func _wait_physics_frames(frame_count: int) -> void:
	for _frame_index in range(frame_count):
		await physics_frame


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
