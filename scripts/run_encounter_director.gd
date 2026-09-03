extends RefCounted

## Builds the constrained, seeded encounter route for one run.
class_name RunEncounterDirector

enum EncounterType {
	NORMAL,
	TREASURE,
	ELITE,
	SHOP,
	BOSS,
	EVENT,
	CHALLENGE,
	RISK_CHEST,
	HOLDOUT,
}

const CHAPTER_SIZE := 5


static func build_sequence(
	room_count: int,
	rng: RandomNumberGenerator
) -> Array[int]:
	var sequence: Array[int] = []
	if room_count <= 0:
		return sequence
	var chapter_count: int = ceili(float(room_count) / float(CHAPTER_SIZE))
	for chapter_index in range(chapter_count):
		sequence.append(EncounterType.NORMAL)
		var chapter_specials: Array[int]
		if chapter_index == 0:
			chapter_specials = [
				EncounterType.TREASURE,
				EncounterType.ELITE,
				EncounterType.SHOP,
			]
		else:
			chapter_specials = _build_weighted_chapter_specials(chapter_index, rng)
		for encounter: int in chapter_specials:
			sequence.append(encounter)
		sequence.append(EncounterType.BOSS)
	sequence.resize(room_count)
	return sequence


static func _build_weighted_chapter_specials(
	chapter_index: int,
	rng: RandomNumberGenerator
) -> Array[int]:
	# Later chapters guarantee one newly introduced archetype. The remaining
	# slots are weighted without replacement and retain a recovery/economy room.
	var required_new_types: Array[int] = [
		EncounterType.HOLDOUT,
		EncounterType.CHALLENGE,
		EncounterType.RISK_CHEST,
	]
	var selected: Array[int] = [required_new_types[clampi(chapter_index - 1, 0, 2)]]
	if selected[0] != EncounterType.EVENT:
		selected.append(_weighted_encounter_pick(
			[EncounterType.TREASURE, EncounterType.SHOP, EncounterType.EVENT],
			selected,
			chapter_index,
			rng
		))
	while selected.size() < 3:
		selected.append(_weighted_encounter_pick(
			[
				EncounterType.TREASURE,
				EncounterType.ELITE,
				EncounterType.SHOP,
				EncounterType.EVENT,
				EncounterType.CHALLENGE,
				EncounterType.RISK_CHEST,
				EncounterType.HOLDOUT,
			],
			selected,
			chapter_index,
			rng
		))
	_shuffle_encounters(selected, rng)
	return selected


static func _weighted_encounter_pick(
	candidates: Array[int],
	excluded: Array[int],
	chapter_index: int,
	rng: RandomNumberGenerator
) -> int:
	var available: Array[int] = []
	var total_weight: float = 0.0
	for encounter: int in candidates:
		if encounter in excluded:
			continue
		available.append(encounter)
		total_weight += _get_encounter_weight(encounter, chapter_index)
	if available.is_empty():
		return EncounterType.NORMAL
	var roll: float = rng.randf_range(0.0, total_weight)
	for encounter: int in available:
		roll -= _get_encounter_weight(encounter, chapter_index)
		if roll <= 0.0:
			return encounter
	return available.back()


static func _get_encounter_weight(encounter: int, chapter_index: int) -> float:
	match encounter:
		EncounterType.TREASURE:
			return 1.65
		EncounterType.ELITE:
			return 1.10 + float(chapter_index) * 0.16
		EncounterType.SHOP:
			return 1.30
		EncounterType.EVENT:
			return 1.35
		EncounterType.CHALLENGE:
			return 0.72 + float(chapter_index) * 0.22
		EncounterType.RISK_CHEST:
			return 0.80 + float(chapter_index) * 0.18
		EncounterType.HOLDOUT:
			return 0.78 + float(chapter_index) * 0.20
		_:
			return 1.0


static func _shuffle_encounters(
	encounters: Array[int],
	rng: RandomNumberGenerator
) -> void:
	for encounter_index in range(encounters.size() - 1, 0, -1):
		var swap_index: int = rng.randi_range(0, encounter_index)
		var held_encounter: int = encounters[encounter_index]
		encounters[encounter_index] = encounters[swap_index]
		encounters[swap_index] = held_encounter
