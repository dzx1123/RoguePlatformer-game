extends RefCounted

const MID := preload("res://scripts/chapter2_mid_catalog.gd")
const BASE := preload("res://scripts/chapter2_slice_catalog.gd")

static func rooms() -> Array[Dictionary]:
	var result := MID.rooms()
	result.append_array([
		MID._room(36, "停炉栈道", &"walkway", &"clear", &"gold", [MID._caster(950, 480), BASE._directional_slime(550, 720), BASE._directional_slime(1020, 1180)], "左侧台阶直通投掷台 · 地面留意史莱姆的咬击方向"),
		MID._room(37, "逆火环廊", &"ring", &"branch", &"gold", [], "在左侧路标选择路线 · 上路守卫，下路双甲虫"),
		MID._room(38, "铸庭前室", &"antechamber", &"clear", &"gold", [MID._guard(620), MID._caster(975, 452), MID._beetle(1040)], "从高台绕过守卫和甲虫 · 先处理右上方的投掷者"),
		MID._room(39, "监炉门前", &"court", &"event", &"supply", [], "前往出口领取战前补给 · 下一房对阵铸庭监炉者"),
		MID._room(40, "监炉核心", &"core", &"boss", &"chapter", [BASE._enemy(&"forge_overseer", Vector2(870, 590))], "躲过锤击和冲撞后反击 · 过载时退到中间或侧台"),
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
