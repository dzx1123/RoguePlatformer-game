extends SceneTree


func _initialize() -> void:
	call_deferred(&"_run_test")


func _run_test() -> void:
	for action_name in [
		&"restart",
		&"move_left",
		&"move_right",
		&"jump",
		&"dash",
		&"attack",
		&"skill",
	]:
		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name)

	var player_scene: PackedScene = load("res://scenes/Player.tscn")
	var player: RoguePlayer = player_scene.instantiate() as RoguePlayer
	root.add_child(player)
	player.set_physics_process(false)
	await process_frame

	var hero_sprite := player.get_node("HeroSprite") as Sprite2D
	var pose_echo := player.get_node("SkillPoseEcho") as Sprite2D
	if hero_sprite == null or pose_echo == null:
		_fail("Skill pose layers are missing")
		return

	var skill_duration: float = float(player.get("_skill_duration"))
	player.set("_skill_remaining", skill_duration * 0.60)
	player.call(&"_update_hero_visuals", 1.0 / 60.0)
	var outgoing_texture: Texture2D = hero_sprite.texture
	player.set("_skill_remaining", skill_duration * 0.50)
	player.call(&"_update_hero_visuals", 1.0 / 60.0)
	if not pose_echo.visible or pose_echo.texture != outgoing_texture:
		_fail("Skill frame interpolation did not preserve the outgoing pose")
		return
	if pose_echo.modulate.a <= 0.0 or pose_echo.modulate.a > 0.145:
		_fail("Skill pose interpolation opacity is outside the subtle motion range")
		return
	player.call(&"_update_skill_pose_echo", 0.08)
	if pose_echo.visible:
		_fail("Skill pose interpolation did not clear promptly")
		return

	player.set("_run_cycle", 5.35)
	player.set("_run_has_settled", false)
	player.set("_skill_elapsed", skill_duration)
	player.call(&"_finish_skill")
	var exit_duration: float = float(player.get("_skill_exit_blend_remaining"))
	if exit_duration <= 0.0:
		_fail("Skill release did not enter the settling window")
		return
	if absf(float(player.get("_run_cycle"))) > 0.001:
		_fail("Skill release kept an arbitrary running frame")
		return
	if not bool(player.get("_run_has_settled")):
		_fail("Skill release did not lock the planted run pose")
		return

	player.call(&"_reset_sprite_pose")
	player.set("_skill_exit_blend_remaining", exit_duration)
	player.call(&"_animate_skill_recovery")
	var release_start_position: Vector2 = hero_sprite.position
	var release_start_scale: Vector2 = hero_sprite.scale
	var release_start_rotation: float = hero_sprite.rotation

	player.call(&"_reset_sprite_pose")
	player.set("_skill_exit_blend_remaining", exit_duration * 0.5)
	player.call(&"_animate_skill_recovery")
	var release_mid_position: Vector2 = hero_sprite.position
	if release_mid_position.distance_to(release_start_position) > 0.01:
		_fail("Skill release moved off its planted anchor")
		return
	if hero_sprite.scale.distance_to(release_start_scale) > 0.001:
		_fail("Skill release changed scale during its planted hold")
		return
	if absf(hero_sprite.rotation - release_start_rotation) > 0.001:
		_fail("Skill release rotated during its planted hold")
		return

	player.call(&"_reset_sprite_pose")
	player.set("_skill_exit_blend_remaining", 0.0)
	player.call(&"_animate_skill_recovery")
	if hero_sprite.position.distance_to(release_start_position) > 0.01:
		_fail("Skill release position does not return to its starting anchor")
		return
	if hero_sprite.scale.distance_to(release_start_scale) > 0.001:
		_fail("Skill release scale does not return to its starting anchor")
		return
	if absf(hero_sprite.rotation - release_start_rotation) > 0.001:
		_fail("Skill release rotation does not return to its starting anchor")
		return
	if not hero_sprite.texture.resource_path.ends_with("hero_recovery.png"):
		_fail("Skill release did not retain the canonical recovery pose")
		return

	player.queue_free()
	await process_frame
	print("skill_release_motion_smoke: PASS")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
