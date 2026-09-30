extends SceneTree

func _initialize() -> void:
	call_deferred("capture")

func capture_frame(file_name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://test_output/" + file_name + ".png") == OK)

func capture() -> void:
	create_timer(25).timeout.connect(func(): quit(1))
	var scene = load("res://scenes/Chapter2Journey.tscn").instantiate()
	scene.persistence_enabled = false
	root.add_child(scene)
	scene._load_layout(2)
	await create_timer(1.8).timeout
	scene._open_choice(&"supply")
	scene._toggle_pause()
	await capture_frame("chapter2_pause_shared")
	scene.chapter_menu._open_settings(true)
	await capture_frame("chapter2_settings_shared")
	scene.chapter_menu._close_settings()
	scene.chapter_menu._open_build_overview(true)
	await capture_frame("chapter2_overview_shared")
	scene.chapter_menu._close_build_overview()
	scene._toggle_pause()
	await capture_frame("chapter2_cards_after_pause")
	scene.queue_free()
	await process_frame
	print("capture_chapter2_menus: PASS")
	quit()
