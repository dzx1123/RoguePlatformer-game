extends RefCounted

## Event-room responses. Each option is a tradeoff, not a free gift.
class_name EventCatalog


static func create_choices(chapter: int = 0) -> Array[Dictionary]:
	var choices: Array[Dictionary] = [
		_rest_choice(),
		_gold_choice(),
		_shard_choice(),
	]
	if chapter >= 2:
		choices[2] = _omen_choice()
	if chapter >= 3:
		choices[0] = _blood_choice()
	return choices


static func _rest_choice() -> Dictionary:
	return {
		"id": &"event_rest",
		"name": "月泉献礼",
		"description": "恢复 40 点生命，但失去 8 金币",
		"effect": &"rest",
		"heal": 40,
		"gold": -8,
		"rarity_name": "事件",
	}


static func _gold_choice() -> Dictionary:
	return {
		"id": &"event_gold",
		"name": "搜寻遗物",
		"description": "获得 28 金币，但受到 16 点伤害",
		"effect": &"gold",
		"amount": 28,
		"damage": 16,
		"rarity_name": "事件",
	}


static func _shard_choice() -> Dictionary:
	return {
		"id": &"event_shards",
		"name": "星语契约",
		"description": "获得 3 星屑并恢复 12 生命，本局最大生命 -10",
		"effect": &"shards",
		"amount": 3,
		"heal": 12,
		"max_health": -10,
		"rarity_name": "事件",
	}


static func _omen_choice() -> Dictionary:
	return {
		"id": &"event_omen",
		"name": "赤印猎场",
		"description": "恢复 18 生命；下一房必出精英",
		"effect": &"rest",
		"heal": 18,
		"gold": 0,
		"next_encounter": "elite",
		"rarity_name": "事件",
	}


static func _blood_choice() -> Dictionary:
	return {
		"id": &"event_blood",
		"name": "焦月浴血",
		"description": "恢复 55 生命，本局最大生命 -16",
		"effect": &"rest",
		"heal": 55,
		"gold": 0,
		"max_health": -16,
		"rarity_name": "事件",
	}
