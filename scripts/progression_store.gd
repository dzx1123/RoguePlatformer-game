extends RefCounted

## Persistent meta progression. The default save lives in Godot's user data folder.
class_name ProgressionStore

const SAFE_JSON_STORE_SCRIPT := preload("res://scripts/safe_json_store.gd")
const SAVE_VERSION := 1
const DEFAULT_SAVE_PATH := "user://rogue_progress.json"
const TWIN_BLADES_UNLOCK_SHARDS := 6
const GREATSWORD_UNLOCK_WINS := 2

var _save_path: String = DEFAULT_SAVE_PATH
var _meta_shards: int = 0
var _runs_completed: int = 0
var _bosses_defeated: int = 0
var _unlocked_weapons: Array[StringName] = [WeaponCatalog.SWORD]
var _selected_weapon: StringName = WeaponCatalog.SWORD


func _init(save_path: String = DEFAULT_SAVE_PATH) -> void:
	_save_path = save_path


func reset_to_defaults() -> void:
	_meta_shards = 0
	_runs_completed = 0
	_bosses_defeated = 0
	_unlocked_weapons = [WeaponCatalog.SWORD]
	_selected_weapon = WeaponCatalog.SWORD


func load_progress() -> bool:
	reset_to_defaults()
	var load_result: Dictionary = SAFE_JSON_STORE_SCRIPT.load_dictionary(
		_save_path,
		Callable(self, "_is_valid_save_data")
	)
	if not bool(load_result.get("ok", false)):
		return false
	var data: Dictionary = load_result.get("data", {}) as Dictionary
	_meta_shards = maxi(0, int(data.get("meta_shards", 0)))
	_runs_completed = maxi(0, int(data.get("runs_completed", 0)))
	_bosses_defeated = maxi(0, int(data.get("bosses_defeated", 0)))
	_unlocked_weapons.clear()
	var unlocked_values: Array = data.get("unlocked_weapons", []) as Array
	for unlocked_value in unlocked_values:
		var weapon_id := StringName(String(unlocked_value))
		if WeaponCatalog.all_weapon_ids().has(weapon_id) and not _unlocked_weapons.has(weapon_id):
			_unlocked_weapons.append(weapon_id)
	if not _unlocked_weapons.has(WeaponCatalog.SWORD):
		_unlocked_weapons.push_front(WeaponCatalog.SWORD)
	_selected_weapon = StringName(String(data.get("selected_weapon", WeaponCatalog.SWORD)))
	if not _unlocked_weapons.has(_selected_weapon):
		_selected_weapon = WeaponCatalog.SWORD
	return true


func save_progress() -> Error:
	var unlocked_strings: Array[String] = []
	for weapon_id in _unlocked_weapons:
		unlocked_strings.append(String(weapon_id))
	var data := {
		"version": SAVE_VERSION,
		"meta_shards": _meta_shards,
		"runs_completed": _runs_completed,
		"bosses_defeated": _bosses_defeated,
		"unlocked_weapons": unlocked_strings,
		"selected_weapon": String(_selected_weapon),
	}
	return SAFE_JSON_STORE_SCRIPT.save_dictionary(_save_path, data)


func bank_run(earned_shards: int, victory: bool) -> Array[StringName]:
	_meta_shards += maxi(0, earned_shards)
	if victory:
		_runs_completed += 1
		_bosses_defeated += 1
	var newly_unlocked: Array[StringName] = []
	if _meta_shards >= TWIN_BLADES_UNLOCK_SHARDS:
		_unlock_weapon(WeaponCatalog.TWIN_BLADES, newly_unlocked)
	if _runs_completed >= GREATSWORD_UNLOCK_WINS:
		_unlock_weapon(WeaponCatalog.GREATSWORD, newly_unlocked)
	return newly_unlocked


func select_weapon(weapon_id: StringName) -> bool:
	if not _unlocked_weapons.has(weapon_id):
		return false
	_selected_weapon = weapon_id
	return true


func get_meta_shards() -> int:
	return _meta_shards


func get_runs_completed() -> int:
	return _runs_completed


func get_bosses_defeated() -> int:
	return _bosses_defeated


func get_unlocked_weapons() -> Array[StringName]:
	return _unlocked_weapons.duplicate()


func get_selected_weapon() -> StringName:
	return _selected_weapon


func get_save_path() -> String:
	return _save_path


func get_snapshot() -> Dictionary:
	return {
		"meta_shards": _meta_shards,
		"runs_completed": _runs_completed,
		"bosses_defeated": _bosses_defeated,
		"unlocked_weapons": get_unlocked_weapons(),
		"selected_weapon": _selected_weapon,
	}


func _unlock_weapon(weapon_id: StringName, newly_unlocked: Array[StringName]) -> void:
	if _unlocked_weapons.has(weapon_id):
		return
	_unlocked_weapons.append(weapon_id)
	newly_unlocked.append(weapon_id)


func _is_valid_save_data(data: Dictionary) -> bool:
	return (
		int(data.get("version", 0)) >= 1
		and data.has("meta_shards")
		and data.has("runs_completed")
		and data.get("unlocked_weapons", null) is Array
	)
