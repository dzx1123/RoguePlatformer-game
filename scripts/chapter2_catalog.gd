extends RefCounted

## 第二章设计包：先作为独立原型数据保存，不进入当前 20 房正式路线。
class_name Chapter2Catalog

const THEME := {
	"id": &"ember_forge",
	"title": "第二章·余烬铸庭",
	"palette": Color("#d49a5a"),
	"hazard": &"heat_zone",
	"enemies": [&"ember_caster", &"forge_sentinel", &"ember_beetle"],
}

static func room_prototypes() -> Array[Dictionary]:
	return [
		{
			"id": &"ember_forge_hall",
			"title": "熔炉长廊",
			"theme": THEME["id"],
			"layout_rule": "multi_level_heat_lanes",
			"hazard_warning_seconds": 0.85,
			"hazard_active_seconds": 0.55,
			"hazard_damage": 8,
			"memory_hook": "周期热区迫使玩家换层",
		},
		{
			"id": &"fractured_cast_bridge",
			"title": "断裂铸桥",
			"theme": THEME["id"],
			"layout_rule": "broken_ground_air_control",
			"hazard_warning_seconds": 0.65,
			"hazard_active_seconds": 0.40,
			"hazard_damage": 10,
			"memory_hook": "断桥间隙鼓励冲刺和空中调整",
		},
	]

static func enemy_prototype() -> Dictionary:
	return {
		"id": &"ember_caster",
		"name": "熔火投掷者",
		"role": "ranged_space_control",
		"telegraph_seconds": 0.72,
		"attack_pattern": "lobbed_ember_arc",
		"counterplay": "保持移动，利用平台高度或冲刺穿过落点",
		"first_room": 23,
	}

static func enemy_roster() -> Array[Dictionary]:
	return [
		enemy_prototype(),
		{"id": &"forge_sentinel", "name": "铸炉守卫", "role": "melee_charge", "telegraph_seconds": 0.80, "counterplay": "闪避冲撞后攻击背部"},
		{"id": &"ember_beetle", "name": "余烬甲虫", "role": "fast_swarmer", "telegraph_seconds": 0.45, "counterplay": "优先清理，避免灼烧叠加"},
	]

static func event_prototypes() -> Array[Dictionary]:
	return [
		{"id": &"forge_toll", "title": "铸火代价", "choice": "失去生命换取武器专属强化"},
		{"id": &"cooling_ritual", "title": "冷却仪式", "choice": "关闭下一房热区，放弃部分金币"},
		{"id": &"molten_trial", "title": "熔流试炼", "choice": "接受精英挑战，获得稀有强化"},
	]
