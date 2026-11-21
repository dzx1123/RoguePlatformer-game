extends SceneTree

const CAMPAIGN_STORE := preload("res://scripts/campaign_continue_store.gd")
const SAVE := "res://test_output/chapter2_game_entry_official.json"
const SEED := 438271

func _initialize() -> void:
	call_deferred("run_test")

func capture(name: String) -> void:
	if "capture" not in OS.get_cmdline_user_args():
		return
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	await create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://test_output/" + name + ".png") == OK)

func run_test() -> void:
	var store := CAMPAIGN_STORE.new(SAVE, true, "")
	assert(store.clear_snapshot() == OK)
	var main = load("res://scenes/Main.tscn").instantiate()
	main.save_enabled = false
	main.continue_save_path = SAVE
	main.set_next_run_seed(SEED)
	root.add_child(main)
	current_scene = main
	main._continue_store = store
	main.player.set_current_health(67)
	main.player.apply_run_upgrade(&"tempered_edge")
	main._gold = 81
	main._persist_continue_snapshot()
	var saved_story := FileAccess.get_file_as_bytes(SAVE)
	assert(not saved_story.is_empty() and store.can_resume() and not store.has_chapter2())
	main._show_start_screen(false)
	assert(main._chapter2_menu_button.is_visible_in_tree() and main._continue_button.is_visible_in_tree())
	await capture("chapter2_direct_menu")
	main._chapter2_menu_button.pressed.emit()
	await process_frame
	await process_frame
	var journey = current_scene
	assert(journey.scene_file_path.ends_with("Chapter2Journey.tscn"))
	assert(journey.campaign_hud.has_node("BottomHUD"), "Development entry must use chapter-one HUD")
	assert(journey.campaign_presenter.attack_slot.visible and journey.campaign_presenter.skill_slot.visible)
	assert(not journey.return_panel.visible, "Legacy corner button must not replace the shared HUD")
	assert(not journey.persistence_enabled and journey.save_path.is_empty() and journey.campaign.is_empty())
	var first_test_store: RunContinueStore = journey.checkpoint_store
	assert(first_test_store != store)
	assert(not paused, "Chapter 2 inherited the main menu's paused SceneTree")
	await create_timer(1.7).timeout
	assert(journey.player.modulate.a > 0.95, "Hero must finish arrival and become visible")
	var start_x: float = journey.player.position.x
	Input.action_press(&"move_right")
	await create_timer(0.4).timeout
	Input.action_release(&"move_right")
	assert(journey.player.position.x > start_x + 20, "Hero must respond to movement after menu entry")
	assert(journey.room_index == 0 and journey.player.get_current_health() == 100)
	journey.player.position = journey.EXIT_POSITION
	assert(journey.try_exit() and journey.room_index == 1)
	assert(first_test_store.get_snapshot().room_index == 1)
	assert(FileAccess.get_file_as_bytes(SAVE) == saved_story, "Playing the test must leave the official slot unchanged")
	journey._load_layout(17, true)
	journey.set_physics_process(false)
	journey.player.set_physics_process(false)
	for enemy in journey.living_enemies():
		enemy.set_physics_process(false)
	await capture("chapter2_playable_art")
	journey.return_to_menu()
	await process_frame
	await process_frame
	main = current_scene
	assert(main.scene_file_path.ends_with("Main.tscn"))
	assert(main.continue_save_path == SAVE and main._continue_store.can_resume())
	main._show_start_screen(false)
	assert(main._chapter2_menu_button.is_visible_in_tree())
	main._chapter2_menu_button.pressed.emit()
	await process_frame
	await process_frame
	journey = current_scene
	assert(not paused, "Restarting a test must resume gameplay physics")
	assert(journey.room_index == 0 and journey.player.get_current_health() == 100)
	assert(journey.checkpoint_store != first_test_store and journey.checkpoint_store.get_snapshot().room_index == 0)
	journey.return_to_menu()
	await process_frame
	await process_frame
	main = current_scene
	assert(FileAccess.get_file_as_bytes(SAVE) == saved_story, "Returning from the test must leave the official slot unchanged")
	assert(main._continue_button.is_visible_in_tree())
	main._continue_button.pressed.emit()
	assert(not paused and main.get_run_seed() == SEED and main._current_room_index == 0)
	assert(main.player.get_current_health() == 67 and main._gold == 81)
	assert(main.player.get_run_upgrade_count(&"tempered_edge") == 1)
	main.queue_free()
	await process_frame
	assert(store.clear_snapshot() == OK)
	print("chapter2_game_entry_smoke: PASS")
	quit()
