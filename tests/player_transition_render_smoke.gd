extends SceneTree

var failed := false

func _initialize() -> void:
	call_deferred("run_test")

func check(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		push_error(message)

func run_test() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(64, 64)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var p: RoguePlayer = load("res://scenes/Player.tscn").instantiate()
	viewport.add_child(p)
	p.set_physics_process(false)
	p.get_node("Camera2D").enabled = false
	p.position = Vector2(32, 32)
	# Synthetic opaque poses isolate compositing from the artwork's soft edges.
	var red := Image.create(24, 24, false, Image.FORMAT_RGBA8)
	red.fill(Color(0.8, 0.1, 0.1, 1))
	var blue := Image.create(24, 24, false, Image.FORMAT_RGBA8)
	blue.fill(Color(0.1, 0.1, 0.8, 1))
	p.hero_sprite.texture = ImageTexture.create_from_image(blue)
	p._pose_transition.texture = ImageTexture.create_from_image(red)
	p.hero_sprite.material = p._hero_edge_material
	p._pose_transition.material = p._snapshot_pose_material(p._hero_edge_material)
	for sprite: Sprite2D in [p.hero_sprite, p._pose_transition]:
		sprite.position = Vector2.ZERO
		sprite.scale = Vector2.ONE
		sprite.rotation = 0
		sprite.offset = Vector2.ZERO
		sprite.flip_h = false
		sprite.show()
	for material: ShaderMaterial in [p._hero_edge_material, p._hero_run_material]:
		p.hero_sprite.material = material
		for weight in [0.25, 0.5, 0.75]:
			p.hero_sprite.modulate = Color(1, 1, 1, weight)
			p._pose_transition.modulate = Color(1, 1, 1, 1.0 - weight)
			p._update_transition_compositing()
			await process_frame
			await RenderingServer.frame_post_draw
			var pixel := viewport.get_texture().get_image().get_pixel(32, 32)
			print("weight=", weight, " center=", pixel)
			check(pixel.a > 0.99, "Opaque body becomes transparent during pose transition")
			check(absf(pixel.r - lerpf(0.8, 0.1, weight)) < 0.02 and absf(pixel.b - lerpf(0.1, 0.8, weight)) < 0.02, "Pose colors must blend without darkening")
		check(not p._snapshot_pose_material(material).get_shader_parameter(&"pose_blend_active"), "Trails must not inherit live pose compositing")
	# Non-overlapping silhouettes must still fade; compensation applies only at overlap.
	p._pose_transition.position.x = 24
	p.hero_sprite.modulate.a = 0.5
	p._pose_transition.modulate.a = 0.5
	p._update_transition_compositing()
	await process_frame
	await RenderingServer.frame_post_draw
	check(absf(viewport.get_texture().get_image().get_pixel(32, 32).a - 0.5) < 0.02, "Non-overlapping pose must retain its fade")
	# White cutout islands in run artwork must not be treated as opaque body.
	red.fill(Color.WHITE)
	p._pose_transition.texture = ImageTexture.create_from_image(red)
	p._pose_transition.material = p._snapshot_pose_material(p._hero_run_material)
	p._pose_transition.position = Vector2.ZERO
	p._update_transition_compositing()
	await process_frame
	await RenderingServer.frame_post_draw
	check(absf(viewport.get_texture().get_image().get_pixel(32, 38).a - 0.5) < 0.02, "Run cutout holes must remain transparent")
	# Verify UV registration with different offsets, facing, scale and rotation.
	p.hero_sprite.offset = Vector2(3, -2)
	p.hero_sprite.flip_h = true
	p.hero_sprite.rotation = 0.2
	p._pose_transition.offset = Vector2(-1, 4)
	p._pose_transition.scale = Vector2(1.2, 0.8)
	p._pose_transition.rotation = -0.1
	var uv := Vector2(0.3, 0.6)
	var current_point := (uv - Vector2(0.5, 0.5)) * p.hero_sprite.texture.get_size()
	current_point.x *= -1
	current_point = p.hero_sprite.transform * (current_point + p.hero_sprite.offset)
	var old_uv := p._pose_uv_in_previous(uv)
	var old_point := p._pose_transition.transform * ((old_uv - Vector2(0.5, 0.5)) * p._pose_transition.texture.get_size() + p._pose_transition.offset)
	check(current_point.distance_to(old_point) < 0.001, "Mirrored/offset poses must sample the same screen position")
	viewport.queue_free()
	await process_frame
	if not failed: print("player_transition_render_smoke: PASS")
	quit(1 if failed else 0)
