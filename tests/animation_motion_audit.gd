extends SceneTree

const GOBLIN_CELL_SIZE := Vector2i(144, 138)
const GOBLIN_WALK_FIRST_FRAME := 11
const GOBLIN_WALK_FRAME_COUNT := 6


func _initialize() -> void:
	call_deferred(&"_run_audit")


func _run_audit() -> void:
	var cases: Array[Dictionary] = [
		{
			"name": "club",
			"role": RogueEnemy.EnemyRole.MELEE,
			"rank": RogueEnemy.EnemyRank.NORMAL,
		},
		{
			"name": "elite",
			"role": RogueEnemy.EnemyRole.MELEE,
			"rank": RogueEnemy.EnemyRank.ELITE,
		},
		{
			"name": "archer",
			"role": RogueEnemy.EnemyRole.RANGED,
			"rank": RogueEnemy.EnemyRank.NORMAL,
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
	var anchor_min: float = INF
	var anchor_max: float = -INF
	var frames_seen: Dictionary = {}
	var atlas_image := sprite.texture.get_image()
	if atlas_image == null or atlas_image.get_size() != Vector2i(2448, 138):
		push_error("%s does not use the canonical goblin reference atlas" % String(case_data["name"]))
		enemy.queue_free()
		return false
	for sample_index in range(150):
		enemy.velocity = Vector2(180.0, 0.0)
		enemy.call(&"_update_locomotion_animation", 1.0 / 60.0)
		enemy.call(&"_update_sprite_animation", 1.0 / 60.0)
		if sample_index < 18:
			continue
		if sprite.region_rect.size != Vector2(GOBLIN_CELL_SIZE):
			push_error("%s walk frame lost its 144x138 source canvas" % String(case_data["name"]))
			enemy.queue_free()
			return false
		var frame_index: int = int(round(sprite.region_rect.position.x / GOBLIN_CELL_SIZE.x))
		if (
			frame_index < GOBLIN_WALK_FIRST_FRAME
			or frame_index >= GOBLIN_WALK_FIRST_FRAME + GOBLIN_WALK_FRAME_COUNT
		):
			push_error("%s left the authored six-frame walk range" % String(case_data["name"]))
			enemy.queue_free()
			return false
		frames_seen[frame_index] = true
		var frame_image := atlas_image.get_region(Rect2i(
			frame_index * GOBLIN_CELL_SIZE.x,
			0,
			GOBLIN_CELL_SIZE.x,
			GOBLIN_CELL_SIZE.y
		))
		var used_rect := frame_image.get_used_rect()
		if used_rect.size == Vector2i.ZERO:
			push_error("%s walk frame %d is empty" % [String(case_data["name"]), frame_index])
			enemy.queue_free()
			return false
		var bottom_pixel: float = float(used_rect.end.y - 1)
		var foot_y: float = (
			sprite.position.y
			+ (bottom_pixel - GOBLIN_CELL_SIZE.y * 0.5) * absf(sprite.scale.y)
		)
		foot_min = minf(foot_min, foot_y)
		foot_max = maxf(foot_max, foot_y)
		anchor_min = minf(anchor_min, sprite.position.x)
		anchor_max = maxf(anchor_max, sprite.position.x)
	print(
		"%s: frames=%s foot_range=%.3fpx anchor_range=%.3fpx"
		% [String(case_data["name"]), frames_seen.keys(), foot_max - foot_min, anchor_max - anchor_min]
	)
	var foot_range: float = foot_max - foot_min
	var anchor_range: float = anchor_max - anchor_min
	if frames_seen.size() != GOBLIN_WALK_FRAME_COUNT:
		push_error("%s run cycle did not visit all six authored frames" % String(case_data["name"]))
		enemy.queue_free()
		return false
	if foot_range > 1.25:
		push_error(
			"%s run feet drifted %.3fpx instead of staying planted"
			% [String(case_data["name"]), foot_range]
		)
		enemy.queue_free()
		return false
	if anchor_range > 0.01:
		push_error(
			"%s run body anchor drifted %.3fpx"
			% [String(case_data["name"]), anchor_range]
		)
		enemy.queue_free()
		return false
	enemy.queue_free()
	await process_frame
	return true
