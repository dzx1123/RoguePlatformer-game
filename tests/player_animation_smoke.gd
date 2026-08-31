extends SceneTree

var _attack_hit_count: int = 0


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
	player.attack_hit.connect(_on_attack_hit)
	await physics_frame

	var expected_size := Vector2(640.0, 416.0)
	var texture_paths: Array[String] = [
		"res://assets/characters/frames_polished/hero_idle.png",
		"res://assets/characters/frames_polished/hero_run_0.png",
		"res://assets/characters/frames_polished/hero_run_1.png",
		"res://assets/characters/frames_polished/hero_run_2.png",
		"res://assets/characters/frames_polished/hero_run_3.png",
		"res://assets/characters/frames_polished/hero_run_4.png",
		"res://assets/characters/frames_polished/hero_run_5.png",
		"res://assets/characters/frames_polished/hero_run_6.png",
		"res://assets/characters/frames_polished/hero_run_7.png",
		"res://assets/characters/frames_polished/hero_jump_takeoff.png",
		"res://assets/characters/frames_polished/hero_jump_tuck.png",
		"res://assets/characters/frames_polished/hero_jump_fall.png",
		"res://assets/characters/frames_polished/hero_land.png",
		"res://assets/characters/frames_polished/hero_windup.png",
		"res://assets/characters/frames_polished/hero_slash.png",
		"res://assets/characters/frames_polished/hero_slash_followthrough.png",
		"res://assets/characters/frames_polished/hero_recovery.png",
		"res://assets/characters/frames_polished/hero_slash_up_followthrough.png",
		"res://assets/characters/frames_polished/hero_slash_down_followthrough.png",
	]
	for texture_path in texture_paths:
		var texture: Texture2D = load(texture_path)
		if texture.get_size() != expected_size:
			_fail("Unexpected frame size for %s: %s" % [texture_path, texture.get_size()])
			return
	var skill_sheet := load(
		"res://assets/characters/frames_polished/hero_skill_fullmoon_sheet_v2.png"
	) as Texture2D
	if skill_sheet == null or skill_sheet.get_width() % 3 != 0 or skill_sheet.get_height() % 2 != 0:
		_fail("Full-moon skill sheet is not a valid 3x2 animation grid")
		return

	var hero_sprite: Sprite2D = player.get_node("HeroSprite") as Sprite2D
	var run_texture_paths: Dictionary = {}
	for run_frame_index in range(8):
		player.set("_run_cycle", float(run_frame_index))
		player.set("_movement_blend", 1.0)
		player.call(&"_reset_sprite_pose")
		player.call(&"_animate_run")
		run_texture_paths[hero_sprite.texture.resource_path] = true
	if run_texture_paths.size() != 8:
		_fail("Same-character run cycle used %d poses instead of 8" % run_texture_paths.size())
		return
	if player.get_node_or_null("RunBlendSprite") != null:
		_fail("Run animation still contains the double-exposure layer that caused white flashing")
		return

	player.set("_airborne_time", 0.03)
	player.call(&"_reset_sprite_pose")
	player.call(&"_animate_jump_rise")
	if not hero_sprite.texture.resource_path.ends_with("hero_jump_takeoff.png"):
		_fail("Jump takeoff did not use the takeoff pose")
		return

	player.set("_airborne_time", 0.20)
	player.call(&"_reset_sprite_pose")
	player.call(&"_animate_jump_rise")
	if not hero_sprite.texture.resource_path.ends_with("hero_jump_tuck.png"):
		_fail("Jump rise did not tuck the legs")
		return

	player.velocity.y = 400.0
	player.call(&"_reset_sprite_pose")
	player.call(&"_animate_jump_fall")
	if not hero_sprite.texture.resource_path.ends_with("hero_jump_fall.png"):
		_fail("Jump fall did not extend the legs")
		return

	player.set("_landing_squash_remaining", 0.18)
	player.call(&"_reset_sprite_pose")
	player.call(&"_animate_land")
	if not hero_sprite.texture.resource_path.ends_with("hero_land.png"):
		_fail("Landing did not start in the crouched pose")
		return

	player.set("_landing_squash_remaining", 0.02)
	player.call(&"_reset_sprite_pose")
	player.call(&"_animate_land")
	if not hero_sprite.texture.resource_path.ends_with("hero_idle.png"):
		_fail("Landing did not finish in the standing pose")
		return

	player.call(&"_start_attack")
	var seen_windup: bool = false
	var seen_slash: bool = false
	var seen_recovery: bool = false
	for _frame_index in range(36):
		await physics_frame
		var current_texture: Texture2D = hero_sprite.texture
		var current_path: String = current_texture.resource_path
		seen_windup = seen_windup or current_path.ends_with("hero_windup.png")
		seen_slash = seen_slash or current_path.ends_with("hero_slash.png")
		seen_recovery = seen_recovery or current_path.ends_with("hero_recovery.png")

	if not seen_windup or not seen_slash or not seen_recovery:
		_fail("Attack did not visit every visual phase")
		return
	if _attack_hit_count != 1:
		_fail("Attack hit signal count was %d instead of 1" % _attack_hit_count)
		return

	var skill_regions: Dictionary = {}
	var skill_duration: float = float(player.get("_skill_duration"))
	for frame_index in range(6):
		var progress: float = (float(frame_index) + 0.01) / 6.0
		player.set("_skill_remaining", skill_duration * (1.0 - progress))
		player.call(&"_reset_sprite_pose")
		player.call(&"_animate_skill")
		if not hero_sprite.texture.resource_path.ends_with("hero_skill_fullmoon_sheet_v2.png"):
			_fail("Skill did not use the painted full-moon animation")
			return
		if not hero_sprite.region_enabled:
			_fail("Skill sprite sheet region was not enabled")
			return
		skill_regions[hero_sprite.region_rect.position] = true
	if skill_regions.size() != 6:
		_fail("Full-moon skill did not expose all six animation frames")
		return
	player.set("_skill_remaining", 0.0)
	player.call(&"_reset_sprite_pose")
	player.call(&"_animate_idle")
	if hero_sprite.region_enabled:
		_fail("Skill sprite region leaked into the normal hero animation")
		return

	player.queue_free()
	print("player_animation_smoke: PASS")
	quit(0)


func _on_attack_hit(_origin: Vector2, _facing: float) -> void:
	_attack_hit_count += 1


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
