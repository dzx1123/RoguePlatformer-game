extends SceneTree

const SETTINGS_STORE := preload("res://scripts/settings_store.gd")
const OUTPUT_DIR := "res://tests/artifacts/accessibility-matrix"
const SAVE_PATH := "res://tests/accessibility_matrix_temp.json"
const WINDOW_SIZE := Vector2i(1280, 720)
const SCENARIOS: Array[Dictionary] = [
	{
		"name": "hud_90_default",
		"hud_scale_index": 0,
		"large_text": false,
		"high_contrast": false,
		"color_blind": false,
		"reduced_effects": false,
	},
	{
		"name": "hud_100_default",
		"hud_scale_index": 1,
		"large_text": false,
		"high_contrast": false,
		"color_blind": false,
		"reduced_effects": false,
	},
	{
		"name": "hud_110_default",
		"hud_scale_index": 2,
		"large_text": false,
		"high_contrast": false,
		"color_blind": false,
		"reduced_effects": false,
	},
	{
		"name": "hud_110_large_text",
		"hud_scale_index": 2,
		"large_text": true,
		"high_contrast": false,
		"color_blind": false,
		"reduced_effects": false,
	},
	{
		"name": "hud_110_all_accessibility",
		"hud_scale_index": 2,
		"large_text": true,
		"high_contrast": true,
		"color_blind": true,
		"reduced_effects": true,
	},
]


func _initialize() -> void:
	call_deferred(&"_capture_matrix")


func _capture_matrix() -> void:
	if DisplayServer.get_name() == "headless":
		_fail("Accessibility screenshots require a non-headless display server")
		return
	_cleanup()
	var output_absolute: String = ProjectSettings.globalize_path(OUTPUT_DIR)
	var directory_error: Error = DirAccess.make_dir_recursive_absolute(output_absolute)
	if directory_error != OK:
		_fail("Could not create the accessibility capture directory")
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(WINDOW_SIZE)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	root.content_scale_size = WINDOW_SIZE
	var main_scene := load("res://scenes/Main.tscn") as PackedScene
	var main := main_scene.instantiate() as Node2D
	main.set("save_enabled", false)
	root.add_child(main)
	await physics_frame
	await _wait_frames(16)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(WINDOW_SIZE)
	await _wait_frames(8)

	var settings = SETTINGS_STORE.new(SAVE_PATH)
	main.set("_settings", settings)
	var entries: Array[Dictionary] = []
	for scenario: Dictionary in SCENARIOS:
		settings.set_hud_scale_index(int(scenario["hud_scale_index"]))
		settings.set_large_text_enabled(bool(scenario["large_text"]))
		settings.set_high_contrast_enabled(bool(scenario["high_contrast"]))
		settings.set_color_blind_enabled(bool(scenario["color_blind"]))
		settings.set_reduced_effects_enabled(bool(scenario["reduced_effects"]))
		main.call(&"_apply_accessibility_presentation")
		await _wait_frames(4)
		RenderingServer.force_draw(false)
		await process_frame
		var image: Image = root.get_texture().get_image()
		if image == null or image.is_empty():
			_fail("Renderer returned an empty image for %s" % String(scenario["name"]))
			return
		if Vector2i(image.get_width(), image.get_height()) != WINDOW_SIZE:
			_fail("Capture size was incorrect for %s" % String(scenario["name"]))
			return
		var relative_path := "%s/%s.png" % [OUTPUT_DIR, String(scenario["name"])]
		var save_error: Error = image.save_png(ProjectSettings.globalize_path(relative_path))
		if save_error != OK:
			_fail("Could not save %s" % relative_path)
			return
		var room_label := main.get_node("HUD/RoomProgress") as Label
		var health_background := main.get_node("HUD/HealthBackground") as Control
		var health_fill := main.get_node("HUD/HealthBackground/HealthFill") as ColorRect
		entries.append({
			"name": scenario["name"],
			"path": relative_path,
			"capture_size": [image.get_width(), image.get_height()],
			"hud_scale_index": scenario["hud_scale_index"],
			"large_text": scenario["large_text"],
			"high_contrast": scenario["high_contrast"],
			"color_blind": scenario["color_blind"],
			"reduced_effects": scenario["reduced_effects"],
			"applied_health_scale": health_background.scale.x,
			"room_font_size": room_label.get_theme_font_size("font_size"),
			"room_color": room_label.get_theme_color("font_color").to_html(),
			"health_color": health_fill.color.to_html(),
		})
	if not _write_report(entries):
		return
	main.queue_free()
	await process_frame
	_cleanup()
	print("capture_accessibility_matrix: PASS captures=%d" % entries.size())
	quit(0)


func _write_report(entries: Array[Dictionary]) -> bool:
	var report_path := "%s/report.json" % OUTPUT_DIR
	var report := FileAccess.open(report_path, FileAccess.WRITE)
	if report == null:
		_fail("Could not open the accessibility report for writing")
		return false
	report.store_string(JSON.stringify({
		"window_size": [WINDOW_SIZE.x, WINDOW_SIZE.y],
		"captures": entries,
	}, "\t"))
	report.close()
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
	_cleanup()
	push_error(message)
	quit(1)
