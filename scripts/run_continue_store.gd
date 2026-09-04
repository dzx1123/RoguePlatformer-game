extends RefCounted

## Mid-run continue snapshot. Saved at room boundaries so a quit can resume
## the same seed, upgrades, and remaining route.
class_name RunContinueStore

const SAFE_JSON_STORE_SCRIPT := preload("res://scripts/safe_json_store.gd")
const SAVE_VERSION := 1
const DEFAULT_SAVE_PATH := "user://run_continue.json"

var _save_path: String = DEFAULT_SAVE_PATH
var _persistence_enabled: bool = true
var _snapshot: Dictionary = {}


func _init(
	save_path: String = DEFAULT_SAVE_PATH,
	persistence_enabled: bool = true
) -> void:
	_save_path = save_path
	_persistence_enabled = persistence_enabled


func load_snapshot() -> bool:
	_snapshot.clear()
	if not _persistence_enabled:
		return false
	var load_result: Dictionary = SAFE_JSON_STORE_SCRIPT.load_dictionary(
		_save_path,
		Callable(self, "_is_valid_snapshot")
	)
	if not bool(load_result.get("ok", false)):
		return false
	_snapshot = (load_result.get("data", {}) as Dictionary).duplicate(true)
	return has_snapshot()


func save_snapshot(snapshot: Dictionary) -> Error:
	if not _persistence_enabled:
		_snapshot = snapshot.duplicate(true)
		return OK
	if not _is_valid_snapshot(snapshot):
		return ERR_INVALID_DATA
	_snapshot = snapshot.duplicate(true)
	return SAFE_JSON_STORE_SCRIPT.save_dictionary(_save_path, _snapshot)


func clear_snapshot() -> Error:
	_snapshot.clear()
	if not _persistence_enabled:
		return OK
	return SAFE_JSON_STORE_SCRIPT.remove_dictionary(_save_path)


func has_snapshot() -> bool:
	return _is_valid_snapshot(_snapshot)


func get_snapshot() -> Dictionary:
	return _snapshot.duplicate(true)


func get_save_path() -> String:
	return _save_path


func _is_valid_snapshot(data: Dictionary) -> bool:
	if data.is_empty() or int(data.get("version", 0)) < 1:
		return false
	if int(data.get("seed", 0)) <= 0:
		return false
	if int(data.get("room_index", -1)) < 0:
		return false
	if not data.get("room_sequence", null) is Array:
		return false
	if not data.get("encounter_sequence", null) is Array:
		return false
	if not data.get("upgrade_counts", null) is Dictionary:
		return false
	if String(data.get("weapon_id", "")).is_empty():
		return false
	return true
