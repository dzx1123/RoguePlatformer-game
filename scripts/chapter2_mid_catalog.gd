extends RefCounted

const BASE := preload("res://scripts/chapter2_slice_catalog.gd")

static func rooms() -> Array[Dictionary]:
	var result := BASE.rooms()
	result.append_array([
		_room(26, "守桥者", &"bridge", &"clear", &"gold", [_guard(740)], "守卫锁定冲撞方向后不再追踪；冲撞结束是反击窗口。"),
		_room(27, "错层铸桥", &"bridge", &"clear", &"gold", [_guard(650), _caster(970, 490)], "从上层绕行接近投掷者，下层躲开守卫冲撞。"),
		_room(28, "铸火代价", &"court", &"event", &"toll", [], "可支付 20 生命换取武器强化；生命不足时无法支付，可免费离开。"),
		_room(29, "链架侧道", &"chain", &"clear", &"gold", [_basic(760), _basic(1040)], "高处宝箱可选；落下可回到主路，清敌后出口开放。"),
		_room(30, "炉门守阵", &"bastion", &"clear", &"upgrade", [_guard(730), _basic(1010)], "两波守阵；上层双台可绕过地面冲撞，再落地反击。下一波先显示落点。"),
		_room(31, "灰烬孵场", &"hatchery", &"clear", &"gold", [_beetle(760)], "双台上方观察甲虫蜷缩，下层留出短扑与退避空间；落地黄圈变红后离开灼烧范围再反击。"),
		_room(32, "余烬夹道", &"ember_pass", &"clear", &"gold", [_beetle(660), _caster(980, 412)], "沿三层台阶绕上高处，再落到右台处理投掷者；下层保留甲虫反击空间。"),
		_room(33, "熔流试炼", &"ring", &"trial", &"rare", [], "出口处可拒绝挑战；接受后两波战斗，胜利获得稀有武器强化。"),
		_room(34, "冷却水庭", &"court", &"shop", &"shop", [], "出口处购买一次补给或直接离开；不会自动恢复生命。"),
		_room(35, "三炉联动", &"ring", &"clear", &"upgrade", [_guard(700), _beetle(1030)], "两波组合战斗；左右热区交替排热，中间与上层保留安全落脚点。"),
	])
	result[8]["chest"] = Vector2(650, 388)
	result[9]["waves"] = [[_guard(690), _basic(990)]]
	result[12]["waves"] = [[_beetle(670), _beetle(1020)], [_guard(700), _caster(960, 490)]]
	result[14]["waves"] = [[_caster(940, 490), _beetle(700)]]
	result[14]["heat"] = [Rect2(390, 580, 120, 40), Rect2(810, 580, 120, 40)]
	result[14]["heat_damage"] = true
	return result

static func _room(number: int, title: String, layout: StringName, goal: StringName, reward: StringName, enemies: Array, hint: String) -> Dictionary:
	return {"id": StringName("forge_%d" % number), "chapter": 2, "number": number, "title": title, "layout": layout, "goal": goal, "reward": reward, "enemies": enemies, "heat": [], "heat_damage": false, "hint": hint, "waves": []}

static func _basic(x: float) -> Dictionary:
	return BASE._enemy(&"basic", Vector2(x, 590), x - 90, x + 90)

static func _guard(x: float) -> Dictionary:
	return BASE._enemy(&"forge_sentinel", Vector2(x, 590), x - 160, x + 160)

static func _beetle(x: float) -> Dictionary:
	return BASE._enemy(&"ember_beetle", Vector2(x, 598), x - 140, x + 140)

static func _caster(x: float, y: float) -> Dictionary:
	return BASE._enemy(&"ember_caster", Vector2(x, y))
