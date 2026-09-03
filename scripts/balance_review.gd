class_name BalanceReview
extends RefCounted

## Converts the bounded telemetry history into conservative, reviewable balance
## signals. It never changes combat values automatically.

const MIN_RUNS := 8
const MIN_UPGRADE_OFFERS := 12
const MIN_ROOM_SAMPLES := 8
const LOW_PICK_RATE := 0.22
const HIGH_PICK_RATE := 0.56
const WIN_RATE_DELTA := 0.12
const LONG_ROOM_SECONDS := 42.0
const HIGH_ROOM_DEATH_RATE := 0.28


static func build(history: Array[Dictionary], version: String) -> Dictionary:
	var weapon_stats: Dictionary = {}
	for weapon_id: StringName in WeaponCatalog.all_weapon_ids():
		weapon_stats[String(weapon_id)] = {"runs": 0, "wins": 0}
	var upgrade_stats: Dictionary = {}
	var room_stats: Dictionary = {}

	for run: Dictionary in history:
		var weapon_key: String = String(run.get("starting_weapon_id", WeaponCatalog.SWORD))
		var weapon_entry: Dictionary = weapon_stats.get(weapon_key, {"runs": 0, "wins": 0}) as Dictionary
		weapon_entry["runs"] = int(weapon_entry.get("runs", 0)) + 1
		if bool(run.get("victory", false)):
			weapon_entry["wins"] = int(weapon_entry.get("wins", 0)) + 1
		weapon_stats[weapon_key] = weapon_entry
		for offer_value: Variant in run.get("upgrade_offers", []) as Array:
			if not offer_value is Dictionary:
				continue
			for upgrade_value: Variant in (offer_value as Dictionary).get("choice_ids", []) as Array:
				var upgrade_key: String = String(upgrade_value)
				if upgrade_key.is_empty():
					continue
				var upgrade_entry: Dictionary = upgrade_stats.get(upgrade_key, {"offered": 0, "chosen": 0}) as Dictionary
				upgrade_entry["offered"] = int(upgrade_entry.get("offered", 0)) + 1
				upgrade_stats[upgrade_key] = upgrade_entry
		for choice_value: Variant in run.get("upgrade_choices", []) as Array:
			if not choice_value is Dictionary:
				continue
			var choice_key: String = String((choice_value as Dictionary).get("upgrade_id", ""))
			if choice_key.is_empty():
				continue
			var choice_entry: Dictionary = upgrade_stats.get(choice_key, {"offered": 0, "chosen": 0}) as Dictionary
			choice_entry["chosen"] = int(choice_entry.get("chosen", 0)) + 1
			upgrade_stats[choice_key] = choice_entry
		for room_value: Variant in run.get("rooms", []) as Array:
			if not room_value is Dictionary:
				continue
			var room: Dictionary = room_value as Dictionary
			var encounter_key: String = String(room.get("encounter", "unknown"))
			var room_entry: Dictionary = room_stats.get(encounter_key, {
				"rooms": 0, "seconds": 0.0, "damage": 0, "deaths": 0,
			}) as Dictionary
			room_entry["rooms"] = int(room_entry.get("rooms", 0)) + 1
			room_entry["seconds"] = float(room_entry.get("seconds", 0.0)) + float(room.get("elapsed_seconds", 0.0))
			room_entry["damage"] = int(room_entry.get("damage", 0)) + int(room.get("damage_taken", 0))
			if not String(room.get("death_reason", "")).is_empty():
				room_entry["deaths"] = int(room_entry.get("deaths", 0)) + 1
			room_stats[encounter_key] = room_entry

	var total_runs: int = history.size()
	var total_wins: int = 0
	for weapon_value: Variant in weapon_stats.values():
		if weapon_value is Dictionary:
			total_wins += int((weapon_value as Dictionary).get("wins", 0))
	var average_win_rate: float = _ratio(total_wins, total_runs)
	var recommendations: Array[Dictionary] = []
	var weapon_review: Array[Dictionary] = _review_weapons(
		weapon_stats,
		total_runs,
		average_win_rate,
		recommendations
	)
	var upgrade_review: Array[Dictionary] = _review_upgrades(upgrade_stats, recommendations)
	var room_review: Array[Dictionary] = _review_rooms(room_stats, recommendations)
	return {
		"version": version,
		"generated_at_unix": int(Time.get_unix_time_from_system()),
		"runs_recorded": total_runs,
		"sample_ready": total_runs >= MIN_RUNS,
		"weapon_review": weapon_review,
		"upgrade_review": upgrade_review,
		"room_review": room_review,
		"recommendations": recommendations,
		"thresholds": {
			"min_runs": MIN_RUNS,
			"min_upgrade_offers": MIN_UPGRADE_OFFERS,
			"min_room_samples": MIN_ROOM_SAMPLES,
			"low_pick_rate": LOW_PICK_RATE,
			"high_pick_rate": HIGH_PICK_RATE,
			"long_room_seconds": LONG_ROOM_SECONDS,
			"high_room_death_rate": HIGH_ROOM_DEATH_RATE,
		},
	}


static func _review_weapons(
	stats: Dictionary,
	total_runs: int,
	average_win_rate: float,
	recommendations: Array[Dictionary]
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var expected_runs: float = float(total_runs) / float(maxi(1, WeaponCatalog.all_weapon_ids().size()))
	for weapon_key: Variant in stats.keys():
		var weapon_id: String = String(weapon_key)
		var entry: Dictionary = stats[weapon_key] as Dictionary
		var runs: int = int(entry.get("runs", 0))
		var wins: int = int(entry.get("wins", 0))
		var rate: float = _ratio(wins, runs)
		var status := "healthy"
		var action := "monitor"
		if total_runs < MIN_RUNS:
			status = "insufficient_sample"
		elif float(runs) < expected_runs * 0.60:
			status = "underpicked"
			action = "improve_discoverability"
		elif runs >= MIN_RUNS and rate < average_win_rate - WIN_RATE_DELTA:
			status = "underperforming"
			action = "consider_buff"
		elif runs >= MIN_RUNS and rate > average_win_rate + WIN_RATE_DELTA:
			status = "overperforming"
			action = "consider_nerf"
		var review := {"id": weapon_id, "runs": runs, "wins": wins, "win_rate": rate, "status": status, "action": action}
		result.append(review)
		if action != "monitor":
			recommendations.append({"category": "weapon", "id": weapon_id, "signal": status, "action": action})
	return result


static func _review_upgrades(stats: Dictionary, recommendations: Array[Dictionary]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for upgrade_key: Variant in stats.keys():
		var entry: Dictionary = stats[upgrade_key] as Dictionary
		var offered: int = int(entry.get("offered", 0))
		var chosen: int = int(entry.get("chosen", 0))
		var rate: float = _ratio(chosen, offered)
		var status := "healthy"
		var action := "monitor"
		if offered < MIN_UPGRADE_OFFERS:
			status = "insufficient_sample"
		elif rate < LOW_PICK_RATE:
			status = "underpicked"
			action = "consider_buff_or_reword"
		elif rate > HIGH_PICK_RATE:
			status = "overpicked"
			action = "consider_tuning_down"
		var review := {"id": String(upgrade_key), "offered": offered, "chosen": chosen, "pick_rate": rate, "status": status, "action": action}
		result.append(review)
		if action != "monitor":
			recommendations.append({"category": "upgrade", "id": String(upgrade_key), "signal": status, "action": action})
	return result


static func _review_rooms(stats: Dictionary, recommendations: Array[Dictionary]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for room_key: Variant in stats.keys():
		var entry: Dictionary = stats[room_key] as Dictionary
		var samples: int = int(entry.get("rooms", 0))
		var average_seconds: float = _ratio_float(float(entry.get("seconds", 0.0)), samples)
		var average_damage: float = _ratio_float(float(entry.get("damage", 0)), samples)
		var death_rate: float = _ratio(int(entry.get("deaths", 0)), samples)
		var status := "healthy"
		var action := "monitor"
		if samples < MIN_ROOM_SAMPLES:
			status = "insufficient_sample"
		elif average_seconds > LONG_ROOM_SECONDS and death_rate > HIGH_ROOM_DEATH_RATE:
			status = "slow_and_deadly"
			action = "review_enemy_budget_and_telegraphs"
		elif average_seconds > LONG_ROOM_SECONDS:
			status = "slow"
			action = "reduce_time_budget"
		elif death_rate > HIGH_ROOM_DEATH_RATE:
			status = "deadly"
			action = "reduce_damage_or_improve_telegraph"
		var review := {"id": String(room_key), "samples": samples, "average_seconds": average_seconds, "average_damage": average_damage, "death_rate": death_rate, "status": status, "action": action}
		result.append(review)
		if action != "monitor":
			recommendations.append({"category": "room", "id": String(room_key), "signal": status, "action": action})
	return result


static func _ratio(numerator: int, denominator: int) -> float:
	return 0.0 if denominator <= 0 else float(numerator) / float(denominator)


static func _ratio_float(numerator: float, denominator: int) -> float:
	return 0.0 if denominator <= 0 else numerator / float(denominator)
