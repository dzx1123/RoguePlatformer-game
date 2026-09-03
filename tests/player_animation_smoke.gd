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
		"res://assets/characters/frames_polished/hero_slash_up_windup.png",
		"res://assets/characters/frames_polished/hero_slash_up.png",
		"res://assets/characters/frames_polished/hero_slash_up_followthrough.png",
		"res://assets/characters/frames_polished/hero_slash_down_windup.png",
		"res://assets/characters/frames_polished/hero_slash_down.png",
		"res://assets/characters/frames_polished/hero_slash_down_followthrough.png",
	]
	for texture_path in texture_paths:
		var texture: Texture2D = load(texture_path)
		if texture.get_size() != expected_size:
			_fail("Unexpected frame size for %s: %s" % [texture_path, texture.get_size()])
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
	player.set("_run_cycle", 2.35)
	player.set("_run_is_settling", false)
	player.set("_run_has_settled", false)
	for _settle_frame in range(20):
		player.call(&"_settle_run_cycle", 1.0 / 60.0)
	if (
		not bool(player.get("_run_has_settled"))
		or absf(float(player.get("_run_cycle")) - 4.0) > 0.01
	):
		_fail("Run stop did not settle onto the next planted-foot pose")
		return
	if player.get_node_or_null("RunBlendSprite") != null:
		_fail("Run animation still contains the double-exposure layer that caused white flashing")
		return
	player.set("_facing", -1.0)
	player.call(&"_begin_ground_turn", 1.0)
	var turn_duration: float = float(player.get("_turn_remaining"))
	player.call(&"_reset_sprite_pose")
	player.call(&"_animate_turn")
	if hero_sprite.flip_h or not hero_sprite.texture.resource_path.ends_with("hero_run_0.png"):
		_fail("Turn anticipation did not retain the planted outgoing-facing pose")
		return
	player.set("_turn_remaining", turn_duration * 0.40)
	player.call(&"_reset_sprite_pose")
	player.call(&"_animate_turn")
	if not hero_sprite.flip_h or not hero_sprite.texture.resource_path.ends_with("hero_run_4.png"):
		_fail("Turn completion did not switch to the planted incoming-facing pose")
		return
	player.set("_turn_remaining", 0.0)
	player.set("_facing", 1.0)

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

	var dash_texture_paths: Dictionary = {}
	var dash_duration: float = float(player.get("dash_duration"))
	for remaining_ratio in [0.90, 0.50, 0.10]:
		player.set("_dash_remaining", dash_duration * float(remaining_ratio))
		player.call(&"_reset_sprite_pose")
		player.call(&"_animate_dash")
		dash_texture_paths[hero_sprite.texture.resource_path] = true
	player.set("_dash_remaining", 0.0)
	if dash_texture_paths.size() != 3:
		_fail("Dash did not progress through anticipation, travel and exit poses")
		return
	player.set("_run_cycle", 6.35)
	player.set("_dash_remaining", dash_duration)
	player.call(&"_finish_dash")
	var dash_exit_duration: float = float(player.get("_dash_exit_blend_remaining"))
	if dash_exit_duration <= 0.0:
		_fail("Dash release did not enter the planted recovery window")
		return
	if int(player.call(&"_resolve_visual_state")) != RoguePlayer.VisualState.DASH_RECOVERY:
		_fail("Dash release did not expose the recovery visual state")
		return
	if absf(float(player.get("_run_cycle"))) > 0.001 or not bool(player.get("_run_has_settled")):
		_fail("Dash release resumed from an arbitrary running frame")
		return
	player.call(&"_reset_sprite_pose")
	player.call(&"_animate_dash_recovery")
	if not hero_sprite.texture.resource_path.ends_with("hero_run_0.png"):
		_fail("Dash release did not use the planted run pose")
		return
	player.set("_dash_exit_blend_remaining", 0.0)

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
	player.set("_run_cycle", 5.35)
	player.set("_run_has_settled", false)
	player.set("_attack_elapsed", float(player.get("attack_duration")))
	player.call(&"_finish_attack")
	var attack_exit_duration: float = float(player.get("_attack_exit_blend_remaining"))
	if attack_exit_duration <= 0.0:
		_fail("Attack release did not enter the planted recovery window")
		return
	if int(player.call(&"_resolve_visual_state")) != RoguePlayer.VisualState.ATTACK_RECOVERY:
		_fail("Attack release did not expose the recovery visual state")
		return
	if absf(float(player.get("_run_cycle"))) > 0.001 or not bool(player.get("_run_has_settled")):
		_fail("Attack release resumed from an arbitrary running frame")
		return
	player.call(&"_reset_sprite_pose")
	player.call(&"_animate_attack_recovery")
	var attack_release_position: Vector2 = hero_sprite.position
	var attack_release_scale: Vector2 = hero_sprite.scale
	var attack_release_rotation: float = hero_sprite.rotation
	player.set("_attack_exit_blend_remaining", attack_exit_duration * 0.5)
	player.call(&"_reset_sprite_pose")
	player.call(&"_animate_attack_recovery")
	if (
		hero_sprite.position.distance_to(attack_release_position) > 0.01
		or hero_sprite.scale.distance_to(attack_release_scale) > 0.001
		or absf(hero_sprite.rotation - attack_release_rotation) > 0.001
	):
		_fail("Attack release moved away from its planted anchor")
		return
	player.set("_attack_exit_blend_remaining", 0.0)

	var skill_duration: float = float(player.get("_skill_duration"))
	var skill_progress_samples: Array[float] = [0.08, 0.22, 0.40, 0.50, 0.59, 0.70, 0.82, 0.94]
	var expected_skill_frames: Array[String] = [
		"hero_windup.png",
		"hero_slash_up_windup.png",
		"hero_slash_up.png",
		"hero_slash_up_followthrough.png",
		"hero_slash_down_windup.png",
		"hero_slash_down.png",
		"hero_slash_down_followthrough.png",
		"hero_recovery.png",
	]
	var seen_skill_frames: Dictionary = {}
	for frame_index in range(skill_progress_samples.size()):
		var progress: float = skill_progress_samples[frame_index]
		player.set("_skill_remaining", skill_duration * (1.0 - progress))
		player.call(&"_reset_sprite_pose")
		player.call(&"_animate_skill")
		var skill_path: String = hero_sprite.texture.resource_path
		if not skill_path.ends_with(expected_skill_frames[frame_index]):
			_fail("Skill phase %d used the wrong canonical hero pose: %s" % [frame_index, skill_path])
			return
		if hero_sprite.region_enabled:
			_fail("Skill enabled a mismatched sprite-sheet region")
			return
		if hero_sprite.texture.get_size() != expected_size:
			_fail("Skill phase changed the canonical hero canvas size")
			return
		seen_skill_frames[skill_path] = true
	if seen_skill_frames.size() != 8:
		_fail("Moon-wheel skill did not visit all eight canonical poses")
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
