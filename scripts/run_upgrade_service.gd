extends RefCounted

## Selects run upgrades and creates shop offers without depending on HUD state.
class_name RunUpgradeService

const UPGRADE_CATALOG_SCRIPT := preload("res://scripts/upgrade_catalog.gd")
const DEFAULT_CHOICE_COUNT := 3
const DEFAULT_SHOP_BASE_COST := 16
const DEFAULT_SHOP_COST_STEP := 4


static func create_pool(
	weapon_id: StringName,
	upgrade_counts: Dictionary
) -> Array[Dictionary]:
	return UPGRADE_CATALOG_SCRIPT.create_available_pool(weapon_id, upgrade_counts)


static func pick_choices(
	weapon_id: StringName,
	upgrade_counts: Dictionary,
	rng: RandomNumberGenerator,
	choice_count: int = DEFAULT_CHOICE_COUNT
) -> Array[Dictionary]:
	var upgrade_pool: Array[Dictionary] = create_pool(weapon_id, upgrade_counts)
	var available_indices: Array[int] = []
	for upgrade_index in range(upgrade_pool.size()):
		available_indices.append(upgrade_index)
	for index in range(available_indices.size() - 1, 0, -1):
		var swap_index: int = rng.randi_range(0, index)
		var held_index: int = available_indices[index]
		available_indices[index] = available_indices[swap_index]
		available_indices[swap_index] = held_index

	var choices: Array[Dictionary] = []
	for choice_index in range(mini(maxi(choice_count, 0), available_indices.size())):
		choices.append(upgrade_pool[available_indices[choice_index]])
	return choices


static func create_shop_offers(
	weapon_id: StringName,
	upgrade_counts: Dictionary,
	rng: RandomNumberGenerator,
	choice_count: int = DEFAULT_CHOICE_COUNT,
	base_cost: int = DEFAULT_SHOP_BASE_COST,
	cost_step: int = DEFAULT_SHOP_COST_STEP
) -> Array[Dictionary]:
	var choices: Array[Dictionary] = pick_choices(
		weapon_id,
		upgrade_counts,
		rng,
		choice_count
	)
	var offers: Array[Dictionary] = []
	for choice_index in range(choices.size()):
		var offer: Dictionary = choices[choice_index].duplicate(true)
		offer["cost"] = maxi(0, base_cost + choice_index * cost_step)
		offers.append(offer)
	return offers
