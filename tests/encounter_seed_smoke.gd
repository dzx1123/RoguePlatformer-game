extends SceneTree


func _initialize() -> void:
	call_deferred(&"_run_test")


func _run_test() -> void:
	var first_snapshot: Dictionary = await _capture_seed_snapshot(123456)
	if first_snapshot.is_empty():
		return
	var repeated_snapshot: Dictionary = await _capture_seed_snapshot(123456)
	if repeated_snapshot.is_empty():
		return
	if (
		first_snapshot.get("rooms", []) != repeated_snapshot.get("rooms", [])
		or first_snapshot.get("encounters", []) != repeated_snapshot.get("encounters", [])
	):
		_fail("The same run seed did not reproduce rooms and encounters")
		return

	var different_snapshot: Dictionary = await _capture_seed_snapshot(654321)
	if different_snapshot.is_empty():
		return
	if (
		first_snapshot.get("rooms", []) == different_snapshot.get("rooms", [])
		and first_snapshot.get("encounters", []) == different_snapshot.get("encounters", [])
	):
		_fail("Different run seeds produced an identical complete route")
		return

	var encounters: Array = first_snapshot.get("encounters", []) as Array
	if encounters.size() != 20:
		_fail("Seeded run did not create twenty encounters")
		return
	for chapter_index in range(4):
		var chapter_start: int = chapter_index * 5
		if int(encounters[chapter_start]) != 0:
			_fail("Chapter %d did not begin with a normal combat room" % (chapter_index + 1))
			return
		if int(encounters[chapter_start + 4]) != 4:
			_fail("Chapter %d did not end with a boss room" % (chapter_index + 1))
			return
		var special_counts := {1: 0, 2: 0, 3: 0}
		for room_offset in range(1, 4):
			var encounter: int = int(encounters[chapter_start + room_offset])
			if not special_counts.has(encounter):
				_fail("Chapter contained an invalid constrained encounter")
				return
			special_counts[encounter] = int(special_counts[encounter]) + 1
		for count_value: Variant in special_counts.values():
			if int(count_value) != 1:
				_fail("Chapter did not contain one treasure, elite and shop room")
				return

	print("encounter_seed_smoke: PASS")
	quit(0)


func _capture_seed_snapshot(seed_value: int) -> Dictionary:
	var main_scene: PackedScene = load("res://scenes/Main.tscn")
	var main: Node2D = main_scene.instantiate() as Node2D
	main.set("save_enabled", false)
	main.set("_next_run_seed", seed_value)
	root.add_child(main)
	await physics_frame
	await physics_frame
	if int(main.call(&"get_run_seed")) != seed_value:
		_fail("Main did not honor the requested run seed")
		return {}
	var room_label := main.get_node("HUD/RoomProgress") as Label
	if not room_label.text.contains("S%06d" % seed_value):
		_fail("HUD did not expose the reproducible run seed")
		return {}
	var snapshot := {
		"rooms": main.call(&"get_room_sequence_ids"),
		"encounters": main.call(&"get_encounter_sequence"),
	}
	main.queue_free()
	await process_frame
	return snapshot


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
