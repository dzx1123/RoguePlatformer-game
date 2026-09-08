extends SceneTree

const PREVIEW_SIZE := Vector2i(960, 540)
const BACKGROUND := Color("#08111d")


func _init() -> void:
	_capture()


func _capture() -> void:
	root.content_scale_size = PREVIEW_SIZE
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_IGNORE
	root.size = PREVIEW_SIZE
	RenderingServer.set_default_clear_color(BACKGROUND)

	var backdrop_layer := CanvasLayer.new()
	backdrop_layer.layer = -1
	root.add_child(backdrop_layer)
	var backdrop := ColorRect.new()
	backdrop.size = Vector2(PREVIEW_SIZE)
	backdrop.color = BACKGROUND
	backdrop_layer.add_child(backdrop)

	var positions := [180.0, 480.0, 780.0]
	var effects: Array[WeaponSkillEffect] = []
	for attack_type in range(3):
		var twin := WeaponSkillEffect.new()
		root.add_child(twin)
		effects.append(twin)
		twin.position = Vector2(positions[attack_type], 185.0)
		twin.call_deferred(&"set_attack_state", true, 0.43, 1.0, WeaponCatalog.TWIN_BLADES, 0.88, Color("#b48cff"), attack_type)

		var great := WeaponSkillEffect.new()
		root.add_child(great)
		effects.append(great)
		great.position = Vector2(positions[attack_type], 405.0)
		great.call_deferred(&"set_attack_state", true, 0.47, 1.0, WeaponCatalog.GREATSWORD, 1.28, Color("#ff9b62"), attack_type)

	await process_frame
	RenderingServer.force_draw()
	await RenderingServer.frame_post_draw
	for effect: WeaponSkillEffect in effects:
		if effect.get_draw_call_count() <= 0:
			push_error("Weapon attack qi effect was not submitted to CanvasItem drawing")
			quit(1)
			return
	print("weapon_attack_qi_render_smoke: PASS effects=%d" % effects.size())
	quit(0)
