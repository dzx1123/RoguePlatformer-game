extends SceneTree

const CAMPAIGN_STORE := preload("res://scripts/campaign_continue_store.gd")
const SAVE := "res://test_output/chapter2_campaign_official.json"
const PROFILE := "res://test_output/chapter2_campaign_profile.json"

func _initialize() -> void:
	call_deferred("run_test")

func settle_frames() -> void:
	for i in range(5):
		await process_frame

func run_test() -> void:
	for victory in [false, true]:
		var store := CAMPAIGN_STORE.new(SAVE, true, "")
		assert(store.clear_snapshot() == OK)
		assert(SafeJsonStore.remove_dictionary(PROFILE) == OK)
		var main = load("res://scenes/Main.tscn").instantiate()
		main.save_enabled = false
		main.continue_save_path = SAVE
		root.add_child(main)
		current_scene = main
		# Keep the story slot and the profile on disk under test_output. The run's
		# telemetry instance still behaves normally in memory.
		main._continue_store = store
		main._progression = ProgressionStore.new(PROFILE)
		main.save_enabled = true
		main._selected_difficulty = 2
		main._lives_remaining = 2
		main._run_shards = 37
		main._gold = 81
		main.player.apply_run_upgrade(&"tempered_edge")
		main.player.apply_max_health_delta(20)
		main.player.set_current_health(47)
		var progression = main._progression
		var before_runs: int = progression.get_runs_completed()
		var before_shards: int = progression.get_meta_shards()
		var telemetry = main._telemetry
		var seed_value: int = main._run_seed
		main._current_room_index = 19
		main._persist_continue_snapshot()
		assert(store.can_resume() and not store.has_chapter2())
		assert(FileAccess.file_exists(SAVE))
		main._advance_to_next_room()
		await settle_frames()
		var journey = current_scene
		assert(journey.scene_file_path.ends_with("Chapter2Journey.tscn"))
		assert(journey.persistence_enabled and journey.save_path == SAVE)
		assert(journey.checkpoint_store == store and store.has_chapter2())
		assert(not paused and journey.campaign.seed == seed_value)
		assert(journey.campaign.difficulty == 2 and journey.campaign.lives == 2)
		assert(journey.campaign.run_shards == 37 and journey.gold == 81)
		assert(journey.player.get_current_health() == 47 and journey.player.get_max_health() == 120)
		assert(journey.player.get_run_upgrade_count(&"tempered_edge") == 1)
		assert(progression.get_runs_completed() == before_runs and progression.get_meta_shards() == before_shards, "Chapter transition must not settle")
		assert(journey.campaign_runtime.telemetry == telemetry and telemetry.is_run_active())
		await create_timer(1.7).timeout
		var x: float = journey.player.position.x
		Input.action_press(&"move_right")
		await create_timer(0.25).timeout
		Input.action_release(&"move_right")
		assert(journey.player.position.x > x + 20 and journey.player.modulate.a > 0.95)
		journey.player.position = journey.EXIT_POSITION
		assert(journey.try_exit() and journey.room_index == 1)
		# The title reopens the same path from disk and restores the second room
		# of the chapter through the normal Continue action.
		var runtime: Dictionary = journey.campaign_runtime
		journey.return_to_menu()
		await settle_frames()
		main = current_scene
		assert(main.scene_file_path.ends_with("Main.tscn") and main.continue_save_path == SAVE)
		assert(main._continue_store != store and main._continue_store.has_chapter2())
		assert(main._continue_store.get_snapshot().room_index == 1)
		assert(main._continue_button.tooltip_text.contains("第 22 房"))
		set_meta(&"campaign_runtime", runtime)
		main._continue_button.pressed.emit()
		await settle_frames()
		journey = current_scene
		assert(journey.scene_file_path.ends_with("Chapter2Journey.tscn"))
		assert(journey.room_index == 1 and journey.save_path == SAVE and journey.persistence_enabled)
		assert(journey.campaign.seed == seed_value and journey.campaign.lives == 2)
		assert(journey.player.get_current_health() == 47 and journey.gold == 81)
		assert(journey.campaign_hud.has_node("BottomHUD"))
		if "capture" in OS.get_cmdline_user_args() and not victory:
			root.size = Vector2i(1280, 720)
			root.content_scale_size = Vector2i(1280, 720)
			await create_timer(1.7).timeout
			await RenderingServer.frame_post_draw
			var capture_error := root.get_texture().get_image().save_png("res://test_output/chapter2_campaign_hud.png")
			assert(capture_error == OK)
		journey.player.set_current_health(30)
		journey.retry_room()
		assert(journey.player.get_current_health() == 30, "Campaign must not allow free checkpoint healing")
		journey._load_layout(19, true)
		assert(journey.overseer.get_max_health() > 520, "Inherited hard difficulty must affect enemies")
		if victory:
			journey.overseer.receive_player_attack(journey.overseer.position, 1, 99999)
			journey.overseer._physics_process(2)
			await process_frame
			journey.player.position = journey.EXIT_POSITION
			assert(journey.try_exit())
		else:
			journey.player._die(Vector2.ZERO, &"forge_heat")
		await settle_frames()
		main = current_scene
		assert(main.scene_file_path.ends_with("Main.tscn"))
		assert(main._selected_difficulty == 2)
		assert(main._lives_remaining == (2 if victory else 1))
		assert(main._flow_state.run_complete if victory else main._flow_state.death_restart_pending)
		assert(not telemetry.is_run_active())
		assert(progression.get_meta_shards() >= before_shards + 37)
		assert(not FileAccess.file_exists(SAVE), "Run settlement must consume the story slot")
		if victory:
			var banked: int = progression.get_meta_shards()
			main._finish_campaign_run()
			assert(progression.get_meta_shards() == banked, "Settlement must be idempotent")
		else:
			main._finish_death_sequence(main._run_generation)
			assert(main._current_room_index == 0 and main._lives_remaining == 1)
		current_scene = null
		main.queue_free()
		await settle_frames()
		assert(store.clear_snapshot() == OK)
		assert(SafeJsonStore.remove_dictionary(PROFILE) == OK)
		paused = false
	print("chapter2_campaign_smoke: PASS")
	quit()
