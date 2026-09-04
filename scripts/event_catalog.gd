extends RefCounted

## Event-room responses. Each option is a tradeoff, not a free gift.
class_name EventCatalog


static func create_choices() -> Array[Dictionary]:
	return [
		{
			"id": &"event_rest",
			"name": "月泉献礼",
			"description": "恢复 40 点生命，但失去 8 金币",
			"effect": &"rest",
			"heal": 40,
			"gold": -8,
			"rarity_name": "事件",
		},
		{
			"id": &"event_gold",
			"name": "搜寻遗物",
			"description": "获得 28 金币，但受到 16 点伤害",
			"effect": &"gold",
			"amount": 28,
			"damage": 16,
			"rarity_name": "事件",
		},
		{
			"id": &"event_shards",
			"name": "星语契约",
			"description": "获得 3 星屑并恢复 12 生命，本局最大生命 -10",
			"effect": &"shards",
			"amount": 3,
			"heal": 12,
			"max_health": -10,
			"rarity_name": "事件",
		},
	]
