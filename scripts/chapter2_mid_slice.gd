extends "res://scripts/chapter2_slice.gd"

const MID := preload("res://scripts/chapter2_mid_catalog.gd")
const UPGRADES := preload("res://scripts/upgrade_catalog.gd")
const SHOP := preload("res://scripts/run_upgrade_service.gd")
const TOLL_COST := 20
var next_wave := 0
var wave_delay := -1.0
var trial_active := false
var offered: Array[Dictionary] = []

func _init() -> void:
	rooms = MID.rooms()

func _load_layout(index: int, carry_health: bool = false) -> void:
	next_wave = 0
	wave_delay = -1
	trial_active = false
	offered.clear()
	super._load_layout(index, carry_health)

func _waves_pending() -> bool:
	return next_wave < rooms[room_index].get("waves", []).size()

func _physics_process(delta: float) -> void:
	if not paused and not ritual_open and not route_complete and not player.is_dead():
		if int(rooms[room_index].number) == 35:
			# A single danger lane per complete warning/active cycle; center and upper routes stay safe.
			heat_zones = [rooms[room_index].heat[int(floor((elapsed + delta) / HEAT_PERIOD)) % 2]]
		if living_enemies().is_empty() and _waves_pending() and (rooms[room_index].goal != &"trial" or trial_active):
			if wave_delay < 0:
				wave_delay = 1.2
			else:
				wave_delay = maxf(0, wave_delay - delta)
				if wave_delay == 0 and _spawn_points_clear():
					for spec: Dictionary in rooms[room_index].waves[next_wave]:
						_spawn_enemy(spec)
					next_wave += 1
					wave_delay = -1
					cast_timer = 2.5
	super._physics_process(delta)

func _spawn_points_clear() -> bool:
	for spec: Dictionary in rooms[room_index].waves[next_wave]:
		if player.position.distance_to(spec.position) < 90:
			return false
	return true

func try_exit() -> bool:
	if paused or ritual_open or route_complete or player.is_dead():
		return false
	var room := rooms[room_index]
	if room.has("chest") and not claimed.has(&"chain_chest") and player.position.distance_to(room.chest) < 70:
		claimed[&"chain_chest"] = true
		gold += 15
		last_reward = "链架宝箱：金币 +15"
		return true
	if player.position.distance_to(EXIT_POSITION) > 65 or not living_enemies().is_empty():
		return false
	if room.goal == &"trial" and not trial_active and not claimed.has(room.id):
		_open_choice(&"trial")
		return true
	if _waves_pending() and (room.goal != &"trial" or trial_active):
		return false
	if not claimed.has(room.id):
		if room.reward == &"toll":
			_open_choice(&"toll")
			return true
		if room.reward == &"shop":
			_open_choice(&"shop")
			return true
		if room.reward == &"rare":
			_open_choice(&"rare")
			return true
	return super.try_exit()

func _choice_title(kind: StringName) -> String:
	match kind:
		&"toll": return "铸火代价 · 支付 20 生命选择一项（当前 %d）" % player.get_current_health()
		&"trial": return "熔流试炼 · 可拒绝；本试玩失败后重试本房"
		&"rare": return "熔流试炼完成 · 选择一次稀有武器强化"
		&"shop": return "冷却水庭旅商 · 金币 %d · 可购买一项" % gold
	return super._choice_title(kind)

func _choice_options(kind: StringName) -> Array:
	if kind == &"trial":
		return ["接受两波挑战 · 2 甲虫，再守卫 + 投掷者", "拒绝挑战 · 无奖励，安全前进"]
	if kind not in [&"toll", &"rare", &"shop"]:
		return super._choice_options(kind)
	offered.clear()
	if kind == &"shop":
		var rng := RandomNumberGenerator.new()
		rng.seed = 2034
		offered = SHOP.create_shop_offers(player.get_weapon_id(), player.get_run_upgrade_counts(), rng)
	else:
		for upgrade: Dictionary in UPGRADES.create_available_pool(player.get_weapon_id(), player.get_run_upgrade_counts()):
			if upgrade.get("weapon", &"") == player.get_weapon_id() and int(upgrade.rarity) == UPGRADES.Rarity.RARE:
				offered.append(upgrade)
				if offered.size() == 2:
					break
	var options: Array = []
	for offer: Dictionary in offered:
		var cost := "%d 金币 · " % offer.cost if kind == &"shop" else ("20 生命 · " if kind == &"toll" else "")
		options.append(cost + str(offer.name) + " · " + str(offer.description))
	if kind == &"rare":
		if offered.is_empty():
			options.append("稀有强化已满 · 改领 20 金币")
	else:
		options.append("不交易 · 直接离开")
	return options

func _select_option(index: int) -> void:
	if choice_kind in [&"toll", &"trial", &"rare", &"shop"]:
		choose_mid_option(index)
	else:
		super._select_option(index)

func choose_mid_option(index: int) -> bool:
	var kind := choice_kind
	if kind not in [&"toll", &"trial", &"rare", &"shop"] or not _can_claim(kind) or index < 0:
		return false
	if kind == &"trial":
		if index > 1:
			return false
		_close_choice()
		if index == 1:
			claimed[rooms[room_index].id] = &"declined"
			_advance_room()
		else:
			trial_active = true
			wave_delay = 1.2
			player.set_physics_process(true)
			last_reward = "挑战已接受 · 避开标记落点，等待第一波"
		return true
	if index == offered.size() and kind in [&"toll", &"shop"]:
		claimed[rooms[room_index].id] = &"declined"
		_close_choice()
		_advance_room()
		return true
	if kind == &"rare" and offered.is_empty() and index == 0:
		gold += 20
	elif index >= offered.size():
		return false
	else:
		var offer := offered[index]
		if kind == &"toll" and player.get_current_health() <= TOLL_COST:
			last_reward = "生命不足：支付后必须至少保留 1 生命，可选择不交易"
			return false
		if kind == &"shop" and gold < int(offer.cost):
			last_reward = "金币不足，可选择不交易"
			return false
		if not player.apply_run_upgrade(offer.id):
			return false
		if kind == &"toll":
			player.apply_event_cost(TOLL_COST)
		elif kind == &"shop":
			gold -= int(offer.cost)
	claimed[rooms[room_index].id] = true
	last_reward = "交易 / 奖励已结算一次"
	_close_choice()
	_advance_room()
	return true

func _objective_text() -> String:
	var room := rooms[room_index]
	if room.number <= 25:
		return super._objective_text()
	if room.goal in [&"event", &"shop"]:
		return "前往出口进行选择；可以免费离开"
	if room.goal == &"trial" and not trial_active:
		return "前往出口接受或拒绝挑战"
	if wave_delay >= 0:
		return "下一波即将出现 · 请让开地面圆环标记"
	return "清理所有波次后前往出口" if room.get("waves", []).size() > 0 else "清理敌人后前往出口"

func _draw() -> void:
	super._draw()
	var room := rooms[room_index]
	if room.has("chest"):
		var opened := claimed.has(&"chain_chest")
		draw_rect(Rect2(room.chest - Vector2(18, 12), Vector2(36, 24)), Color("#655f55") if opened else Color("#e4ba67"))
		draw_string(ThemeDB.fallback_font, room.chest + Vector2(-75, -25), "已领取" if opened else "交互：金币 +15", HORIZONTAL_ALIGNMENT_LEFT, -1, 15)
	if wave_delay >= 0 and _waves_pending():
		for spec: Dictionary in room.waves[next_wave]:
			draw_arc(spec.position + Vector2(0, 20), 35, 0, TAU, 24, Color("#ffda85"), 3)
			draw_string(ThemeDB.fallback_font, spec.position + Vector2(-38, -60), "即将出现", HORIZONTAL_ALIGNMENT_LEFT, -1, 14)
	if _waves_pending() and (room.goal != &"trial" or trial_active):
		draw_rect(Rect2(1120, 516, 160, 35), Color("#100d16"))
		draw_string(ThemeDB.fallback_font, Vector2(1130, 539), "全部波次后开放", HORIZONTAL_ALIGNMENT_LEFT, -1, 15)

func _draw_forge_background() -> void:
	super._draw_forge_background()
	var layout: StringName = rooms[room_index].layout
	if layout == &"chain":
		for x in [280, 560, 740, 1040]:
			for y in range(180, 450, 24):
				draw_arc(Vector2(x, y), 8, 0, TAU, 10, Color("#5a5259"), 2)

func _uses_hall_background() -> bool:
	return rooms[room_index].layout != &"bridge"
