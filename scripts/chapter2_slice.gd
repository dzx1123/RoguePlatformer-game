extends "res://scripts/chapter2_forge_prototype.gd"

const SLICE := preload("res://scripts/chapter2_slice_catalog.gd")
var rooms: Array[Dictionary] = SLICE.rooms()
var encounter: Array[RogueEnemy] = []
var claimed: Dictionary = {}
var cooling_room := -1
var gold := 0
var room_gold := 0
var tutorial_enabled := true
var choice_kind: StringName = &""
var last_reward := ""
var input_settings := preload("res://scripts/settings_store.gd").new()
var using_controller := false

func _ready() -> void:
	assert(SLICE.validate(rooms).is_empty())
	input_settings.load_settings()
	tutorial_enabled = input_settings.get_tutorial_enabled()
	super._ready()
	input_settings.apply()

func living_enemies() -> Array[RogueEnemy]:
	var result: Array[RogueEnemy] = []
	for enemy in encounter:
		if is_instance_valid(enemy) and not enemy.is_queued_for_deletion():
			result.append(enemy)
	return result

func _load_layout(index: int, carry_health: bool = false) -> void:
	for enemy in living_enemies():
		remove_child(enemy)
		enemy.queue_free()
	encounter.clear()
	caster = null
	guard = null
	beetle = null
	for old_node in [terrain, embers]:
		if is_instance_valid(old_node):
			remove_child(old_node)
			old_node.queue_free()
	terrain = Node2D.new()
	embers = Node2D.new()
	add_child(terrain)
	add_child(embers)
	room_index = clampi(index, 0, rooms.size() - 1)
	var room := rooms[room_index]
	platforms = SLICE.LAYOUTS[room.layout]
	heat_zones = room.heat
	for rect: Rect2 in platforms:
		_add_platform(rect)
	room_gold = 0
	for spec: Dictionary in room.enemies:
		_spawn_enemy(spec)
	cycle = 0
	elapsed = 0
	cast_timer = 2.5
	heat_hits = 0
	retry_remaining = -1
	route_complete = false
	ritual_open = false
	choice_kind = &""
	heat_disabled = cooling_room == int(room.number)
	if is_instance_valid(ritual_panel):
		ritual_panel.hide()
	if is_instance_valid(player):
		if carry_health:
			player.enter_room(Vector2(100, 580), 0)
		else:
			player.respawn()
		player.set_physics_process(not paused)
	queue_redraw()

func _spawn_enemy(spec: Dictionary) -> void:
	var enemy: RogueEnemy
	match spec.kind:
		&"ember_caster":
			enemy = preload("res://scripts/forge_caster_prototype.gd").new()
			caster = enemy
		&"forge_sentinel":
			enemy = preload("res://scripts/forge_guard_prototype.gd").new()
			guard = enemy
			enemy.lane_left = spec.left
			enemy.lane_right = spec.right
		&"ember_beetle":
			enemy = preload("res://scripts/forge_beetle_prototype.gd").new()
			beetle = enemy
			enemy.lane_left = spec.left
			enemy.lane_right = spec.right
		_:
			enemy = preload("res://scripts/rogue_enemy.gd").new()
	enemy.position = spec.position
	enemy.setup(0, 0, spec.left, spec.right)
	add_child(enemy)
	enemy.set_target(player)
	enemy.set_physics_process(not paused)
	encounter.append(enemy)
	room_gold += enemy.get_gold_reward()

func _heat_damage_enabled() -> bool:
	return bool(rooms[room_index].heat_damage)

func _spawn_ember() -> void:
	# The entry and distant platforms are outside the caster's engagement range.
	if not is_instance_valid(caster) or absf(player.position.x - caster.position.x) > 530:
		return
	super._spawn_ember()

func try_exit() -> bool:
	if paused or ritual_open or route_complete or player.is_dead():
		return false
	if player.position.distance_to(EXIT_POSITION) > 65 or not living_enemies().is_empty():
		return false
	var room := rooms[room_index]
	if room.reward == &"ritual" and not claimed.has(room.id):
		_open_choice(&"ritual")
	elif room.reward == &"upgrade" and not claimed.has(room.id):
		_open_choice(&"upgrade")
	else:
		if room.reward == &"gold" and not claimed.has(room.id):
			claimed[room.id] = true
			gold += room_gold
			last_reward = "第 %d 房奖励：金币 +%d（仅本次试玩）" % [room.number, room_gold]
		_advance_room()
	return true

func _advance_room() -> void:
	if cooling_room == int(rooms[room_index].number):
		cooling_room = -1
		heat_disabled = false
	if room_index == rooms.size() - 1:
		route_complete = true
		player.set_physics_process(false)
		for ember in embers.get_children():
			ember.queue_free()
	else:
		_load_layout(room_index + 1, true)
	queue_redraw()

func _create_ritual_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	ritual_panel = PanelContainer.new()
	ritual_panel.position = Vector2(320, 210)
	ritual_panel.custom_minimum_size = Vector2(640, 250)
	layer.add_child(ritual_panel)
	ritual_panel.hide()

func _open_choice(kind: StringName) -> void:
	ritual_open = true
	choice_kind = kind
	player.set_physics_process(false)
	for child in ritual_panel.get_children():
		ritual_panel.remove_child(child)
		child.queue_free()
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 18)
	ritual_panel.add_child(column)
	var title := Label.new()
	title.text = _choice_title(kind)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	var options: Array = _choice_options(kind)
	for i in options.size():
		var button := Button.new()
		button.text = options[i]
		button.custom_minimum_size.y = 72
		button.pressed.connect(_select_option.bind(i))
		column.add_child(button)
	ritual_panel.show()
	column.get_child(1).grab_focus()
	queue_redraw()

func _choice_title(kind: StringName) -> String:
	return "冷却仪式 · 选择一项" if kind == &"ritual" else "试炼完成 · 选择一次强化"

func _choice_options(kind: StringName) -> Array:
	return ["关闭第 25 房环境热区（熔火弹仍有伤害）", "恢复 25 生命（当前实际恢复 %d）" % mini(25, player.get_max_health() - player.get_current_health())] if kind == &"ritual" else ["锋刃磨砺 · 攻击伤害 +8", "生命铸纹 · 最大生命 +20，并恢复 20"]

func _select_option(index: int) -> void:
	if choice_kind == &"ritual":
		choose_ritual(index == 0)
	else:
		choose_upgrade(&"tempered_edge" if index == 0 else &"vitality_rune")

func choose_ritual(cooling: bool) -> bool:
	if not _can_claim(&"ritual"):
		return false
	claimed[rooms[room_index].id] = true
	if cooling:
		cooling_room = 25
		last_reward = "已选择冷却：仅关闭第 25 房环境热区"
	else:
		last_reward = "冷却仪式：恢复 %d 生命" % player.heal(25)
	_close_choice()
	_advance_room()
	return true

func choose_upgrade(id: StringName) -> bool:
	if not _can_claim(&"upgrade") or id not in [&"tempered_edge", &"vitality_rune"]:
		return false
	if not player.apply_run_upgrade(id):
		return false
	claimed[rooms[room_index].id] = true
	last_reward = "强化已领取 · 仅本次试玩生效"
	_close_choice()
	_advance_room()
	return true

func _can_claim(kind: StringName) -> bool:
	return ritual_open and choice_kind == kind and not paused and not player.is_dead() and not claimed.has(rooms[room_index].id)

func _close_choice() -> void:
	ritual_open = false
	choice_kind = &""
	ritual_panel.hide()

func retry_room() -> void:
	if route_complete or ritual_open:
		return
	_load_layout(room_index)

func restart_slice() -> void:
	claimed.clear()
	cooling_room = -1
	gold = 0
	last_reward = ""
	paused = false
	player.restore_run_progression({}, player.get_max_health())
	_load_layout(0)

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_P:
			_toggle_pause()
		KEY_H:
			tutorial_enabled = not tutorial_enabled
		KEY_F2:
			if not paused and not ritual_open:
				restart_slice()
		KEY_ESCAPE:
			get_tree().quit()
	queue_redraw()

func _toggle_pause() -> void:
	paused = not paused
	player.set_physics_process(not paused and not ritual_open and not route_complete and not player.is_dead())
	for enemy in living_enemies():
		enemy.set_physics_process(not paused and not player.is_dead())
	if ritual_open:
		for control in ritual_panel.get_child(0).get_children():
			if control is Button:
				control.disabled = paused
	queue_redraw()

func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton or (event is InputEventJoypadMotion and absf(event.axis_value) > 0.3):
		using_controller = true
	elif event is InputEventKey or event is InputEventMouseButton:
		using_controller = false
	queue_redraw()

func _completion_text() -> String:
	return "第 21–%d 房试玩完成 · F2 从入口重新开始" % rooms.back().number

func _draw_hud() -> void:
	var room := rooms[room_index]
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(34, 42), "余烬铸庭 · 第 %d 房 / %d · %s" % [room.number, rooms.back().number, room.title], HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color("#f1c184"))
	var objective := _objective_text()
	draw_string(font, Vector2(34, 70), objective + (" · 环境热区已冷却" if heat_disabled else ""), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("#c9bdaf"))
	if is_instance_valid(player):
		draw_string(font, Vector2(34, 98), "生命 %d / %d · 金币 %d · 剩余敌人 %d%s" % [player.get_current_health(), player.get_max_health(), gold, living_enemies().size(), " · 已暂停" if paused else ""], HORIZONTAL_ALIGNMENT_LEFT, -1, 18)
	if tutorial_enabled:
		draw_string(font, Vector2(34, 158), room.hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("#a8d9dd"))
	draw_string(font, Vector2(34, 655), last_reward, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("#77ead5"))
	var actions := ""
	for action: StringName in [&"jump", &"attack", &"dash", &"skill", &"interact"]:
		actions += input_settings.get_action_prompt(action, using_controller) + " " + str({&"jump": "跳跃", &"attack": "攻击", &"dash": "冲刺", &"skill": "技能", &"interact": "出口"}[action]) + " · "
	draw_string(font, Vector2(34, 690), actions + "R 重试 · P 暂停 · H 提示 · F2 重新开始", HORIZONTAL_ALIGNMENT_LEFT, -1, 15)

func _draw_forge_background() -> void:
	preload("res://scripts/forge_background_art.gd").draw_background(self, rooms[room_index].layout)

func _uses_hall_background() -> bool:
	return true

func _objective_text() -> String:
	var room := rooms[room_index]
	return "清理敌人后前往出口" if room.goal == &"clear" else ("前往出口选择冷却仪式" if room.goal == &"event" else "前往出口；本房热区仅作无伤演示")
