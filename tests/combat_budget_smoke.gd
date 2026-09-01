extends SceneTree

const BUDGET_SCRIPT := preload("res://scripts/combat_budget.gd")


func _initialize() -> void:
	call_deferred(&"_run_test")


func _run_test() -> void:
	var easy_first: Dictionary = BUDGET_SCRIPT.create_profile(0, 0, 0)
	var easy_final: Dictionary = BUDGET_SCRIPT.create_profile(0, 19, 0)
	var hard_final: Dictionary = BUDGET_SCRIPT.create_profile(2, 19, 0)
	var easy_behavior: Dictionary = easy_first.get("behavior", {}) as Dictionary
	var hard_behavior: Dictionary = hard_final.get("behavior", {}) as Dictionary
	if (
		float(easy_first.get("budget", 0.0)) >= float(easy_final.get("budget", 0.0))
		or float(easy_final.get("budget", 0.0)) >= float(hard_final.get("budget", 0.0))
		or int(easy_behavior.get("tier", -1)) != 0
		or int(easy_behavior.get("pursuit_level", -1)) != 0
		or int(easy_behavior.get("ranged_volley_count", 0)) != 1
		or float(easy_behavior.get("melee_combo_chance", 1.0)) != 0.0
		or int(hard_behavior.get("tier", -1)) != 5
		or int(hard_behavior.get("pursuit_level", 0)) != 2
		or int(hard_behavior.get("ranged_volley_count", 0)) != 3
		or float(hard_behavior.get("melee_combo_chance", 0.0)) <= 0.30
	):
		_fail("Combat profiles did not progress from restrained to advanced behavior")
		return
	if (
		float(hard_final.get("health_multiplier", 0.0)) > 1.45
		or float(hard_final.get("damage_multiplier", 0.0)) > 1.35
		or float(hard_final.get("speed_multiplier", 0.0)) > 1.15
	):
		_fail("Late hard mode still relies on excessive raw stat multipliers")
		return

	var candidates: Array[Dictionary] = []
	for candidate_index in range(12):
		candidates.append({
			"surface": candidate_index % 6,
			"ratio": 0.20 + float(candidate_index % 5) * 0.13,
			"role": candidate_index % 2,
		})
	var easy_rng := RandomNumberGenerator.new()
	easy_rng.seed = 4401
	var easy_plan: Array[Dictionary] = BUDGET_SCRIPT.build_spawn_plan(
		candidates,
		easy_first,
		easy_rng
	)
	var hard_rng := RandomNumberGenerator.new()
	hard_rng.seed = 4401
	var hard_plan: Array[Dictionary] = BUDGET_SCRIPT.build_spawn_plan(
		candidates,
		hard_final,
		hard_rng
	)
	if easy_plan.size() > 3 or easy_plan.size() < 2 or hard_plan.size() <= easy_plan.size():
		_fail("Encounter budget did not constrain the easy opening roster")
		return
	if _count_role(easy_plan, 1) > 1:
		_fail("Easy opening budget exceeded its ranged-enemy allowance")
		return

	var medium_elite: Dictionary = BUDGET_SCRIPT.create_profile(1, 2, 2)
	var elite_rng := RandomNumberGenerator.new()
	elite_rng.seed = 9917
	var elite_plan: Array[Dictionary] = BUDGET_SCRIPT.build_spawn_plan(
		candidates,
		medium_elite,
		elite_rng
	)
	if elite_plan.size() < 4 or _count_rank(elite_plan, 1) != 2:
		_fail("Elite encounter budget did not preserve its two promoted enemies")
		return
	var medium_challenge: Dictionary = BUDGET_SCRIPT.create_profile(1, 12, 6)
	var challenge_rng := RandomNumberGenerator.new()
	challenge_rng.seed = 7319
	var challenge_plan: Array[Dictionary] = BUDGET_SCRIPT.build_spawn_plan(
		candidates,
		medium_challenge,
		challenge_rng
	)
	if challenge_plan.size() < 7 or _count_rank(challenge_plan, 1) < 2:
		_fail("Challenge budget did not create the intended high-pressure composition")
		return

	var repeat_rng := RandomNumberGenerator.new()
	repeat_rng.seed = 4401
	var repeated_plan: Array[Dictionary] = BUDGET_SCRIPT.build_spawn_plan(
		candidates,
		easy_first,
		repeat_rng
	)
	if JSON.stringify(easy_plan) != JSON.stringify(repeated_plan):
		_fail("A fixed seed did not reproduce the same combat-budget roster")
		return

	var ranged_enemy := RogueEnemy.new()
	var target := Node2D.new()
	target.position = Vector2(220.0, 0.0)
	ranged_enemy.setup(
		1,
		0.0,
		-100.0,
		100.0,
		RogueEnemy.EnemyRole.RANGED,
		RogueEnemy.EnemyRank.NORMAL,
		float(hard_final.get("health_multiplier", 1.0)),
		float(hard_final.get("damage_multiplier", 1.0)),
		RogueEnemy.EnemyFamily.GOBLIN,
		float(hard_final.get("speed_multiplier", 1.0)),
		float(hard_final.get("awareness_multiplier", 1.0)),
		hard_behavior
	)
	ranged_enemy.set_target(target)
	var projectile_velocities: Array[Vector2] = []
	ranged_enemy.projectile_requested.connect(func(
		_origin: Vector2,
		projectile_velocity: Vector2,
		_damage: int,
		_style: int
	) -> void:
		projectile_velocities.append(projectile_velocity)
	)
	ranged_enemy.call(&"_fire_projectile")
	if projectile_velocities.size() != 3:
		ranged_enemy.free()
		target.free()
		_fail("Highest behavior tier did not unlock the three-arrow ranged volley")
		return
	if is_equal_approx(projectile_velocities[0].angle(), projectile_velocities[2].angle()):
		ranged_enemy.free()
		target.free()
		_fail("Advanced ranged volley did not apply its spread behavior")
		return
	ranged_enemy.free()
	target.free()
	print("combat_budget_smoke: PASS")
	quit(0)


func _count_role(plan: Array[Dictionary], role: int) -> int:
	var count: int = 0
	for descriptor: Dictionary in plan:
		if int(descriptor.get("role", 0)) == role:
			count += 1
	return count


func _count_rank(plan: Array[Dictionary], rank: int) -> int:
	var count: int = 0
	for descriptor: Dictionary in plan:
		if int(descriptor.get("rank", 0)) == rank:
			count += 1
	return count


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
