extends SceneTree

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1280, 720)
	var scene = load("res://scenes/Chapter2FullSlice.tscn").instantiate()
	root.add_child(scene)
	scene.set_physics_process(false)
	for index in [0, 1, 2, 3, 4, 5, 8, 9, 14]:
		scene._load_layout(index)
		await create_timer(0.45).timeout
		for enemy in scene.living_enemies():
			enemy.set_physics_process(false)
		if index == 5:
			scene.guard.charge_state = scene.guard.ChargeState.WINDUP
			scene.guard.charge_facing = -1
			scene.guard.queue_redraw()
		scene.queue_redraw()
		await RenderingServer.frame_post_draw
		var error := root.get_texture().get_image().save_png("res://test_output/chapter2_terrain_%d.png" % (21 + index))
		assert(error == OK)
	scene.queue_free()
	await process_frame
	print("capture_chapter2_terrain: PASS")
	quit()
