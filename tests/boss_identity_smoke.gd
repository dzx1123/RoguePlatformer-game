extends SceneTree

var _crystal_volley_velocities: Array[Vector2] = []
var _warchief_volley_velocities: Array[Vector2] = []


func _initialize() -> void:
	call_deferred(&"_run_test")


func _run_test() -> void:
	var target: Node2D = Node2D.new()
	target.position = Vector2(360.0, 0.0)
	root.add_child(target)
	var crystal_king: RogueEnemy = _make_boss(RogueEnemy.EnemyFamily.SLIME)
	var war_chief: RogueEnemy = _make_boss(RogueEnemy.EnemyFamily.GOBLIN)
	crystal_king.set_target(target)
	war_chief.set_target(target)
	crystal_king.projectile_requested.connect(_on_crystal_projectile_requested)
	war_chief.projectile_requested.connect(_on_warchief_projectile_requested)
	await process_frame

	if crystal_king.get_boss_identity() != RogueEnemy.BossIdentity.CRYSTAL_KING:
		_fail("Slime boss did not receive the Crystal King identity")
		return
	if war_chief.get_boss_identity() != RogueEnemy.BossIdentity.WAR_CHIEF:
		_fail("Goblin boss did not receive the Warchief identity")
		return
	var crystal_sprite: Sprite2D = crystal_king.get_node("EnemySprite") as Sprite2D
	var warchief_sprite: Sprite2D = war_chief.get_node("EnemySprite") as Sprite2D
	if (
		crystal_sprite.texture == null
		or warchief_sprite.texture == null
		or not crystal_sprite.texture.resource_path.contains("red_crystal_slime_boss")
		or not warchief_sprite.texture.resource_path.contains("red_fang_goblin_elite")
	):
		_fail("Boss identities did not keep their separate authored silhouettes")
		return

	var crystal_lunge_speed: float = float(crystal_king.call(&"_get_boss_lunge_speed"))
	var warchief_lunge_speed: float = float(war_chief.call(&"_get_boss_lunge_speed"))
	var crystal_slam_reach: float = float(crystal_king.call(&"_get_boss_slam_reach_x"))
	var warchief_slam_reach: float = float(war_chief.call(&"_get_boss_slam_reach_x"))
	if warchief_lunge_speed <= crystal_lunge_speed:
		_fail("Warchief charge %.1f was not faster than Crystal King %.1f" % [warchief_lunge_speed, crystal_lunge_speed])
		return
	if crystal_slam_reach <= warchief_slam_reach:
		_fail("Crystal King slam %.1f was not wider than Warchief %.1f" % [crystal_slam_reach, warchief_slam_reach])
		return

	if not _verify_phase_openers(crystal_king, war_chief):
		return
	crystal_king.set("_boss_phase", 3)
	crystal_king.set("_boss_attack_counter", 0)
	war_chief.set("_boss_phase", 3)
	war_chief.set("_boss_attack_counter", 0)
	crystal_king.call(&"_fire_projectile")
	war_chief.call(&"_fire_projectile")
	if _crystal_volley_velocities.size() != 5 or _warchief_volley_velocities.size() != 5:
		_fail(
			"Final volleys did not emit five projectiles (crystal %d, warchief %d)"
			% [_crystal_volley_velocities.size(), _warchief_volley_velocities.size()]
		)
		return
	var crystal_spread: float = _get_angle_span(_crystal_volley_velocities)
	var warchief_spread: float = _get_angle_span(_warchief_volley_velocities)
	if crystal_spread <= warchief_spread + 0.10:
		_fail("Crystal volley %.2f was not wider than Warchief fan %.2f" % [crystal_spread, warchief_spread])
		return

	print("boss_identity_smoke: PASS")
	quit(0)


func _make_boss(family: int) -> RogueEnemy:
	var boss: RogueEnemy = RogueEnemy.new()
	boss.position = Vector2(-160.0, 0.0)
	boss.setup(
		0,
		0.0,
		-540.0,
		540.0,
		RogueEnemy.EnemyRole.MELEE,
		RogueEnemy.EnemyRank.BOSS,
		1.0,
		1.0,
		family,
		1.0,
		1.0
	)
	root.add_child(boss)
	boss.set_physics_process(false)
	return boss


func _verify_phase_openers(crystal_king: RogueEnemy, war_chief: RogueEnemy) -> bool:
	crystal_king.set("_boss_phase", 3)
	crystal_king.set("_boss_attack_counter", 0)
	war_chief.set("_boss_phase", 3)
	war_chief.set("_boss_attack_counter", 0)
	var crystal_opener: int = int(crystal_king.call(&"_peek_next_boss_attack_pattern"))
	var warchief_opener: int = int(war_chief.call(&"_peek_next_boss_attack_pattern"))
	if crystal_opener != RogueEnemy.BossAttackPattern.SLAM:
		_fail("Crystal King final phase did not open with its slam")
		return false
	if warchief_opener != RogueEnemy.BossAttackPattern.VOLLEY:
		_fail("Warchief final phase did not open with its arrow fan")
		return false
	return true


func _get_angle_span(velocities: Array[Vector2]) -> float:
	var minimum_angle: float = INF
	var maximum_angle: float = -INF
	for velocity: Vector2 in velocities:
		var angle: float = velocity.angle()
		minimum_angle = minf(minimum_angle, angle)
		maximum_angle = maxf(maximum_angle, angle)
	return maximum_angle - minimum_angle


func _on_crystal_projectile_requested(
	_origin: Vector2,
	velocity: Vector2,
	_damage: int,
	_style: int
) -> void:
	_crystal_volley_velocities.append(velocity)


func _on_warchief_projectile_requested(
	_origin: Vector2,
	velocity: Vector2,
	_damage: int,
	_style: int
) -> void:
	_warchief_volley_velocities.append(velocity)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
