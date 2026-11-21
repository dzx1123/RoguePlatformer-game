extends SceneTree

const CAMPAIGN_STORE := preload("res://scripts/campaign_continue_store.gd")
const SAVE := "res://test_output/chapter2_entry_official.json"

func _initialize() -> void:
	call_deferred("run_test")

func run_test() -> void:
	var scene = load("res://scenes/Main.tscn").instantiate()
	scene.save_enabled = false
	scene.continue_save_path = SAVE
	root.add_child(scene)
	await process_frame
	var store := CAMPAIGN_STORE.new(SAVE, true, "")
	assert(store.clear_snapshot() == OK)
	scene._continue_store = store
	scene._show_start_screen(false)
	assert(not scene._continue_button.is_visible_in_tree() and scene._chapter2_menu_button.is_visible_in_tree())
	scene.player.set_current_health(51)
	scene.player.apply_run_upgrade(&"tempered_edge")
	var data: Dictionary = scene.CHAPTER2_STORE.from_player(scene.player, 77)
	assert(data.health == 51 and data.gold == 77 and data.upgrade_counts[&"tempered_edge"] == 1)
	data.room_index = 8
	data.campaign = {"seed": 906132, "difficulty": 1, "lives": 2, "run_shards": 12, "run_number": 1}
	assert(store.save_snapshot(data) == OK)
	scene._refresh_continue_button()
	assert(scene._continue_button.is_visible_in_tree() and scene._continue_button.text == "继续旅程")
	assert(scene._continue_button.tooltip_text.contains("第 29 房") and scene._chapter2_menu_button.is_visible_in_tree())
	data.completed = true
	assert(store.save_snapshot(data) == OK)
	scene._refresh_continue_button()
	assert(not scene._continue_button.is_visible_in_tree(), "A completed journey cannot resume")
	assert(scene._chapter2_menu_button.is_visible_in_tree(), "The testing shortcut is independent of the official slot")
	scene._entry_flow_active = false
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
	assert(store.clear_snapshot() == OK)
	scene.queue_free()
	await process_frame
	print("chapter2_entry_smoke: PASS")
	quit()
