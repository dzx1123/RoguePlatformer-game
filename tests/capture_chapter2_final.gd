extends SceneTree

func _initialize() -> void:
	call_deferred("capture")

func save_frame(scene: Node, name: String) -> void:
	scene.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://test_output/chapter2_%s.png" % name) == OK)

func capture() -> void:
	var scene = load("res://scenes/Chapter2FullSlice.tscn").instantiate()
	root.add_child(scene)
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1280, 720)
	scene.set_physics_process(false)
	for index in [15, 16, 17, 18, 19]:
		scene._load_layout(index)
		await physics_frame
		await physics_frame
		scene.player.set_physics_process(false)
		for enemy in scene.living_enemies():
			enemy.set_physics_process(false)
		if index == 15:
			scene.cycle = 2
		if index == 16:
			scene.player.position = scene.BRANCH_SIGN
			scene.try_exit()
		if index == 18:
			scene.player.position = scene.EXIT_POSITION
			scene.try_exit()
		if index == 19:
			scene.player.position = Vector2(710, 590)
			scene.overseer._begin_attack(0)
			scene.overseer.queue_redraw()
		await save_frame(scene, "room_%d" % (21 + index))
	scene.overseer._current_health = 260
	scene.overseer._physics_process(0.01)
	await save_frame(scene, "boss_shift")
	scene.overseer.receive_player_attack(scene.overseer.position, 1, 9999)
	scene.overseer._physics_process(2)
	await process_frame
	scene.player.position = scene.EXIT_POSITION
	assert(scene.try_exit() and scene.route_complete)
	await save_frame(scene, "chapter_complete")
	scene.queue_free()
	await process_frame
	print("capture_chapter2_final: PASS")
	quit()
