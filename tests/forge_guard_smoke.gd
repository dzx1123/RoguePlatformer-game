extends SceneTree
class Target extends Node2D:
	var hits := 0
	func is_dead() -> bool:
		return false
	func receive_enemy_attack(_origin: Vector2, _damage: int, _cause: StringName) -> bool:
		hits += 1
		return true

func _initialize() -> void:
	call_deferred("run_test")

func run_test() -> void:
	var guard = preload("res://scripts/forge_guard_prototype.gd").new()
	root.add_child(guard)
	guard.set_physics_process(false)
	guard.position = Vector2(550, 308)
	var target := Target.new()
	root.add_child(target)
	target.position = Vector2(590, 308)
	guard.set_target(target)
	guard.state_time = 0
	guard._physics_process(0.01)
	assert(guard.charge_state == guard.ChargeState.WINDUP)
	var warning: Rect2 = guard.get_charge_warning_rect()
	assert(is_equal_approx(warning.end.x, guard.lane_right - guard.position.x + 40), "Warning must cover clamped charge travel plus contact reach")
	target.position.x = 510
	guard._physics_process(0.10)
	assert(guard.charge_facing == 1.0, "Warning direction must stay locked")
	assert(guard.get_charge_warning_rect() == warning)
	assert(target.hits == 0 and guard.charge_state == guard.ChargeState.WINDUP)
	guard.state_time = 0
	guard._physics_process(0.01)
	assert(guard.charge_state == guard.ChargeState.CHARGE)
	guard.position.x = guard.lane_right
	guard._physics_process(0.01)
	assert(guard.charge_state == guard.ChargeState.RECOVER, "Edge must stop charge")
	assert(guard.state_time > 1.0 and guard.velocity.x == 0)
	guard.queue_free()
	target.queue_free()
	await process_frame
	print("forge_guard_smoke: PASS")
	quit()
