extends "res://scripts/run_continue_store.gd"

## The room-boundary continue slot for the full two-chapter campaign.
class_name CampaignContinueStore

const CHAPTER2_STORE := preload("res://scripts/chapter2_continue_store.gd")
const LAST_CHAPTER_ONE_ROOM := 19

var _legacy_chapter2: RunContinueStore


func _init(
	save_path: String = DEFAULT_SAVE_PATH,
	persistence_enabled: bool = true,
	legacy_path: String = CHAPTER2_STORE.CHAPTER2_PATH
) -> void:
	super(save_path, persistence_enabled)
	_legacy_chapter2 = CHAPTER2_STORE.new(legacy_path, persistence_enabled)


func load_snapshot() -> bool:
	var has_canonical := super.load_snapshot()
	if not _persistence_enabled or _legacy_paths().is_empty():
		return has_canonical

	# Read legacy candidates without repairing their files. Older standalone
	# checkpoints are still valid in their own format and must stay in place.
	var legacy := _read_legacy_snapshot()
	if legacy.is_empty() or not legacy.has("campaign"):
		return has_canonical

	if not has_canonical or _is_interrupted_handoff(legacy):
		if save_snapshot(legacy) != OK:
			# Keep the legacy checkpoint usable if the unified path is unwritable.
			_snapshot = legacy
			return true
	_archive_legacy_campaign()
	return true


func save_snapshot(snapshot: Dictionary) -> Error:
	if not _is_valid_snapshot(snapshot):
		return ERR_INVALID_DATA
	if _persistence_enabled:
		var error := SAFE_JSON_STORE_SCRIPT.save_dictionary(_save_path, snapshot)
		if error != OK:
			return error
	_snapshot = snapshot.duplicate(true)
	return OK


func clear_snapshot() -> Error:
	if _persistence_enabled:
		var archival_error := _archive_legacy_campaign()
		if archival_error != OK:
			return archival_error
	return super.clear_snapshot()


func has_chapter2() -> bool:
	return has_snapshot() and _snapshot.get("chapter", 1) == 2


func can_resume() -> bool:
	return has_snapshot() and not bool(_snapshot.get("completed", false))


func _is_valid_snapshot(data: Dictionary) -> bool:
	match data.get("chapter", 1):
		1, 1.0:
			return super._is_valid_snapshot(data)
		2, 2.0:
			return data.get("campaign", null) is Dictionary and _legacy_chapter2._is_valid_snapshot(data)
		_:
			return false


func _legacy_paths() -> Array[String]:
	var path := _legacy_chapter2.get_save_path()
	if path.is_empty() or ProjectSettings.globalize_path(path) == ProjectSettings.globalize_path(_save_path):
		return []
	return [
		path,
		SAFE_JSON_STORE_SCRIPT.get_temporary_path(path),
		SAFE_JSON_STORE_SCRIPT.get_backup_path(path),
	]


func _read_legacy_snapshot() -> Dictionary:
	for path: String in _legacy_paths():
		var candidate := _read_legacy_file(path)
		if not candidate.is_empty():
			return candidate
	return {}


func _read_legacy_file(path: String) -> Dictionary:
	var candidate: Variant = SAFE_JSON_STORE_SCRIPT._read_valid_dictionary(
		ProjectSettings.globalize_path(path),
		Callable(_legacy_chapter2, "_is_valid_snapshot")
	)
	return candidate if candidate is Dictionary else {}


func _is_interrupted_handoff(legacy: Dictionary) -> bool:
	return (
		not has_chapter2()
		and int(_snapshot.get("room_index", -1)) == LAST_CHAPTER_ONE_ROOM
		and int(_snapshot.get("seed", 0)) == int(legacy.campaign.seed)
		and not bool(legacy.completed)
	)


func _archive_legacy_campaign() -> Error:
	var paths := _legacy_paths()
	paths.reverse()
	for path: String in paths:
		if not _read_legacy_file(path).has("campaign"):
			continue
		var source := ProjectSettings.globalize_path(path)
		var target := source + ".migrated"
		var suffix := 1
		while FileAccess.file_exists(target) or DirAccess.dir_exists_absolute(target):
			target = source + ".migrated.%d" % suffix
			suffix += 1
		# Retire the old slot without erasing distinct historical runs or backups.
		var error := DirAccess.rename_absolute(source, target)
		if error != OK:
			return error
	return OK
