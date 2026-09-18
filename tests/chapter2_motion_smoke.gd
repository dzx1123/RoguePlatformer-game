extends SceneTree

func _initialize() -> void:
	call_deferred("run_test")

func run_test() -> void:
	var scene = load("res://scenes/Chapter2FullSlice.tscn").instantiate()
	root.add_child(scene)
	scene._load_layout(5)
	var guard = scene.guard
	await create_timer(0.1).timeout
	assert(guard.animation_time > 0)
	var before: Vector2 = guard.position
	var shape: Vector2 = guard._pose_motion(1, 1)
	assert(shape.x > 1 and shape.y < 1 and guard.position == before)
	scene._toggle_pause()
	var clock_before: float = guard.animation_time
	await create_timer(0.15).timeout
	assert(guard.animation_time == clock_before, "Paused actors must not animate")
	scene._toggle_pause()
	await create_timer(0.1).timeout
	assert(guard.animation_time > clock_before)
	scene.queue_free()
	await process_frame
	print("chapter2_motion_smoke: PASS")
	quit()
