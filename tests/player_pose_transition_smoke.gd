extends SceneTree

var failed := false
var sheet: Node2D

func _initialize() -> void:
	call_deferred("run_test")

func check(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		push_error(message)

func frames(count: int) -> void:
	for i in range(count): await physics_frame

func sample(p: RoguePlayer, column: int, row: int) -> void:
	if sheet == null: return
	for layer: Sprite2D in [p.hero_sprite, p._pose_transition]:
		if not layer.visible: continue
		var copy := layer.duplicate() as Sprite2D
		copy.material = layer.material.duplicate() if layer.material != null else null
		copy.position += Vector2(115 + column * 200, 135 + row * 185)
		sheet.add_child(copy)

func run_test() -> void:
	create_timer(35).timeout.connect(func(): push_error("Transition test timeout"); quit(1))
	var capture := "capture" in OS.get_cmdline_user_args()
	if capture:
		root.size = Vector2i(1280, 720)
		root.content_scale_size = root.size
		RenderingServer.set_default_clear_color(Color("#142332"))
		sheet = Node2D.new()
		root.add_child(sheet)
	var scene = load("res://scenes/Chapter2Journey.tscn").instantiate()
	scene.persistence_enabled = false
	root.add_child(scene)
	if capture:
		scene.hide()
		scene.campaign_hud.hide()
	await create_timer(1.8).timeout
	var p: RoguePlayer = scene.player
	var row := 0
	for weapon in WeaponCatalog.all_weapon_ids():
		p.respawn()
		p.configure_weapon(weapon)
		await frames(35)
		var cache_count := p._weapon_pose_cache.size()
		Input.action_press(&"move_right")
		await frames(7)
		Input.action_press(&"attack")
		await frames(2)
		Input.action_release(&"attack")
		# Heavy/light weapons retain the run frame briefly before their authored windup.
		for tick in range(4):
			if p._pose_transition_remaining > 0: break
			await physics_frame
		var remaining: float = p._pose_transition_remaining
		check(remaining > 0 and p._pose_transition.visible, "%s: run -> attack must preserve the outgoing silhouette" % weapon)
		check(p._pose_head_position(p._pose_transition).distance_to(p._pose_head_position(p.hero_sprite)) < 0.01, "Pose blend must align both heads")
		sample(p, 0, row)
		await frames(2)
		sample(p, 1, row)
		check(p._pose_transition_remaining < remaining, "Pose transition must advance")
		while p._attack_remaining > 0: await physics_frame
		await frames(1)
		check(p._visual_state == p.VisualState.RUN and p._pose_transition_remaining > 0, "%s: attack -> run must blend without an input lock" % weapon)
		sample(p, 2, row)
		p._hitstop_remaining = 0.1
		var frozen: float = p._pose_transition_remaining
		await frames(3)
		check(p._pose_transition_remaining == frozen, "Hitstop must freeze the outgoing silhouette")
		await frames(13)
		Input.action_release(&"move_right")
		Input.action_press(&"skill")
		await frames(2)
		Input.action_release(&"skill")
		check(p._pose_transition_remaining > 0, "%s: run -> skill has no pose transition" % weapon)
		sample(p, 3, row)
		while p._skill_remaining > 0: await physics_frame
		await frames(1)
		sample(p, 4, row)
		await frames(16)
		check(not p._pose_transition.visible and is_equal_approx(p.hero_sprite.modulate.a, 1.0), "Transition must finish with one opaque player")
		check(p._weapon_pose_cache.size() == cache_count, "Combat must not load new weapon poses")
		var next_weapon: StringName = WeaponCatalog.all_weapon_ids()[(row + 1) % 3]
		p._attack_cooldown_remaining = 0
		Input.action_press(&"attack")
		await frames(2)
		Input.action_release(&"attack")
		p.request_weapon_switch(next_weapon)
		while p._attack_remaining > 0: await physics_frame
		await frames(2)
		check(p.get_weapon_id() == next_weapon, "Weapon switch must complete at action end, not after visual recovery")
		sample(p, 5, row)
		row += 1
	if capture:
		await process_frame
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png("D:/Godot/RoguePlatformer-game/test_output/player_pose_transitions.png") == OK, "Capture transitions")
	scene.queue_free()
	await process_frame
	if not failed: print("player_pose_transition_smoke: PASS")
	quit(1 if failed else 0)
