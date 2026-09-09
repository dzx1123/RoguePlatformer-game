extends SceneTree

const WEAPON_DIRS := {
	&"twin_blades": "res://assets/characters/weapon_sets/twin_blades",
	&"star_greatsword": "res://assets/characters/weapon_sets/greatsword",
}
const CANVAS_WIDTHS := {
	&"twin_blades": 640,
	&"star_greatsword": 768,
}
const POSE_NAMES := [
	"hero_idle",
	"hero_jump_takeoff", "hero_jump_rise", "hero_jump_apex", "hero_jump_fall", "hero_land",
	"hero_attack_recovery",
	"hero_attack_forward_windup", "hero_attack_forward_strike", "hero_attack_forward_follow",
	"hero_attack_up_windup", "hero_attack_up_strike", "hero_attack_up_follow",
	"hero_attack_down_windup", "hero_attack_down_strike", "hero_attack_down_follow",
	"hero_skill_a", "hero_skill_b",
]
const TWIN_SKILL_SAMPLES: Array[float] = [
	0.02,
	0.075,
	0.12,
	0.18,
	0.28,
	0.48,
	0.585,
	0.67,
	0.73,
	0.78,
	0.88,
	0.96,
]

var _failures: Array[String] = []


func _init() -> void:
	_run_test()


func _run_test() -> void:
	for action_name: StringName in [&"restart", &"move_left", &"move_right", &"jump", &"dash", &"attack", &"skill"]:
		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name)

	for weapon_id: StringName in WEAPON_DIRS:
		_validate_asset_set(weapon_id)

	var player_scene: PackedScene = load("res://scenes/Player.tscn")
	var player: RoguePlayer = player_scene.instantiate() as RoguePlayer
	root.add_child(player)
	await process_frame
	player.set_physics_process(false)
	var hero_sprite: Sprite2D = player.get_node("HeroSprite") as Sprite2D
	var skill_pose_echo: Sprite2D = player.get_node("SkillPoseEcho") as Sprite2D
	var weapon_effect: WeaponSkillEffect = player.get_node("WeaponSkillEffect") as WeaponSkillEffect
	if hero_sprite.texture_filter != CanvasItem.TEXTURE_FILTER_NEAREST:
		_failures.append("HeroSprite is not locked to nearest-neighbor filtering")
	if skill_pose_echo.texture_filter != CanvasItem.TEXTURE_FILTER_NEAREST:
		_failures.append("SkillPoseEcho is not locked to nearest-neighbor filtering")

	for weapon_id: StringName in WEAPON_DIRS:
		var directory: String = WEAPON_DIRS[weapon_id]
		if not player.configure_weapon(weapon_id):
			_failures.append("configure_weapon failed: %s" % weapon_id)
			continue

		player.call(&"_reset_sprite_pose")
		player.call(&"_animate_idle")
		_expect_path(hero_sprite, "%s/hero_idle.png" % directory, "idle")

		var run_paths: Dictionary = {}
		for frame_index in range(12):
			player.set("_run_cycle", float(frame_index))
			player.call(&"_reset_sprite_pose")
			player.call(&"_animate_run")
			var expected_path := "%s/hero_run_%d.png" % [directory, frame_index]
			_expect_path(hero_sprite, expected_path, "run %d" % frame_index)
			run_paths[hero_sprite.texture.resource_path] = true
		if run_paths.size() != 12:
			_failures.append("%s run cycle only resolved %d unique frames" % [weapon_id, run_paths.size()])

		player.set("_airborne_time", 0.02)
		player.velocity.y = -500.0
		player.call(&"_reset_sprite_pose")
		player.call(&"_animate_jump_rise")
		_expect_path(hero_sprite, "%s/hero_jump_takeoff.png" % directory, "takeoff")
		player.set("_airborne_time", 0.20)
		player.velocity.y = -400.0
		player.call(&"_reset_sprite_pose")
		player.call(&"_animate_jump_rise")
		_expect_path(hero_sprite, "%s/hero_jump_rise.png" % directory, "rise")
		player.velocity.y = 420.0
		player.call(&"_reset_sprite_pose")
		player.call(&"_animate_jump_fall")
		_expect_path(hero_sprite, "%s/hero_jump_fall.png" % directory, "fall")

		var alias_cases := {
			"hero_attack_forward_windup": load("res://assets/characters/frames_polished/hero_windup.png"),
			"hero_attack_forward_strike": load("res://assets/characters/frames_polished/hero_slash.png"),
			"hero_attack_up_strike": load("res://assets/characters/frames_polished/hero_slash_up.png"),
			"hero_attack_down_strike": load("res://assets/characters/frames_polished/hero_slash_down.png"),
		}
		for pose_name: String in alias_cases:
			player.call(&"_set_texture", alias_cases[pose_name])
			_expect_path(hero_sprite, "%s/%s.png" % [directory, pose_name], pose_name)

		var expected_duration := 0.27 if weapon_id == &"twin_blades" else 0.52
		if absf(float(player.get("attack_duration")) - expected_duration) > 0.001:
			_failures.append("%s attack duration changed during visual work" % weapon_id)
		for attack_type in range(3):
			var direction_name := "forward" if attack_type == 0 else ("up" if attack_type == 1 else "down")
			player.set("_attack_type", attack_type)
			player.set("_run_cycle", 5.0)
			player.call(&"_reset_sprite_pose")
			player.call(&"_animate_run")
			player.set("_attack_remaining", expected_duration * 0.96)
			player.call(&"_reset_sprite_pose")
			player.call(&"_animate_attack")
			_expect_path(hero_sprite, "%s/hero_run_5.png" % directory, "%s entry continuity" % direction_name)

			var samples := {
				"windup": 0.18,
				"strike": 0.43,
				"follow": 0.68,
			}
			for phase_name: String in samples:
				var progress: float = samples[phase_name]
				player.set("_attack_remaining", expected_duration * (1.0 - progress))
				player.call(&"_reset_sprite_pose")
				player.call(&"_animate_attack")
				_expect_path(
					hero_sprite,
					"%s/hero_attack_%s_%s.png" % [directory, direction_name, phase_name],
					"%s %s" % [direction_name, phase_name]
				)
			player.call(&"_update_skill_effect")
			if not weapon_effect.is_attack_effect_active() or weapon_effect.get_weapon_id() != weapon_id:
				_failures.append("%s %s did not activate its own attack qi" % [weapon_id, direction_name])
		player.set("_attack_remaining", 0.0)
		player.call(&"_update_skill_effect")
		if weapon_effect.is_attack_effect_active():
			_failures.append("%s attack qi remained active after attack" % weapon_id)

		if weapon_id == &"twin_blades":
			var skill_duration: float = float(player.get("_skill_duration"))
			var skill_paths: Dictionary = {}
			for frame_index in range(TWIN_SKILL_SAMPLES.size()):
				var progress: float = TWIN_SKILL_SAMPLES[frame_index]
				player.set("_skill_remaining", skill_duration * (1.0 - progress))
				player.call(&"_reset_sprite_pose")
				player.call(&"_animate_skill")
				var expected_path := "%s/hero_skill_%d.png" % [directory, frame_index]
				_expect_path(hero_sprite, expected_path, "skill frame %d" % frame_index)
				skill_paths[hero_sprite.texture.resource_path] = true
			if skill_paths.size() != TWIN_SKILL_SAMPLES.size():
				_failures.append(
					"twin_blades skill resolved %d unique frames, expected %d"
					% [skill_paths.size(), TWIN_SKILL_SAMPLES.size()]
				)

			player.set("_turn_remaining", 0.0)
			player.set("_facing", 1.0)
			player.set("_skill_remaining", skill_duration * (1.0 - 0.48))
			player.call(&"_reset_sprite_pose")
			player.call(&"_animate_skill")
			var right_position := hero_sprite.position
			var right_rotation := hero_sprite.rotation
			var right_scale := hero_sprite.scale
			var right_path := hero_sprite.texture.resource_path

			player.set("_facing", -1.0)
			player.call(&"_reset_sprite_pose")
			player.call(&"_animate_skill")
			if not hero_sprite.flip_h:
				_failures.append("twin_blades mirrored skill frame did not flip horizontally")
			if hero_sprite.texture.resource_path != right_path:
				_failures.append("twin_blades mirrored skill resolved a different texture")
			if absf(hero_sprite.position.x + right_position.x) > 0.001:
				_failures.append("twin_blades skill horizontal offset was not mirrored")
			if absf(hero_sprite.position.y - right_position.y) > 0.001:
				_failures.append("twin_blades skill vertical anchor changed when mirrored")
			if absf(hero_sprite.rotation + right_rotation) > 0.001:
				_failures.append("twin_blades skill rotation was not mirrored")
			if not hero_sprite.scale.is_equal_approx(right_scale):
				_failures.append("twin_blades skill scale changed when mirrored")
			player.set("_facing", 1.0)
			player.set("_skill_remaining", 0.0)

	player.configure_weapon(&"moon_sword")
	player.call(&"_reset_sprite_pose")
	player.call(&"_animate_idle")
	_expect_path(hero_sprite, "res://assets/characters/frames_polished/hero_idle.png", "longsword restore")

	player.queue_free()
	if _failures.is_empty():
		print("weapon_animation_set_smoke: PASS")
		quit(0)
	else:
		for failure: String in _failures:
			print("weapon_animation_set_smoke: FAIL: ", failure)
		quit(1)


func _validate_asset_set(weapon_id: StringName) -> void:
	var directory: String = WEAPON_DIRS[weapon_id]
	var names: Array[String] = []
	for pose_name: String in POSE_NAMES:
		names.append(pose_name)
	if weapon_id == &"twin_blades":
		for frame_index in range(12):
			names.append("hero_skill_%d" % frame_index)
	for frame_index in range(12):
		names.append("hero_run_%d" % frame_index)
	for pose_name: String in names:
		var path := "%s/%s.png" % [directory, pose_name]
		var image := Image.load_from_file(ProjectSettings.globalize_path(path))
		if image == null or image.is_empty():
			_failures.append("missing or empty: %s" % path)
			continue
		if image.get_size() != Vector2i(CANVAS_WIDTHS[weapon_id], 416):
			_failures.append("wrong canvas: %s %s" % [path, image.get_size()])
		if image.get_format() not in [Image.FORMAT_RGBA8, Image.FORMAT_RGBAF, Image.FORMAT_RGBAH]:
			_failures.append("not RGBA: %s" % path)
		var used := image.get_used_rect()
		if used.position.x < 2 or used.end.x > image.get_width() - 2 or used.position.y < 2 or used.end.y > 414:
			_failures.append("unsafe crop: %s %s" % [path, used])
		for corner: Vector2i in [Vector2i.ZERO, Vector2i(image.get_width() - 1, 0), Vector2i(0, 415), Vector2i(image.get_width() - 1, 415)]:
			if image.get_pixelv(corner).a > 0.0:
				_failures.append("opaque corner: %s %s" % [path, corner])


func _expect_path(sprite: Sprite2D, expected: String, label: String) -> void:
	if sprite.texture == null or sprite.texture.resource_path != expected:
		_failures.append("%s expected %s, got %s" % [label, expected, sprite.texture.resource_path if sprite.texture else "<null>"])
