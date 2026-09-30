extends SceneTree

var failed := false
var captures: Dictionary = {}

func _initialize() -> void:
	call_deferred("run_test")

func check(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		push_error(message)

func peak(capture: AudioEffectCapture) -> float:
	var value := 0.0
	for frame: Vector2 in capture.get_buffer(capture.get_frames_available()):
		value = maxf(value, maxf(absf(frame.x), absf(frame.y)))
	return value

func frames(count: int) -> void:
	for i in range(count): await physics_frame

func run_test() -> void:
	create_timer(70).timeout.connect(func(): push_error("Player output timeout"); quit(1))
	for chapter in [1, 2]:
		var scene = load("res://scenes/Main.tscn" if chapter == 1 else "res://scenes/Chapter2Journey.tscn").instantiate()
		if chapter == 1: scene.save_enabled = false
		else: scene.persistence_enabled = false
		root.add_child(scene)
		if chapter == 1:
			scene._start_new_run()
			scene._clear_enemies()
		await create_timer(1.8).timeout
		var player: RoguePlayer = scene.player
		var sound: RogueSoundscape = scene._soundscape if chapter == 1 else scene.portal_sound
		check(player.get_script().resource_path == "res://scripts/player.gd", "Both chapters must use the same player")
		check(sound._effects_generator.bus == &"SFX", "Action transients must use SFX")
		check(sound._effects_generator.stream.buffer_length <= 0.05, "Action audio must have a short buffer")
		AudioServer.set_bus_mute(AudioServer.get_bus_index("Music"), true)
		AudioServer.set_bus_volume_db(0, 0)
		for bus in ["SFX", "Voice"]:
			var index := AudioServer.get_bus_index(bus)
			AudioServer.set_bus_volume_db(index, 0)
			if not captures.has(bus):
				var capture := AudioEffectCapture.new()
				capture.buffer_length = 1.0
				AudioServer.add_bus_effect(index, capture)
				captures[bus] = capture
		for weapon in WeaponCatalog.all_weapon_ids():
			player.configure_weapon(weapon)
			for action in [&"attack", &"skill", &"jump", &"dash"]:
				player._skill_cooldown_remaining = 0
				await create_timer(0.8).timeout
				for capture: AudioEffectCapture in captures.values(): capture.clear_buffer()
				Input.action_press(action)
				await frames(2)
				Input.action_release(action)
				await create_timer(0.24).timeout
				var sfx_peak := peak(captures.SFX)
				var voice_peak := peak(captures.Voice)
				print("chapter=%d weapon=%s action=%s SFX=%.4f Voice=%.4f" % [chapter, weapon, action, sfx_peak, voice_peak])
				check(sfx_peak > 0.001, "Chapter %d %s %s: no actual SFX samples with music muted" % [chapter, weapon, action])
				if action in [&"attack", &"skill"]:
					check(voice_peak > 0.001, "Chapter %d %s: no actual player voice samples" % [chapter, action])
				await create_timer(0.4).timeout
				# Keep the test in its starting lane after dash, without touching health/damage.
				player.position.x = 100
		AudioServer.set_bus_mute(AudioServer.get_bus_index("Music"), false)
		scene.queue_free()
		await process_frame
	if not failed: print("chapter_player_output_smoke: PASS")
	quit(1 if failed else 0)
