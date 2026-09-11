extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var sound := RogueSoundscape.new()
	root.add_child(sound)
	sound.set_process(false)
	for path in [RogueSoundscape.GOBLIN_ATTACK_VOICE_PATHS[0], RogueSoundscape.GOBLIN_HURT_VOICE_PATHS[0]]:
		assert(RogueSoundscape.wav_duration(path) > 0.1)
		assert(RogueSoundscape.wav_duration(path) < 0.65)
		assert(RogueSoundscape.wav_peak_db(path) < -5.5)
	sound.play_enemy_attack_voice()
	assert(sound._goblin_attack_player.stream == sound._goblin_attack_voices[0])
	var stamp := sound._last_goblin_attack_msec
	sound.play_enemy_attack_voice()
	assert(sound._last_goblin_attack_msec == stamp)
	sound.play_impact()
	assert(sound._pending_hurt_clips == sound._goblin_hurt_voices)
	sound._process(0.11)
	assert(sound._enemy_hurt_player.stream == sound._goblin_hurt_voices[0])
	sound._last_impact_msec = -1000
	sound.play_impact(false, false, true)
	assert(sound._pending_hurt_clips == sound._bat_hurt_voices)
	sound._last_impact_msec = -1000
	sound.play_impact(true)
	assert(sound._pending_hurt_clips == sound._slime_hurt_voices)
	sound._last_goblin_attack_msec = -1000
	sound.play_enemy_attack_voice(false, true)
	assert(is_equal_approx(sound._goblin_attack_player.pitch_scale, 0.9))
	print("goblin_user_audio_smoke: PASS")
	sound.queue_free()
	await process_frame
	quit()
