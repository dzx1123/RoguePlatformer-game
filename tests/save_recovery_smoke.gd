extends SceneTree

const SAFE_JSON_STORE := preload("res://scripts/safe_json_store.gd")
const TEMP_SAVE_PATH := "res://tests/save_recovery_smoke_temp.json"


func _initialize() -> void:
	call_deferred(&"_run_test")


func _run_test() -> void:
	_cleanup()
	var store := ProgressionStore.new(TEMP_SAVE_PATH)
	store.bank_run(6, true)
	if not store.select_weapon(WeaponCatalog.TWIN_BLADES):
		_fail("Recovery fixture could not select the unlocked twin blades")
		return
	if store.save_progress() != OK:
		_fail("Initial atomic save failed")
		return

	store.bank_run(0, true)
	if not store.select_weapon(WeaponCatalog.GREATSWORD):
		_fail("Recovery fixture could not select the unlocked greatsword")
		return
	if store.save_progress() != OK:
		_fail("Second atomic save failed")
		return
	if FileAccess.file_exists(SAFE_JSON_STORE.get_temporary_path(TEMP_SAVE_PATH)):
		_fail("Successful save left a temporary file behind")
		return
	if not FileAccess.file_exists(SAFE_JSON_STORE.get_backup_path(TEMP_SAVE_PATH)):
		_fail("Second save did not retain the previous valid backup")
		return

	if not _write_direct(TEMP_SAVE_PATH, "{broken json"):
		return
	var recovered := ProgressionStore.new(TEMP_SAVE_PATH)
	if not recovered.load_progress():
		_fail("Corrupted primary save did not recover from its backup")
		return
	if (
		recovered.get_runs_completed() != 1
		or recovered.get_meta_shards() != 6
		or recovered.get_selected_weapon() != WeaponCatalog.TWIN_BLADES
	):
		_fail("Backup recovery did not restore the last complete snapshot")
		return
	if not _is_valid_json_dictionary(TEMP_SAVE_PATH):
		_fail("Backup recovery did not repair the corrupted primary file")
		return

	var interrupted_data := {
		"version": 1,
		"meta_shards": 12,
		"runs_completed": 2,
		"bosses_defeated": 2,
		"unlocked_weapons": [
			String(WeaponCatalog.SWORD),
			String(WeaponCatalog.TWIN_BLADES),
			String(WeaponCatalog.GREATSWORD),
		],
		"selected_weapon": String(WeaponCatalog.GREATSWORD),
	}
	_remove_path(TEMP_SAVE_PATH)
	if not _write_direct(
		SAFE_JSON_STORE.get_temporary_path(TEMP_SAVE_PATH),
		JSON.stringify(interrupted_data)
	):
		return
	var interrupted_recovery := ProgressionStore.new(TEMP_SAVE_PATH)
	if not interrupted_recovery.load_progress():
		_fail("Interrupted atomic save did not recover its complete temporary file")
		return
	if (
		interrupted_recovery.get_meta_shards() != 12
		or interrupted_recovery.get_selected_weapon() != WeaponCatalog.GREATSWORD
		or FileAccess.file_exists(SAFE_JSON_STORE.get_temporary_path(TEMP_SAVE_PATH))
	):
		_fail("Temporary-file recovery did not promote the latest complete snapshot")
		return

	_cleanup()
	print("save_recovery_smoke: PASS")
	quit(0)


func _write_direct(path: String, contents: String) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_fail("Could not create save-recovery fixture: %s" % path)
		return false
	file.store_string(contents)
	file.flush()
	return true


func _is_valid_json_dictionary(path: String) -> bool:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	return JSON.parse_string(file.get_as_text()) is Dictionary


func _cleanup() -> void:
	for path: String in [
		TEMP_SAVE_PATH,
		SAFE_JSON_STORE.get_temporary_path(TEMP_SAVE_PATH),
		SAFE_JSON_STORE.get_backup_path(TEMP_SAVE_PATH),
	]:
		_remove_path(path)


func _remove_path(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _fail(message: String) -> void:
	_cleanup()
	push_error(message)
	quit(1)
