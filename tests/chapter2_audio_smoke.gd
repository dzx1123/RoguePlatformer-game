extends SceneTree

func _initialize() -> void:
	call_deferred("run_test")

func run_test() -> void:
	var scene = load("res://scenes/Chapter2Journey.tscn").instantiate()
	scene.persistence_enabled = false
	root.add_child(scene)
	await create_timer(1.8).timeout
	var sound: RogueSoundscape = scene.portal_sound
	assert(scene.player.action_started.is_connected(scene._on_shared_player_action))
	assert(scene.player.vocal_requested.is_connected(sound.handle_player_vocal))
	for weapon in WeaponCatalog.all_weapon_ids():
		scene.player.configure_weapon(weapon)
		Input.action_press(&"attack")
		await physics_frame
		await physics_frame
		Input.action_release(&"attack")
		assert(sound._swing_player.playing and sound._swing_player.stream != null)
		assert(sound._swing_player.stream in (sound._greatsword_swing_sfx if weapon == WeaponCatalog.GREATSWORD else sound._sword_swing_sfx))
		await create_timer(1.0).timeout
	scene._load_layout(2)
	await create_timer(1.8).timeout
	assert(scene.caster.sound_requested.is_connected(sound.handle_enemy_sound))
	scene.player.position = scene.caster.position - Vector2(45, 0)
	Input.action_press(&"move_right")
	await physics_frame
	Input.action_release(&"move_right")
	var before: int = sound._last_impact_msec
	Input.action_press(&"attack")
	await create_timer(0.6).timeout
	Input.action_release(&"attack")
	assert(sound._last_impact_msec > before and sound._hit_player.stream != null)
	scene.player.vocal_requested.emit(&"hurt")
	assert(not sound.get_current_player_voice_path().is_empty())
	scene.queue_free()
	await process_frame
	print("chapter2_audio_smoke: PASS")
	quit()
