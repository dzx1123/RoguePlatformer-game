extends SceneTree

var _phase_changes: Array[int] = []
var _projectile_count: int = 0


func _initialize() -> void:
	call_deferred(&"_run_test")


func _run_test() -> void:
	for action_name in [
		&"restart",
		&"move_left",
		&"move_right",
		&"jump",
		&"dash",
		&"attack",
		&"skill",
	]:
		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name)

	var player_scene: PackedScene = load("res://scenes/Player.tscn")
	var player := player_scene.instantiate() as RoguePlayer
	player.position = Vector2(120.0, 0.0)
	root.add_child(player)
	player.set_physics_process(false)

	var boss := RogueEnemy.new()
	boss.setup(
		0,
		0.0,
		-500.0,
		500.0,
		RogueEnemy.EnemyRole.MELEE,
		RogueEnemy.EnemyRank.BOSS,
		1.0,
		1.0,
		RogueEnemy.EnemyFamily.GOBLIN,
		1.0,
		1.0
	)
	root.add_child(boss)
	boss.set_physics_process(false)
	boss.set_target(player)
	boss.boss_phase_changed.connect(_on_boss_phase_changed)
	boss.projectile_requested.connect(_on_projectile_requested)
	await process_frame

	if boss.get_boss_phase() != 1:
		_fail("Boss did not begin in phase one")
		return
	var phase_one_cooldown: float = float(boss.call(&"_get_attack_cooldown"))
	var maximum_health: int = boss.get_max_health()
	boss.set("_hurt_invulnerability_remaining", 0.0)
	if not boss.receive_player_attack(Vector2.ZERO, 1.0, ceili(float(maximum_health) * 0.31)):
		_fail("Boss rejected the hit that should cross seventy percent")
		return
	if boss.get_boss_phase() != 2 or _phase_changes != [2]:
		_fail("Boss did not enter phase two at seventy percent health")
		return

	var phase_two_patterns: Dictionary = {}
	var phase_two_names: Dictionary = {}
	for _pattern_index in range(3):
		boss.set("_attack_remaining", 0.0)
		boss.call(&"_start_attack")
		var pattern: int = boss.get_boss_attack_pattern()
		phase_two_patterns[pattern] = true
		phase_two_names[boss.get_boss_attack_name()] = true
		var duration: float = float(boss.call(&"_get_attack_duration"))
		var warning_time: float = float(boss.call(&"_get_attack_action_delay"))
		if warning_time < 0.45 or warning_time >= duration:
			_fail("Boss attack did not preserve a readable pre-impact warning")
			return
	if phase_two_patterns.size() != 3 or phase_two_names.size() != 3:
		_fail("Phase two did not cycle through three distinct attacks")
		return

	# Phase two starts with the slam. Verify its warning is backed by real area damage.
	boss.set("_boss_attack_pattern", RogueEnemy.BossAttackPattern.SLAM)
	player.set("_hurt_invulnerability_remaining", 0.0)
	var health_before_slam: int = player.get_current_health()
	boss.call(&"_perform_boss_slam")
	if player.get_current_health() >= health_before_slam:
		_fail("Boss slam telegraph had no matching area damage")
		return

	boss.set("_hurt_invulnerability_remaining", 0.0)
	var damage_to_phase_three: int = boss.get_current_health() - floori(float(maximum_health) * 0.34)
	boss.receive_player_attack(Vector2.ZERO, 1.0, damage_to_phase_three)
	if boss.get_boss_phase() != 3 or _phase_changes != [2, 3]:
		_fail("Boss did not enter phase three at thirty-five percent health")
		return
	var phase_three_cooldown: float = float(boss.call(&"_get_attack_cooldown"))
	if phase_three_cooldown >= phase_one_cooldown:
		_fail("Final phase did not increase the boss attack cadence")
		return

	# The final-phase sequence begins with a five-shot aimed volley.
	boss.set("_attack_remaining", 0.0)
	boss.call(&"_start_attack")
	if boss.get_boss_attack_pattern() != RogueEnemy.BossAttackPattern.VOLLEY:
		_fail("Final phase did not prioritize its enhanced volley")
		return
	boss.call(&"_fire_projectile")
	if _projectile_count != 5:
		_fail("Final-phase volley emitted %d projectiles instead of five" % _projectile_count)
		return

	boss.queue_free()
	player.queue_free()
	await process_frame
	print("boss_phase_depth_smoke: PASS")
	quit(0)


func _on_boss_phase_changed(phase: int) -> void:
	_phase_changes.append(phase)


func _on_projectile_requested(
	_origin: Vector2,
	_velocity: Vector2,
	_damage: int,
	_style: int
) -> void:
	_projectile_count += 1


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
