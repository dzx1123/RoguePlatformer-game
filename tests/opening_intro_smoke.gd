extends SceneTree

const OPENING_INTRO_SCRIPT := preload("res://scripts/opening_intro.gd")


func _init() -> void:
	_run_test()


func _run_test() -> void:
	for action_name: StringName in [&"attack", &"jump", &"interact", &"ui_accept", &"ui_cancel", &"pause"]:
		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name)

	var intro: Control = OPENING_INTRO_SCRIPT.new() as Control
	root.add_child(intro)
	await process_frame
	if intro.visible or bool(intro.call(&"is_playing")):
		_fail("Opening intro should start hidden")
		return
	var full_duration: float = float(intro.call(&"get_duration"))
	if absf(full_duration - 5.60) > 0.001 or full_duration > 6.01:
		_fail("Opening intro duration must stay inside 5–6 seconds")
		return
	var kicker := intro.get_node_or_null("Kicker") as Label
	var title := intro.get_node_or_null("Title") as Label
	var subtitle := intro.get_node_or_null("Subtitle") as Label
	if kicker == null or kicker.text != "踏入月夜 · 循回不息":
		_fail("Opening intro lost the title kicker")
		return
	if title == null or title.text != "月蚀回廊":
		_fail("Opening intro lost the game title")
		return
	if subtitle == null or subtitle.text != "二十房月桥 · 肉鸽动作":
		_fail("Opening intro lost the corridor subtitle")
		return

	intro.call(&"play", true)
	if not bool(intro.call(&"is_playing")) or not intro.visible:
		_fail("Reduced opening intro did not start")
		return
	await create_timer(1.05).timeout
	if bool(intro.call(&"is_playing")) or intro.visible:
		_fail("Reduced opening intro did not finish on its own")
		return

	intro.call(&"play", false)
	if absf(float(intro.call(&"get_duration")) - full_duration) > 0.001:
		_fail("Full opening intro reported the wrong duration")
		return
	intro.call(&"skip")
	await process_frame
	if bool(intro.call(&"is_playing")) or intro.visible:
		_fail("Opening intro skip did not end the sequence")
		return

	print("opening_intro_smoke: PASS")
	quit(0)


func _fail(message: String) -> void:
	print("opening_intro_smoke: FAIL: ", message)
	push_error(message)
	quit(1)
