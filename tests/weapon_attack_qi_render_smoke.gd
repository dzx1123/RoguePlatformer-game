extends SceneTree

var _failures: Array[String] = []


func _init() -> void:
	_run_test()


func _run_test() -> void:
	for action_name: StringName in [&"restart", &"move_left", &"move_right", &"jump", &"dash", &"attack", &"skill"]:
		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name)

	var player_scene: PackedScene = load("res://scenes/Player.tscn")
	var player: RoguePlayer = player_scene.instantiate() as RoguePlayer
	root.add_child(player)
	await process_frame
	player.set_physics_process(false)
	var weapon_effect: WeaponSkillEffect = player.get_node("WeaponSkillEffect") as WeaponSkillEffect

	for weapon_id: StringName in [WeaponCatalog.TWIN_BLADES, WeaponCatalog.GREATSWORD]:
		if not player.configure_weapon(weapon_id):
			_failures.append("configure_weapon failed: %s" % weapon_id)
			continue
		var duration: float = 0.27 if weapon_id == WeaponCatalog.TWIN_BLADES else 0.52
		for attack_type in range(3):
			player.set("_attack_type", attack_type)
			player.set("_attack_remaining", duration * 0.57)
			player.call(&"_update_skill_effect")
			weapon_effect.queue_redraw()
			await process_frame
			if not weapon_effect.is_attack_effect_active() or weapon_effect.get_weapon_id() != weapon_id:
				_failures.append("%s attack %d did not activate qi" % [weapon_id, attack_type])
				continue
			if weapon_effect.get_draw_call_count() <= 0:
				_failures.append("%s attack %d did not draw" % [weapon_id, attack_type])
			if weapon_effect.get_crescent_surface_polygon_count() < 100:
				_failures.append(
					"%s attack %d crescent polygons=%d"
					% [weapon_id, attack_type, weapon_effect.get_crescent_surface_polygon_count()]
				)
			if weapon_effect.get_slash_shard_polygon_count() < 3:
				_failures.append(
					"%s attack %d shards=%d"
					% [weapon_id, attack_type, weapon_effect.get_slash_shard_polygon_count()]
				)
		player.set("_attack_remaining", 0.0)
		player.call(&"_update_skill_effect")

	player.queue_free()
	if _failures.is_empty():
		print("weapon_attack_qi_render_smoke: PASS")
		quit(0)
	else:
		for failure: String in _failures:
			print("weapon_attack_qi_render_smoke: FAIL: ", failure)
		quit(1)
