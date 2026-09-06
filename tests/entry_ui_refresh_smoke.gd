extends SceneTree

const UI := preload("res://scripts/ui_theme.gd")

func _initialize() -> void:
	call_deferred(&"_run")

func _run() -> void:
	var main := (load("res://scenes/Main.tscn") as PackedScene).instantiate() as Node2D
	main.set("save_enabled", false)
	root.add_child(main)
	await process_frame
	# This store has persistence disabled by main.save_enabled=false.
	main.call(&"_clear_continue_snapshot")
	main.call(&"_show_start_screen")
	await create_timer(0.65).timeout
	var entry: Control = main.get_node("HUD/EntryFlow")
	var start: Button = entry.get_node("StartGame")
	var resume: Button = entry.get_node("ContinueRun")
	var back: Button = entry.get_node("DifficultyBack")
	var profile: Panel = entry.get_node("ProfileSummary")
	var fade: TextureRect = entry.get_node("BottomGradient")
	if resume.visible or start.text != "开启新局" or root.gui_get_focus_owner() != start:
		return _fail("Fresh entry must focus new game without a continue button")
	if profile.position != Vector2(48, 616) or profile.size != Vector2(1184, 88):
		return _fail("Entry gradient and low-priority bottom progression rail differ from U2")
	if (entry.get_node("EntryFrame") as Control).visible or back.visible:
		return _fail("Legacy entry box or difficulty-only return button leaked into title")
	for index in range(3):
		if not profile.has_node("Weapon_%d/Name" % index):
			return _fail("The real three-weapon progression chips were not built")

	# Generate a real in-memory run snapshot, then check the continue hierarchy.
	main.call(&"_start_game_with_difficulty", 0)
	main.call(&"persist_continue_snapshot_for_test")
	main.call(&"_show_start_screen")
	await create_timer(0.65).timeout
	if not resume.visible or resume.text != "继续旅程" or root.gui_get_focus_owner() != resume:
		return _fail("Saved entry must prioritize Continue Journey")
	if resume.position.y >= start.position.y or resume.size.y <= start.size.y:
		return _fail("Continue and New Game do not have the specified primary/secondary hierarchy")
	if not (resume.get_theme_stylebox("focus") as StyleBoxFlat).border_color.is_equal_approx(UI.ACCENT_GOLD):
		return _fail("Continue focus is not the gold primary action")
	main.call(&"_show_difficulty_selection")
	await create_timer(0.5).timeout
	var cards: Array = main.get("_difficulty_buttons")
	if not back.visible or profile.visible or root.gui_get_focus_owner() != cards[0]:
		return _fail("Difficulty must expose return, hide progression and establish one focus")
	for reduced in [false, true]:
		(main.get("_settings") as RefCounted).set("_reduced_effects_enabled", reduced)
		main.call(&"_show_difficulty_selection")
		await create_timer(0.5).timeout
		(cards[1] as Button).grab_focus()
		await create_timer(0.2).timeout
		for index in range(3):
			var card: Button = cards[index]
			var face: Panel = card.get_node("CardFace")
			var expected_y: float = -6.0 if index == 1 and not reduced else 0.0
			if not is_equal_approx(face.position.y, expected_y) or card.scale != Vector2.ONE:
				return _fail("Difficulty focus violates six-pixel lift / reduced-motion contract")
			for label_name in ["Name", "Consequence", "Growth"]:
				var label: Label = face.get_node(label_name)
				if not Rect2(Vector2.ZERO, face.size).encloses(label.get_rect()):
					return _fail("Difficulty card text overflowed its visual face")
			if card.get_node(card.focus_neighbor_bottom) != back:
				return _fail("D-pad down cannot reach the explicit return button")
	back.emit_signal("pressed")
	await process_frame
	if back.visible or not resume.visible or not paused:
		return _fail("Return button lost the saved run or resumed background gameplay")
	main.call(&"_show_difficulty_selection")
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	Input.parse_input_event(escape)
	await process_frame
	escape.pressed = false
	Input.parse_input_event(escape)
	await process_frame
	if back.visible:
		return _fail("Escape did not return from difficulty")
	main.queue_free()
	await process_frame
	await process_frame
	print("entry_ui_refresh_smoke: PASS")
	quit(0)

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
