extends Node2D

const WORLD_SIZE := Vector2(2200, 720)
const ENEMY_SCRIPT := preload("res://scripts/enemy.gd")
const INITIAL_ENEMY_COUNT := 7
const TESTABLE_PLATFORM_COUNT := 4
const MIN_ENEMY_X := 230.0
const MAX_ENEMY_X := 1120.0
const ENEMY_RESPAWN_DELAY := 1.35

@onready var player: RoguePlayer = $Player
@onready var controls_label: Label = $HUD/Controls

var platform_rects := [
	Rect2(-80, 640, 2420, 160),
	Rect2(300, 520, 220, 32),
	Rect2(630, 448, 180, 32),
	Rect2(920, 555, 250, 32),
	Rect2(1280, 475, 200, 32),
	Rect2(1610, 540, 240, 32),
	Rect2(1930, 420, 180, 32),
]
var _rng := RandomNumberGenerator.new()
var _enemies: Array = []
var _spawn_generation := 0


func _ready() -> void:
	_rng.randomize()
	_configure_inputs()
	_create_platform_colliders()
	player.attack_started.connect(_on_player_attack_started)
	_reset_enemies()
	queue_redraw()


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed(&"restart"):
		_reset_enemies()


func _configure_inputs() -> void:
	_register_action(&"move_left", [KEY_A, KEY_LEFT])
	_register_action(&"move_right", [KEY_D, KEY_RIGHT])
	_register_action(&"jump", [KEY_W, KEY_UP, KEY_SPACE])
	_register_action(&"attack", [KEY_J])
	_register_action(&"dash", [KEY_K])
	_register_action(&"restart", [KEY_R])


func _register_action(action: StringName, key_codes: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)

	for key_code in key_codes:
		var event := InputEventKey.new()
		event.keycode = key_code
		InputMap.action_add_event(action, event)


func _create_platform_colliders() -> void:
	for platform_index in range(platform_rects.size()):
		var rect: Rect2 = platform_rects[platform_index]
		var body := StaticBody2D.new()
		body.name = "Platform_%02d" % platform_index
		body.collision_layer = 1
		body.collision_mask = 2
		body.position = rect.get_center()

		var collision := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = rect.size
		collision.shape = shape

		body.add_child(collision)
		add_child(body)


func _reset_enemies() -> void:
	_spawn_generation += 1
	for enemy in _enemies:
		if is_instance_valid(enemy):
			enemy.queue_free()
	_enemies.clear()

	for _enemy_index in range(INITIAL_ENEMY_COUNT):
		_spawn_random_enemy()

	_update_controls()


func _spawn_random_enemy() -> void:
	var surface_limit: int = mini(TESTABLE_PLATFORM_COUNT, platform_rects.size()) - 1
	var surface_index := _rng.randi_range(0, surface_limit)
	var surface: Rect2 = platform_rects[surface_index]
	var minimum_x := maxf(surface.position.x + 42.0, MIN_ENEMY_X)
	var maximum_x := minf(surface.end.x - 42.0, MAX_ENEMY_X)
	var enemy = ENEMY_SCRIPT.new()

	enemy.name = "TestEnemy_%02d" % (_enemies.size() + 1)
	enemy.position = Vector2(
		_rng.randf_range(minimum_x, maximum_x),
		surface.position.y - 22.0
	)
	enemy.setup(_rng.randi_range(0, 2), _rng.randf_range(0.0, TAU), minimum_x, maximum_x)
	enemy.set_target(player)
	enemy.defeated.connect(_on_enemy_defeated.bind(enemy))
	add_child(enemy)
	_enemies.append(enemy)


func _on_player_attack_started(origin: Vector2, facing: float) -> void:
	for enemy in _enemies.duplicate():
		if not is_instance_valid(enemy):
			_enemies.erase(enemy)
			continue

		if enemy.is_hit_by_attack(origin, facing):
			enemy.defeat()


func _on_enemy_defeated(enemy) -> void:
	if not _enemies.has(enemy):
		return

	_enemies.erase(enemy)
	_update_controls()
	get_tree().create_timer(ENEMY_RESPAWN_DELAY).timeout.connect(
		_spawn_enemy_after_delay.bind(_spawn_generation)
	)


func _spawn_enemy_after_delay(spawn_generation: int) -> void:
	if spawn_generation != _spawn_generation:
		return

	_spawn_random_enemy()
	_update_controls()


func _update_controls() -> void:
	controls_label.text = "Move: A/D    Jump: W / Space    Attack: J (defeat enemies)    Dash: K    R: new enemies    Enemies: %d" % _enemies.size()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, WORLD_SIZE), Color("#101924"))

	# Distant silhouettes give the placeholder room a little depth.
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(0, 500), Vector2(260, 310), Vector2(520, 500),
			Vector2(790, 260), Vector2(1090, 500), Vector2(1430, 300),
			Vector2(1780, 500), Vector2(2200, 250), Vector2(2200, 640),
			Vector2(0, 640),
		]),
		Color("#17283a")
	)
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(0, 580), Vector2(370, 390), Vector2(720, 580),
			Vector2(1040, 410), Vector2(1400, 580), Vector2(1760, 360),
			Vector2(2200, 570), Vector2(2200, 640), Vector2(0, 640),
		]),
		Color("#1d3446")
	)

	for rect in platform_rects:
		var platform_rect: Rect2 = rect
		draw_rect(platform_rect, Color("#314f5e"))
		draw_rect(platform_rect, Color("#78bdc3"), false, 2.0)

	for x in range(80, int(WORLD_SIZE.x), 160):
		draw_line(Vector2(x, 120), Vector2(x, 620), Color(0.28, 0.54, 0.62, 0.08), 1.0)

	draw_circle(Vector2(140, 150), 54.0, Color("#ffd587"))
	draw_circle(Vector2(140, 150), 74.0, Color(1.0, 0.76, 0.42, 0.08))
