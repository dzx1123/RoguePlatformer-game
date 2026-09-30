extends SceneTree

var failed := false

func _initialize() -> void:
	call_deferred("run_test")

func check(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		push_error(message)

func run_test() -> void:
	for weapon in WeaponCatalog.all_weapon_ids():
		var reference: RoguePlayer = load("res://scenes/Player.tscn").instantiate()
		var aligned: RoguePlayer = load("res://scenes/Player.tscn").instantiate()
		for p: RoguePlayer in [reference, aligned]:
			root.add_child(p)
			p.set_physics_process(false)
			p.configure_weapon(weapon)
			for tick in range(20): p._update_hero_visuals(1.0 / 60.0)
		# A completed transition must not feed its screen-space correction back
		# into the next pose's movement smoothing.
		aligned._pose_alignment_offset = Vector2(17, -9)
		aligned.hero_sprite.position += aligned._pose_alignment_offset
		for p: RoguePlayer in [reference, aligned]: p._update_hero_visuals(1.0 / 60.0)
		check(reference.hero_sprite.position.distance_to(aligned.hero_sprite.position) < 0.001, "%s: pose alignment leaked into movement" % weapon)
		for interruption in ["turn", "hurt", "dead"]:
			aligned._pose_transition.texture = aligned.hero_sprite.texture
			aligned._pose_transition.material = aligned._snapshot_pose_material(aligned.hero_sprite.material)
			aligned._pose_transition_remaining = 0.075
			aligned._pose_transition.show()
			if interruption == "turn": aligned._facing *= -1
			if interruption == "hurt": aligned._hurt_remaining = 0.2
			if interruption == "dead": aligned._is_dead = true
			aligned._update_hero_visuals(1.0 / 60.0)
			check(not aligned._pose_transition.visible, "%s: %s retained an old pose" % [weapon, interruption])
			check(not aligned.hero_sprite.material.get_shader_parameter(&"pose_blend_active"), "Cancelled transition retained alpha compensation")
			aligned._hurt_remaining = 0
		for p: RoguePlayer in [reference, aligned]: p.queue_free()
		await process_frame
	if not failed: print("player_pose_alignment_smoke: PASS")
	quit(1 if failed else 0)
