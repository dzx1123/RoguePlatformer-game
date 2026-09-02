extends SceneTree

const OUTPUT_DIR := "res://tests/artifacts/resolution-matrix"
const TEST_SIZES: Array[Vector2i] = [
	Vector2i(1280, 840),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
]


func _initialize() -> void:
	call_deferred(&"_capture_matrix")


func _capture_matrix() -> void:
	var output_absolute: String = ProjectSettings.globalize_path(OUTPUT_DIR)
	var directory_error: Error = DirAccess.make_dir_recursive_absolute(output_absolute)
	if directory_error != OK:
		_fail("Could not create resolution capture directory")
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	var scene: PackedScene = load("res://scenes/Main.tscn")
	var main: Node2D = scene.instantiate() as Node2D
	main.set("save_enabled", false)
	root.add_child(main)
	await _wait_frames(20)
	var report_entries: Array[Dictionary] = []
	for window_size: Vector2i in TEST_SIZES:
		DisplayServer.window_set_size(window_size)
		await _wait_frames(12)
		var gameplay_entry: Dictionary = await _save_capture(
			"gameplay",
			window_size
		)
		if gameplay_entry.is_empty():
			return
		report_entries.append(gameplay_entry)
		var settings_overlay: Control = main.get_node("HUD/SettingsMenu") as Control
		settings_overlay.visible = true
		await _wait_frames(5)
		var settings_entry: Dictionary = await _save_capture(
			"settings",
			window_size
		)
		if settings_entry.is_empty():
			return
		report_entries.append(settings_entry)
		settings_overlay.visible = false
		await _wait_frames(3)
	if not _write_report(report_entries):
		return
	main.queue_free()
	print("capture_resolution_matrix: PASS captures=%d" % report_entries.size())
	quit(0)


func _save_capture(mode_name: String, requested_size: Vector2i) -> Dictionary:
	RenderingServer.force_draw(false)
	await process_frame
	var image: Image = root.get_texture().get_image()
	if image == null or image.is_empty():
		_fail("Renderer returned an empty image for %s %s" % [mode_name, requested_size])
		return {}
	var file_name := "%s_%dx%d.png" % [mode_name, requested_size.x, requested_size.y]
	var relative_path := "%s/%s" % [OUTPUT_DIR, file_name]
	var save_error: Error = image.save_png(ProjectSettings.globalize_path(relative_path))
	if save_error != OK:
		_fail("Could not save %s: %s" % [file_name, error_string(save_error)])
		return {}
	return {
		"mode": mode_name,
		"requested_width": requested_size.x,
		"requested_height": requested_size.y,
		"capture_width": image.get_width(),
		"capture_height": image.get_height(),
		"path": relative_path,
	}


func _write_report(entries: Array[Dictionary]) -> bool:
	var report_path := "%s/report.json" % OUTPUT_DIR
	var report_file := FileAccess.open(report_path, FileAccess.WRITE)
	if report_file == null:
		_fail("Could not open resolution report for writing")
		return false
	report_file.store_string(JSON.stringify({
		"design_size": [1280, 840],
		"stretch_mode": "canvas_items",
		"stretch_aspect": "keep",
		"captures": entries,
	}, "\t"))
	report_file.close()
	return true


func _wait_frames(frame_count: int) -> void:
	for _frame_index: int in range(frame_count):
		await process_frame


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
