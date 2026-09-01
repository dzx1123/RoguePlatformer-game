extends SceneTree

var _player: RoguePlayer
var _captured_hit_indices: Array[int] = []
var _captured_damage: Array[int] = []


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
	_player = player_scene.instantiate() as RoguePlayer
	root.add_child(_player)
	_player.set_physics_process(false)
	_player.skill_hit.connect(_on_skill_hit)
	await process_frame

	var expected_hit_counts := {
		WeaponCatalog.SWORD: 1,
		WeaponCatalog.TWIN_BLADES: 3,
		WeaponCatalog.GREATSWORD: 1,
	}
	var sampled_animation_paths: Dictionary = {}
	var moon_effect := _player.get_node("MoonWheelEffect") as MoonWheelEffect
	var weapon_effect := _player.get_node("WeaponSkillEffect") as WeaponSkillEffect
	for weapon_id: StringName in WeaponCatalog.all_weapon_ids():
		if not _player.configure_weapon(weapon_id):
			_fail("Could not configure weapon %s" % weapon_id)
			return
		_captured_hit_indices.clear()
		_captured_damage.clear()
		_player.call(&"_start_skill")
		var duration: float = float(_player.get("_skill_duration"))
		var simulation_steps: int = ceili(duration * 120.0) + 4
		for _step_index in range(simulation_steps):
			_player.call(&"_update_timers", 1.0 / 120.0)

		var expected_count: int = int(expected_hit_counts[weapon_id])
		if _captured_damage.size() != expected_count:
			_fail(
				"Weapon %s emitted %d hits instead of %d"
				% [weapon_id, _captured_damage.size(), expected_count]
			)
			return
		for hit_index in range(expected_count):
			if _captured_hit_indices[hit_index] != hit_index:
				_fail("Weapon %s emitted an out-of-order hit sequence" % weapon_id)
				return
		var weapon: Dictionary = WeaponCatalog.get_weapon(weapon_id)
		var expected_total_damage: float = (
			float(weapon.get("damage", 1))
			* float(weapon.get("skill_multiplier", 1.0))
		)
		var actual_total_damage: int = 0
		for damage_value in _captured_damage:
			actual_total_damage += damage_value
		if absf(float(actual_total_damage) - expected_total_damage) > float(expected_count):
			_fail(
				"Weapon %s skill damage budget was %.1f but emitted %d"
				% [weapon_id, expected_total_damage, actual_total_damage]
			)
			return

		_player.configure_weapon(weapon_id)
		duration = float(_player.get("_skill_duration"))
		_player.set("_skill_remaining", duration * 0.50)
		_player.call(&"_update_hero_visuals", 1.0 / 60.0)
		var hero_sprite := _player.get_node("HeroSprite") as Sprite2D
		sampled_animation_paths[hero_sprite.texture.resource_path] = true
		if weapon_id == WeaponCatalog.SWORD:
			if not moon_effect.is_effect_active() or weapon_effect.is_effect_active():
				_fail("Moon sword did not exclusively activate the moon-wheel effect")
				return
		else:
			if moon_effect.is_effect_active() or not weapon_effect.is_effect_active():
				_fail("Weapon %s did not activate its independent effect" % weapon_id)
				return
			if weapon_effect.get_weapon_id() != weapon_id:
				_fail("Independent skill effect used the wrong weapon identity")
				return

	if sampled_animation_paths.size() != 3:
		_fail("The three weapons did not expose distinct sampled skill poses")
		return

	var twin_start_speed: float
	var twin_peak_speed: float
	_player.configure_weapon(WeaponCatalog.TWIN_BLADES)
	twin_start_speed = float(_player.call(&"_get_skill_lunge_speed", 0.0))
	twin_peak_speed = float(_player.call(&"_get_skill_lunge_speed", 0.18))
	if twin_peak_speed <= twin_start_speed * 2.0:
		_fail("Twin-blade skill did not create a distinct dash pulse")
		return
	_player.configure_weapon(WeaponCatalog.GREATSWORD)
	var greatsword_brace_speed: float = float(
		_player.call(&"_get_skill_lunge_speed", 0.12)
	)
	var greatsword_commit_speed: float = float(
		_player.call(&"_get_skill_lunge_speed", 0.58)
	)
	if greatsword_brace_speed > 0.01 or greatsword_commit_speed <= 0.0:
		_fail("Greatsword skill did not separate brace and committed movement")
		return

	var enemy := RogueEnemy.new()
	root.add_child(enemy)
	enemy.setup(0, 0.0, -500.0, 500.0)
	await process_frame
	enemy.global_position = Vector2(112.0, -10.0)
	if not enemy.is_hit_by_weapon_skill(
		Vector2.ZERO,
		1.0,
		1.35,
		WeaponCatalog.TWIN_BLADES
	):
		_fail("Twin-blade skill rejected a target inside its forward lane")
		return
	enemy.global_position = Vector2(-92.0, 0.0)
	if not enemy.is_hit_by_weapon_skill(
		Vector2.ZERO,
		1.0,
		1.90,
		WeaponCatalog.GREATSWORD
	):
		_fail("Greatsword skill rejected a target inside its ground shockwave")
		return
	enemy.global_position = Vector2(420.0, 0.0)
	if enemy.is_hit_by_weapon_skill(
		Vector2.ZERO,
		1.0,
		1.90,
		WeaponCatalog.GREATSWORD
	):
		_fail("Greatsword skill accepted a target far outside its shockwave")
		return

	enemy.queue_free()
	_player.queue_free()
	await process_frame
	print("weapon_skill_identity_smoke: PASS")
	quit(0)


func _on_skill_hit(
	_origin: Vector2,
	_facing: float,
	damage: int,
	_reach: float
) -> void:
	_captured_hit_indices.append(_player.get_skill_hit_index())
	_captured_damage.append(damage)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
