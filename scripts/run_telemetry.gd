extends RefCounted

## Records balancing data without coupling it to the gameplay scene or HUD.
class_name RunTelemetry

const SAVE_VERSION := 1
const DEFAULT_SAVE_PATH := "user://run_telemetry.json"
const MAX_RUN_HISTORY := 60

var _save_path: String = DEFAULT_SAVE_PATH
var _persistence_enabled: bool = true
var _history: Array[Dictionary] = []
var _current_run: Dictionary = {}
var _current_room: Dictionary = {}


func _init(
	 save_path: String = DEFAULT_SAVE_PATH,
	 persistence_enabled: bool = true
) -> void:
	_save_path = save_path
	_persistence_enabled = persistence_enabled


func load_data() -> bool:
	_history.clear()
	_current_run.clear()
	_current_room.clear()
	if not _persistence_enabled or not FileAccess.file_exists(_save_path):
		return false
	var file := FileAccess.open(_save_path, FileAccess.READ)
	if file == null:
		return false
	var parsed_value: Variant = JSON.parse_string(file.get_as_text())
	if not parsed_value is Dictionary:
		return false
	var data: Dictionary = parsed_value as Dictionary
	var history_value: Variant = data.get("history", [])
	if history_value is Array:
		for run_value: Variant in history_value:
			if run_value is Dictionary:
				_history.append((run_value as Dictionary).duplicate(true))
	var current_value: Variant = data.get("current_run", {})
	if current_value is Dictionary and not (current_value as Dictionary).is_empty():
		_current_run = (current_value as Dictionary).duplicate(true)
		var room_value: Variant = _current_run.get("current_room", {})
		if room_value is Dictionary:
			_current_room = (room_value as Dictionary).duplicate(true)
		_current_run.erase("current_room")
	_trim_history()
	return true


func save_data() -> Error:
	if not _persistence_enabled:
		return OK
	var file := FileAccess.open(_save_path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	var saved_current: Dictionary = _current_run.duplicate(true)
	if not _current_room.is_empty():
		saved_current["current_room"] = _current_room.duplicate(true)
	file.store_string(JSON.stringify({
		"version": SAVE_VERSION,
		"history": _history,
		"current_run": saved_current,
	}, "\t"))
	return OK


func begin_run(seed_value: int, difficulty_name: String, weapon_id: StringName) -> void:
	if is_run_active():
		finish_run(false, StringName(String(_current_run.get("ending_weapon_id", weapon_id))), &"interrupted")
	_current_run = {
		"active": true,
		"seed": maxi(1, seed_value),
		"difficulty": difficulty_name,
		"starting_weapon_id": String(weapon_id),
		"ending_weapon_id": String(weapon_id),
		"started_at_unix": int(Time.get_unix_time_from_system()),
		"elapsed_seconds": 0.0,
		"damage_taken": 0,
		"damage_sources": {},
		"deaths": [],
		"rooms": [],
		"upgrade_offers": [],
		"upgrade_choices": [],
	}
	_current_room.clear()
	_save_after_event()


func begin_room(
	room_number: int,
	room_id: StringName,
	room_title: String,
	encounter_name: String
) -> void:
	if not is_run_active():
		return
	if not _current_room.is_empty():
		complete_room(&"advanced")
	_current_room = {
		"room_number": maxi(1, room_number),
		"room_id": String(room_id),
		"room_title": room_title,
		"encounter": encounter_name,
		"elapsed_seconds": 0.0,
		"damage_taken": 0,
		"damage_sources": {},
		"death_reason": "",
		"boss_kill_time": -1.0,
		"upgrade_offers": [],
		"upgrade_choice": "",
	}
	_save_after_event()


func tick(delta: float) -> void:
	if not is_run_active() or delta <= 0.0:
		return
	_current_run["elapsed_seconds"] = float(_current_run.get("elapsed_seconds", 0.0)) + delta
	if not _current_room.is_empty():
		_current_room["elapsed_seconds"] = float(_current_room.get("elapsed_seconds", 0.0)) + delta


func record_damage(amount: int, cause: StringName) -> void:
	if not is_run_active() or amount <= 0:
		return
	var cause_name: String = _normalize_name(cause, "unknown")
	_current_run["damage_taken"] = int(_current_run.get("damage_taken", 0)) + amount
	var run_sources: Dictionary = _current_run.get("damage_sources", {}) as Dictionary
	run_sources[cause_name] = int(run_sources.get(cause_name, 0)) + amount
	_current_run["damage_sources"] = run_sources
	if not _current_room.is_empty():
		_current_room["damage_taken"] = int(_current_room.get("damage_taken", 0)) + amount
		var room_sources: Dictionary = _current_room.get("damage_sources", {}) as Dictionary
		room_sources[cause_name] = int(room_sources.get(cause_name, 0)) + amount
		_current_room["damage_sources"] = room_sources


func record_death(reason: StringName) -> void:
	if not is_run_active():
		return
	var reason_name: String = _normalize_name(reason, "unknown")
	var deaths: Array = _current_run.get("deaths", []) as Array
	deaths.append({
		"reason": reason_name,
		"room_number": int(_current_room.get("room_number", 0)),
		"elapsed_seconds": float(_current_run.get("elapsed_seconds", 0.0)),
	})
	_current_run["deaths"] = deaths
	if not _current_room.is_empty():
		_current_room["death_reason"] = reason_name
	_save_after_event()


func record_boss_defeat() -> void:
	if not is_run_active() or _current_room.is_empty():
		return
	_current_room["boss_kill_time"] = float(_current_room.get("elapsed_seconds", 0.0))
	_save_after_event()


func record_upgrade_offers(choices: Array[Dictionary], weapon_id: StringName) -> void:
	if not is_run_active() or choices.is_empty():
		return
	var offer_ids: Array[String] = []
	for choice: Dictionary in choices:
		var choice_id: String = String(choice.get("id", ""))
		if not choice_id.is_empty() and not offer_ids.has(choice_id):
			offer_ids.append(choice_id)
	if offer_ids.is_empty():
		return
	if not _current_room.is_empty() and not (_current_room.get("upgrade_offers", []) as Array).is_empty():
		return
	var offer_entry := {
		"room_number": int(_current_room.get("room_number", 0)),
		"weapon_id": String(weapon_id),
		"choice_ids": offer_ids,
	}
	var offers: Array = _current_run.get("upgrade_offers", []) as Array
	offers.append(offer_entry)
	_current_run["upgrade_offers"] = offers
	if not _current_room.is_empty():
		_current_room["upgrade_offers"] = offer_ids.duplicate()
	_save_after_event()


func record_upgrade_choice(upgrade_id: StringName, weapon_id: StringName) -> void:
	if not is_run_active() or upgrade_id.is_empty():
		return
	var choice_entry := {
		"room_number": int(_current_room.get("room_number", 0)),
		"weapon_id": String(weapon_id),
		"upgrade_id": String(upgrade_id),
	}
	var choices: Array = _current_run.get("upgrade_choices", []) as Array
	choices.append(choice_entry)
	_current_run["upgrade_choices"] = choices
	if not _current_room.is_empty():
		_current_room["upgrade_choice"] = String(upgrade_id)
	_save_after_event()


func complete_room(outcome: StringName = &"cleared") -> void:
	if not is_run_active() or _current_room.is_empty():
		return
	_current_room["outcome"] = _normalize_name(outcome, "cleared")
	var rooms: Array = _current_run.get("rooms", []) as Array
	rooms.append(_current_room.duplicate(true))
	_current_run["rooms"] = rooms
	_current_room.clear()
	_save_after_event()


func finish_run(
	victory: bool,
	ending_weapon_id: StringName,
	result_reason: StringName = &"completed"
) -> Dictionary:
	if not is_run_active():
		return {}
	if not _current_room.is_empty():
		complete_room(&"cleared" if victory else &"failed")
	_current_run["active"] = false
	_current_run["victory"] = victory
	_current_run["result_reason"] = _normalize_name(result_reason, "completed")
	_current_run["ending_weapon_id"] = String(ending_weapon_id)
	_current_run["finished_at_unix"] = int(Time.get_unix_time_from_system())
	var finished_run: Dictionary = _current_run.duplicate(true)
	_history.append(finished_run)
	_trim_history()
	_current_run.clear()
	_current_room.clear()
	_save_after_event()
	return finished_run


func get_current_run_snapshot() -> Dictionary:
	var snapshot: Dictionary = _current_run.duplicate(true)
	if not _current_room.is_empty():
		snapshot["current_room"] = _current_room.duplicate(true)
	return snapshot


func get_history() -> Array[Dictionary]:
	return _history.duplicate(true)


func get_summary() -> Dictionary:
	var total_room_seconds: float = 0.0
	var room_count: int = 0
	var total_damage: int = 0
	var victories: int = 0
	var boss_kill_seconds: float = 0.0
	var boss_kills: int = 0
	var death_reasons: Dictionary = {}
	var offered_counts: Dictionary = {}
	var chosen_counts: Dictionary = {}
	var weapon_totals: Dictionary = {}
	for run: Dictionary in _history:
		var victory: bool = bool(run.get("victory", false))
		if victory:
			victories += 1
		total_damage += int(run.get("damage_taken", 0))
		for death_value: Variant in run.get("deaths", []) as Array:
			if death_value is Dictionary:
				var death_reason: String = String((death_value as Dictionary).get("reason", "unknown"))
				death_reasons[death_reason] = int(death_reasons.get(death_reason, 0)) + 1
		for room_value: Variant in run.get("rooms", []) as Array:
			if not room_value is Dictionary:
				continue
			var room: Dictionary = room_value as Dictionary
			room_count += 1
			total_room_seconds += float(room.get("elapsed_seconds", 0.0))
			var boss_time: float = float(room.get("boss_kill_time", -1.0))
			if boss_time >= 0.0:
				boss_kills += 1
				boss_kill_seconds += boss_time
		for offer_value: Variant in run.get("upgrade_offers", []) as Array:
			if not offer_value is Dictionary:
				continue
			for offered_id: Variant in (offer_value as Dictionary).get("choice_ids", []) as Array:
				var offered_name: String = String(offered_id)
				offered_counts[offered_name] = int(offered_counts.get(offered_name, 0)) + 1
		for choice_value: Variant in run.get("upgrade_choices", []) as Array:
			if choice_value is Dictionary:
				var chosen_id: String = String((choice_value as Dictionary).get("upgrade_id", ""))
				chosen_counts[chosen_id] = int(chosen_counts.get(chosen_id, 0)) + 1
		var weapon_id: String = String(run.get("starting_weapon_id", "unknown"))
		var weapon_entry: Dictionary = weapon_totals.get(weapon_id, {"runs": 0, "wins": 0}) as Dictionary
		weapon_entry["runs"] = int(weapon_entry.get("runs", 0)) + 1
		if victory:
			weapon_entry["wins"] = int(weapon_entry.get("wins", 0)) + 1
		weapon_totals[weapon_id] = weapon_entry

	var upgrade_rates: Dictionary = {}
	for offered_id: Variant in offered_counts.keys():
		var offered: int = int(offered_counts[offered_id])
		var chosen: int = int(chosen_counts.get(offered_id, 0))
		upgrade_rates[String(offered_id)] = {
			"offered": offered,
			"chosen": chosen,
			"rate": _safe_ratio(chosen, offered),
		}
	var weapon_rates: Dictionary = {}
	for weapon_key: Variant in weapon_totals.keys():
		var weapon_value: Dictionary = weapon_totals[weapon_key] as Dictionary
		var weapon_runs: int = int(weapon_value.get("runs", 0))
		var weapon_wins: int = int(weapon_value.get("wins", 0))
		weapon_rates[String(weapon_key)] = {
			"runs": weapon_runs,
			"wins": weapon_wins,
			"rate": _safe_ratio(weapon_wins, weapon_runs),
		}
	return {
		"runs_recorded": _history.size(),
		"victories": victories,
		"win_rate": _safe_ratio(victories, _history.size()),
		"rooms_recorded": room_count,
		"average_room_seconds": _safe_ratio_float(total_room_seconds, room_count),
		"damage_taken": total_damage,
		"average_damage_taken": _safe_ratio_float(float(total_damage), _history.size()),
		"death_reasons": death_reasons,
		"boss_kills": boss_kills,
		"average_boss_kill_seconds": _safe_ratio_float(boss_kill_seconds, boss_kills),
		"upgrade_choice_rates": upgrade_rates,
		"weapon_clear_rates": weapon_rates,
	}


func is_run_active() -> bool:
	return not _current_run.is_empty() and bool(_current_run.get("active", false))


func get_save_path() -> String:
	return _save_path


func _save_after_event() -> void:
	var save_error: Error = save_data()
	if save_error != OK:
		push_warning("Could not save optional run telemetry: %s" % error_string(save_error))


func _trim_history() -> void:
	while _history.size() > MAX_RUN_HISTORY:
		_history.pop_front()


func _normalize_name(value: StringName, fallback: String) -> String:
	var text_value: String = String(value)
	return fallback if text_value.is_empty() else text_value


func _safe_ratio(numerator: int, denominator: int) -> float:
	return 0.0 if denominator <= 0 else float(numerator) / float(denominator)


func _safe_ratio_float(numerator: float, denominator: int) -> float:
	return 0.0 if denominator <= 0 else numerator / float(denominator)
