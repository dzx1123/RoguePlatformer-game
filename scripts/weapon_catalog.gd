extends RefCounted

## Central definitions for player weapons and their active skills.
class_name WeaponCatalog

const SWORD := &"moon_sword"
const TWIN_BLADES := &"twin_blades"
const GREATSWORD := &"star_greatsword"


static func all_weapon_ids() -> Array[StringName]:
	return [SWORD, TWIN_BLADES, GREATSWORD]


static func get_weapon(weapon_id: StringName) -> Dictionary:
	match weapon_id:
		TWIN_BLADES:
			return {
				"id": TWIN_BLADES,
				"name": "影织双刃",
				"damage": 25,
				"attack_duration": 0.27,
				"attack_cooldown": 0.30,
				"reach": 0.88,
				"skill_name": "瞬影连斩",
				"skill_duration": 0.42,
				"skill_cooldown": 2.20,
				"skill_multiplier": 1.75,
				"skill_reach": 1.35,
				"skill_lunge": 155.0,
				"skill_hit_progresses": [0.18, 0.48, 0.78],
				"skill_hit_weights": [0.30, 0.32, 0.38],
				"accent": Color("#b48cff"),
			}
		GREATSWORD:
			return {
				"id": GREATSWORD,
				"name": "坠星巨刃",
				"damage": 52,
				"attack_duration": 0.52,
				"attack_cooldown": 0.68,
				"reach": 1.28,
				"skill_name": "裂地坠星",
				"skill_duration": 0.66,
				"skill_cooldown": 3.60,
				"skill_multiplier": 2.20,
				"skill_reach": 1.90,
				"skill_lunge": 65.0,
				"skill_hit_progresses": [0.62],
				"skill_hit_weights": [1.0],
				"accent": Color("#ff9b62"),
			}
		_:
			return {
				"id": SWORD,
				"name": "月弧长剑",
				"damage": 34,
				"attack_duration": 0.30,
				"attack_cooldown": 0.38,
				"reach": 1.00,
				"skill_name": "月轮斩",
				"skill_duration": 0.68,
				"skill_cooldown": 2.80,
				"skill_multiplier": 1.90,
				"skill_reach": 1.62,
				"skill_lunge": 105.0,
				"skill_hit_progresses": [0.70],
				"skill_hit_weights": [1.0],
				"accent": Color("#78d9ef"),
			}


static func get_weapon_name(weapon_id: StringName) -> String:
	var weapon: Dictionary = get_weapon(weapon_id)
	return String(weapon.get("name", "未知武器"))
