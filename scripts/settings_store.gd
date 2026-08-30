extends RefCounted

## Persistent player-facing settings: master volume and rebindable keyboard actions.
class_name RogueSettingsStore

const SAVE_PATH := "user://rogue_settings.json"
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

var _bindings: Dictionary = {}
var _master_volume: float = 0.80
var _damage_numbers_enabled: bool = true


func _init() -> void:
	_reset_defaults()


func load_settings() -> bool:
	_reset_defaults()
	if not FileAccess.file_exists(SAVE_PATH):
		apply()
		return false
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		apply()
		return false
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		apply()
		return false
	var data: Dictionary = parsed as Dictionary
	var saved_version: int = int(data.get("version", 1))
	_master_volume = clampf(float(data.get("master_volume", _master_volume)), 0.0, 1.0)
	_damage_numbers_enabled = bool(data.get("damage_numbers_enabled", true))
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
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify({
		"version": 3,
		"master_volume": _master_volume,
		"damage_numbers_enabled": _damage_numbers_enabled,
		"bindings": binding_data,
	}, "\t"))
	return OK


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
	_apply_master_volume()


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


func get_binding_codes(action_name: String) -> Array[int]:
	var stored: Array = _bindings.get(action_name, []) as Array
	var result: Array[int] = []
	for value in stored:
		result.append(int(value))
	return result


func set_master_volume(value: float) -> void:
	_master_volume = clampf(value, 0.0, 1.0)
	_apply_master_volume()
	save_settings()


func get_master_volume() -> float:
	return _master_volume


func set_damage_numbers_enabled(enabled: bool) -> void:
	_damage_numbers_enabled = enabled
	save_settings()


func get_damage_numbers_enabled() -> bool:
	return _damage_numbers_enabled


func _reset_defaults() -> void:
	_bindings.clear()
	for action_value in DEFAULT_BINDINGS:
		var action_name: String = String(action_value)
		_bindings[action_name] = _copy_default_codes(action_name)
	_master_volume = 0.80
	_damage_numbers_enabled = true


func _copy_default_codes(action_name: String) -> Array[int]:
	var result: Array[int] = []
	for key_code in DEFAULT_BINDINGS.get(action_name, []):
		result.append(int(key_code))
	return result


func _apply_master_volume() -> void:
	var master_bus: int = AudioServer.get_bus_index(&"Master")
	if master_bus >= 0:
		AudioServer.set_bus_volume_db(master_bus, linear_to_db(maxf(_master_volume, 0.001)))
