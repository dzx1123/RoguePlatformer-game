extends SceneTree

const WINDOW_SIZE := Vector2i(1280, 840)

var _original_mode: int
var _original_size: Vector2i
var _original_vsync: int


func _initialize() -> void:
	call_deferred(&"_run_test")


func _run_test() -> void:
	_original_mode = DisplayServer.window_get_mode()
	_original_size = DisplayServer.window_get_size()
	_original_vsync = DisplayServer.window_get_vsync_mode()

	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(WINDOW_SIZE)
	await _wait_frames(8)
	if DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_WINDOWED:
		_fail("Windowed mode was not applied")
		return
	var applied_size: Vector2i = DisplayServer.window_get_size()
	if applied_size.x < WINDOW_SIZE.x or applied_size.y < WINDOW_SIZE.y:
		_fail("Window size was smaller than the requested HUD contract")
		return

	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	await _wait_frames(8)
	if DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_FULLSCREEN:
		_fail("Fullscreen mode was not applied")
		return

	_restore_window()
	print("window_mode_smoke: PASS")
	quit(0)


func _restore_window() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(_original_size)
	DisplayServer.window_set_vsync_mode(_original_vsync)
	DisplayServer.window_set_mode(_original_mode)


func _wait_frames(frame_count: int) -> void:
	for _frame_index: int in range(frame_count):
		await process_frame


func _fail(message: String) -> void:
	_restore_window()
	push_error(message)
	quit(1)
