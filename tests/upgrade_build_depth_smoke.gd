extends SceneTree


func _initialize() -> void:
	call_deferred(&"_run_test")


func _run_test() -> void:
	var all_upgrades: Array[Dictionary] = UpgradeCatalog.all_upgrades()
	if all_upgrades.size() != 20:
		_fail("Upgrade catalog exposed %d entries instead of 20" % all_upgrades.size())
		return
	var unique_ids: Dictionary = {}
	var rarity_counts: Dictionary = {}
	for upgrade: Dictionary in all_upgrades:
		var upgrade_id: StringName = upgrade.get("id", &"")
		unique_ids[upgrade_id] = true
		var rarity: int = int(upgrade.get("rarity", UpgradeCatalog.Rarity.COMMON))
		rarity_counts[rarity] = int(rarity_counts.get(rarity, 0)) + 1
	if unique_ids.size() != all_upgrades.size():
		_fail("Upgrade catalog contains duplicate IDs")
		return
	if (
		int(rarity_counts.get(UpgradeCatalog.Rarity.RARE, 0)) < 6
		or int(rarity_counts.get(UpgradeCatalog.Rarity.LEGENDARY, 0)) < 3
	):
		_fail("Upgrade rarity layers are not meaningfully populated")
		return

	for weapon_id: StringName in WeaponCatalog.all_weapon_ids():
		var available: Array[Dictionary] = UpgradeCatalog.create_available_pool(
			weapon_id,
			{}
		)
		if available.size() != 12:
			_fail(
				"Weapon %s received %d available upgrades instead of 12"
				% [weapon_id, available.size()]
			)
			return
		for upgrade: Dictionary in available:
			var required_weapon: StringName = upgrade.get("weapon", &"")
			if not required_weapon.is_empty() and required_weapon != weapon_id:
				_fail("Upgrade pool leaked a different weapon's exclusive card")
				return

	var capped_pool: Array[Dictionary] = UpgradeCatalog.create_available_pool(
		WeaponCatalog.SWORD,
		{&"tempered_edge": 5, &"eclipse_guard": 1}
	)
	for upgrade: Dictionary in capped_pool:
		if upgrade.get("id", &"") in [&"tempered_edge", &"eclipse_guard"]:
			_fail("Maxed upgrade remained in the available choice pool")
			return

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
	var player: RoguePlayer = player_scene.instantiate() as RoguePlayer
	root.add_child(player)
	player.set_physics_process(false)
	await process_frame

	player.configure_weapon(WeaponCatalog.SWORD)
	var sword_before: Dictionary = player.get_run_stats()
	if (
		not player.apply_run_upgrade(&"moon_rupture")
		or not player.apply_run_upgrade(&"moon_expansion")
		or not player.apply_run_upgrade(&"lunar_cycle")
	):
		_fail("Sword-exclusive build cards could not be applied")
		return
	var sword_after: Dictionary = player.get_run_stats()
	if (
		float(sword_after.get("skill_damage_multiplier", 0.0))
		<= float(sword_before.get("skill_damage_multiplier", 0.0))
		or float(sword_after.get("skill_reach", 0.0))
		<= float(sword_before.get("skill_reach", 0.0))
		or float(sword_after.get("skill_cooldown", INF))
		>= float(sword_before.get("skill_cooldown", INF))
	):
		_fail("Sword build cards did not alter damage, reach and cooldown")
		return

	if not player.apply_run_upgrade(&"eclipse_guard"):
		_fail("Sword defensive legendary could not be applied")
		return
	player.call(&"_start_skill")
	player.set("_hurt_invulnerability_remaining", 0.0)
	var sword_health_before: int = player.get_current_health()
	player.receive_enemy_attack(Vector2(100.0, 0.0), 40)
	if sword_health_before - player.get_current_health() != 26:
		_fail("Eclipse guard did not reduce incoming skill damage by 35 percent")
		return

	player.configure_weapon(WeaponCatalog.TWIN_BLADES)
	if not player.apply_run_upgrade(&"shadowstep"):
		_fail("Twin-blade legendary could not be applied")
		return
	player.call(&"_start_skill")
	player.set("_hurt_invulnerability_remaining", 0.0)
	var twin_health_before: int = player.get_current_health()
	if (
		player.receive_enemy_attack(Vector2(100.0, 0.0), 40)
		or player.get_current_health() != twin_health_before
	):
		_fail("Shadowstep did not protect the active twin-blade skill")
		return

	player.configure_weapon(WeaponCatalog.GREATSWORD)
	if not player.apply_run_upgrade(&"adamant_stance"):
		_fail("Greatsword defensive legendary could not be applied")
		return
	player.call(&"_start_skill")
	player.set("_hurt_invulnerability_remaining", 0.0)
	var greatsword_health_before: int = player.get_current_health()
	player.receive_enemy_attack(Vector2(100.0, 0.0), 40)
	if greatsword_health_before - player.get_current_health() != 22:
		_fail("Adamant stance did not reduce incoming skill damage by 45 percent")
		return

	if player.get_total_run_upgrade_count() < 6:
		_fail("Applied build cards were not tracked for the current run")
		return
	player.reset_run_progression()
	if player.get_total_run_upgrade_count() != 0:
		_fail("Run reset did not clear the expanded build")
		return

	player.queue_free()
	await process_frame
	print("upgrade_build_depth_smoke: PASS")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
