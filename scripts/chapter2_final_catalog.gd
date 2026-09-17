extends RefCounted

const MID := preload("res://scripts/chapter2_mid_catalog.gd")
const BASE := preload("res://scripts/chapter2_slice_catalog.gd")

static func rooms() -> Array[Dictionary]:
	var result := MID.rooms()
	result.append_array([
		MID._room(36, "停炉栈道", &"chain", &"clear", &"gold", [MID._caster(950, 490), MID._basic(660), MID._basic(1040)], "光线变暗不会移除平台；先看热区斜纹，再移动换层。"),
		MID._room(37, "逆火环廊", &"ring", &"branch", &"gold", [], "在左侧路标选择上路守卫或下路双甲虫，两路奖励相同。"),
		MID._room(38, "铸庭前室", &"ring", &"clear", &"gold", [MID._guard(620), MID._caster(940, 490), MID._beetle(1020)], "三类敌人分层出现；先避开落点，利用上层绕开地面夹击。"),
		MID._room(39, "监炉门前", &"court", &"event", &"supply", [], "选择一次战前补给。首领：避开锤击和落点，冲撞后反击；半血后交替排热。"),
		MID._room(40, "监炉核心", &"core", &"boss", &"chapter", [BASE._enemy(&"forge_overseer", Vector2(870, 590))], "锤击与冲撞先锁定位置/方向；背甲变冷时反击，过载时换到安全区。"),
	])
	result[15].heat = [Rect2(400, 580, 110, 40), Rect2(780, 580, 110, 40)]
	result[15].heat_damage = true
	result[16]["branches"] = [
		[BASE._enemy(&"forge_sentinel", Vector2(650, 392), 575, 725)],
		[MID._beetle(660), MID._beetle(1020)],
	]
	result[19].heat = [Rect2(290, 580, 190, 40), Rect2(860, 580, 190, 40)]
	result[19].heat_damage = true
	return result
