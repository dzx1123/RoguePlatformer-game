extends SceneTree
func _initialize() -> void:
	call_deferred(&"_run")

func _run() -> void:
	root.size = Vector2i(1100, 420)
	root.content_scale_size = root.size
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_IGNORE
	RenderingServer.set_default_clear_color(Color("#182631"))
	var actors: Array[RogueEnemy] = []
	for kind in range(4):
		var actor := RogueEnemy.new()
		actor.setup(0, 0, -200, 200, 1 if kind == 2 else 0, 2 if kind == 3 else (1 if kind == 1 else 0), 1, 1, RogueEnemy.EnemyFamily.GOBLIN)
		root.add_child(actor)
		actor.set_physics_process(false)
		actor.scale = Vector2.ONE * 1.6
		actor.position = Vector2(145 + kind * 265, 350 - (52 if kind == 3 else (29 if kind == 1 else 22)) * 1.6)
		actor.set("_facing", 1.0)
		actor.velocity = Vector2(72, 0)
		actors.append(actor)
		var label := Label.new()
		label.text = ["SOLDIER", "ELITE", "ARCHER", "WAR CHIEF"][kind]
		label.position = Vector2(90 + kind * 265, 30)
		root.add_child(label)
	var floor_line := Line2D.new()
	floor_line.points = PackedVector2Array([Vector2(20, 350), Vector2(1080, 350)])
	floor_line.width = 1
	floor_line.default_color = Color("#c5aa76")
	root.add_child(floor_line)
	for tick in range(24):
		for actor in actors:
			if tick < 12:
				actor.set("_facing", 1.0 if tick < 6 else -1.0)
				actor.set("_locomotion_cycle", float(tick % 6))
			elif tick < 18:
				actor.set("_attack_remaining", float(actor.call(&"_get_attack_duration")) * (1.0 - (tick - 12 + 0.1) / 6.0))
			elif tick < 20:
				actor.set("_attack_remaining", 0.0)
				actor.set("_hurt_remaining", 0.15 if tick == 18 else 0.05)
			else:
				actor.set("_hurt_remaining", 0.0)
				actor.set("_is_defeated", true)
				actor.set("_death_remaining", RogueEnemy.DEATH_ANIMATION_DURATION * (1.0 - (tick - 20) / 4.0))
			actor.call(&"_update_sprite_animation")
		await process_frame
		await process_frame
		RenderingServer.force_draw()
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://test_output/goblin_reference_%02d.png" % tick)
	print("capture_goblin_reference_walk: PASS")
	quit(0)
