extends "res://scripts/chapter2_mid_slice.gd"

const FINAL := preload("res://scripts/chapter2_final_catalog.gd")
const BOSS := preload("res://scripts/forge_overseer_prototype.gd")
var overseer: RogueEnemy
var branch_choices: Dictionary = {}
var overheat := false
const BRANCH_SIGN := Vector2(300, 585)

func _init() -> void:
	rooms = FINAL.rooms()

func _load_layout(index: int, carry_health: bool = false) -> void:
	overseer = null
	overheat = false
	if index == 16:
		rooms[16].enemies = rooms[16].branches[int(branch_choices[37])] if branch_choices.has(37) else []
	super._load_layout(index, carry_health)
	if index == 19:
		heat_zones = []

func _spawn_enemy(spec: Dictionary) -> void:
	if spec.kind != &"forge_overseer":
		super._spawn_enemy(spec)
		return
	overseer = BOSS.new()
	overseer.position = spec.position
	add_child(overseer)
	overseer.set_target(player)
	overseer.set_physics_process(not paused)
	overseer.ember_requested.connect(_spawn_boss_ember)
	overseer.hazards_cleared.connect(_clear_boss_hazards)
	overseer.overheat_started.connect(_start_overheat)
	encounter.append(overseer)

func _clear_boss_hazards() -> void:
	overheat = false
	heat_zones = []
	if is_instance_valid(embers):
		for ember in embers.get_children():
			embers.remove_child(ember)
			ember.queue_free()

func _start_overheat() -> void:
	overheat = true
	elapsed = 0
	cycle = 0

func _spawn_boss_ember(origin: Vector2, target_position: Vector2) -> void:
	if paused or player.is_dead() or not is_instance_valid(overseer) or overseer.get_current_health() <= 0:
		return
	var x := clampf(target_position.x, 100, 1180)
	var y := 620.0
	for surface: Rect2 in platforms:
		if x >= surface.position.x and x <= surface.end.x and surface.position.y >= target_position.y + 16:
			y = minf(y, surface.position.y)
	var ember := preload("res://scripts/forge_ember.gd").new()
	ember.origin = origin
	ember.landing = Vector2(x, y - 12)
	ember.target = player
	embers.add_child(ember)

func _physics_process(delta: float) -> void:
	if room_index == 19 and not paused and not ritual_open:
		if overheat and is_instance_valid(overseer) and overseer.get_current_health() > 0 and not player.is_dead():
			heat_zones = [rooms[19].heat[int(floor((elapsed + delta) / HEAT_PERIOD)) % 2]]
		else:
			heat_zones = []
	super._physics_process(delta)

func try_exit() -> bool:
	if paused or ritual_open or route_complete or player.is_dead():
		return false
	if room_index == 16 and not branch_choices.has(37):
		if player.position.distance_to(BRANCH_SIGN) < 75:
			_open_choice(&"branch")
			return true
		return false
	if player.position.distance_to(EXIT_POSITION) <= 65 and living_enemies().is_empty():
		var room := rooms[room_index]
		if room_index == 18 and not claimed.has(room.id):
			_open_choice(&"supply")
			return true
		if room_index in [16, 19] and not claimed.has(room.id):
			gold += 12 if room_index == 16 else 30
			claimed[room.id] = true
			last_reward = "支路奖励：金币 +12" if room_index == 16 else "首领奖励：金币 +30 · 第二章试玩完成 · 第三章待开放"
	return super.try_exit()

func _choice_title(kind: StringName) -> String:
	if kind == &"branch":
		return "逆火环廊 · 两路均奖励 12 金币"
	if kind == &"supply":
		return "战前补给 · 生命 %d/%d · 攻击 %d · 强化 %d" % [player.get_current_health(), player.get_max_health(), player.get_attack_damage(), player.get_total_run_upgrade_count()]
	return super._choice_title(kind)

func _choice_options(kind: StringName) -> Array:
	if kind == &"branch":
		return ["上路 · 高台上的 1 名守卫", "下路 · 宽阔地面的 2 只甲虫"]
	if kind == &"supply":
		return ["恢复 40 生命（实际 %d）" % mini(40, player.get_max_health() - player.get_current_health()), "生命铸纹 · 最大生命及当前生命 +20（满层改领 15 金币）"]
	return super._choice_options(kind)

func _select_option(index: int) -> void:
	if choice_kind in [&"branch", &"supply"]:
		choose_final_option(index)
	else:
		super._select_option(index)

func choose_final_option(index: int) -> bool:
	var kind := choice_kind
	if index not in [0, 1] or kind not in [&"branch", &"supply"] or not _can_claim(kind):
		return false
	if kind == &"branch":
		branch_choices[37] = index
		rooms[16].enemies = rooms[16].branches[index]
		for spec: Dictionary in rooms[16].enemies:
			_spawn_enemy(spec)
		_close_choice()
		player.set_physics_process(true)
		last_reward = "已选择上路；仅需击败高台守卫" if index == 0 else "已选择下路；仅需击败两只甲虫"
	else:
		if index == 0:
			last_reward = "战前补给：恢复 %d 生命" % player.heal(40)
		elif not player.apply_run_upgrade(&"vitality_rune"):
			gold += 15
			last_reward = "生命铸纹已满层：金币 +15"
		else:
			last_reward = "战前补给：最大生命 +20"
		claimed[rooms[room_index].id] = true
		_close_choice()
		_advance_room()
	return true

func restart_slice() -> void:
	branch_choices.clear()
	rooms = FINAL.rooms()
	super.restart_slice()

func _objective_text() -> String:
	if route_complete:
		return "第二章独立试玩已结算 · F2 可重新开始"
	if room_index == 16:
		return "在左侧路标交互，选择路线" if not branch_choices.has(37) else ("清理上路守卫，再前往出口" if branch_choices[37] == 0 else "清理下路两只甲虫，再前往出口")
	if room_index == 18:
		return "出口领取一次补给；下一房为章节首领"
	if room_index == 19:
		return "击败铸庭监炉者后前往出口" + (" · 核心过载，左右交替排热" if overheat else "")
	return super._objective_text()

func _completion_text() -> String:
	return "第二章试玩完成 · 第三章待开放"

func _draw() -> void:
	super._draw()
	if room_index == 16 and not branch_choices.has(37):
		draw_line(BRANCH_SIGN, BRANCH_SIGN - Vector2(0, 80), Color("#8ce1d5"), 5)
		draw_string(ThemeDB.fallback_font, BRANCH_SIGN - Vector2(80, 100), "交互：上路 / 下路", HORIZONTAL_ALIGNMENT_LEFT, -1, 18)
	if route_complete:
		draw_rect(Rect2(300, 240, 680, 190), Color("#19212b"))
		draw_string(ThemeDB.fallback_font, Vector2(380, 295), "余烬铸庭 · 20 房独立试玩已完成", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color("#ffce92"))
		draw_string(ThemeDB.fallback_font, Vector2(380, 338), "金币 %d · 强化 %d · 第三章待开放" % [gold, player.get_total_run_upgrade_count()], HORIZONTAL_ALIGNMENT_LEFT, -1, 21)
		draw_string(ThemeDB.fallback_font, Vector2(380, 390), "F2 重新试玩 · 当前未写入正式通关进度", HORIZONTAL_ALIGNMENT_LEFT, -1, 18)

func _draw_forge_background() -> void:
	super._draw_forge_background()
	if room_index == 15:
		# Background pass only: platform edges, actors and warnings are drawn afterward.
		draw_rect(Rect2(0, 110, 1280, 510), Color(0.02, 0.025, 0.05, 0.45))
