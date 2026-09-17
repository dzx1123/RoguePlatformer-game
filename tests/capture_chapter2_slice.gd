extends SceneTree

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1280, 720)
	var scene = load("res://scenes/Chapter2Slice.tscn").instantiate()
	root.add_child(scene)
	scene.set_physics_process(false)
	for index in [0, 3, 4]:
		scene._load_layout(index)
		await physics_frame
		await physics_frame
		scene.player.set_physics_process(false)
		for enemy in scene.living_enemies():
			enemy.set_physics_process(false)
		if index == 3:
			scene.player.position = scene.EXIT_POSITION
			scene.try_exit()
		scene.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		var frame := root.get_texture().get_image()
		assert(frame.save_png("res://test_output/chapter2_room_%d.png" % (21 + index)) == OK)
	scene.queue_free()
	await process_frame
	print("capture_chapter2_slice: PASS")
	quit()
