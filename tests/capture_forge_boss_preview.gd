extends SceneTree

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	var scene = load("res://scenes/Chapter2Journey.tscn").instantiate()
	scene.persistence_enabled = false
	root.add_child(scene)
	scene._load_layout(19)
	await create_timer(3.5).timeout
	scene.set_physics_process(false)
	scene.player.set_physics_process(false)
	scene.overseer.set_physics_process(false)
	assert(absf(scene.overseer.get_impact_bounds().end.y - 620) < 1)
	for direction in [-1.0, 1.0]:
		scene.overseer.position.x = 660
		scene.player.position = Vector2(660 + direction * 220, 592)
		scene.overseer._begin_attack(2)
		scene.overseer.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		var path := "res://test_output/forge_boss_charge_%s.png" % ("left" if direction < 0 else "right")
		assert(root.get_texture().get_image().save_png(path) == OK)
	scene.queue_free()
	await process_frame
	print("capture_forge_boss_preview: PASS")
	quit()
