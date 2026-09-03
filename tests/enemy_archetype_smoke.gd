extends SceneTree

var _caster_projectile_count: int = 0


func _initialize() -> void:
	call_deferred(&"_run_test")


func _run_test() -> void:
	var target: Node2D = Node2D.new()
	target.position = Vector2(760.0, 520.0)
	root.add_child(target)

	var standard: RogueEnemy = _make_enemy(
		Vector2(280.0, 420.0),
		RogueEnemy.EnemyRole.MELEE,
		RogueEnemy.EnemyFamily.GOBLIN,
		RogueEnemy.EnemyArchetype.STANDARD
	)
	var shield_guard: RogueEnemy = _make_enemy(
		Vector2(440.0, 420.0),
		RogueEnemy.EnemyRole.MELEE,
		RogueEnemy.EnemyFamily.GOBLIN,
		RogueEnemy.EnemyArchetype.SHIELD_GUARD
	)
	var rear_shield_guard: RogueEnemy = _make_enemy(
		Vector2(600.0, 420.0),
		RogueEnemy.EnemyRole.MELEE,
		RogueEnemy.EnemyFamily.GOBLIN,
		RogueEnemy.EnemyArchetype.SHIELD_GUARD
	)
	if shield_guard.get_archetype() != RogueEnemy.EnemyArchetype.SHIELD_GUARD:
		_fail("Shield guard archetype was not retained")
		return
	if not standard.receive_player_attack(standard.global_position + Vector2(28.0, 0.0), -1.0, 20):
		_fail("Reference enemy did not receive the front attack")
		return
	if not shield_guard.receive_player_attack(
		shield_guard.global_position + Vector2(28.0, 0.0),
		-1.0,
		20
	):
		_fail("Shield guard did not receive the front attack")
		return
	if not rear_shield_guard.receive_player_attack(
		rear_shield_guard.global_position - Vector2(28.0, 0.0),
		1.0,
		20
	):
		_fail("Shield guard did not receive the rear attack")
		return
	var standard_loss: int = standard.get_max_health() - standard.get_current_health()
	var blocked_loss: int = shield_guard.get_max_health() - shield_guard.get_current_health()
	var rear_loss: int = rear_shield_guard.get_max_health() - rear_shield_guard.get_current_health()
	if blocked_loss >= standard_loss or rear_loss != standard_loss:
		_fail(
			"Shield directionality was invalid (standard %d, blocked %d, rear %d)"
			% [standard_loss, blocked_loss, rear_loss]
		)
		return

	var flyer: RogueEnemy = _make_enemy(
		Vector2(500.0, 380.0),
		RogueEnemy.EnemyRole.RANGED,
		RogueEnemy.EnemyFamily.SLIME,
		RogueEnemy.EnemyArchetype.FLYER,
		true
	)
	flyer.set_target(target)
	var flyer_start_y: float = flyer.global_position.y
	await _wait_physics_frames(14)
	if not flyer.is_flying_enemy() or flyer.collision_mask != 0:
		_fail("Flyer did not switch to the platform-ignoring flight body")
		return
	if absf(flyer.global_position.y - flyer_start_y) < 4.0:
		_fail("Flyer did not adjust its hover height toward the target")
		return

	var caster: RogueEnemy = _make_enemy(
		Vector2(700.0, 420.0),
		RogueEnemy.EnemyRole.RANGED,
		RogueEnemy.EnemyFamily.GOBLIN,
		RogueEnemy.EnemyArchetype.CASTER
	)
	caster.set_target(target)
	caster.projectile_requested.connect(_on_caster_projectile_requested)
	caster.call(&"_fire_projectile")
	if _caster_projectile_count != 3:
		_fail("Caster emitted %d projectiles instead of three" % _caster_projectile_count)
		return
	var caster_profile: Dictionary = caster.get_behavior_profile()
	if int(caster_profile.get("ranged_volley_count", 0)) < 3:
		_fail("Caster behavior profile did not retain its three-shot volley")
		return

	var ambusher: RogueEnemy = _make_enemy(
		Vector2(860.0, 420.0),
		RogueEnemy.EnemyRole.MELEE,
		RogueEnemy.EnemyFamily.SLIME,
		RogueEnemy.EnemyArchetype.AMBUSHER
	)
	var ambusher_speed: float = float(ambusher.call(&"_get_melee_chase_speed"))
	var standard_speed: float = float(standard.call(&"_get_melee_chase_speed"))
	if ambusher_speed <= standard_speed:
		_fail("Ambusher chase speed %.1f was not higher than standard %.1f" % [ambusher_speed, standard_speed])
		return

	if not _verify_room_unlock_order():
		return
	print("enemy_archetype_smoke: PASS")
	quit(0)


func _make_enemy(
	spawn_position: Vector2,
	role: int,
	family: int,
	archetype: int,
	enable_physics: bool = false
) -> RogueEnemy:
	var enemy: RogueEnemy = RogueEnemy.new()
	enemy.position = spawn_position
	enemy.setup(
		0,
		0.0,
		spawn_position.x - 120.0,
		spawn_position.x + 120.0,
		role,
		RogueEnemy.EnemyRank.NORMAL,
		1.0,
		1.0,
		family,
		1.0,
		1.0,
		{},
		archetype
	)
	root.add_child(enemy)
	if not enable_physics:
		enemy.set_physics_process(false)
	return enemy


func _verify_room_unlock_order() -> bool:
	var main_script: Script = load("res://scripts/main.gd") as Script
	var main: Node2D = main_script.new() as Node2D
	var shield_archetype: int = int(main.call(
		&"_get_enemy_archetype_for_spawn",
		6,
		2,
		0,
		0,
		1
	))
	var flyer_archetype: int = int(main.call(
		&"_get_enemy_archetype_for_spawn",
		10,
		4,
		1,
		0,
		0
	))
	var caster_archetype: int = int(main.call(
		&"_get_enemy_archetype_for_spawn",
		10,
		1,
		1,
		0,
		1
	))
	var ambusher_archetype: int = int(main.call(
		&"_get_enemy_archetype_for_spawn",
		15,
		3,
		0,
		0,
		0
	))
	var elite_archetype: int = int(main.call(
		&"_get_enemy_archetype_for_spawn",
		15,
		3,
		0,
		1,
		0
	))
	main.queue_free()
	if shield_archetype != RogueEnemy.EnemyArchetype.SHIELD_GUARD:
		_fail("Shield guard was not unlocked in the goblin chapter")
		return false
	if flyer_archetype != RogueEnemy.EnemyArchetype.FLYER:
		_fail("Flyer was not unlocked in the mixed chapter")
		return false
	if caster_archetype != RogueEnemy.EnemyArchetype.CASTER:
		_fail("Caster was not unlocked in the mixed chapter")
		return false
	if ambusher_archetype != RogueEnemy.EnemyArchetype.AMBUSHER:
		_fail("Ambusher was not unlocked in the final chapter")
		return false
	if elite_archetype != RogueEnemy.EnemyArchetype.STANDARD:
		_fail("Elite ranks incorrectly received a normal-enemy archetype")
		return false
	return true


func _on_caster_projectile_requested(
	_origin: Vector2,
	_velocity: Vector2,
	_damage: int,
	_style: int
) -> void:
	_caster_projectile_count += 1


func _wait_physics_frames(frame_count: int) -> void:
	for _frame_index in range(frame_count):
		await physics_frame


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
