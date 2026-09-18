extends Node2D

## Standalone second-chapter room prototype. It is intentionally not in Main's run route yet.
const ROOM_SIZE := Vector2(1280.0, 720.0)
const PLATFORM_RECTS := [
	Rect2(-40.0, 620.0, 420.0, 100.0),
	Rect2(470.0, 620.0, 340.0, 100.0),
	Rect2(900.0, 620.0, 420.0, 100.0),
	Rect2(210.0, 470.0, 230.0, 26.0),
	Rect2(570.0, 385.0, 210.0, 26.0),
	Rect2(930.0, 460.0, 220.0, 26.0),
]
const HEAT_RECTS := [Rect2(300.0, 580.0, 120.0, 40.0), Rect2(680.0, 580.0, 110.0, 40.0), Rect2(1010.0, 580.0, 130.0, 40.0)]
var elapsed := 0.0
var cycle := 0.0
var paused := false
var player: CharacterBody2D
var heat_hits := 0
var room_index := 0
var platforms: Array = []
var heat_zones: Array = []
var terrain: Node2D
var embers: Node2D
var cast_timer := 2.5
var caster: RogueEnemy
var guard: RogueEnemy
var beetle: RogueEnemy
var ritual_open := false
var heat_disabled := false
var ritual_panel: PanelContainer
var retry_remaining := -1.0

func _on_player_died() -> void:
	retry_remaining = 1.0
	for enemy in living_enemies():
		enemy.set_physics_process(false)
	for ember in embers.get_children():
		ember.queue_free()
	queue_redraw()

func retry_room() -> void:
	var cooling := heat_disabled
	_load_layout(room_index)
	heat_disabled = cooling
	queue_redraw()

func choose_ritual(cooling: bool) -> bool:
	if not ritual_open or paused or player.is_dead():
		return false
	ritual_open = false
	ritual_panel.hide()
	if not cooling:
		player.heal(25)
	_load_layout(1, true)
	heat_disabled = cooling
	return true

func _create_ritual_ui() -> void:
	ritual_panel = PanelContainer.new()
	ritual_panel.position = Vector2(380, 210)
	ritual_panel.size = Vector2(520, 260)
	var layer := CanvasLayer.new()
	add_child(layer)
	layer.add_child(ritual_panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 20)
	ritual_panel.add_child(column)
	var title := Label.new()
	title.text = "冷却仪式 · 选择一项后前往断桥"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	for cooling in [true, false]:
		var button := Button.new()
		button.text = "关闭断桥热区 · 放弃治疗" if cooling else "恢复 25 生命 · 保留断桥热区"
		button.custom_minimum_size.y = 70
		button.pressed.connect(choose_ritual.bind(cooling))
		column.add_child(button)
	ritual_panel.hide()

func living_enemies() -> Array[RogueEnemy]:
	var result: Array[RogueEnemy] = []
	for enemy in [caster, guard, beetle]:
		if is_instance_valid(enemy):
			result.append(enemy)
	return result
const CASTER_POSITION := Vector2(860, 360)
var route_complete := false
const EXIT_POSITION := Vector2(1220, 585)

func try_exit() -> bool:
	if not living_enemies().is_empty():
		return false
	if paused or player.is_dead() or player.position.distance_to(EXIT_POSITION) > 65.0:
		return false
	if room_index == 0:
		ritual_open = true
		player.set_physics_process(false)
		ritual_panel.show()
		ritual_panel.get_child(0).get_child(1).grab_focus()
	else:
		route_complete = true
	return true
const BRIDGE_PLATFORMS := [
	Rect2(-40, 620, 320, 100), Rect2(390, 560, 170, 26),
	Rect2(660, 485, 190, 26), Rect2(950, 550, 150, 26),
	Rect2(1120, 620, 200, 100), Rect2(210, 425, 160, 26),
	Rect2(470, 330, 180, 26), Rect2(800, 330, 170, 26),
]
const HEAT_CONFIG := preload("res://scripts/chapter2_catalog.gd")
const HEAT_PERIOD := HEAT_CONFIG.HEAT_PERIOD
const HEAT_ACTIVE_START := HEAT_PERIOD - HEAT_CONFIG.HEAT_ACTIVE_SECONDS
const HEAT_WARNING_START := HEAT_ACTIVE_START - HEAT_CONFIG.HEAT_WARNING_SECONDS

func heat_is_active() -> bool:
	return not heat_disabled and cycle >= HEAT_ACTIVE_START

func _ready() -> void:
	preload("res://scripts/settings_store.gd").new().apply()
	_create_ritual_ui()
	_load_layout(0)
	player = preload("res://scenes/Player.tscn").instantiate()
	player.auto_respawn = false
	player.position = Vector2(100, 580)
	add_child(player)
	for enemy in living_enemies():
		enemy.set_target(player)
	player.attack_hit.connect(_attack_hit)
	player.skill_hit.connect(_skill_hit)
	player.died.connect(_on_player_died)
	player.set_base_ground_surface_y(620.0)
	var camera := player.get_node_or_null("Camera2D") as Camera2D
	if camera != null:
		camera.enabled = false
	queue_redraw()

func _load_layout(index: int, carry_health: bool = false) -> void:
	retry_remaining = -1.0
	heat_hits = 0
	ritual_open = false
	heat_disabled = false
	if is_instance_valid(ritual_panel):
		ritual_panel.hide()
	if is_instance_valid(beetle):
		remove_child(beetle)
		beetle.queue_free()
	beetle = null
	if posmod(index, 2) == 0:
		beetle = preload("res://scripts/forge_beetle_prototype.gd").new()
		beetle.position = Vector2(640, 598)
		add_child(beetle)
		beetle.set_target(player)
		beetle.set_physics_process(not paused)
	if is_instance_valid(guard):
		remove_child(guard)
		guard.queue_free()
	guard = null
	if posmod(index, 2) == 1:
		guard = preload("res://scripts/forge_guard_prototype.gd").new()
		guard.position = Vector2(550, 308)
		add_child(guard)
		guard.set_target(player)
		guard.set_physics_process(not paused)
	if is_instance_valid(caster):
		remove_child(caster)
		caster.queue_free()
	caster = preload("res://scripts/forge_caster_prototype.gd").new()
	caster.position = Vector2(1020, 430) if posmod(index, 2) == 0 else Vector2(740, 455)
	add_child(caster)
	caster.set_physics_process(not paused)
	room_index = posmod(index, 2)
	route_complete = false
	elapsed = 0.0
	cycle = 0.0
	cast_timer = 2.5
	if is_instance_valid(embers):
		remove_child(embers)
		embers.queue_free()
	embers = Node2D.new()
	add_child(embers)
	if is_instance_valid(terrain):
		remove_child(terrain)
		terrain.queue_free()
	terrain = Node2D.new()
	add_child(terrain)
	platforms = PLATFORM_RECTS if room_index == 0 else BRIDGE_PLATFORMS
	heat_zones = [Rect2(280, 580, 90, 40), Rect2(680, 580, 110, 40), Rect2(1010, 580, 130, 40)] if room_index == 0 else [Rect2(420, 520, 100, 40), Rect2(700, 445, 100, 40), Rect2(980, 510, 90, 40)]
	for rect: Rect2 in platforms:
		_add_platform(rect)
	if is_instance_valid(player):
		if carry_health:
			player.enter_room(Vector2(100, 580), 0)
		else:
			player.respawn()
		player.set_physics_process(not paused)
	queue_redraw()

func _add_platform(rect: Rect2) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.position = rect.get_center()
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	collision.shape = shape
	collision.one_way_collision = rect.size.y < 100.0
	if collision.one_way_collision:
		body.add_to_group("drop_through_platform")
	body.add_child(collision)
	terrain.add_child(body)

func _physics_process(delta: float) -> void:
	if paused or ritual_open:
		return
	if Input.is_action_just_pressed(&"restart"):
		retry_room()
		return
	if retry_remaining >= 0.0:
		retry_remaining -= delta
		if retry_remaining <= 0.0:
			retry_room()
		return
	if route_complete:
		return
	if player.is_dead() or route_complete:
		for ember in embers.get_children():
			ember.queue_free()
		cast_timer = 2.5
	else:
		cast_timer -= delta
		if cast_timer <= 0.0 and is_instance_valid(caster) and caster.get_current_health() > 0:
			cast_timer = 3.5
			_spawn_ember()
		for ember in embers.get_children():
			ember.advance(delta)
	if Input.is_action_just_pressed(&"interact"):
		if try_exit():
			return
	elapsed += delta
	cycle = fmod(elapsed, HEAT_PERIOD)
	if heat_is_active() and _heat_damage_enabled() and not player.is_dead():
		var player_box := Rect2(player.position - Vector2(18, 28), Vector2(36, 56))
		for heat: Rect2 in heat_zones:
			if heat.intersects(player_box):
				if player.receive_enemy_attack(heat.get_center(), HEAT_CONFIG.HEAT_DAMAGE, &"forge_heat"):
					heat_hits += 1
				break
	queue_redraw()

func _heat_damage_enabled() -> bool:
	return true

func _spawn_ember() -> void:
	if is_instance_valid(caster):
		caster.cast_pose_time = 1.52
	# Lock a supported landing point once. The marker never tracks the player.
	var point := player.position + Vector2(0, 28)
	var best_y := INF
	for surface: Rect2 in platforms:
		if point.x >= surface.position.x and point.x <= surface.end.x and surface.position.y >= point.y - 12:
			best_y = minf(best_y, surface.position.y)
	if best_y == INF:
		return
	var ember := preload("res://scripts/forge_ember.gd").new()
	ember.origin = caster.position
	ember.landing = Vector2(point.x, best_y - 12)
	ember.target = player
	embers.add_child(ember)

func _attack_hit(origin: Vector2, facing: float) -> void:
	if paused:
		return
	for enemy in living_enemies():
		if enemy.receive_player_attack(origin, facing, player.get_attack_damage(), player.get_attack_reach(), player.get_attack_type(), player.get_weapon_id()):
			player.confirm_attack_connected()
			_spawn_impact_slash(enemy, facing, 1.0)

func _skill_hit(origin: Vector2, facing: float, damage: int, reach: float) -> void:
	if not paused:
		for enemy in living_enemies():
			if enemy.receive_player_weapon_skill(origin, facing, damage, reach, player.get_weapon_id(), player.get_skill_hit_index(), player.get_skill_hit_count()):
				_spawn_impact_slash(enemy, facing, 1.25)

func _spawn_impact_slash(enemy: RogueEnemy, facing: float, strength: float) -> void:
	var effect := preload("res://scripts/combat_vfx.gd").new()
	add_child(effect)
	effect.global_position = enemy.global_position + Vector2(0, -12)
	effect.z_index = 8
	effect.play_enemy_hit(enemy, facing, strength)

func _unhandled_key_input(event: InputEvent) -> void:
	if ritual_open:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_P:
			paused = not paused
			player.set_physics_process(not paused)
			if is_instance_valid(beetle):
				beetle.set_physics_process(not paused)
			if is_instance_valid(guard):
				guard.set_physics_process(not paused)
			if is_instance_valid(caster):
				caster.set_physics_process(not paused)
			queue_redraw()
		elif event.keycode == KEY_ESCAPE:
			get_tree().quit()
		elif event.keycode == KEY_F2:
			_load_layout(room_index + 1)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, ROOM_SIZE), Color("#100d16"))
	_draw_forge_background()
	_draw_exit_marker()
	if retry_remaining >= 0:
		draw_string(ThemeDB.fallback_font, Vector2(440, 170), "挑战失败 · 正在重置本房", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("#ffd1a0"))
	if route_complete:
		draw_string(ThemeDB.fallback_font, Vector2(430, 130), _completion_text(), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("#77ead5"))
	for rect: Rect2 in platforms:
		preload("res://scripts/forge_platform_art.gd").draw_platform(self, rect)
	for heat: Rect2 in heat_zones:
		var warning := not heat_disabled and cycle >= HEAT_WARNING_START and cycle < HEAT_ACTIVE_START
		var active := heat_is_active()
		var color := Color("#ffbe62") if warning else (Color("#ff4b20") if active else Color("#8c4328"))
		if heat_disabled:
			color = Color("#77b9ce")
		draw_rect(heat, Color(color, 0.28 if active else 0.14))
		draw_line(heat.position, Vector2(heat.end.x, heat.position.y), Color(color, 0.95), 4.0)
		if warning:
			for x in range(int(heat.position.x) + 8, int(heat.end.x), 22):
				draw_line(Vector2(x, heat.end.y), Vector2(x + 8, heat.position.y), Color("#ffd78c"), 2.0)

	_draw_hud()

func _draw_exit_marker() -> void:
	var exit_open := living_enemies().is_empty()
	var exit_color := Color("#77ead5") if exit_open else Color("#88747d")
	draw_arc(EXIT_POSITION, 29, 0, TAU, 32, exit_color, 4)
	draw_string(ThemeDB.fallback_font, EXIT_POSITION + Vector2(-90, -45), "E / RB 出口" if exit_open else "清敌后开放", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, exit_color)

func _completion_text() -> String:
	return "两张地图已探索完成 · F2 重新试玩"

func _draw_hud() -> void:
	draw_string(ThemeDB.fallback_font, Vector2(34.0, 42.0), "第二章原型 · " + ("熔炉长廊" if room_index == 0 else "断裂铸桥"), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 24, Color("#f1c184"))
	draw_string(ThemeDB.fallback_font, Vector2(34.0, 70.0), "清理全部敌人后出口开放 · 敌人为占位外观 · " + ("热区已冷却" if heat_disabled else "热区预警 0.85 秒"), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 16, Color("#bd9b86"))
	if is_instance_valid(player):
		draw_string(ThemeDB.fallback_font, Vector2(34, 96), "生命 %d · 热区命中 %d" % [player.get_current_health(), heat_hits], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)
	draw_string(ThemeDB.fallback_font, Vector2(34.0, 690.0), "A/D 移动 · 空格跳跃 · K 冲刺 · F2 切换地图 · R 重置 · P 暂停 · Esc 退出", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14, Color("#d0bcc5"))

func _draw_forge_background() -> void:
	# Low-contrast architecture stays behind the bright playable platform edges.
	for i in range(7):
		var x: float = 30.0 + i * 205.0
		draw_rect(Rect2(x, 130, 125, 510), Color("#211c26"))
		draw_rect(Rect2(x + 14, 175, 97, 410), Color("#15131d"))
		for y in range(200, 600, 62):
			draw_line(Vector2(x, y), Vector2(x + 125, y), Color("#302630"), 2)
	if _uses_hall_background():
		for x in [120.0, 545.0, 1000.0]:
			draw_rect(Rect2(x, 210, 160, 330), Color("#39272b"))
			draw_circle(Vector2(x + 80, 350), 67, Color("#7d3624"))
			draw_circle(Vector2(x + 80, 350), 48, Color("#a55129"))
			for offset in range(-45, 50, 18):
				draw_line(Vector2(x + 80 + offset, 285), Vector2(x + 80 + offset, 415), Color("#29212a"), 9)
			draw_polyline(PackedVector2Array([Vector2(x + 30, 210), Vector2(x + 30, 140), Vector2(x + 185, 140)]), Color("#49353b"), 18)
	else:
		for x in [320.0, 620.0, 910.0]:
			draw_line(Vector2(x, 110), Vector2(x, 510), Color("#45363e"), 5)
			for y in range(130, 500, 28):
				draw_arc(Vector2(x, y), 8, 0, TAU, 10, Color("#59424a"), 2)
		draw_rect(Rect2(0, 625, 1280, 95), Color("#652b26"))
		for i in range(24):
			var x: float = i * 57.0
			draw_line(Vector2(x, 646 + sin(elapsed + i) * 3), Vector2(x + 34, 646 + sin(elapsed + i) * 3), Color("#bf6232"), 3)

func _uses_hall_background() -> bool:
	return room_index == 0
