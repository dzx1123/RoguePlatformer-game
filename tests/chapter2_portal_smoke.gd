extends SceneTree

func _initialize() -> void:
	call_deferred("run_test")

func run_test() -> void:
	var scene = load("res://scenes/Chapter2Journey.tscn").instantiate()
	scene.persistence_enabled = false
	root.add_child(scene)
	assert(is_instance_valid(scene.entry_beam) and scene.player.modulate.a == 0)
	assert(is_instance_valid(scene.room_portal))
	assert(scene.room_portal.global_position.x + scene.room_portal.prompt_offset_x + 284.0 <= 1268.0)
	if "capture" in OS.get_cmdline_user_args():
		root.size = Vector2i(1280, 720)
		root.content_scale_size = Vector2i(1280, 720)
		await create_timer(0.4).timeout
		await RenderingServer.frame_post_draw
		var error := root.get_texture().get_image().save_png("res://test_output/chapter2_portal_restored.png")
		assert(error == OK)
	await create_timer(1.7).timeout
	assert(scene.player.modulate.a > 0.95)
	scene.player.position = Vector2(1190, 592)
	Input.action_press(&"interact")
	await physics_frame
	await physics_frame
	Input.action_release(&"interact")
	assert(scene.room_index == 0 and scene.room_portal.is_activating())
	await create_timer(0.3).timeout
	assert(scene.room_index == 1 and is_instance_valid(scene.entry_beam))
	assert(not is_instance_valid(scene.room_portal), "Combat must not have an exit portal")
	for enemy in scene.living_enemies():
		enemy.queue_free()
	await process_frame
	await physics_frame
	await physics_frame
	assert(is_instance_valid(scene.room_portal), "Clear must spawn the chapter-one portal")
	scene._load_layout(9)
	for enemy in scene.living_enemies():
		enemy.queue_free()
	await process_frame
	await physics_frame
	await physics_frame
	assert(not is_instance_valid(scene.room_portal), "Pending wave must block portal")
	scene.queue_free()
	await process_frame
	print("chapter2_portal_smoke: PASS")
	quit()
