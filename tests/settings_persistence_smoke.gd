extends SceneTree

const SETTINGS_STORE := preload("res://scripts/settings_store.gd")
const SAVE_PATH := "res://tests/settings_persistence_smoke_temp.json"


func _initialize() -> void:
	call_deferred(&"_run_test")


func _run_test() -> void:
	_cleanup()
	var store = SETTINGS_STORE.new(SAVE_PATH)
	store.set_master_volume(0.65)
	store.set_music_volume(0.35)
	store.set_effects_volume(0.45)
	store.set_voice_volume(0.55)
	store.set_damage_numbers_enabled(false)
	store.set_resolution_index(2)
	store.set_fullscreen_enabled(true)
	store.set_vsync_enabled(false)
	store.set_reduced_effects_enabled(true)

	var loaded = SETTINGS_STORE.new(SAVE_PATH)
	if not loaded.load_settings():
		return _fail("Expanded settings save could not be loaded")
	if (
		absf(float(loaded.get_master_volume()) - 0.65) > 0.001
		or absf(float(loaded.get_music_volume()) - 0.35) > 0.001
		or absf(float(loaded.get_effects_volume()) - 0.45) > 0.001
		or absf(float(loaded.get_voice_volume()) - 0.55) > 0.001
		or bool(loaded.get_damage_numbers_enabled())
		or int(loaded.get_resolution_index()) != 2
		or not bool(loaded.get_fullscreen_enabled())
		or bool(loaded.get_vsync_enabled())
		or not bool(loaded.get_reduced_effects_enabled())
	):
		return _fail("Expanded settings did not survive an atomic save round-trip")
	for bus_name: StringName in [&"Music", &"SFX", &"Voice"]:
		if AudioServer.get_bus_index(bus_name) < 0:
			return _fail("Audio bus was not created: %s" % bus_name)
	var controller_actions := {
		&"move_left": InputEventJoypadMotion,
		&"aim_up": InputEventJoypadMotion,
		&"aim_down": InputEventJoypadMotion,
		&"jump": InputEventJoypadButton,
		&"attack": InputEventJoypadButton,
		&"pause": InputEventJoypadButton,
	}
	for action_name: StringName in controller_actions:
		var found_controller_event := false
		for input_event: InputEvent in InputMap.action_get_events(action_name):
			if is_instance_of(input_event, controller_actions[action_name]):
				found_controller_event = true
		if not found_controller_event:
			return _fail("Controller mapping is missing for %s" % action_name)
	if not _has_left_stick_y_mapping(&"aim_up", -1.0):
		return _fail("Left-stick up is not mapped to the upward slash direction")
	if not _has_left_stick_y_mapping(&"aim_down", 1.0):
		return _fail("Left-stick down is not mapped to the downward slash direction")
	if (
		not _has_joy_button(&"choice_1", JOY_BUTTON_X)
		or not _has_joy_button(&"choice_2", JOY_BUTTON_Y)
		or not _has_joy_button(&"choice_3", JOY_BUTTON_B)
	):
		return _fail("The three card-choice shortcuts are not mapped to X / Y / B")
	if (
		not _has_joy_button(&"ui_accept", JOY_BUTTON_A)
		or not _has_joy_button(&"ui_cancel", JOY_BUTTON_B)
		or not _has_left_stick_mapping(&"ui_left", JOY_AXIS_LEFT_X, -1.0)
		or not _has_left_stick_mapping(&"ui_down", JOY_AXIS_LEFT_Y, 1.0)
	):
		return _fail("Controller menu navigation/confirm/cancel mappings are incomplete")
	if (
		String(loaded.get_controller_binding_name(&"attack")) != "X"
		or not String(loaded.get_controller_binding_name(&"aim_up")).contains("LS↑")
		or not String(loaded.get_combined_binding_name(&"dash")).contains("B")
	):
		return _fail("Controller binding labels do not match the installed Xbox map")
	print("settings_persistence_smoke: PASS")
	_cleanup()
	quit(0)


func _cleanup() -> void:
	for path: String in [SAVE_PATH, SAVE_PATH + ".tmp", SAVE_PATH + ".bak"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _has_left_stick_y_mapping(action_name: StringName, direction: float) -> bool:
	return _has_left_stick_mapping(action_name, JOY_AXIS_LEFT_Y, direction)


func _has_left_stick_mapping(action_name: StringName, axis: int, direction: float) -> bool:
	for input_event: InputEvent in InputMap.action_get_events(action_name):
		if (
			input_event is InputEventJoypadMotion
			and input_event.axis == axis
			and is_equal_approx(input_event.axis_value, direction)
		):
			return true
	return false


func _has_joy_button(action_name: StringName, button_index: int) -> bool:
	for input_event: InputEvent in InputMap.action_get_events(action_name):
		if (
			input_event is InputEventJoypadButton
			and input_event.button_index == button_index
		):
			return true
	return false


func _fail(message: String) -> void:
	_cleanup()
	push_error(message)
	quit(1)
