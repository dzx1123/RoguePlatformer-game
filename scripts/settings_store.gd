extends RefCounted

## Persistent player-facing settings: master volume and rebindable keyboard actions.
class_name RogueSettingsStore

const SAFE_JSON_STORE_SCRIPT := preload("res://scripts/safe_json_store.gd")
const SAVE_PATH := "user://rogue_settings.json"
const SAVE_VERSION := 4
const RESOLUTION_OPTIONS: Array[Vector2i] = [
	Vector2i(1280, 840),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
]
const DEFAULT_BINDINGS := {
	"move_left": [KEY_A, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT],
	"jump": [KEY_SPACE],
	"aim_up": [KEY_W, KEY_UP],
	"aim_down": [KEY_S, KEY_DOWN],
	"attack": [KEY_J],
	"dash": [KEY_K],
	"skill": [KEY_L],
	"interact": [KEY_E],
	"cycle_weapon": [KEY_Q],
	"restart": [KEY_R],
	"pause": [KEY_ESCAPE],
}
const CONTROLLER_BINDING_NAMES := {
	"move_left": "LS← / D←",
	"move_right": "LS→ / D→",
	"jump": "A",
	"aim_up": "LS↑ / D↑",
	"aim_down": "LS↓ / D↓",
	"attack": "X",
	"dash": "B",
	"skill": "Y",
	"interact": "RB",
	"cycle_weapon": "LB",
	"restart": "View",
	"pause": "Menu",
}
const CHOICE_KEY_BINDINGS := {
	"choice_1": [KEY_1, KEY_KP_1],
	"choice_2": [KEY_2, KEY_KP_2],
	"choice_3": [KEY_3, KEY_KP_3],
}

var _bindings: Dictionary = {}
var _save_path: String = SAVE_PATH
var _master_volume: float = 0.80
var _music_volume: float = 0.80
var _effects_volume: float = 0.85
var _voice_volume: float = 0.90
var _damage_numbers_enabled: bool = true
var _resolution_index: int = 0
var _fullscreen_enabled: bool = false
var _vsync_enabled: bool = true
var _reduced_effects_enabled: bool = false


func _init(save_path: String = SAVE_PATH) -> void:
	_save_path = save_path
	_reset_defaults()


func load_settings() -> bool:
	_reset_defaults()
	var load_result: Dictionary = SAFE_JSON_STORE_SCRIPT.load_dictionary(
		_save_path,
		Callable(self, "_is_valid_settings_data")
	)
	if not bool(load_result.get("ok", false)):
		apply()
		return false
	var data: Dictionary = load_result.get("data", {}) as Dictionary
	var saved_version: int = int(data.get("version", 1))
	_master_volume = clampf(float(data.get("master_volume", _master_volume)), 0.0, 1.0)
	_music_volume = clampf(float(data.get("music_volume", _music_volume)), 0.0, 1.0)
	_effects_volume = clampf(float(data.get("effects_volume", _effects_volume)), 0.0, 1.0)
	_voice_volume = clampf(float(data.get("voice_volume", _voice_volume)), 0.0, 1.0)
	_damage_numbers_enabled = bool(data.get("damage_numbers_enabled", true))
	_resolution_index = clampi(int(data.get("resolution_index", 0)), 0, RESOLUTION_OPTIONS.size() - 1)
	_fullscreen_enabled = bool(data.get("fullscreen_enabled", false))
	_vsync_enabled = bool(data.get("vsync_enabled", true))
	_reduced_effects_enabled = bool(data.get("reduced_effects_enabled", false))
	var loaded_bindings: Dictionary = data.get("bindings", {}) as Dictionary
	for action_value in DEFAULT_BINDINGS:
		var action_name: String = String(action_value)
		# Version 1 mapped W/Up to jump. Version 2 reserves them for directional slashes.
		if saved_version < 2 and action_name == "jump":
			continue
		var values: Array = loaded_bindings.get(action_name, []) as Array
		var valid_keys: Array[int] = []
		for key_value in values:
			var key_code: int = int(key_value)
			if key_code != KEY_NONE and not valid_keys.has(key_code):
				valid_keys.append(key_code)
		if not valid_keys.is_empty():
			_bindings[action_name] = valid_keys
	apply()
	return true


func save_settings() -> Error:
	var binding_data := {}
	for action_value in DEFAULT_BINDINGS:
		var action_name: String = String(action_value)
		binding_data[action_name] = get_binding_codes(action_name)
	return SAFE_JSON_STORE_SCRIPT.save_dictionary(_save_path, {
		"version": SAVE_VERSION,
		"master_volume": _master_volume,
		"music_volume": _music_volume,
		"effects_volume": _effects_volume,
		"voice_volume": _voice_volume,
		"damage_numbers_enabled": _damage_numbers_enabled,
		"resolution_index": _resolution_index,
		"fullscreen_enabled": _fullscreen_enabled,
		"vsync_enabled": _vsync_enabled,
		"reduced_effects_enabled": _reduced_effects_enabled,
		"bindings": binding_data,
	})


func apply() -> void:
	for action_value in DEFAULT_BINDINGS:
		var action_name: StringName = StringName(String(action_value))
		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name)
		InputMap.action_erase_events(action_name)
		for key_code in get_binding_codes(String(action_name)):
			var event := InputEventKey.new()
			event.keycode = key_code
			InputMap.action_add_event(action_name, event)
	_apply_controller_defaults()
	_apply_audio()
	_apply_display()


func _apply_controller_defaults() -> void:
	_add_joy_axis(&"move_left", JOY_AXIS_LEFT_X, -1.0)
	_add_joy_axis(&"move_right", JOY_AXIS_LEFT_X, 1.0)
	_add_joy_axis(&"aim_up", JOY_AXIS_LEFT_Y, -1.0)
	_add_joy_axis(&"aim_down", JOY_AXIS_LEFT_Y, 1.0)
	_add_joy_button(&"move_left", JOY_BUTTON_DPAD_LEFT)
	_add_joy_button(&"move_right", JOY_BUTTON_DPAD_RIGHT)
	_add_joy_button(&"aim_up", JOY_BUTTON_DPAD_UP)
	_add_joy_button(&"aim_down", JOY_BUTTON_DPAD_DOWN)
	_add_joy_button(&"jump", JOY_BUTTON_A)
	_add_joy_button(&"attack", JOY_BUTTON_X)
	_add_joy_button(&"dash", JOY_BUTTON_B)
	_add_joy_button(&"skill", JOY_BUTTON_Y)
	_add_joy_button(&"interact", JOY_BUTTON_RIGHT_SHOULDER)
	_add_joy_button(&"cycle_weapon", JOY_BUTTON_LEFT_SHOULDER)
	_add_joy_button(&"restart", JOY_BUTTON_BACK)
	_add_joy_button(&"pause", JOY_BUTTON_START)

	# Context actions stay outside DEFAULT_BINDINGS: they are fixed menu controls,
	# not entries in the keyboard-rebinding grid.
	for action_value in CHOICE_KEY_BINDINGS:
		var action_name := StringName(String(action_value))
		_ensure_action(action_name)
		for key_code in CHOICE_KEY_BINDINGS[action_value]:
			_add_key(action_name, int(key_code))
	_add_joy_button(&"choice_1", JOY_BUTTON_X)
	_add_joy_button(&"choice_2", JOY_BUTTON_Y)
	_add_joy_button(&"choice_3", JOY_BUTTON_B)

	# Godot's built-in UI actions are made explicit so every menu works with
	# either the left stick or D-pad on a fresh project/input-map install.
	_add_joy_axis(&"ui_left", JOY_AXIS_LEFT_X, -1.0)
	_add_joy_axis(&"ui_right", JOY_AXIS_LEFT_X, 1.0)
	_add_joy_axis(&"ui_up", JOY_AXIS_LEFT_Y, -1.0)
	_add_joy_axis(&"ui_down", JOY_AXIS_LEFT_Y, 1.0)
	_add_joy_button(&"ui_left", JOY_BUTTON_DPAD_LEFT)
	_add_joy_button(&"ui_right", JOY_BUTTON_DPAD_RIGHT)
	_add_joy_button(&"ui_up", JOY_BUTTON_DPAD_UP)
	_add_joy_button(&"ui_down", JOY_BUTTON_DPAD_DOWN)
	_add_joy_button(&"ui_accept", JOY_BUTTON_A)
	_add_joy_button(&"ui_cancel", JOY_BUTTON_B)


func _ensure_action(action_name: StringName) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)


func _add_key(action_name: StringName, key_code: int) -> void:
	_ensure_action(action_name)
	for existing_event in InputMap.action_get_events(action_name):
		if existing_event is InputEventKey and existing_event.keycode == key_code:
			return
	var event := InputEventKey.new()
	event.keycode = key_code
	InputMap.action_add_event(action_name, event)


func _add_joy_button(action_name: StringName, button_index: int) -> void:
	_ensure_action(action_name)
	for existing_event in InputMap.action_get_events(action_name):
		if (
			existing_event is InputEventJoypadButton
			and existing_event.button_index == button_index
		):
			return
	var event := InputEventJoypadButton.new()
	event.button_index = button_index
	InputMap.action_add_event(action_name, event)


func _add_joy_axis(action_name: StringName, axis: int, axis_value: float) -> void:
	_ensure_action(action_name)
	for existing_event in InputMap.action_get_events(action_name):
		if (
			existing_event is InputEventJoypadMotion
			and existing_event.axis == axis
			and is_equal_approx(existing_event.axis_value, axis_value)
		):
			return
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = axis_value
	InputMap.action_add_event(action_name, event)


func rebind(action_name: StringName, key_code: int) -> bool:
	var action: String = String(action_name)
	if not DEFAULT_BINDINGS.has(action) or key_code == KEY_NONE:
		return false
	for other_action_value in DEFAULT_BINDINGS:
		var other_action: String = String(other_action_value)
		var codes := get_binding_codes(other_action)
		codes.erase(key_code)
		if codes.is_empty():
			codes = [int(DEFAULT_BINDINGS[other_action][0])]
		_bindings[other_action] = codes
	_bindings[action] = [key_code]
	apply()
	return save_settings() == OK


func reset_bindings() -> void:
	for action_value in DEFAULT_BINDINGS:
		var action_name: String = String(action_value)
		_bindings[action_name] = _copy_default_codes(action_name)
	apply()
	save_settings()


func get_binding_name(action_name: StringName) -> String:
	var codes := get_binding_codes(String(action_name))
	if codes.is_empty():
		return "未绑定"
	return OS.get_keycode_string(codes[0])


func get_controller_binding_name(action_name: StringName) -> String:
	return String(CONTROLLER_BINDING_NAMES.get(String(action_name), "未绑定"))


func get_action_prompt(action_name: StringName, using_controller: bool) -> String:
	if using_controller:
		return get_controller_binding_name(action_name)
	return get_binding_name(action_name)


func get_combined_binding_name(action_name: StringName) -> String:
	return "%s / %s" % [get_binding_name(action_name), get_controller_binding_name(action_name)]


func get_binding_codes(action_name: String) -> Array[int]:
	var stored: Array = _bindings.get(action_name, []) as Array
	var result: Array[int] = []
	for value in stored:
		result.append(int(value))
	return result


func set_master_volume(value: float) -> void:
	_master_volume = clampf(value, 0.0, 1.0)
	_apply_audio()
	save_settings()


func get_master_volume() -> float:
	return _master_volume


func set_music_volume(value: float) -> void:
	_music_volume = clampf(value, 0.0, 1.0)
	_apply_audio()
	save_settings()


func get_music_volume() -> float:
	return _music_volume


func set_effects_volume(value: float) -> void:
	_effects_volume = clampf(value, 0.0, 1.0)
	_apply_audio()
	save_settings()


func get_effects_volume() -> float:
	return _effects_volume


func set_voice_volume(value: float) -> void:
	_voice_volume = clampf(value, 0.0, 1.0)
	_apply_audio()
	save_settings()


func get_voice_volume() -> float:
	return _voice_volume


func set_damage_numbers_enabled(enabled: bool) -> void:
	_damage_numbers_enabled = enabled
	save_settings()


func get_damage_numbers_enabled() -> bool:
	return _damage_numbers_enabled


func get_resolution_options() -> Array[Vector2i]:
	return RESOLUTION_OPTIONS.duplicate()


func set_resolution_index(value: int) -> void:
	_resolution_index = clampi(value, 0, RESOLUTION_OPTIONS.size() - 1)
	_apply_display()
	save_settings()


func get_resolution_index() -> int:
	return _resolution_index


func set_fullscreen_enabled(enabled: bool) -> void:
	_fullscreen_enabled = enabled
	_apply_display()
	save_settings()


func get_fullscreen_enabled() -> bool:
	return _fullscreen_enabled


func set_vsync_enabled(enabled: bool) -> void:
	_vsync_enabled = enabled
	_apply_display()
	save_settings()


func get_vsync_enabled() -> bool:
	return _vsync_enabled


func set_reduced_effects_enabled(enabled: bool) -> void:
	_reduced_effects_enabled = enabled
	save_settings()


func get_reduced_effects_enabled() -> bool:
	return _reduced_effects_enabled


func get_save_path() -> String:
	return _save_path


func _reset_defaults() -> void:
	_bindings.clear()
	for action_value in DEFAULT_BINDINGS:
		var action_name: String = String(action_value)
		_bindings[action_name] = _copy_default_codes(action_name)
	_master_volume = 0.80
	_music_volume = 0.80
	_effects_volume = 0.85
	_voice_volume = 0.90
	_damage_numbers_enabled = true
	_resolution_index = 0
	_fullscreen_enabled = false
	_vsync_enabled = true
	_reduced_effects_enabled = false


func _copy_default_codes(action_name: String) -> Array[int]:
	var result: Array[int] = []
	for key_code in DEFAULT_BINDINGS.get(action_name, []):
		result.append(int(key_code))
	return result


func _apply_audio() -> void:
	_apply_bus_volume(&"Master", _master_volume)
	_apply_bus_volume(&"Music", _music_volume)
	_apply_bus_volume(&"SFX", _effects_volume)
	_apply_bus_volume(&"Voice", _voice_volume)


func _apply_bus_volume(bus_name: StringName, linear_volume: float) -> void:
	var bus_index: int = AudioServer.get_bus_index(bus_name)
	if bus_index < 0:
		AudioServer.add_bus()
		bus_index = AudioServer.bus_count - 1
		AudioServer.set_bus_name(bus_index, bus_name)
	AudioServer.set_bus_volume_db(bus_index, linear_to_db(maxf(linear_volume, 0.001)))


func apply_display() -> bool:
	return _apply_display()


func can_apply_display() -> bool:
	return DisplayServer.get_name() != "headless" and not Engine.is_embedded_in_editor()


func get_requested_resolution() -> Vector2i:
	return RESOLUTION_OPTIONS[_resolution_index]


func _apply_display() -> bool:
	if not can_apply_display():
		return false
	DisplayServer.window_set_vsync_mode(
		DisplayServer.VSYNC_ENABLED if _vsync_enabled else DisplayServer.VSYNC_DISABLED
	)
	if _fullscreen_enabled:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		# Fullscreen forces borderless on. Restore the native frame before resizing.
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
		DisplayServer.window_set_size(RESOLUTION_OPTIONS[_resolution_index])
	return true


func _is_valid_settings_data(data: Dictionary) -> bool:
	return (
		int(data.get("version", 0)) >= 1
		and data.get("bindings", null) is Dictionary
	)
