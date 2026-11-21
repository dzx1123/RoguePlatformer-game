extends SceneTree

const BOSS := preload("res://scripts/forge_overseer_prototype.gd")

func _initialize() -> void:
	call_deferred("run_test")

static func release_inputs() -> void:
	for action in [&"move_left", &"move_right", &"jump", &"aim_down", &"attack", &"skill", &"dash", &"interact"]:
		Input.action_release(action)

func run_test() -> void:
	create_timer(180).timeout.connect(func(): push_error("Boss combat timeout"); quit(1))
	var scene = load("res://scenes/Chapter2Journey.tscn").instantiate()
	scene.persistence_enabled = false
	root.add_child(scene)
	for weapon in WeaponCatalog.all_weapon_ids():
		scene._load_layout(19)
		scene.player.configure_weapon(weapon)
		await create_timer(1.8).timeout
		var boss = scene.overseer
		assert(boss.is_on_floor() and absf(boss.get_impact_bounds().end.y - 620.0) < 1.0, "Boss art feet must meet physical floor")
		if not await clear_boss(scene):
			quit(1)
			return
		await create_timer(0.8).timeout
		assert(is_instance_valid(scene.room_portal) and scene.embers.get_child_count() == 0 and not scene.overheat, "Boss defeat must clear hazards and create portal")
		if weapon == WeaponCatalog.all_weapon_ids().back():
			Input.action_press(&"move_right")
			for frame in range(360):
				await physics_frame
				if scene.room_portal.is_in_range(scene.player.global_position):
					break
			Input.action_release(&"move_right")
			assert(scene.room_portal.is_in_range(scene.player.global_position), "Must walk to final portal")
			Input.action_press(&"interact")
			await physics_frame
			await physics_frame
			Input.action_release(&"interact")
			await create_timer(0.4).timeout
			assert(scene.route_complete, "Final portal input must complete the developer journey")
	scene.queue_free()
	await process_frame
	print("chapter2_boss_combat_smoke: PASS")
	quit()


static func clear_boss(scene: Node) -> bool:
	var tree := scene.get_tree()
	var boss: BOSS = scene.overseer
	var weapon: StringName = scene.player.get_weapon_id()
	var saw_second_phase := false
	var states_seen := {}
	for step in range(2400):
		release_inputs()
		if not is_instance_valid(scene) or scene.player.is_dead():
			push_error("Boss / %s: player died" % weapon)
			return false
		if not is_instance_valid(boss) or boss.get_current_health() <= 0:
			if not saw_second_phase:
				push_error("Boss / %s: both phases must run through actual inputs" % weapon)
				return false
			print("Boss / %s: cleared, health=%d, states=%s" % [weapon, scene.player.get_current_health(), states_seen.keys()])
			return true
		states_seen[boss.state] = true
		saw_second_phase = saw_second_phase or boss.phase == 2
		if "diagnose" in OS.get_cmdline_user_args() and step % 300 == 0:
			print(weapon, " step=", step, " player=", scene.player.position, " hp=", scene.player.get_current_health(), " boss=", boss.position, " hp=", boss.get_current_health(), " state=", boss.state)
		var offset: Vector2 = boss.position - scene.player.position
		if absf(offset.x) > 48 or step % 30 == 0:
			Input.action_press(&"move_right" if offset.x > 0 else &"move_left")
		if offset.y > 65 and scene.player.is_on_floor() and step % 12 == 0:
			Input.action_press(&"aim_down")
			Input.action_press(&"jump")
		var danger := false
		if boss.state == BOSS.State.HAMMER_WARNING and boss.remaining < 0.40:
			danger = boss.hammer_rect.grow(20).has_point(scene.player.position)
		if boss.state == BOSS.State.CHARGE_WARNING and boss.remaining < 0.30:
			danger = boss.get_charge_warning_rect().has_point(scene.player.position - boss.position)
		for ember in scene.embers.get_children():
			if not ember.impacted and ember.age > 1.10 and scene.player.position.distance_to(ember.landing) < 80:
				danger = true
		for heat: Rect2 in scene.heat_zones:
			if scene.player.position.y > heat.position.y - 35 and scene.player.position.x > heat.position.x - 35 and scene.player.position.x < heat.end.x + 35:
				danger = true
		if danger and scene.player.is_on_floor() and step % 3 == 0:
			Input.action_release(&"aim_down")
			Input.action_press(&"jump")
		if absf(offset.x) < 110 and absf(offset.y) < 65:
			if step % 6 == 0:
				Input.action_press(&"attack")
			if step % 60 == 0:
				Input.action_press(&"skill")
		await tree.physics_frame
		await tree.physics_frame
	release_inputs()
	push_error("Boss / %s: combat timed out" % weapon)
	return false
