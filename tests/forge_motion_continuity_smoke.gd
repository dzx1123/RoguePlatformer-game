extends SceneTree

var failed := false

func _initialize() -> void:
	call_deferred("run_test")

func check(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		push_error(message)

func run_test() -> void:
	create_timer(30).timeout.connect(func(): push_error("Motion test timed out"); quit(1))
	var scene = load("res://scenes/Chapter2Journey.tscn").instantiate()
	scene.persistence_enabled = false
	root.add_child(scene)
	for room in [2, 5, 10, 19]:
		scene._load_layout(room)
		await create_timer(0.5).timeout
		var enemy = scene.overseer if room == 19 else scene.living_enemies()[0]
		if room == 19:
			enemy.engaged = true
			enemy.remaining = 10
		var phase_before: float = enemy.actor_motion.phase
		await create_timer(0.3).timeout
		check(enemy.actor_motion.weight > 0.5 and enemy.actor_motion.phase != phase_before, "Room %d: walking must animate feet, including the boss" % (room + 21))
		if "capture" in OS.get_cmdline_user_args():
			await RenderingServer.frame_post_draw
			check(root.get_texture().get_image().save_png("D:/Godot/RoguePlatformer-game/test_output/forge_motion_room_%d.png" % (room + 21)) == OK, "Save room capture")
		scene._toggle_pause()
		var frozen: Array = [enemy.actor_motion.phase, enemy.actor_motion.weight, enemy.actor_motion.shape, enemy.position]
		await create_timer(0.15).timeout
		check(frozen == [enemy.actor_motion.phase, enemy.actor_motion.weight, enemy.actor_motion.shape, enemy.position], "Pause must freeze gait and body")
		scene._toggle_pause()
		enemy._hitstop_remaining = 0.3
		await create_timer(0.1).timeout
		check(frozen == [enemy.actor_motion.phase, enemy.actor_motion.weight, enemy.actor_motion.shape, enemy.position], "Hitstop must freeze gait and body")
	# A cast must remain aimed in its initial direction when the player crosses behind.
	scene._load_layout(2)
	await create_timer(0.5).timeout
	scene.set_physics_process(false)
	scene.player.set_physics_process(false)
	scene.player.position = scene.caster.position + Vector2(100, 0)
	scene.caster.cast_pose_time = 1.52
	await create_timer(0.05).timeout
	var direction: float = scene.caster._visual_state().facing
	scene.player.position.x = scene.caster.position.x - 100
	await create_timer(0.1).timeout
	check(direction == 1 and scene.caster._visual_state().facing == direction, "Caster windup must not flip when crossed")
	# The projectile and the release pose share the cast phase and the hand anchor.
	scene._spawn_ember()
	var ember = scene.embers.get_child(0)
	ember.advance(ember.WARNING - 0.01)
	scene.caster._physics_process(0.01)
	check(scene.caster._visual_state().pose == 1, "The lantern must stay in windup before projectile release")
	scene.caster._hitstop_remaining = 0.05
	ember.advance(0.02)
	check(ember.age < ember.WARNING, "Caster hitstop must delay an unreleased projectile")
	scene.caster._hitstop_remaining = 0.0
	ember.advance(0.02)
	scene.caster._physics_process(0.01)
	check(scene.caster._visual_state().pose == 2, "Release must select the extended hand pose")
	check(ember.origin.is_equal_approx(scene.caster.get_ember_release_point()), "Fireball must begin at the extended hand")
	# Stop and change posture: shape eases toward its target without changing hit geometry.
	var bounds: Rect2 = scene.caster.get_impact_bounds()
	var before_shape: Vector2 = scene.caster.actor_motion.shape
	scene.caster.actor_motion.advance(1.0 / 60.0, 0, true, false, Vector2(1.08, 0.92), 1, 60)
	check(scene.caster.actor_motion.shape.distance_to(before_shape) < 0.08, "Body shape must ease across pose changes")
	check(scene.caster.get_impact_bounds() == bounds, "Visual gait must not change impact bounds")
	for i in range(30):
		scene.caster.actor_motion.advance(1.0 / 60.0, 0, true, false, Vector2.ONE, 1, 60)
	check(is_zero_approx(scene.caster.actor_motion.weight), "Stopped actor must settle its feet")
	scene.queue_free()
	await process_frame
	if not failed: print("forge_motion_continuity_smoke: PASS")
	quit(1 if failed else 0)
