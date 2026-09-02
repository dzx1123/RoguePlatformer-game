extends SceneTree

const ENCOUNTER_DIRECTOR := preload("res://scripts/run_encounter_director.gd")
const UPGRADE_SERVICE := preload("res://scripts/run_upgrade_service.gd")


func _initialize() -> void:
	call_deferred(&"_run_test")


func _run_test() -> void:
	var route_rng := RandomNumberGenerator.new()
	route_rng.seed = 736421
	var route: Array[int] = ENCOUNTER_DIRECTOR.build_sequence(20, route_rng)
	if route.size() != 20:
		_fail("Encounter director did not build a twenty-room route")
		return
	for chapter_index in range(4):
		var chapter_start: int = chapter_index * 5
		if route[chapter_start] != ENCOUNTER_DIRECTOR.EncounterType.NORMAL:
			_fail("Encounter director broke a chapter opening constraint")
			return
		if route[chapter_start + 4] != ENCOUNTER_DIRECTOR.EncounterType.BOSS:
			_fail("Encounter director broke a chapter boss constraint")
			return

	var repeat_rng := RandomNumberGenerator.new()
	repeat_rng.seed = 736421
	if route != ENCOUNTER_DIRECTOR.build_sequence(20, repeat_rng):
		_fail("Encounter director is not reproducible for the same seed")
		return

	var choice_rng := RandomNumberGenerator.new()
	choice_rng.seed = 91277
	var choices: Array[Dictionary] = UPGRADE_SERVICE.pick_choices(
		WeaponCatalog.SWORD,
		{},
		choice_rng
	)
	if choices.size() != 3 or not _contains_unique_ids(choices):
		_fail("Upgrade service did not return three unique choices")
		return

	var shop_rng := RandomNumberGenerator.new()
	shop_rng.seed = 91277
	var offers: Array[Dictionary] = UPGRADE_SERVICE.create_shop_offers(
		WeaponCatalog.SWORD,
		{},
		shop_rng
	)
	if offers.size() != 3:
		_fail("Upgrade service did not create three shop offers")
		return
	for offer_index in range(offers.size()):
		if int(offers[offer_index].get("cost", -1)) != 16 + offer_index * 4:
			_fail("Shop offer pricing changed during service extraction")
			return
		if offers[offer_index].get("id", &"") != choices[offer_index].get("id", &""):
			_fail("Shop and reward selection no longer share deterministic ordering")
			return

	var capped_pool: Array[Dictionary] = UPGRADE_SERVICE.create_pool(
		WeaponCatalog.SWORD,
		{&"tempered_edge": 5, &"eclipse_guard": 1}
	)
	for upgrade: Dictionary in capped_pool:
		if upgrade.get("id", &"") in [&"tempered_edge", &"eclipse_guard"]:
			_fail("Upgrade service leaked a maxed build card")
			return

	print("run_services_smoke: PASS")
	quit(0)


func _contains_unique_ids(choices: Array[Dictionary]) -> bool:
	var ids: Dictionary = {}
	for choice: Dictionary in choices:
		ids[choice.get("id", &"")] = true
	return ids.size() == choices.size()


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
