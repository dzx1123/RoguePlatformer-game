extends SceneTree
func _initialize():
	call_deferred("run_test")
func run_test():
	var last_size := 0.0
	for kind in ["beetle", "caster", "guard", "overseer"]:
		var enemy = load("res://scripts/forge_%s_prototype.gd" % kind).new()
		root.add_child(enemy)
		enemy.set_physics_process(false)
		enemy.position = Vector2(300, 300)
		var effect := CombatVfx.new()
		root.add_child(effect)
		effect.play_enemy_hit(enemy, 1)
		assert(effect.global_position.is_equal_approx(enemy.get_impact_bounds().get_center()))
		assert(effect._scale_multiplier > last_size)
		last_size = effect._scale_multiplier
		enemy.queue_free()
		effect.queue_free()
	print("impact_size_smoke: PASS")
	quit()
