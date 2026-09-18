extends SceneTree

const SAVE := "D:/Godot/RoguePlatformer-game/test_output/chapter2_game_entry.json"

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
	var store = load("res://scripts/chapter2_continue_store.gd").new(SAVE + ".test")
	store.clear_snapshot()
	var main = load("res://scenes/Main.tscn").instantiate()
	main.save_enabled = false
	main.chapter2_save_path = SAVE
	root.add_child(main)
	current_scene = main
	main._show_start_screen(false)
	assert(main._chapter2_menu_button.visible)
	main._show_difficulty_selection()
	assert(not main._chapter2_menu_button.visible)
	main._show_start_screen(false)
	await capture("chapter2_direct_menu")
	main._chapter2_menu_button.pressed.emit()
	await process_frame
	await process_frame
	var journey = current_scene
	assert(journey.scene_file_path.ends_with("Chapter2Journey.tscn"))
	assert(journey.campaign_hud.has_node("BottomHUD"), "Development entry must use chapter-one HUD")
	assert(journey.campaign_presenter.attack_slot.visible and journey.campaign_presenter.skill_slot.visible)
	assert(not journey.return_panel.visible, "Legacy corner button must not replace the shared HUD")
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
	main.chapter2_save_path = SAVE
	main._show_start_screen(false)
	# The development entry resumes its own file without displacing a real run.
	main._chapter2_menu_button.pressed.emit()
	await process_frame
	await process_frame
	journey = current_scene
	assert(not paused, "Continue must resume gameplay physics")
	assert(journey.room_index == 17 and journey.living_enemies().size() == 3)
	assert(store.load_snapshot() and store.get_snapshot().room_index == 17)
	journey.queue_free()
	await process_frame
	store.clear_snapshot()
	print("chapter2_game_entry_smoke: PASS")
	quit()
