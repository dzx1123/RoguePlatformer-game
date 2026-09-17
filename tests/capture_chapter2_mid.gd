extends SceneTree

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	var scene = load("res://scenes/Chapter2MidSlice.tscn").instantiate()
	root.add_child(scene)
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1280, 720)
	scene.set_physics_process(false)
	for index in [5, 7, 8, 12, 13, 14]:
		scene._load_layout(index)
		await physics_frame
		await physics_frame
		scene.player.set_physics_process(false)
		for enemy in scene.living_enemies():
			enemy.set_physics_process(false)
		if index in [7, 12, 13]:
			scene.gold = 24
			scene.player.position = scene.EXIT_POSITION
			scene.try_exit()
		if index == 14:
			scene.elapsed = 2
			scene._physics_process(0.01)
		scene.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		assert(root.get_texture().get_image().save_png("res://test_output/chapter2_room_%d.png" % (21 + index)) == OK)
	scene.queue_free()
	await process_frame
	print("capture_chapter2_mid: PASS")
	quit()
