extends SceneTree

const SETTINGS_STORE := preload("res://scripts/settings_store.gd")
const UI := preload("res://scripts/ui_theme.gd")
const SAVE_PATH := "res://tests/accessibility_settings_smoke_temp.json"


func _initialize() -> void:
	call_deferred(&"_run_test")


func _run_test() -> void:
	_cleanup()
	var settings = SETTINGS_STORE.new(SAVE_PATH)
	settings.set_reduced_effects_enabled(true)
	settings.set_large_text_enabled(true)
	settings.set_high_contrast_enabled(true)
	settings.set_color_blind_enabled(true)
	settings.set_hud_scale_index(2)
	var main_scene: PackedScene = load("res://scenes/Main.tscn")
	var main: Node2D = main_scene.instantiate() as Node2D
	main.set("save_enabled", false)
	root.add_child(main)
	await physics_frame
	main.set("_settings", settings)
	main.call(&"_apply_accessibility_presentation")
	var player: RoguePlayer = main.get_node("Player") as RoguePlayer
	player.set_reduced_effects_enabled(true)
	main.set("_camera_shake_strength", 0.0)
	main.set("_camera_shake_duration", 0.0)
	main.call(&"_trigger_camera_shake", 8.0, 0.20)
	if (
		float(main.get("_camera_shake_strength")) > 2.01
		or float(main.get("_camera_shake_duration")) > 0.141
		or not player.get_reduced_effects_enabled()
	):
		return _fail("Reduced-effects mode did not limit shake and player flashes")
	var room_label: Label = main.get_node("HUD/RoomProgress") as Label
	if room_label == null:
		return _fail("RoomProgress label missing for accessibility checks")
	var room_font_size: int = room_label.get_theme_font_size("font_size")
	if room_font_size < 15:
		return _fail("Large-text mode did not bump RoomProgress font_size (>=15), got %d" % room_font_size)
	var room_color: Color = room_label.get_theme_color("font_color")
	var primary: Color = UI.TEXT_PRIMARY
	if (
		absf(room_color.r - primary.r) > 0.08
		or absf(room_color.g - primary.g) > 0.08
		or absf(room_color.b - primary.b) > 0.08
	):
		return _fail(
			"High-contrast mode did not set RoomProgress near TEXT_PRIMARY, got %s" % str(room_color)
		)
	var health_background := main.get_node("HUD/HealthBackground") as Control
	var health_fill := main.get_node("HUD/HealthBackground/HealthFill") as ColorRect
	if absf(health_background.scale.x - 1.10) > 0.001:
		return _fail("HUD scale was not applied at 110%%: %s" % str(health_background.scale))
	var accessible_health := Color("#4cc9ff")
	if (
		absf(health_fill.color.r - accessible_health.r) > 0.02
		or absf(health_fill.color.g - accessible_health.g) > 0.02
		or absf(health_fill.color.b - accessible_health.b) > 0.02
	):
		return _fail("Color-vision palette did not reach the health bar: %s" % str(health_fill.color))
	# Idempotency: re-apply must not compound font sizes.
	main.call(&"_apply_accessibility_presentation")
	if room_label.get_theme_font_size("font_size") != room_font_size:
		return _fail("Accessibility apply compounded RoomProgress font_size")
	if absf(health_background.scale.x - 1.10) > 0.001:
		return _fail("Accessibility apply compounded HUD scale")
	main.queue_free()
	await process_frame
	_cleanup()
	print("accessibility_settings_smoke: PASS")
	quit(0)


func _cleanup() -> void:
	for path: String in [SAVE_PATH, SAVE_PATH + ".tmp", SAVE_PATH + ".bak"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _fail(message: String) -> void:
	_cleanup()
	push_error(message)
	quit(1)
