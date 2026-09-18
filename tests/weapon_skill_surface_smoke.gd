extends SceneTree

func _initialize() -> void:
	call_deferred("run_test")

func run_test() -> void:
	var effect := WeaponSkillEffect.new()
	root.add_child(effect)
	effect.position = Vector2(320, 300)
	for weapon in [WeaponCatalog.TWIN_BLADES, WeaponCatalog.GREATSWORD]:
		for facing in [-1.0, 1.0]:
			for step in range(101):
				effect.set_skill_state(true, float(step) / 100.0, facing, weapon, 1.0, Color.WHITE)
				await RenderingServer.frame_post_draw
	assert(effect.get_draw_call_count() >= 400)
	assert(root.get_texture().get_image().save_png("res://test_output/skill_surface.png") == OK)
	effect.queue_free()
	print("weapon_skill_surface_smoke: PASS")
	quit()
