extends SceneTree

func _initialize() -> void:
	call_deferred("run_test")

func run_test() -> void:
	var scene = load("res://scenes/Chapter2Journey.tscn").instantiate()
	scene.persistence_enabled = false
	root.add_child(scene)
	await create_timer(1.7).timeout
	# In-memory settings only: never overwrite the user's bindings.
	scene.input_settings._bindings["attack"] = [KEY_U]
	scene.input_settings._bindings["restart"] = [KEY_T]
	scene.input_settings.apply()
	assert(scene._gameplay_prompt().contains("U 攻击"))
	assert(scene._journey_prompt().contains("T 重试"))
	var event := InputEventJoypadButton.new()
	event.button_index = JOY_BUTTON_START
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	assert(scene.paused and not scene.player.is_physics_processing())
	assert(scene.using_controller and scene._journey_prompt().contains("Menu 暂停"))
	assert(ThemeDB.fallback_font.get_string_size(scene._gameplay_prompt(), HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x < 1212, "Controller hints must fit the HUD")
	var elapsed: float = scene.elapsed
	var position: Vector2 = scene.player.position
	await create_timer(0.2).timeout
	assert(scene.elapsed == elapsed and scene.player.position == position)
	event.pressed = false
	Input.parse_input_event(event)
	await process_frame
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	assert(not scene.paused and scene.player.is_physics_processing())
	event.pressed = false
	Input.parse_input_event(event)
	scene.route_complete = true
	assert(not scene._objective_text().contains("F2"))
	if "capture" in OS.get_cmdline_user_args():
		root.size = Vector2i(1280, 720)
		root.content_scale_size = Vector2i(1280, 720)
		scene.queue_redraw()
		await RenderingServer.frame_post_draw
		var error := root.get_texture().get_image().save_png("res://test_output/chapter2_controls_audit.png")
		assert(error == OK)
	scene.queue_free()
	await process_frame
	load("res://scripts/settings_store.gd").new().apply()
	print("chapter2_controls_smoke: PASS")
	quit()
