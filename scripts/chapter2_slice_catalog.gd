extends RefCounted

## Independent playable slice; no persistent run rewards are written.
const LAYOUTS := {
	&"hatchery": [Rect2(-40, 620, 1360, 100), Rect2(220, 540, 170, 34), Rect2(430, 460, 190, 36), Rect2(660, 460, 180, 36), Rect2(880, 540, 220, 34)],
	&"ember_pass": [Rect2(-40, 620, 1360, 100), Rect2(200, 530, 180, 34), Rect2(420, 440, 180, 36), Rect2(640, 350, 190, 38), Rect2(870, 440, 220, 36)],
	&"core": [Rect2(-40, 620, 1360, 100), Rect2(240, 520, 240, 26), Rect2(850, 520, 230, 26)],
	&"entry": [Rect2(-40, 620, 1360, 100), Rect2(210, 550, 160, 32), Rect2(390, 480, 160, 32), Rect2(570, 410, 240, 38), Rect2(830, 480, 160, 32), Rect2(1010, 550, 140, 32)],
	&"practice": [Rect2(-40, 620, 1360, 100), Rect2(240, 520, 220, 32), Rect2(480, 420, 180, 32), Rect2(690, 520, 220, 32)],
	&"hall": [Rect2(-40, 620, 1360, 100), Rect2(250, 520, 240, 36), Rect2(540, 420, 220, 36), Rect2(830, 520, 250, 36)],
	&"trial_gate": [Rect2(-40, 620, 1360, 100), Rect2(220, 520, 200, 36), Rect2(460, 420, 230, 36), Rect2(730, 420, 160, 36), Rect2(930, 520, 180, 36)],
	&"court": [Rect2(-40, 620, 1360, 100), Rect2(240, 540, 200, 34), Rect2(480, 460, 300, 38), Rect2(820, 540, 200, 34)],
	&"bridge": [Rect2(-40, 620, 1360, 100), Rect2(250, 520, 240, 26), Rect2(560, 420, 210, 26), Rect2(860, 520, 240, 26)],
	&"bastion": [Rect2(-40, 620, 1360, 100), Rect2(200, 530, 210, 36), Rect2(450, 440, 200, 36), Rect2(700, 440, 180, 36), Rect2(920, 530, 190, 36)],
	&"chain": [Rect2(-40, 620, 1360, 100), Rect2(260, 520, 210, 26), Rect2(540, 420, 230, 26), Rect2(850, 520, 230, 26)],
	&"ring": [Rect2(-40, 620, 1360, 100), Rect2(240, 520, 260, 26), Rect2(550, 420, 200, 26), Rect2(800, 520, 270, 26)],
}

static func rooms() -> Array[Dictionary]:
	return [
		{"id": &"forge_21", "chapter": 2, "number": 21, "title": "铸庭入口", "layout": &"entry", "goal": &"reach", "enemies": [], "heat": [Rect2(590, 580, 120, 40)], "heat_damage": false, "reward": &"none", "hint": "沿阶梯练习换层，或走下层前往出口；斜纹为排热预警，本房演示不伤人。"},
		{"id": &"forge_22", "chapter": 2, "number": 22, "title": "排热走廊", "layout": &"practice", "goal": &"clear", "enemies": [_enemy(&"basic", Vector2(830, 590), 750, 970), _enemy(&"basic", Vector2(1040, 590), 930, 1110)], "heat": [Rect2(340, 580, 120, 40)], "heat_damage": true, "reward": &"gold", "hint": "下层观察排热周期；也可跳上三段石台绕过热区，再落地接敌。"},
		{"id": &"forge_23", "chapter": 2, "number": 23, "title": "第一炉火", "layout": &"hall", "goal": &"clear", "enemies": [_enemy(&"ember_caster", Vector2(950, 492))], "heat": [], "heat_damage": false, "reward": &"gold", "hint": "熔火弹锁定落点后不再追踪；走开或换层即可躲避。"},
		{"id": &"forge_24", "chapter": 2, "number": 24, "title": "冷却仪式", "layout": &"court", "goal": &"event", "enemies": [], "heat": [], "heat_damage": false, "reward": &"ritual", "hint": "恢复生命或关闭下一房环境热区；冷却不会阻止敌人的熔火弹。"},
		{"id": &"forge_25", "chapter": 2, "number": 25, "title": "炉口试炼", "layout": &"trial_gate", "goal": &"clear", "enemies": [_enemy(&"ember_caster", Vector2(950, 492)), _enemy(&"basic", Vector2(660, 590), 560, 770), _enemy(&"basic", Vector2(1040, 590), 930, 1110)], "heat": [Rect2(380, 580, 110, 40), Rect2(780, 580, 110, 40)], "heat_damage": true, "reward": &"upgrade", "hint": "上层双台可跨过两处热区，右侧落台接近投掷者；清敌后选择强化。"},
	]

static func _enemy(kind: StringName, position: Vector2, left: float = 0, right: float = 0) -> Dictionary:
	return {"kind": kind, "position": position, "left": left, "right": right}

static func validate(data: Array[Dictionary]) -> PackedStringArray:
	var errors := PackedStringArray()
	var ids := {}
	for i in data.size():
		var room := data[i]
		if ids.has(room.get("id")) or str(room.get("id", "")).is_empty():
			errors.append("Missing or duplicate room ID")
		ids[room.get("id")] = true
		if room.get("chapter") != 2 or room.get("number") != 21 + i:
			errors.append("Invalid room sequence")
		if not LAYOUTS.has(room.get("layout")):
			errors.append("Unknown layout")
		if room.get("goal") not in [&"reach", &"clear", &"event", &"trial", &"shop", &"branch", &"boss"] or room.get("reward") not in [&"none", &"gold", &"ritual", &"upgrade", &"toll", &"rare", &"shop", &"supply", &"chapter"]:
			errors.append("Unknown goal or reward")
		var specs: Array = room.get("enemies", []).duplicate()
		for wave: Array in room.get("waves", []):
			specs.append_array(wave)
		for branch: Array in room.get("branches", []):
			specs.append_array(branch)
		for enemy: Dictionary in specs:
			if enemy.get("kind") not in [&"basic", &"ember_caster", &"forge_sentinel", &"ember_beetle", &"forge_overseer"]:
				errors.append("Enemy outside slice roster")
			var first_room := int({&"basic": 21, &"ember_caster": 23, &"forge_sentinel": 26, &"ember_beetle": 31, &"forge_overseer": 40}.get(enemy.get("kind"), 21))
			if int(room.get("number", 0)) < first_room:
				errors.append("Enemy introduced too early")
	return errors
