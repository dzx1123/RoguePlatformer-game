extends SceneTree

func _initialize() -> void:
	call_deferred("run_probe")

func run_probe() -> void:
	var scene = load("res://scenes/Chapter2FullSlice.tscn").instantiate()
	root.add_child(scene)
	root.size = Vector2i(1280, 720)
	scene.set_physics_process(false)
	for index in [2, 5, 10, 17, 18, 19]:
		scene._load_layout(index)
		await create_timer(0.25).timeout
		for enemy in scene.living_enemies():
			enemy.set_physics_process(false)
		scene.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		if index == 17:
			root.get_texture().get_image().save_png("D:/Godot/RoguePlatformer-game/test_output/chapter2_exported_art.png")
	print("chapter2_export_probe: PASS — packaged background and four character types loaded")
	scene.queue_free()
	await process_frame
	quit()
