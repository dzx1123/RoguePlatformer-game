extends RefCounted

class_name UpgradeCatalog

enum Rarity {
	COMMON,
	RARE,
	LEGENDARY,
}


static func all_upgrades() -> Array[Dictionary]:
	return [
		_upgrade(&"tempered_edge", "锋刃磨砺", "攻击伤害 +8", 5),
		_upgrade(&"vitality_rune", "生命铸纹", "最大生命 +20，并恢复 20", 4),
		_upgrade(&"swift_step", "迅捷步法", "移动速度 +32", 3),
		_upgrade(&"dash_core", "冲刺核心", "冲刺速度 +90", 3),
		_upgrade(&"battle_rhythm", "战斗节奏", "普通攻击冷却缩短 12%", 4),
		_upgrade(&"resonant_focus", "共鸣聚焦", "主动技能冷却缩短 14%", 4),
		_upgrade(&"extended_guard", "延展剑势", "普通攻击范围增加 10%", 3),
		_upgrade(&"second_wind", "再生气息", "立即恢复 35 点生命", 3),
		_upgrade(
			&"moon_expansion",
			"满月扩张",
			"月轮斩范围增加 12%",
			3,
			Rarity.RARE,
			WeaponCatalog.SWORD
		),
		_upgrade(
			&"moon_rupture",
			"蚀月破裂",
			"月轮斩总伤害增加 18%",
			3,
			Rarity.RARE,
			WeaponCatalog.SWORD
		),
		_upgrade(
			&"lunar_cycle",
			"月相循环",
			"月轮斩冷却额外缩短 16%",
			3,
			Rarity.RARE,
			WeaponCatalog.SWORD
		),
		_upgrade(
			&"eclipse_guard",
			"蚀影护体",
			"月轮斩期间受到的伤害降低 35%",
			1,
			Rarity.LEGENDARY,
			WeaponCatalog.SWORD
		),
		_upgrade(
			&"woven_momentum",
			"织影动量",
			"瞬影连斩突进速度增加 18%",
			3,
			Rarity.RARE,
			WeaponCatalog.TWIN_BLADES
		),
		_upgrade(
			&"threaded_edge",
			"贯线锋芒",
			"瞬影连斩每段伤害增加 12%",
			3,
			Rarity.RARE,
			WeaponCatalog.TWIN_BLADES
		),
		_upgrade(
			&"quicksilver",
			"流银回路",
			"瞬影连斩冷却额外缩短 14%",
			3,
			Rarity.RARE,
			WeaponCatalog.TWIN_BLADES
		),
		_upgrade(
			&"shadowstep",
			"影遁",
			"释放瞬影连斩期间免疫敌人攻击",
			1,
			Rarity.LEGENDARY,
			WeaponCatalog.TWIN_BLADES
		),
		_upgrade(
			&"fault_line",
			"断层延伸",
			"裂地坠星范围增加 12%",
			3,
			Rarity.RARE,
			WeaponCatalog.GREATSWORD
		),
		_upgrade(
			&"starfall_core",
			"坠星核心",
			"裂地坠星伤害增加 20%",
			3,
			Rarity.RARE,
			WeaponCatalog.GREATSWORD
		),
		_upgrade(
			&"meteor_rhythm",
			"陨星节律",
			"裂地坠星冷却额外缩短 12%",
			3,
			Rarity.RARE,
			WeaponCatalog.GREATSWORD
		),
		_upgrade(
			&"adamant_stance",
			"不动架势",
			"裂地坠星期间受到的伤害和击退降低 45%",
			1,
			Rarity.LEGENDARY,
			WeaponCatalog.GREATSWORD
		),
	]


static func create_available_pool(
	weapon_id: StringName,
	upgrade_counts: Dictionary
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for upgrade: Dictionary in all_upgrades():
		var required_weapon: StringName = upgrade.get("weapon", &"")
		if not required_weapon.is_empty() and required_weapon != weapon_id:
			continue
		var upgrade_id: StringName = upgrade.get("id", &"")
		var current_count: int = int(upgrade_counts.get(upgrade_id, 0))
		var max_stacks: int = int(upgrade.get("max_stacks", 1))
		if current_count >= max_stacks:
			continue
		var available_upgrade: Dictionary = upgrade.duplicate(true)
		available_upgrade["current_stacks"] = current_count
		result.append(available_upgrade)
	return result


static func get_upgrade(upgrade_id: StringName) -> Dictionary:
	for upgrade: Dictionary in all_upgrades():
		if upgrade.get("id", &"") == upgrade_id:
			return upgrade
	return {}


static func get_rarity_name(rarity: int) -> String:
	match rarity:
		Rarity.RARE:
			return "稀有"
		Rarity.LEGENDARY:
			return "传说"
		_:
			return "普通"


static func _upgrade(
	id: StringName,
	name: String,
	description: String,
	max_stacks: int,
	rarity: int = Rarity.COMMON,
	weapon: StringName = &""
) -> Dictionary:
	return {
		"id": id,
		"name": name,
		"description": description,
		"max_stacks": maxi(1, max_stacks),
		"rarity": clampi(rarity, Rarity.COMMON, Rarity.LEGENDARY),
		"rarity_name": get_rarity_name(rarity),
		"weapon": weapon,
	}
