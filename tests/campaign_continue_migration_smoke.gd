extends SceneTree

const CAMPAIGN_STORE := preload("res://scripts/campaign_continue_store.gd")
const LEGACY_STORE := preload("res://scripts/chapter2_continue_store.gd")

var _canonical_path := ""
var _legacy_path := ""


func _initialize() -> void:
	call_deferred(&"_run_test")


func _run_test() -> void:
	create_timer(5.0).timeout.connect(quit.bind(1))
	var fixture_prefix := "res://test_output/continue_migration_%d_" % OS.get_process_id()
	_canonical_path = fixture_prefix + "campaign.json"
	_legacy_path = fixture_prefix + "legacy.json"

	var canonical := CAMPAIGN_STORE.new(_canonical_path, true, _legacy_path)
	var legacy := LEGACY_STORE.new(_legacy_path)
	var standalone := _chapter_two(31)
	standalone.erase("campaign")
	assert(legacy.save_snapshot(standalone) == OK)
	var standalone_before := FileAccess.get_file_as_string(_legacy_path)
	assert(not canonical.load_snapshot() and FileAccess.get_file_as_string(_legacy_path) == standalone_before)
	assert(canonical.save_snapshot(standalone) == ERR_INVALID_DATA, "The unified slot rejected a standalone chapter")

	assert(canonical.save_snapshot(_chapter_one(72, 8)) == OK)
	assert(legacy.save_snapshot(_chapter_two(81)) == OK)
	assert(canonical.load_snapshot() and not canonical.has_chapter2())
	assert(int(canonical.get_snapshot().seed) == 72)
	assert(FileAccess.file_exists(_legacy_path + ".migrated"), "A distinct run must be preserved in the archive")
	assert(FileAccess.get_file_as_string(SafeJsonStore.get_backup_path(_legacy_path)) == standalone_before)
	assert(canonical.clear_snapshot() == OK and not canonical.load_snapshot(), "An older official run must not resurrect")

	assert(canonical.save_snapshot(_chapter_one(81, 19)) == OK)
	assert(legacy.save_snapshot(_chapter_two(81)) == OK)
	assert(canonical.load_snapshot() and canonical.has_chapter2() and canonical.can_resume())
	assert(int(canonical.get_snapshot().room_index) == 4)
	assert(FileAccess.file_exists(_legacy_path + ".migrated.1"), "Migration must not replace an earlier archive")

	var later := canonical.get_snapshot()
	later.room_index = 5
	assert(canonical.save_snapshot(later) == OK)
	_corrupt_primary()
	assert(canonical.load_snapshot() and int(canonical.get_snapshot().room_index) == 4)
	later.completed = true
	assert(canonical.save_snapshot(later) == OK)
	assert(canonical.load_snapshot() and canonical.has_chapter2() and not canonical.can_resume())

	assert(legacy.save_snapshot(_chapter_two(91)) == OK)
	var unwritable := CAMPAIGN_STORE.new(_canonical_path + "/child.json", true, _legacy_path)
	assert(unwritable.load_snapshot() and unwritable.can_resume())
	assert(FileAccess.file_exists(_legacy_path), "A failed migration must leave legacy data available")

	assert(canonical.clear_snapshot() == OK)
	SafeJsonStore.remove_dictionary(_legacy_path)
	for suffix in [".migrated", ".migrated.1", ".migrated.2"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_legacy_path + suffix))
	print("campaign_continue_migration_smoke: PASS")
	quit()


func _chapter_one(seed_value: int, room_index: int) -> Dictionary:
	return {
		"version": 1,
		"seed": seed_value,
		"room_index": room_index,
		"room_sequence": [0],
		"encounter_sequence": [0],
		"upgrade_counts": {},
		"weapon_id": String(WeaponCatalog.SWORD),
	}


func _chapter_two(seed_value: int) -> Dictionary:
	return {
		"version": 1,
		"chapter": 2,
		"room_index": 4,
		"weapon_id": String(WeaponCatalog.SWORD),
		"health": 79,
		"max_health": 100,
		"gold": 13,
		"upgrade_counts": {},
		"claimed": {},
		"branches": {},
		"cooling_room": -1,
		"completed": false,
		"campaign": {"seed": seed_value, "difficulty": 1, "lives": 2, "run_shards": 5, "run_number": 1},
	}


func _corrupt_primary() -> void:
	var file := FileAccess.open(_canonical_path, FileAccess.WRITE)
	assert(file != null)
	file.store_string("{incomplete")
	file.flush()
