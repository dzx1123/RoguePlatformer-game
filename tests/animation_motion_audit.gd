extends SceneTree


func _initialize() -> void:
	call_deferred(&"_run_audit")


func _run_audit() -> void:
	var cases: Array[Dictionary] = [
		{
			"name": "club",
			"role": RogueEnemy.EnemyRole.MELEE,
			"rank": RogueEnemy.EnemyRank.NORMAL,
			"bottoms": [300.0, 300.0, 300.0, 300.0, 300.0, 300.0, 300.0, 300.0],
			"heads": [146.0, 146.0, 146.0, 146.0, 146.0, 146.0, 146.0, 146.0],
		},
		{
			"name": "elite",
			"role": RogueEnemy.EnemyRole.MELEE,
			"rank": RogueEnemy.EnemyRank.ELITE,
			"bottoms": [303.0, 303.0, 303.0, 303.0, 303.0, 303.0, 303.0, 303.0],
			"heads": [161.193, 161.372, 160.639, 160.524, 161.224, 161.143, 160.881, 161.647],
		},
		{
			"name": "archer",
			"role": RogueEnemy.EnemyRole.RANGED,
			"rank": RogueEnemy.EnemyRank.NORMAL,
			"bottoms": [296.0, 296.0, 296.0, 296.0, 296.0, 296.0, 296.0, 296.0],
			"heads": [159.943, 160.829, 160.335, 160.033, 160.202, 160.526, 160.487, 160.248],
		},
	]
	for case_data in cases:
		if not await _audit_case(case_data):
			quit(1)
			return
	print("animation_motion_audit: PASS")
	quit(0)


func _audit_case(case_data: Dictionary) -> bool:
	var enemy := RogueEnemy.new()
	enemy.setup(
		0,
		0.0,
		-100.0,
		100.0,
		int(case_data["role"]),
		int(case_data["rank"]),
		1.0,
		1.0,
		RogueEnemy.EnemyFamily.GOBLIN
	)
	root.add_child(enemy)
	await process_frame
	enemy.set_physics_process(false)
	enemy.set("_locomotion_cycle", 0.0)
	enemy.set("_locomotion_blend", 0.0)
	enemy.set("_locomotion_active", false)
	enemy.set("_sprite_pose_initialized", false)

	var sprite := enemy.get_node("EnemySprite") as Sprite2D
	var foot_min: float = INF
	var foot_max: float = -INF
	var head_min: float = INF
	var head_max: float = -INF
	var frames_seen: Dictionary = {}
	var bottoms: Array = case_data["bottoms"]
	var heads: Array = case_data["heads"]
	for sample_index in range(150):
		enemy.velocity = Vector2(180.0, 0.0)
		enemy.call(&"_update_locomotion_animation", 1.0 / 60.0)
		enemy.call(&"_update_sprite_animation", 1.0 / 60.0)
		if sample_index < 18:
			continue
		var cell_width: float = float(sprite.texture.get_width()) / 4.0
		var cell_height: float = float(sprite.texture.get_height()) / 2.0
		var frame_column: int = int(round(sprite.region_rect.position.x / cell_width))
		var frame_row: int = int(round(sprite.region_rect.position.y / cell_height))
		var frame_index: int = frame_row * 4 + frame_column
		frames_seen[frame_index] = true
		var foot_y: float = (
			sprite.position.y
			+ (float(bottoms[frame_index]) - cell_height * 0.5) * absf(sprite.scale.y)
		)
		var source_head_offset: float = (
			float(heads[frame_index]) - cell_width * 0.5
		) * absf(sprite.scale.x)
		if sprite.flip_h:
			source_head_offset *= -1.0
		var head_x: float = sprite.position.x + source_head_offset
		foot_min = minf(foot_min, foot_y)
		foot_max = maxf(foot_max, foot_y)
		head_min = minf(head_min, head_x)
		head_max = maxf(head_max, head_x)
	print(
		"%s: frames=%s foot_range=%.3fpx head_range=%.3fpx"
		% [String(case_data["name"]), frames_seen.keys(), foot_max - foot_min, head_max - head_min]
	)
	var foot_range: float = foot_max - foot_min
	var head_range: float = head_max - head_min
	if frames_seen.size() != 8:
		push_error("%s run cycle did not visit all eight frames" % String(case_data["name"]))
		enemy.queue_free()
		return false
	if foot_range > 1.25:
		push_error(
			"%s run feet drifted %.3fpx instead of staying planted"
			% [String(case_data["name"]), foot_range]
		)
		enemy.queue_free()
		return false
	if head_range > 0.50:
		push_error(
			"%s run body anchor drifted %.3fpx"
			% [String(case_data["name"]), head_range]
		)
		enemy.queue_free()
		return false
	enemy.queue_free()
	await process_frame
	return true
