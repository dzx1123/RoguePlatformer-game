extends SceneTree

const PREVIEW_SIZE := Vector2i(1280, 720)


func _initialize() -> void:
	call_deferred(&"_capture_preview")


func _capture_preview() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("P7 UI preview requires a rendered compatibility window")
		quit(1)
		return
	root.content_scale_size = PREVIEW_SIZE
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_IGNORE
	root.size = PREVIEW_SIZE
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	var mode: String = "menu"
	var output_path: String = "user://p7_ui_preview.png"
	if not arguments.is_empty():
		mode = String(arguments[0])
	if arguments.size() >= 2:
		output_path = String(arguments[1])

	var main_scene: PackedScene = load("res://scenes/Main.tscn")
	var main: Node2D = main_scene.instantiate() as Node2D
	# Preview fixtures must never clear or overwrite the player's real continue.
	main.set("save_enabled", false)
	root.add_child(main)
	await physics_frame
	await process_frame
	# Saved display preferences must not change the capture contract.
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	root.size = PREVIEW_SIZE

	match mode:
		"menu", "menu_continue":
			if mode == "menu_continue":
				main.call(&"persist_continue_snapshot_for_test")
			else:
				# save_enabled=false constructs RunContinueStore with persistence
				# disabled; clear_snapshot returns before touching any file.
				main.call(&"_clear_continue_snapshot")
			main.call(&"_show_start_screen")
		"death":
			main.call(&"_clear_enemies")
			var preview_player := main.get_node("Player") as RoguePlayer
			preview_player.set("_hurt_invulnerability_remaining", 0.0)
			preview_player.receive_enemy_attack(preview_player.global_position + Vector2(40, 0), 999)
		"pause":
			main.call(&"_pause_game")
		"settings":
			main.call(&"_pause_game")
			main.call(&"_open_settings", true)
		"difficulty":
			main.call(&"_show_difficulty_selection")
		"portal", "upgrade":
			main.call(&"_clear_enemies")
			main.call(&"_on_room_cleared")
			await process_frame
			if mode == "upgrade":
				(main.get_node("Player") as Node2D).global_position = (main.get_node("RoomExitPortal") as Node2D).global_position
				main.call(&"_activate_room_exit")
				await create_timer(0.30).timeout
		"shop", "shop_poor":
			main.set("_gold", 999 if mode == "shop" else 0)
			main.call(&"_show_shop")
		"event":
			main.call(&"_show_event_choice")
		"chest":
			main.call(&"_clear_enemies")
			main.call(&"_spawn_reward_chest")
			await process_frame
			main.call(&"open_current_chest_for_test")
		"victory":
			main.call(&"_complete_run")
		"combat":
			main.call(&"_start_game_with_difficulty", 1)
			await create_timer(0.55).timeout
			main.call(&"_update_room_label")
			main.call(&"_sync_combat_hud_visibility")
		"status":
			main.call(&"_set_status", "清理房间 · 剩余敌人 3")
		"toast":
			main.call(
				&"_present_reward_feedback",
				&"relic",
				"遗物确认",
				"已获得「锋刃磨砺」",
				"攻击伤害 +8",
				Color("#5ED7F2"),
				2.40
			)
			main.call(&"_sync_combat_hud_visibility")
		_:
			pass

	var settle_seconds: float = 0.28 if mode in ["status", "toast", "chest"] else 0.72
	await create_timer(settle_seconds).timeout
	var viewport_texture: Texture2D = root.get_texture()
	if viewport_texture == null:
		push_error("P7 UI preview could not read the rendered viewport")
		quit(1)
		return
	var image: Image = viewport_texture.get_image()
	var save_error: Error = image.save_png(output_path)
	if save_error != OK:
		push_error("Could not save P7 UI preview: %s" % error_string(save_error))
		quit(1)
		return
	print("capture_p7_ui_preview: PASS %s" % output_path)
	# Drain scene-owned tweens, audio and draw resources before renderer shutdown.
	main.queue_free()
	await process_frame
	await process_frame
	quit(0)
