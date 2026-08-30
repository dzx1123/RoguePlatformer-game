extends SceneTree


func _initialize() -> void:
	call_deferred(&"_run_test")


func _run_test() -> void:
	var soundscape := RogueSoundscape.new()
	root.add_child(soundscape)
	await process_frame
	soundscape.play_sword_swing()
	soundscape.play_impact()
	soundscape.play_dash()
	soundscape.play_skill()
	soundscape.play_player_attack_voice()
	soundscape.play_player_skill_voice()
	soundscape.play_player_hurt_voice()
	soundscape.play_player_defeat_voice()
	if soundscape.get_current_player_voice_path() != "res://assets/audio/player_voice/defeat.wav":
		_fail("Player vocal cue did not select the rendered defeat sample")
		return
	if soundscape.get_player_voice_sample_count() != 10:
		_fail("The complete young protagonist combat voice set was not loaded")
		return
	if soundscape.get_loaded_combat_sample_count() != 12:
		_fail("CC0 combat samples were not loaded")
		return
	soundscape.play_enemy_bite(true)
	soundscape.play_enemy_spit(true)
	soundscape.play_enemy_defeat(true)
	if soundscape.get_active_voice_count() != 5:
		_fail("Soundscape did not register every combat sound cue")
		return
	for _frame in range(42):
		await process_frame
	if soundscape.get_active_voice_count() != 0:
		_fail("Soundscape did not release completed sound voices")
		return
	soundscape.queue_free()
	print("soundscape_smoke: PASS")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
