extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var sound := RogueSoundscape.new()
	root.add_child(sound)
	sound.set_process(false)
	for path in [RogueSoundscape.USER_GREAT_SWING_PATH, RogueSoundscape.USER_FLESH_CUT_PATH]:
		var length := RogueSoundscape.wav_duration(path)
		if length < 0.1 or length > 0.8:
			_fail("Invalid user clip duration: %s" % path)
			return
		if RogueSoundscape.wav_peak_db(path) > -8.0:
			_fail("User clip peak is too loud: %s" % path)
			return
	sound.play_sword_swing(WeaponCatalog.GREATSWORD)
	if sound._swing_player.stream != sound._greatsword_swing_sfx[0] or sound._hit_player.playing:
		_fail("Greatsword swing routing or miss behavior is incorrect")
		return
	sound.play_impact(false)
	if sound._hit_player.stream != sound._flesh_cut_sfx[0] or not sound._swing_player.playing:
		_fail("Flesh hit must use user clip and preserve swing tail")
		return
	var first_hit := sound._last_impact_msec
	sound.play_impact(true)
	if sound._last_impact_msec != first_hit or sound._hit_player.stream != sound._flesh_cut_sfx[0]:
		_fail("Same-frame multi-target hit was not coalesced")
		return
	while Time.get_ticks_msec() - first_hit < 90:
		await process_frame
	sound.play_impact(true)
	if sound._hit_player.stream not in sound._hit_sfx:
		_fail("Slime must retain its existing contact sound")
		return
	for weapon in [WeaponCatalog.SWORD, WeaponCatalog.TWIN_BLADES]:
		sound.play_sword_swing(weapon)
		if sound._swing_player.stream not in sound._sword_swing_sfx:
			_fail("Light weapon incorrectly uses greatsword clip")
			return
	sound.play_skill(WeaponCatalog.GREATSWORD)
	if sound._swing_player.stream != sound._greatsword_swing_sfx[0]:
		_fail("Greatsword skill must share its weapon sound")
		return
	print("user_combat_audio_smoke: PASS")
	sound.queue_free()
	await process_frame
	quit()

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
