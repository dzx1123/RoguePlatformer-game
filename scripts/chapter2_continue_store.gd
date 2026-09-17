extends "res://scripts/run_continue_store.gd"

## Separate versioned checkpoint: never parsed as a chapter-one run snapshot.
const CHAPTER2_PATH := "user://chapter2_continue.json"

func save_snapshot(snapshot: Dictionary) -> Error:
	if not _is_valid_snapshot(snapshot):
		return ERR_INVALID_DATA
	return super.save_snapshot(snapshot)

func can_resume() -> bool:
	return has_snapshot() and not bool(get_snapshot().get("completed", false))

func _is_valid_snapshot(data: Dictionary) -> bool:
	for required in ["version", "chapter", "room_index", "weapon_id", "health", "max_health", "gold", "upgrade_counts", "claimed", "branches", "cooling_room", "completed"]:
		if not data.has(required):
			return false
	if int(data.get("version", 0)) != 1 or int(data.get("chapter", 0)) != 2:
		return false
	if int(data.get("room_index", -1)) not in range(20):
		return false
	if StringName(str(data.get("weapon_id", ""))) not in WeaponCatalog.all_weapon_ids():
		return false
	var health := int(data.get("health", 0))
	var maximum := int(data.get("max_health", 0))
	if maximum < 1 or maximum > 10000 or health < 1 or health > maximum or int(data.get("gold", -1)) < 0:
		return false
	for key in ["upgrade_counts", "claimed", "branches"]:
		if not data.get(key) is Dictionary:
			return false
	for id in data.upgrade_counts:
		var upgrade := UpgradeCatalog.get_upgrade(StringName(str(id)))
		if upgrade.is_empty() or int(data.upgrade_counts[id]) < 0 or int(data.upgrade_counts[id]) > int(upgrade.max_stacks):
			return false
		if upgrade.weapon != &"" and str(upgrade.weapon) != str(data.weapon_id):
			return false
	for key in data.claimed:
		var valid_ids: Array[String] = ["chain_chest"]
		for number in range(21, 41):
			valid_ids.append("forge_%d" % number)
		if str(key) not in valid_ids:
			return false
	for key in data.branches:
		if str(key) != "37" or int(data.branches[key]) not in [0, 1]:
			return false
	if int(data.get("cooling_room", -1)) not in [-1, 25]:
		return false
	if data.has("campaign"):
		if not data.campaign is Dictionary:
			return false
		var run: Dictionary = data.campaign
		for key in ["seed", "difficulty", "lives", "run_shards", "run_number"]:
			if not run.has(key) or not (run[key] is int or run[key] is float):
				return false
		if int(run.seed) < 1 or int(run.difficulty) not in [0, 1, 2] or int(run.lives) not in [1, 2, 3] or int(run.run_shards) < 0 or int(run.run_number) < 1:
			return false
	return data.get("completed", false) is bool

static func from_player(player: Node, gold: int) -> Dictionary:
	return {"version": 1, "chapter": 2, "room_index": 0, "weapon_id": str(player.get_weapon_id()), "health": player.get_current_health(), "max_health": player.get_max_health(), "gold": gold, "upgrade_counts": player.get_run_upgrade_counts(), "claimed": {}, "branches": {}, "cooling_room": -1, "completed": false}
