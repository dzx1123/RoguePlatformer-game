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
	if health_background.scale.x < 1.05 or health_background.scale.x > 1.101:
		return _fail("HUD 110%% did not enlarge the combat dock: %s" % str(health_background.scale))
	var canvas := Rect2(Vector2.ZERO, Vector2(1280.0, 720.0))
	var vitals := main.get_node("HUD/VitalsPanel") as Control
	var abilities := main.get_node("HUD/AbilityPanel") as Control
	var weapons := main.get_node("HUD/WeaponPanel") as Control
	var ability_bar := main.get_node("HUD/AbilityBar") as Control
	for control: Control in [vitals, abilities, weapons, health_background, ability_bar]:
		if not canvas.encloses(control.get_global_rect().grow(-0.5)):
			return _fail("Scaled HUD left the 1280x720 canvas: %s %s" % [control.name, control.get_global_rect()])
	if vitals.get_global_rect().grow(-0.5).intersects(abilities.get_global_rect().grow(-0.5)):
		return _fail("110%% HUD packed vitals over the ability dock")
	if abilities.get_global_rect().grow(-0.5).intersects(weapons.get_global_rect().grow(-0.5)):
		return _fail("110%% HUD packed abilities over the weapon dock")
	var accessible_health := Color("#4cc9ff")
	if (
		absf(health_fill.color.r - accessible_health.r) > 0.02
		or absf(health_fill.color.g - accessible_health.g) > 0.02
		or absf(health_fill.color.b - accessible_health.b) > 0.02
	):
		return _fail("Color-vision palette did not reach the health bar: %s" % str(health_fill.color))
	# Idempotency: re-apply must not compound font sizes or HUD scale.
	var scaled_health: float = health_background.scale.x
	main.call(&"_apply_accessibility_presentation")
	if room_label.get_theme_font_size("font_size") != room_font_size:
		return _fail("Accessibility apply compounded RoomProgress font_size")
	if absf(health_background.scale.x - scaled_health) > 0.001:
		return _fail("Accessibility apply compounded HUD scale")
	var presentation_cases: Array[Dictionary] = [
		{
			"name": "default",
			"large_text": false,
			"high_contrast": false,
			"color_blind": false,
		},
		{
			"name": "all_accessibility",
			"large_text": true,
			"high_contrast": true,
			"color_blind": true,
		},
	]
	for scale_index: int in range(3):
		settings.set_hud_scale_index(scale_index)
		for presentation: Dictionary in presentation_cases:
			var large_text_enabled := bool(presentation["large_text"])
			var high_contrast_enabled := bool(presentation["high_contrast"])
			var color_blind_enabled := bool(presentation["color_blind"])
			settings.set_large_text_enabled(large_text_enabled)
			settings.set_high_contrast_enabled(high_contrast_enabled)
			settings.set_color_blind_enabled(color_blind_enabled)
			main.call(&"_apply_accessibility_presentation")
			await process_frame
			var case_name := "%s_%d" % [String(presentation["name"]), scale_index]
			var actual_scale: float = health_background.scale.x
			if scale_index < 2:
				var requested_scale: float = float(settings.get_hud_scale_factor())
				if absf(actual_scale - requested_scale) > 0.015:
					return _fail("HUD scale mismatch for %s: %.3f" % [case_name, actual_scale])
			elif actual_scale < 1.05 or actual_scale > 1.101:
				return _fail("HUD 110%% fitted scale was invalid for %s: %.3f" % [case_name, actual_scale])
			var expected_font_size: int = UI.CAPTION + (2 if large_text_enabled else 0)
			if room_label.get_theme_font_size("font_size") != expected_font_size:
				return _fail("Large-text state was incorrect for %s" % case_name)
			var expected_room_color: Color = UI.TEXT_PRIMARY if high_contrast_enabled else UI.TEXT_SECONDARY
			if not room_label.get_theme_color("font_color").is_equal_approx(expected_room_color):
				return _fail("High-contrast state was incorrect for %s" % case_name)
			var expected_health_color: Color = Color("#4cc9ff") if color_blind_enabled else UI.ACCENT_MOON
			if not health_fill.color.is_equal_approx(expected_health_color):
				return _fail("Color-vision state was incorrect for %s" % case_name)
			for control: Control in [vitals, abilities, weapons, health_background, ability_bar]:
				if not canvas.encloses(control.get_global_rect().grow(-0.5)):
					return _fail("Accessible HUD left the canvas for %s: %s" % [case_name, control.name])
			if vitals.get_global_rect().grow(-0.5).intersects(abilities.get_global_rect().grow(-0.5)):
				return _fail("Accessible HUD overlapped vitals and abilities for %s" % case_name)
			if abilities.get_global_rect().grow(-0.5).intersects(weapons.get_global_rect().grow(-0.5)):
				return _fail("Accessible HUD overlapped abilities and weapons for %s" % case_name)
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
