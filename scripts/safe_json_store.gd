extends RefCounted

## Crash-tolerant JSON persistence shared by progression, settings and telemetry.
class_name SafeJsonStore

const TEMPORARY_SUFFIX := ".tmp"
const BACKUP_SUFFIX := ".bak"


static func load_dictionary(
	save_path: String,
	validator: Callable = Callable()
) -> Dictionary:
	var primary_path: String = _absolute_path(save_path)
	var temporary_path: String = primary_path + TEMPORARY_SUFFIX
	var backup_path: String = primary_path + BACKUP_SUFFIX

	var primary_data: Variant = _read_valid_dictionary(primary_path, validator)
	if primary_data is Dictionary:
		_remove_if_exists(temporary_path)
		return _load_result(primary_data as Dictionary, &"primary", OK)

	var temporary_data: Variant = _read_valid_dictionary(temporary_path, validator)
	if temporary_data is Dictionary:
		var temporary_repair_error: Error = _promote_temporary(
			primary_path,
			temporary_path
		)
		return _load_result(
			temporary_data as Dictionary,
			&"temporary",
			temporary_repair_error
		)

	var backup_data: Variant = _read_valid_dictionary(backup_path, validator)
	if backup_data is Dictionary:
		var backup_repair_error: Error = _restore_backup(
			primary_path,
			temporary_path,
			backup_path
		)
		return _load_result(
			backup_data as Dictionary,
			&"backup",
			backup_repair_error
		)

	_remove_if_exists(temporary_path)
	return {
		"ok": false,
		"data": {},
		"source": &"none",
		"recovered": false,
		"repair_error": ERR_FILE_CORRUPT,
	}


static func save_dictionary(save_path: String, data: Dictionary) -> Error:
	var primary_path: String = _absolute_path(save_path)
	var temporary_path: String = primary_path + TEMPORARY_SUFFIX
	var backup_path: String = primary_path + BACKUP_SUFFIX
	var directory_error: Error = DirAccess.make_dir_recursive_absolute(
		primary_path.get_base_dir()
	)
	if directory_error not in [OK, ERR_ALREADY_EXISTS]:
		return directory_error

	var cleanup_error: Error = _remove_if_exists(temporary_path)
	if cleanup_error != OK:
		return cleanup_error
	var write_error: Error = _write_text(
		temporary_path,
		JSON.stringify(data, "\t")
	)
	if write_error != OK:
		_remove_if_exists(temporary_path)
		return write_error
	if not _read_valid_dictionary(temporary_path) is Dictionary:
		_remove_if_exists(temporary_path)
		return ERR_FILE_CORRUPT

	var had_primary: bool = FileAccess.file_exists(primary_path)
	if had_primary:
		var backup_cleanup_error: Error = _remove_if_exists(backup_path)
		if backup_cleanup_error != OK:
			_remove_if_exists(temporary_path)
			return backup_cleanup_error
		var rotate_error: Error = DirAccess.rename_absolute(primary_path, backup_path)
		if rotate_error != OK:
			_remove_if_exists(temporary_path)
			return rotate_error

	var promote_error: Error = DirAccess.rename_absolute(temporary_path, primary_path)
	if promote_error != OK:
		if had_primary and not FileAccess.file_exists(primary_path):
			DirAccess.rename_absolute(backup_path, primary_path)
		_remove_if_exists(temporary_path)
		return promote_error
	return OK


static func get_temporary_path(save_path: String) -> String:
	return save_path + TEMPORARY_SUFFIX


static func get_backup_path(save_path: String) -> String:
	return save_path + BACKUP_SUFFIX


static func _read_valid_dictionary(
	path: String,
	validator: Callable = Callable()
) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK:
		return null
	var parsed_value: Variant = parser.data
	if not parsed_value is Dictionary:
		return null
	var data: Dictionary = parsed_value as Dictionary
	if validator.is_valid() and not bool(validator.call(data)):
		return null
	return data


static func _write_text(path: String, contents: String) -> Error:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(contents)
	file.flush()
	return file.get_error()


static func _promote_temporary(primary_path: String, temporary_path: String) -> Error:
	var remove_error: Error = _remove_if_exists(primary_path)
	if remove_error != OK:
		return remove_error
	return DirAccess.rename_absolute(temporary_path, primary_path)


static func _restore_backup(
	primary_path: String,
	temporary_path: String,
	backup_path: String
) -> Error:
	var backup_file := FileAccess.open(backup_path, FileAccess.READ)
	if backup_file == null:
		return FileAccess.get_open_error()
	var backup_text: String = backup_file.get_as_text()
	var cleanup_error: Error = _remove_if_exists(temporary_path)
	if cleanup_error != OK:
		return cleanup_error
	var write_error: Error = _write_text(temporary_path, backup_text)
	if write_error != OK:
		return write_error
	return _promote_temporary(primary_path, temporary_path)


static func _remove_if_exists(path: String) -> Error:
	if not FileAccess.file_exists(path):
		return OK
	return DirAccess.remove_absolute(path)


static func _absolute_path(path: String) -> String:
	if path.is_absolute_path():
		return path
	return ProjectSettings.globalize_path(path)


static func _load_result(
	data: Dictionary,
	source: StringName,
	repair_error: Error
) -> Dictionary:
	return {
		"ok": true,
		"data": data,
		"source": source,
		"recovered": source != &"primary",
		"repair_error": repair_error,
	}
