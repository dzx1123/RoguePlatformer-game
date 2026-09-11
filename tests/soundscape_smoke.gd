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
	if soundscape.get_current_player_voice_path() != "res://assets/audio/designed/down_1.wav":
		_fail("Player vocal cue did not select the designed defeat sample")
		return
	if soundscape.get_player_voice_sample_count() != 10:
		_fail("The complete young protagonist combat voice set was not loaded")
		return
	var loaded_combat_samples: int = soundscape.get_loaded_combat_sample_count()
	if loaded_combat_samples != 44:
		_fail("Designed combat samples were not loaded (got %d, expected 44)" % loaded_combat_samples)
		return
	soundscape.play_land()
	soundscape.play_ui()
	soundscape.play_skill(WeaponCatalog.TWIN_BLADES)
	soundscape.play_skill(WeaponCatalog.GREATSWORD)
	if soundscape.get_loaded_music_count() != 3:
		_fail("Cover, room, and boss music beds were not loaded")
		return
	soundscape.set_music_state(RogueSoundscape.MusicState.EXPLORE)
	soundscape.set_music_state(RogueSoundscape.MusicState.BOSS)
	if soundscape.get_music_state() != RogueSoundscape.MusicState.BOSS:
		_fail("Boss music state did not apply")
		return
	soundscape.play_enemy_bite(true)
	soundscape.play_enemy_spit(true)
	soundscape.play_enemy_defeat(true)
	var active_voice_count: int = soundscape.get_active_voice_count()
	if active_voice_count != 9:
		_fail("Soundscape did not register every combat sound cue (got %d, expected 9)" % active_voice_count)
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
