extends RefCounted

## Converts difficulty and room progress into a bounded encounter budget plus
## discrete behavior unlocks. Numeric multipliers remain deliberately modest.
class_name CombatBudget

const EASY := 0
const MEDIUM := 1
const HARD := 2

const NORMAL := 0
const TREASURE := 1
const ELITE := 2
const SHOP := 3
const BOSS := 4
const EVENT := 5
const CHALLENGE := 6
const RISK_CHEST := 7

const ROLE_MELEE := 0
const ROLE_RANGED := 1
const RANK_NORMAL := 0
const RANK_ELITE := 1


static func create_profile(difficulty: int, room_index: int, encounter: int) -> Dictionary:
	var safe_difficulty: int = clampi(difficulty, EASY, HARD)
	var safe_room: int = clampi(room_index, 0, 19)
	var progress: float = float(safe_room) / 19.0
	var chapter: int = mini(3, floori(float(safe_room) / 5.0))
	var behavior_tier: int = clampi(chapter + safe_difficulty, 0, 5)

	var health_multiplier: float
	var damage_multiplier: float
	var speed_multiplier: float
	var awareness_multiplier: float
	var base_budget: float
	var max_enemies: int
	var ranged_limit: int
	match safe_difficulty:
		EASY:
			health_multiplier = lerpf(0.82, 1.00, progress)
			damage_multiplier = lerpf(0.65, 0.85, progress)
			speed_multiplier = lerpf(0.88, 0.96, progress)
			awareness_multiplier = lerpf(0.62, 0.82, progress)
			base_budget = lerpf(3.10, 6.10, progress)
			max_enemies = 3 + roundi(progress * 3.0)
			ranged_limit = 1 + (1 if safe_room >= 10 else 0)
		HARD:
			health_multiplier = lerpf(1.12, 1.40, progress)
			damage_multiplier = lerpf(1.05, 1.30, progress)
			speed_multiplier = lerpf(1.02, 1.12, progress)
			awareness_multiplier = lerpf(1.05, 1.27, progress)
			base_budget = lerpf(6.40, 10.60, progress)
			max_enemies = 6 + roundi(progress * 4.0)
			ranged_limit = 3 + (1 if safe_room >= 15 else 0)
		_:
			health_multiplier = lerpf(0.98, 1.20, progress)
			damage_multiplier = lerpf(0.90, 1.08, progress)
			speed_multiplier = lerpf(0.96, 1.04, progress)
			awareness_multiplier = lerpf(0.88, 1.06, progress)
			base_budget = lerpf(5.20, 8.60, progress)
			max_enemies = 5 + roundi(progress * 3.0)
			ranged_limit = 2 + (1 if safe_room >= 10 else 0)

	var encounter_factor: float = 1.0
	var minimum_enemies: int = 2 if safe_difficulty == EASY else (4 if safe_difficulty == MEDIUM else 5)
	var elite_slots: int = 0
	match encounter:
		TREASURE:
			encounter_factor = 0.78
			max_enemies = maxi(2, max_enemies - 1)
		ELITE:
			encounter_factor = 1.18
			minimum_enemies = 3 if safe_difficulty == EASY else (4 if safe_difficulty == MEDIUM else 5)
			elite_slots = (
				1 + (1 if safe_room >= 10 else 0)
				if safe_difficulty == EASY
				else (2 + (1 if safe_room >= 15 else 0) if safe_difficulty == MEDIUM else 3)
			)
		CHALLENGE:
			encounter_factor = 1.36
			minimum_enemies = 4 if safe_difficulty == EASY else (7 if safe_difficulty == MEDIUM else 8)
			max_enemies += 2
			elite_slots = (
				1 if safe_difficulty == EASY
				else (1 + (1 if safe_room >= 10 else 0) if safe_difficulty == MEDIUM else 2)
			)
		BOSS:
			encounter_factor = 1.0
			minimum_enemies = 1
			max_enemies = 1
		RISK_CHEST:
			minimum_enemies = 0
			max_enemies = 0
			elite_slots = 1 if safe_difficulty != HARD else 2
		SHOP, EVENT:
			minimum_enemies = 0
			max_enemies = 0

	var candidate_reinforcements: int = chapter
	if safe_difficulty == EASY:
		candidate_reinforcements = maxi(0, chapter - 1)
	elif safe_difficulty == HARD:
		candidate_reinforcements = chapter + 1
	if encounter == CHALLENGE:
		candidate_reinforcements += 3

	var boss_escort_count: int = 0
	if encounter == BOSS and safe_room >= 10:
		boss_escort_count = 1 if safe_difficulty == EASY else (2 if safe_difficulty == MEDIUM else 3)
	var risk_ambush_count: int = (
		3 + (1 if safe_room >= 10 else 0)
		if safe_difficulty == EASY
		else (
			4 + (1 if safe_room >= 10 else 0)
			if safe_difficulty == MEDIUM
			else 5 + floori(float(chapter) / 2.0)
		)
	)

	return {
		"difficulty": safe_difficulty,
		"room_index": safe_room,
		"chapter": chapter,
		"progress": progress,
		"budget": base_budget * encounter_factor,
		"minimum_enemies": minimum_enemies,
		"max_enemies": maxi(minimum_enemies, max_enemies),
		"ranged_limit": ranged_limit,
		"elite_slots": elite_slots,
		"candidate_reinforcements": candidate_reinforcements,
		"boss_escort_count": boss_escort_count,
		"risk_ambush_count": risk_ambush_count,
		"health_multiplier": health_multiplier,
		"damage_multiplier": damage_multiplier,
		"speed_multiplier": speed_multiplier,
		"awareness_multiplier": awareness_multiplier,
		"behavior": _create_behavior_profile(behavior_tier),
	}


static func build_spawn_plan(
	candidates: Array[Dictionary],
	profile: Dictionary,
	rng: RandomNumberGenerator
) -> Array[Dictionary]:
	var shuffled: Array[Dictionary] = []
	for candidate: Dictionary in candidates:
		shuffled.append(candidate.duplicate(true))
	_shuffle(shuffled, rng)
	var ordered: Array[Dictionary] = []
	_extract_first_role(shuffled, ordered, ROLE_MELEE)
	_extract_first_role(shuffled, ordered, ROLE_RANGED)
	ordered.append_array(shuffled)

	var plan: Array[Dictionary] = []
	var budget: float = maxf(0.0, float(profile.get("budget", 0.0)))
	var spent: float = 0.0
	var minimum_enemies: int = maxi(0, int(profile.get("minimum_enemies", 0)))
	var max_enemies: int = maxi(minimum_enemies, int(profile.get("max_enemies", minimum_enemies)))
	var ranged_limit: int = maxi(0, int(profile.get("ranged_limit", 0)))
	var elite_slots: int = maxi(0, int(profile.get("elite_slots", 0)))
	var ranged_count: int = 0
	var elite_count: int = 0
	for candidate: Dictionary in ordered:
		if plan.size() >= max_enemies:
			break
		var role: int = int(candidate.get("role", ROLE_MELEE))
		if role == ROLE_RANGED and ranged_count >= ranged_limit:
			continue
		var rank: int = RANK_ELITE if elite_count < elite_slots else RANK_NORMAL
		var cost: float = _get_enemy_cost(role, rank)
		if plan.size() >= minimum_enemies and spent + cost > budget:
			continue
		var selected: Dictionary = candidate.duplicate(true)
		selected["rank"] = rank
		selected["budget_cost"] = cost
		plan.append(selected)
		spent += cost
		if role == ROLE_RANGED:
			ranged_count += 1
		if rank == RANK_ELITE:
			elite_count += 1
	return plan


static func get_plan_cost(plan: Array[Dictionary]) -> float:
	var cost: float = 0.0
	for descriptor: Dictionary in plan:
		cost += float(descriptor.get(
			"budget_cost",
			_get_enemy_cost(
				int(descriptor.get("role", ROLE_MELEE)),
				int(descriptor.get("rank", RANK_NORMAL))
			)
		))
	return cost


static func _create_behavior_profile(tier: int) -> Dictionary:
	var safe_tier: int = clampi(tier, 0, 5)
	var cooldown_scales := [2.15, 1.76, 1.43, 1.18, 1.00, 0.88]
	var reaction_delays := [1.35, 1.05, 0.78, 0.56, 0.38, 0.24]
	var telegraph_scales := [1.18, 1.13, 1.07, 1.00, 0.95, 0.90]
	var stagger_delays := [0.42, 0.34, 0.27, 0.20, 0.14, 0.10]
	var combo_chances := [0.0, 0.0, 0.0, 0.18, 0.32, 0.45]
	return {
		"tier": safe_tier,
		"attack_cooldown_scale": float(cooldown_scales[safe_tier]),
		"reaction_delay": float(reaction_delays[safe_tier]),
		"telegraph_scale": float(telegraph_scales[safe_tier]),
		"engagement_stagger": float(stagger_delays[safe_tier]),
		"pursuit_level": 0 if safe_tier <= 1 else (1 if safe_tier <= 3 else 2),
		"ranged_volley_count": 1 if safe_tier <= 2 else (2 if safe_tier <= 4 else 3),
		"ranged_spread": 0.0 if safe_tier <= 2 else (0.075 if safe_tier <= 4 else 0.11),
		"melee_combo_chance": float(combo_chances[safe_tier]),
		"melee_combo_limit": 0 if safe_tier <= 2 else (1 if safe_tier <= 4 else 2),
	}


static func _get_enemy_cost(role: int, rank: int) -> float:
	var cost: float = 1.30 if role == ROLE_RANGED else 1.0
	if rank == RANK_ELITE:
		cost += 1.25
	return cost


static func _extract_first_role(
	values: Array[Dictionary],
	destination: Array[Dictionary],
	role: int
) -> void:
	for index in range(values.size()):
		if int(values[index].get("role", ROLE_MELEE)) == role:
			destination.append(values[index])
			values.remove_at(index)
			return


static func _shuffle(values: Array[Dictionary], rng: RandomNumberGenerator) -> void:
	for index in range(values.size() - 1, 0, -1):
		var swap_index: int = rng.randi_range(0, index)
		var held: Dictionary = values[index]
		values[index] = values[swap_index]
		values[swap_index] = held
