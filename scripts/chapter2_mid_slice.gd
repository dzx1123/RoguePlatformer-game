extends "res://scripts/chapter2_slice.gd"

const MID := preload("res://scripts/chapter2_mid_catalog.gd")
const UPGRADES := preload("res://scripts/upgrade_catalog.gd")
const SHOP := preload("res://scripts/run_upgrade_service.gd")
const TOLL_COST := 20
const TRIAL_FALLBACK_GOLD := 20
const CHEST_REACH := 70.0
const CHEST_GOLD := 15
const WAVE_WARNING_SECONDS := 1.2
const WAVE_CLEARANCE := 90.0
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
				wave_delay = WAVE_WARNING_SECONDS
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
		if _wave_point_occupied(spec.position):
			return false
	return true

func _wave_point_occupied(point: Vector2) -> bool:
	return player.position.distance_squared_to(point) < WAVE_CLEARANCE * WAVE_CLEARANCE

func try_exit() -> bool:
	if paused or ritual_open or route_complete or player.is_dead():
		return false
	var room := rooms[room_index]
	if room.has("chest") and not claimed.has(&"chain_chest") and _at_side_chest(room.chest):
		claimed[&"chain_chest"] = true
		gold += CHEST_GOLD
		last_reward = "链架宝箱 · 金币 +%d" % CHEST_GOLD
		return true
	if not _at_exit() or not living_enemies().is_empty():
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
		offered = _available_weapon_rares().slice(0, 2)
	var options: Array = []
	for offer: Dictionary in offered:
		var cost := "%d 金币 · " % offer.cost if kind == &"shop" else ("20 生命 · " if kind == &"toll" else "")
		options.append(cost + str(offer.name) + " · " + str(offer.description))
	if kind == &"rare":
		if offered.is_empty():
			options.append("稀有强化已满 · 改领 %d 金币" % TRIAL_FALLBACK_GOLD)
	else:
		options.append("不交易 · 直接离开")
	return options

func _available_weapon_rares() -> Array[Dictionary]:
	var weapon: StringName = player.get_weapon_id()
	var pool := UPGRADES.create_available_pool(weapon, player.get_run_upgrade_counts())
	return pool.filter(func(upgrade: Dictionary) -> bool:
		return upgrade.weapon == weapon and int(upgrade.rarity) == UPGRADES.Rarity.RARE
	)

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
			wave_delay = WAVE_WARNING_SECONDS
			player.set_physics_process(true)
			last_reward = "挑战已接受 · 避开标记落点，等待第一波"
		return true
	if index == offered.size() and kind in [&"toll", &"shop"]:
		claimed[rooms[room_index].id] = &"declined"
		_close_choice()
		_advance_room()
		return true
	var outcome := "交易 / 奖励已结算一次"
	if kind == &"rare" and offered.is_empty() and index == 0:
		gold += TRIAL_FALLBACK_GOLD
		outcome = "稀有强化已满层 · 金币 +%d" % TRIAL_FALLBACK_GOLD
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
		elif kind == &"rare":
			outcome = "已获得「%s」" % offer.name
	claimed[rooms[room_index].id] = true
	last_reward = outcome
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
		return "下一波即将出现 · 请让开增援落点"
	return "清理所有波次后前往出口" if room.get("waves", []).size() > 0 else "清理敌人后前往出口"

func _draw() -> void:
	super._draw()
	var room := rooms[room_index]
	if room.has("chest"):
		_draw_side_chest(room.chest)
	if wave_delay >= 0 and _waves_pending():
		for spec: Dictionary in room.waves[next_wave]:
			_draw_wave_warning(spec.position, platforms[0].position.y)

func _at_side_chest(point: Vector2) -> bool:
	return is_instance_valid(player) and player.position.distance_squared_to(point) < CHEST_REACH * CHEST_REACH

func _side_chest_prompt(point: Vector2) -> String:
	if claimed.has(&"chain_chest"):
		return "宝箱已领取"
	if _at_side_chest(point):
		return "%s 打开 · 金币 +%d" % [input_settings.get_action_prompt(&"interact", using_controller), CHEST_GOLD]
	return "高处宝箱 · 金币 +%d" % CHEST_GOLD

func _draw_side_chest(point: Vector2) -> void:
	var opened := claimed.has(&"chain_chest")
	var chest_base := point + Vector2(0, 32)
	var edge := Color("#7390a0") if opened else Color("#e8b45a")
	var body := Rect2(chest_base - Vector2(23, 28), Vector2(46, 28))
	draw_rect(body, Color("#132a3a"))
	draw_rect(body, edge, false, 2.0)
	var lid_y := -39.0 if opened else -28.0
	draw_rect(Rect2(chest_base + Vector2(-25, lid_y), Vector2(50, 9)), Color("#29495a"))
	draw_line(chest_base + Vector2(-24, lid_y), chest_base + Vector2(24, lid_y), edge, 2.0)
	for x in [-14, 14]:
		draw_line(chest_base + Vector2(x, -26), chest_base + Vector2(x, -2), edge, 2.0)
	if not opened:
		draw_rect(Rect2(chest_base + Vector2(-4, -21), Vector2(8, 10)), edge)
	var plate := Rect2(point - Vector2(115, 83), Vector2(230, 30))
	draw_rect(plate, Color("#111e26"))
	draw_rect(plate, edge, false, 1.0)
	draw_string(ThemeDB.fallback_font, plate.position + Vector2(5, 21), _side_chest_prompt(point), HORIZONTAL_ALIGNMENT_CENTER, plate.size.x - 10.0, 16, edge)

func _wave_warning_label(point: Vector2) -> String:
	return "让开落点" if wave_delay == 0.0 and _wave_point_occupied(point) else "增援落点"

func _draw_wave_warning(point: Vector2, floor_y: float) -> void:
	# Draw the same exclusion circle checked at spawn, clipped to the playable floor.
	var allowance := asin(clampf((floor_y - point.y) / WAVE_CLEARANCE, -1.0, 1.0))
	var outline := PackedVector2Array()
	var is_clipped := floor_y < point.y + WAVE_CLEARANCE
	for index in range(41 if is_clipped else 40):
		var angle := lerpf(PI - allowance, TAU + allowance, float(index) / 40.0)
		outline.append(point + WAVE_CLEARANCE * Vector2.from_angle(angle))
	var color := Color("#ffad65") if wave_delay == 0.0 else Color("#ffda85")
	draw_colored_polygon(outline, Color(color, 0.10))
	outline.append(outline[0])
	draw_polyline(outline, Color(color, 0.78), 2.0, true)
	var marker := PackedVector2Array([point - Vector2(0, 13), point + Vector2(13, 0), point + Vector2(0, 13), point - Vector2(13, 0), point - Vector2(0, 13)])
	draw_polyline(marker, color, 2.0, true)
	var plate := Rect2(point - Vector2(58, 103), Vector2(116, 29))
	draw_rect(plate, Color("#201a23"))
	draw_string(ThemeDB.fallback_font, plate.position + Vector2(4, 20), _wave_warning_label(point), HORIZONTAL_ALIGNMENT_CENTER, plate.size.x - 8.0, 15, color)
	var progress := 1.0 - clampf(wave_delay / WAVE_WARNING_SECONDS, 0.0, 1.0)
	if progress > 0.0:
		draw_rect(Rect2(plate.position.x, plate.end.y - 2.0, plate.size.x * progress, 2.0), color)

func _draw_forge_background() -> void:
	super._draw_forge_background()
	var layout: StringName = rooms[room_index].layout
	if layout == &"chain":
		for x in [280, 560, 740, 1040]:
			for y in range(180, 450, 24):
				draw_arc(Vector2(x, y), 8, 0, TAU, 10, Color("#5a5259"), 2)
	elif layout == &"walkway":
		for surface in platforms.slice(1):
			for x in [surface.position.x + 18, surface.end.x - 18]:
				draw_line(Vector2(x, 0), Vector2(x, surface.position.y), Color("#221b1b"), 2.0)
				for y in range(4, int(surface.position.y) - 8, 16):
					var link_width := 7.0 if y % 32 == 4 else 3.0
					var link := Rect2(x - link_width * 0.5, y, link_width, 10)
					draw_rect(link, Color("#51403a"), false, 1.0)

func _uses_hall_background() -> bool:
	return rooms[room_index].layout != &"bridge"
