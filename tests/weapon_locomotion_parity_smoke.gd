extends SceneTree

const WEAPON_DIRS := {
	WeaponCatalog.TWIN_BLADES: "res://assets/characters/weapon_sets/twin_blades",
	WeaponCatalog.GREATSWORD: "res://assets/characters/weapon_sets/greatsword",
}
const RUN_FRAME_COUNT := 12
const SIMULATION_FRAMES := 20 * 60

var _failures: Array[String] = []


func _init() -> void:
	_run_test()


func _run_test() -> void:
	for action_name: StringName in [&"restart", &"move_left", &"move_right", &"jump", &"dash", &"attack", &"skill"]:
		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name)

	var player_scene := load("res://scenes/Player.tscn") as PackedScene
	var player := player_scene.instantiate() as RoguePlayer
	root.add_child(player)
	await process_frame
	player.set_physics_process(false)
	var sprite := player.get_node("HeroSprite") as Sprite2D

	var canonical_run: Dictionary = {}
	player.configure_weapon(WeaponCatalog.SWORD)
	for facing in [-1.0, 1.0]:
		for frame_index in range(RUN_FRAME_COUNT):
			canonical_run[_run_key(facing, frame_index)] = _sample_run(
				player,
				sprite,
				frame_index,
				facing
			)

	var air_cases: Array[Dictionary] = [
		{"label": "takeoff", "method": &"_animate_jump_rise", "time": 0.02, "velocity_y": -500.0},
		{"label": "rise", "method": &"_animate_jump_rise", "time": 0.20, "velocity_y": -400.0},
		{"label": "apex", "method": &"_animate_jump_rise", "time": 0.20, "velocity_y": -80.0},
		{"label": "fall", "method": &"_animate_jump_fall", "time": 0.20, "velocity_y": 420.0},
	]
	var canonical_air: Dictionary = {}
	for facing in [-1.0, 1.0]:
		for case_data: Dictionary in air_cases:
			canonical_air[_air_key(facing, String(case_data["label"]))] = _sample_air(
				player,
				sprite,
				case_data,
				facing
			)

	for weapon_id: StringName in WEAPON_DIRS:
		player.configure_weapon(weapon_id)
		var directory: String = WEAPON_DIRS[weapon_id]
		for facing in [-1.0, 1.0]:
			for frame_index in range(RUN_FRAME_COUNT):
				var actual := _sample_run(player, sprite, frame_index, facing)
				var expected: Dictionary = canonical_run[_run_key(facing, frame_index)]
				_expect_same_transform(actual, expected, "%s run %d" % [weapon_id, frame_index])
				_expect_path(
					sprite,
					"%s/hero_run_%d.png" % [directory, frame_index],
					"%s run %d" % [weapon_id, frame_index]
				)

			for case_data: Dictionary in air_cases:
				var label: String = case_data["label"]
				var actual := _sample_air(player, sprite, case_data, facing)
				var expected: Dictionary = canonical_air[_air_key(facing, label)]
				_expect_same_transform(actual, expected, "%s %s" % [weapon_id, label])

		_run_twenty_second_cycle(player, sprite, weapon_id, directory)

	player.queue_free()
	if _failures.is_empty():
		print("weapon_locomotion_parity_smoke: PASS 20s_cycles=%d" % WEAPON_DIRS.size())
		quit(0)
		return
	for failure: String in _failures:
		print("weapon_locomotion_parity_smoke: FAIL: ", failure)
	quit(1)


func _sample_run(
	player: RoguePlayer,
	sprite: Sprite2D,
	frame_index: int,
	facing: float
) -> Dictionary:
	player.set("_facing", facing)
	player.set("_turn_remaining", 0.0)
	player.set("_run_start_remaining", 0.0)
	player.set("_run_cycle", float(frame_index))
	player.call(&"_reset_sprite_pose")
	player.call(&"_animate_run")
	return _sprite_transform(sprite)


func _sample_air(
	player: RoguePlayer,
	sprite: Sprite2D,
	case_data: Dictionary,
	facing: float
) -> Dictionary:
	player.set("_facing", facing)
	player.set("_turn_remaining", 0.0)
	player.set("_airborne_time", float(case_data["time"]))
	player.velocity.y = float(case_data["velocity_y"])
	player.call(&"_reset_sprite_pose")
	player.call(case_data["method"])
	return _sprite_transform(sprite)


func _run_twenty_second_cycle(
	player: RoguePlayer,
	sprite: Sprite2D,
	weapon_id: StringName,
	directory: String
) -> void:
	var counts := PackedInt32Array()
	counts.resize(RUN_FRAME_COUNT)
	var cycle := 0.0
	var previous_index := -1
	for sample_index in range(SIMULATION_FRAMES):
		cycle = fposmod(cycle + 0.64, float(RUN_FRAME_COUNT))
		var facing := -1.0 if int(sample_index / 300) % 2 == 1 else 1.0
		player.set("_facing", facing)
		player.set("_turn_remaining", 0.0)
		player.set("_run_start_remaining", 0.0)
		player.set("_run_cycle", cycle)
		player.call(&"_reset_sprite_pose")
		player.call(&"_animate_run")
		var frame_index := int(floor(cycle))
		counts[frame_index] += 1
		_expect_path(
			sprite,
			"%s/hero_run_%d.png" % [directory, frame_index],
			"%s 20s sample %d" % [weapon_id, sample_index]
		)
		if sprite.flip_h != (facing < 0.0):
			_failures.append("%s lost facing at sample %d" % [weapon_id, sample_index])
		if previous_index >= 0:
			var frame_advance := posmod(frame_index - previous_index, RUN_FRAME_COUNT)
			if frame_advance > 1:
				_failures.append(
					"%s skipped run frame %d -> %d" % [weapon_id, previous_index, frame_index]
				)
		previous_index = frame_index
	for frame_index in range(RUN_FRAME_COUNT):
		if counts[frame_index] == 0:
			_failures.append("%s 20s cycle missed run frame %d" % [weapon_id, frame_index])


func _sprite_transform(sprite: Sprite2D) -> Dictionary:
	return {
		"position": sprite.position,
		"scale": sprite.scale,
		"rotation": sprite.rotation,
		"flip_h": sprite.flip_h,
	}


func _expect_same_transform(actual: Dictionary, expected: Dictionary, label: String) -> void:
	var actual_position: Vector2 = actual["position"]
	var expected_position: Vector2 = expected["position"]
	var actual_scale: Vector2 = actual["scale"]
	var expected_scale: Vector2 = expected["scale"]
	if (
		actual_position.distance_to(expected_position) > 0.001
		or actual_scale.distance_to(expected_scale) > 0.0001
		or absf(float(actual["rotation"]) - float(expected["rotation"])) > 0.0001
		or bool(actual["flip_h"]) != bool(expected["flip_h"])
	):
		_failures.append("%s diverged from one-hand locomotion transform" % label)


func _expect_path(sprite: Sprite2D, expected: String, label: String) -> void:
	if sprite.texture == null or sprite.texture.resource_path != expected:
		_failures.append(
			"%s expected %s, got %s"
			% [label, expected, sprite.texture.resource_path if sprite.texture else "<null>"]
		)


func _run_key(facing: float, frame_index: int) -> String:
	return "%d:%d" % [int(facing), frame_index]


func _air_key(facing: float, label: String) -> String:
	return "%d:%s" % [int(facing), label]
