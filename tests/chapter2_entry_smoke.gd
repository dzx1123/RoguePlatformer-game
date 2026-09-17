extends SceneTree

func _initialize() -> void:
	call_deferred("run_test")

func run_test() -> void:
	var scene = load("res://scenes/Main.tscn").instantiate()
	scene.save_enabled = false
	scene.chapter2_save_path = "res://test_output/chapter2_entry_test.json"
	root.add_child(scene)
	await process_frame
	var store = scene.CHAPTER2_STORE.new(scene.chapter2_save_path)
	store.clear_snapshot()
	scene.player.set_current_health(51)
	scene.player.apply_run_upgrade(&"tempered_edge")
	var data: Dictionary = scene.CHAPTER2_STORE.from_player(scene.player, 77)
	assert(data.health == 51 and data.gold == 77 and data.upgrade_counts[&"tempered_edge"] == 1)
	assert(store.save_snapshot(data) == OK)
	scene.save_enabled = true
	scene._entry_flow_active = true
	scene._start_button.show()
	scene._refresh_continue_button()
	assert(scene._continue_button.visible and scene._continue_button.text.contains("第二章"))
	data.completed = true
	assert(store.save_snapshot(data) == OK)
	scene._refresh_continue_button()
	assert(not scene._continue_button.visible or not scene._continue_button.text.contains("第二章"), "Completed chapter cannot resume")
	scene.save_enabled = false
	scene._start_new_run()
	scene._finish_campaign_run()
	scene._victory_restart_button.grab_focus()
	scene._ensure_context_focus()
	assert(scene.get_viewport().gui_get_focus_owner() == scene._victory_restart_button)
	assert(not scene._chapter2_button.visible)
	if "capture" in OS.get_cmdline_user_args():
		root.mode = Window.MODE_WINDOWED
		root.size = Vector2i(1280, 720)
		await create_timer(0.6).timeout
		await RenderingServer.frame_post_draw
		assert(root.get_texture().get_image().save_png("res://test_output/chapter2_entry.png") == OK)
	store.clear_snapshot()
	scene.queue_free()
	await process_frame
	print("chapter2_entry_smoke: PASS")
	quit()
