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
	print("settings_persistence_smoke: PASS")
	_cleanup()
	quit(0)


func _cleanup() -> void:
	for path: String in [SAVE_PATH, SAVE_PATH + ".tmp", SAVE_PATH + ".bak"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _fail(message: String) -> void:
	_cleanup()
	push_error(message)
	quit(1)
