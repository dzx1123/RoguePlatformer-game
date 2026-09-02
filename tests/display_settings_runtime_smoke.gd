extends SceneTree

const SETTINGS_STORE := preload("res://scripts/settings_store.gd")
const SAVE_PATH := "res://tests/display_settings_runtime_smoke_temp.json"
const REPORT_PATH := "res://tests/artifacts/display-settings/report.json"


func _initialize() -> void:
	call_deferred(&"_run_test")


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
	_write_report(true, "", windowed_size, fullscreen_mode)
	_cleanup()
	print("display_settings_runtime_smoke: PASS")
	quit(0)


func _wait_frames(frame_count: int) -> void:
	for _frame_index: int in range(frame_count):
		await process_frame


func _cleanup() -> void:
	for path: String in [SAVE_PATH, SAVE_PATH + ".tmp", SAVE_PATH + ".bak"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _fail(message: String) -> void:
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
	}, "\t"))
	report.close()
