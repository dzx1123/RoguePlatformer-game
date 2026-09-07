extends SceneTree

const SETTINGS_STORE := preload("res://scripts/settings_store.gd")
const SAVE_PATH := "res://tests/display_settings_runtime_smoke_temp.json"
const REPORT_PATH := "res://tests/artifacts/display-settings/report.json"
const RECOVERY_SCREENSHOT_PATH := "res://tests/artifacts/display-settings/recovered.png"
const FOCUS_RECOVERY_SCREENSHOT_PATH := "res://tests/artifacts/display-settings/focus-recovered.png"
const RESTORED_SIZE := Vector2i(1280, 720)

var _minimized_mode: int = -1
var _restored_size := Vector2i.ZERO
var _render_size := Vector2i.ZERO
var _focus_recovered: bool = false
var _audio_recovered: bool = false
var _input_recovered: bool = false
var _external_focus_checked: bool = false
var _awaiting_external_focus: bool = false
var _focus_out_seen: bool = false
var _focus_in_recovered: bool = false
var _external_focus_mode: int = -1
var _focus_render_size := Vector2i.ZERO


func _initialize() -> void:
	call_deferred(&"_run_test")


func _notification(what: int) -> void:
	if not _awaiting_external_focus:
		return
	if what == MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT:
		_focus_out_seen = true
	elif what == MainLoop.NOTIFICATION_APPLICATION_FOCUS_IN and _focus_out_seen:
		_focus_in_recovered = true


func _run_test() -> void:
	if DisplayServer.get_name() == "headless":
		var headless_store = SETTINGS_STORE.new(SAVE_PATH)
		if headless_store.can_apply_display():
			_fail("Headless display server incorrectly accepted window control")
			return
		print("display_settings_runtime_smoke: PASS headless guard")
		quit(0)
		return
	if Engine.is_embedded_in_editor():
		_fail("Display settings runtime test must run outside editor embedding")
		return
	_cleanup()
	var store = SETTINGS_STORE.new(SAVE_PATH)
	store.set_fullscreen_enabled(false)
	store.set_resolution_index(1)
	store.apply_display()
	await _wait_frames(8)
	var windowed_size: Vector2i = DisplayServer.window_get_size()
	if windowed_size != Vector2i(1600, 900):
		_fail("Window resolution was not applied: %s" % windowed_size)
		return

	store.set_fullscreen_enabled(true)
	store.apply_display()
	await _wait_frames(12)
	var fullscreen_mode: int = DisplayServer.window_get_mode()
	if fullscreen_mode not in [
		DisplayServer.WINDOW_MODE_FULLSCREEN,
		DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN,
	]:
		_fail("Fullscreen mode was not applied: %d" % fullscreen_mode)
		return

	store.set_fullscreen_enabled(false)
	store.set_resolution_index(0)
	store.apply_display()
	await _wait_frames(8)
	if DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_WINDOWED:
		_fail("Windowed mode was not restored")
		return
	_restored_size = DisplayServer.window_get_size()
	if _restored_size != RESTORED_SIZE:
		_fail("Restored window size was incorrect: %s" % _restored_size)
		return
	var recovery_succeeded: bool = await _exercise_minimize_recovery()
	if not recovery_succeeded:
		return
	_write_report(true, "", windowed_size, fullscreen_mode)
	_cleanup()
	print("display_settings_runtime_smoke: PASS")
	quit(0)


func _exercise_minimize_recovery() -> bool:
	var main_scene := load("res://scenes/Main.tscn") as PackedScene
	var main := main_scene.instantiate() as Node2D
	main.set("save_enabled", false)
	root.add_child(main)
	await physics_frame
	await _wait_frames(20)
	main.call(&"_pause_game")
	await _wait_frames(3)
	var pause_overlay := main.get_node("HUD/PauseMenu") as Control
	var resume_button := pause_overlay.get_node("Resume") as Button
	if not paused or not pause_overlay.visible or root.gui_get_focus_owner() != resume_button:
		_fail("Pause state was not ready before minimizing")
		return false
	var soundscape := main.get("_soundscape") as Node
	var generator_player := soundscape.get("_player") as AudioStreamPlayer
	var bgm_player := soundscape.get("_bgm_player") as AudioStreamPlayer
	var music_time_before: float = float(soundscape.get("_music_time"))
	if not generator_player.playing or not bgm_player.playing:
		_fail("Music playback was not active before minimizing")
		return false

	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED)
	await _wait_frames(12)
	_minimized_mode = DisplayServer.window_get_mode()
	if _minimized_mode != DisplayServer.WINDOW_MODE_MINIMIZED:
		_fail("Window did not enter minimized mode: %d" % _minimized_mode)
		return false

	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(RESTORED_SIZE)
	await _wait_frames(12)
	_restored_size = DisplayServer.window_get_size()
	if DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_WINDOWED:
		_fail("Windowed mode was not restored after minimizing")
		return false
	if _restored_size != RESTORED_SIZE:
		_fail("Window size changed after minimizing: %s" % _restored_size)
		return false

	RenderingServer.force_draw(false)
	await process_frame
	var image: Image = root.get_texture().get_image()
	if image == null or image.is_empty():
		_fail("Renderer returned an empty frame after restoring the window")
		return false
	_render_size = Vector2i(image.get_width(), image.get_height())
	if _render_size != RESTORED_SIZE:
		_fail("Restored frame size was incorrect: %s" % _render_size)
		return false
	var artifact_directory_error: Error = DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(RECOVERY_SCREENSHOT_PATH.get_base_dir())
	)
	if artifact_directory_error != OK:
		_fail("Could not create the display-settings artifact directory")
		return false
	var screenshot_error: Error = image.save_png(
		ProjectSettings.globalize_path(RECOVERY_SCREENSHOT_PATH)
	)
	if screenshot_error != OK:
		_fail("Could not save the restored-window screenshot")
		return false

	_focus_recovered = root.gui_get_focus_owner() == resume_button
	_audio_recovered = (
		generator_player.playing
		and bgm_player.playing
		and float(soundscape.get("_music_time")) > music_time_before
	)
	if not _focus_recovered:
		_fail("Pause-menu focus was lost after restoring the window")
		return false
	if not _audio_recovered:
		_fail("Music processing did not recover after restoring the window")
		return false
	if OS.get_cmdline_user_args().has("--external-focus-probe"):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		await _wait_frames(12)
		_external_focus_mode = DisplayServer.window_get_mode()
		if _external_focus_mode not in [
			DisplayServer.WINDOW_MODE_FULLSCREEN,
			DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN,
		]:
			_fail("Fullscreen mode was not ready for the external focus cycle")
			return false
		var external_focus_succeeded: bool = await _exercise_external_focus_cycle(
			resume_button,
			soundscape
		)
		if not external_focus_succeeded:
			return false
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(RESTORED_SIZE)
		await _wait_frames(12)
		if (
			DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_WINDOWED
			or DisplayServer.window_get_size() != RESTORED_SIZE
		):
			_fail("Windowed mode was not restored after the external focus cycle")
			return false

	var enter_pressed := InputEventKey.new()
	enter_pressed.keycode = KEY_ENTER
	enter_pressed.pressed = true
	Input.parse_input_event(enter_pressed)
	await process_frame
	var enter_released := InputEventKey.new()
	enter_released.keycode = KEY_ENTER
	enter_released.pressed = false
	Input.parse_input_event(enter_released)
	await process_frame
	_input_recovered = not paused and not pause_overlay.visible
	if not _input_recovered:
		_fail("Focused input did not resume gameplay after restoring the window")
		return false
	main.queue_free()
	await process_frame
	return true


func _exercise_external_focus_cycle(resume_button: Button, soundscape: Node) -> bool:
	_external_focus_checked = true
	_awaiting_external_focus = true
	var expected_frame_size: Vector2i = DisplayServer.window_get_size()
	var generator_player := soundscape.get("_player") as AudioStreamPlayer
	var bgm_player := soundscape.get("_bgm_player") as AudioStreamPlayer
	var music_time_before: float = float(soundscape.get("_music_time"))
	print("display_settings_runtime_smoke: FOCUS_PROBE_READY")
	var deadline_msec: int = Time.get_ticks_msec() + 20000
	while not _focus_in_recovered and Time.get_ticks_msec() < deadline_msec:
		await process_frame
	_awaiting_external_focus = false
	if not _focus_out_seen or not _focus_in_recovered:
		_fail("External focus-out/focus-in notifications were not both received")
		return false
	if DisplayServer.window_get_mode() != _external_focus_mode:
		_fail("Fullscreen mode changed during the external focus cycle")
		return false
	if root.gui_get_focus_owner() != resume_button:
		_fail("Pause-menu focus was lost after the external focus cycle")
		return false
	if (
		not generator_player.playing
		or not bgm_player.playing
		or float(soundscape.get("_music_time")) <= music_time_before
	):
		_fail("Music processing stopped during the external focus cycle")
		return false
	RenderingServer.force_draw(false)
	await process_frame
	var image: Image = root.get_texture().get_image()
	if image == null or image.is_empty():
		_fail("Renderer returned an empty frame after the external focus cycle")
		return false
	_focus_render_size = Vector2i(image.get_width(), image.get_height())
	if _focus_render_size != expected_frame_size:
		_fail("Frame size changed after the external focus cycle")
		return false
	var screenshot_error: Error = image.save_png(
		ProjectSettings.globalize_path(FOCUS_RECOVERY_SCREENSHOT_PATH)
	)
	if screenshot_error != OK:
		_fail("Could not save the external-focus recovery screenshot")
		return false
	return true


func _wait_frames(frame_count: int) -> void:
	for _frame_index: int in range(frame_count):
		await process_frame


func _cleanup() -> void:
	for path: String in [SAVE_PATH, SAVE_PATH + ".tmp", SAVE_PATH + ".bak"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _fail(message: String) -> void:
	if paused:
		paused = false
	_write_report(false, message, DisplayServer.window_get_size(), DisplayServer.window_get_mode())
	_cleanup()
	push_error(message)
	quit(1)


func _write_report(
	success: bool,
	failure: String,
	windowed_size: Vector2i,
	fullscreen_mode: int
) -> void:
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(REPORT_PATH.get_base_dir())
	)
	var report := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if report == null:
		return
	report.store_string(JSON.stringify({
		"success": success,
		"failure": failure,
		"windowed_size": [windowed_size.x, windowed_size.y],
		"fullscreen_mode": fullscreen_mode,
		"minimized_mode": _minimized_mode,
		"restored_size": [_restored_size.x, _restored_size.y],
		"render_size": [_render_size.x, _render_size.y],
		"focus_recovered": _focus_recovered,
		"audio_recovered": _audio_recovered,
		"input_recovered": _input_recovered,
		"external_focus_checked": _external_focus_checked,
		"focus_out_seen": _focus_out_seen,
		"focus_in_recovered": _focus_in_recovered,
		"external_focus_mode": _external_focus_mode,
		"focus_render_size": [_focus_render_size.x, _focus_render_size.y],
		"recovery_screenshot": RECOVERY_SCREENSHOT_PATH,
		"focus_recovery_screenshot": (
			FOCUS_RECOVERY_SCREENSHOT_PATH if _external_focus_checked else ""
		),
	}, "\t"))
	report.close()
