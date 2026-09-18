extends SceneTree

func _initialize() -> void:
	call_deferred("run_test")

func settle_frames() -> void:
	for i in range(5):
		await process_frame

func run_test() -> void:
	for victory in [false, true]:
		var main = load("res://scenes/Main.tscn").instantiate()
		main.save_enabled = false
		root.add_child(main)
		current_scene = main
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
		main._advance_to_next_room()
		await settle_frames()
		var journey = current_scene
		assert(journey.scene_file_path.ends_with("Chapter2Journey.tscn"))
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
		# Recreate from a real JSON checkpoint, retaining only the run services.
		var checkpoint_path := "D:/Godot/RoguePlatformer-game/test_output/campaign_resume.json"
		var store = load("res://scripts/chapter2_continue_store.gd").new(checkpoint_path)
		assert(store.save_snapshot(journey._snapshot()) == OK)
		var runtime: Dictionary = journey.campaign_runtime
		journey.queue_free()
		await process_frame
		set_meta(&"campaign_runtime", runtime)
		journey = load("res://scenes/Chapter2Journey.tscn").instantiate()
		journey.save_path = checkpoint_path
		# Use disk loading but keep progression and telemetry writes disabled.
		runtime.save_enabled = true
		root.add_child(journey)
		current_scene = journey
		runtime.save_enabled = false
		journey.persistence_enabled = false
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
		if victory:
			var banked: int = progression.get_meta_shards()
			main._finish_campaign_run()
			assert(progression.get_meta_shards() == banked, "Settlement must be idempotent")
		else:
			main._finish_death_sequence(main._run_generation)
			assert(main._current_room_index == 0 and main._lives_remaining == 1)
		main.queue_free()
		await process_frame
		store.clear_snapshot()
		paused = false
	print("chapter2_campaign_smoke: PASS")
	quit()
