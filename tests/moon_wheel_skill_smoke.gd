extends SceneTree

const GEOMETRY := preload("res://scripts/moon_wheel_geometry.gd")

var _skill_hit_count: int = 0


func _initialize() -> void:
	call_deferred(&"_run_test")


func _run_test() -> void:
	var required_actions: Array[StringName] = [
		&"restart",
		&"move_left",
		&"move_right",
		&"jump",
		&"dash",
		&"attack",
		&"skill",
	]
	for action_name in required_actions:
		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name)

	var player_scene: PackedScene = load("res://scenes/Player.tscn")
	var player: RoguePlayer = player_scene.instantiate() as RoguePlayer
	root.add_child(player)
	player.set_physics_process(false)
	player.skill_hit.connect(_on_skill_hit)
	await process_frame

	var skill_duration: float = float(player.get("_skill_duration"))
	player.set("_skill_remaining", skill_duration * 0.30)
	player.call(&"_update_hero_visuals", 1.0 / 60.0)
	var effect := player.get_node("MoonWheelEffect") as MoonWheelEffect
	if effect == null or not effect.is_effect_active():
		_fail("Moon-wheel effect did not activate with the skill")
		return
	var expected_radii: Vector2 = player.get_skill_hit_radii()
	if effect.get_hit_radii().distance_to(expected_radii) > 0.01:
		_fail("Visible moon-wheel radii differ from the combat radii")
		return
	var expected_center: Vector2 = GEOMETRY.get_local_center(1.0)
	if effect.get_effect_center().distance_to(expected_center) > 0.01:
		_fail("Visible moon-wheel center differs from the combat center")
		return
	player.set("_skill_hit_emitted", false)
	player.set("_skill_remaining", skill_duration * 0.31)
	player.call(&"_update_timers", 0.0)
	if _skill_hit_count != 0:
		_fail("Moon-wheel dealt damage before the dark-moon shatter frame")
		return
	player.set("_skill_remaining", skill_duration * 0.29)
	player.call(&"_update_timers", 0.0)
	player.call(&"_update_timers", 0.0)
	if _skill_hit_count != 1:
		_fail("Dark-moon shatter did not emit exactly one skill hit")
		return

	var enemy := RogueEnemy.new()
	root.add_child(enemy)
	enemy.setup(0, 0.0, -500.0, 500.0)
	await process_frame
	var origin := Vector2.ZERO
	var world_center: Vector2 = GEOMETRY.get_world_center(origin, 1.0)
	var reach_scale: float = float(player.get("_skill_reach"))

	enemy.global_position = world_center + Vector2(expected_radii.x - 18.0, 0.0)
	if not enemy.is_hit_by_skill(origin, 1.0, reach_scale):
		_fail("Moon-wheel rejected a target inside the visible front arc")
		return
	enemy.global_position = world_center - Vector2(expected_radii.x - 18.0, 0.0)
	if not enemy.is_hit_by_skill(origin, 1.0, reach_scale):
		_fail("Moon-wheel rejected a target inside the visible rear arc")
		return
	enemy.global_position = world_center + Vector2(0.0, -expected_radii.y + 16.0)
	if not enemy.is_hit_by_skill(origin, 1.0, reach_scale):
		_fail("Moon-wheel rejected a target inside the visible upper arc")
		return
	enemy.global_position = world_center + Vector2(expected_radii.x + 70.0, 0.0)
	if enemy.is_hit_by_skill(origin, 1.0, reach_scale):
		_fail("Moon-wheel hit a target clearly outside the visible arc")
		return
	enemy.global_position = world_center + Vector2(expected_radii.x * 0.55, 0.0)
	var health_before: int = enemy.get_current_health()
	if not enemy.receive_player_skill(origin, 1.0, 12, reach_scale):
		_fail("Moon-wheel combat path rejected an enemy inside the visible arc")
		return
	if enemy.get_current_health() != health_before - 12:
		_fail("Moon-wheel combat path did not apply its damage exactly once")
		return

	enemy.queue_free()
	player.queue_free()
	await process_frame
	print("moon_wheel_skill_smoke: PASS")
	quit(0)


func _on_skill_hit(_origin: Vector2, _facing: float, _damage: int, _reach: float) -> void:
	_skill_hit_count += 1


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
