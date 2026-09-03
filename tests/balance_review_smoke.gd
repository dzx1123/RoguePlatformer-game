extends SceneTree


func _initialize() -> void:
	var history: Array[Dictionary] = []
	for index in range(16):
		var choice_id := "moon_expansion" if index < 2 else "tempered_edge"
		history.append(_make_run(
			"moon_sword",
			true,
			50.0,
			index < 5,
			["moon_expansion", "tempered_edge"],
			choice_id
		))
	for _index in range(4):
		history.append(_make_run("twin_blades", false, 26.0, false, [], ""))
	for _index in range(4):
		history.append(_make_run("star_greatsword", false, 26.0, false, [], ""))

	var review: Dictionary = BalanceReview.build(history, "test-balance")
	if not bool(review.get("sample_ready", false)):
		_fail("Balance review did not recognize a sufficient run sample")
		return
	if String(review.get("version", "")) != "test-balance":
		_fail("Balance review did not retain its version label")
		return
	if not _has_status(review.get("weapon_review", []) as Array, "twin_blades", "underpicked"):
		_fail("Balance review did not flag the cold weapon")
		return
	if not _has_status(review.get("upgrade_review", []) as Array, "moon_expansion", "underpicked"):
		_fail("Balance review did not flag the cold upgrade")
		return
	if not _has_status(review.get("room_review", []) as Array, "challenge", "slow_and_deadly"):
		_fail("Balance review did not flag the slow and deadly room type")
		return
	if (review.get("recommendations", []) as Array).is_empty():
		_fail("Balance review did not produce review actions")
		return
	var telemetry: RunTelemetry = RunTelemetry.new("user://balance_review_smoke.json", false)
	telemetry.set("_history", history)
	var telemetry_review: Dictionary = telemetry.get_balance_review()
	if String(telemetry_review.get("version", "")) != "0.5.0-p6-content":
		_fail("Telemetry did not expose the P6 balance record version")
		return
	print("balance_review_smoke: PASS")
	quit(0)


func _make_run(
	weapon_id: String,
	victory: bool,
	room_seconds: float,
	died: bool,
	offers: Array,
	choice_id: String
) -> Dictionary:
	var upgrade_offers: Array = []
	if not offers.is_empty():
		upgrade_offers.append({"choice_ids": offers})
	var upgrade_choices: Array = []
	if not choice_id.is_empty():
		upgrade_choices.append({"upgrade_id": choice_id})
	return {
		"starting_weapon_id": weapon_id,
		"victory": victory,
		"upgrade_offers": upgrade_offers,
		"upgrade_choices": upgrade_choices,
		"rooms": [{
			"encounter": "challenge" if room_seconds > 40.0 else "normal",
			"elapsed_seconds": room_seconds,
			"damage_taken": 24,
			"death_reason": "goblin" if died else "",
		}],
	}


func _has_status(entries: Array, identifier: String, expected_status: String) -> bool:
	for entry_value in entries:
		if not entry_value is Dictionary:
			continue
		var entry: Dictionary = entry_value as Dictionary
		if String(entry.get("id", "")) == identifier:
			return String(entry.get("status", "")) == expected_status
	return false


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
