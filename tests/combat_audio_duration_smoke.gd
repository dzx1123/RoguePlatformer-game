extends SceneTree


func _initialize() -> void:
	var checks := {
		"res://assets/audio/designed/whoosh_1.wav": 0.80,
		"res://assets/audio/designed/whoosh_2.wav": 0.80,
		"res://assets/audio/designed/whoosh_3.wav": 0.80,
		"res://assets/audio/designed/hyah_1.wav": 0.80,
		"res://assets/audio/designed/hit_1.wav": 0.80,
		"res://assets/audio/gore_cc0/flesh_burst.ogg": 1.50,
		"res://assets/audio/gore_cc0/flesh_burst_2.ogg": 1.50,
		"res://assets/audio/gore_cc0/crunch.ogg": 1.50,
		"res://assets/audio/gore_cc0/slime_splat_1.wav": 1.50,
		"res://assets/audio/gore_cc0/slime_splat_2.wav": 1.50,
	}
	for path_value in checks:
		var path := String(path_value)
		var duration := 0.0
		if path.begins_with("res://assets/audio/designed/"):
			duration = RogueSoundscape.wav_duration(path)
		else:
			var stream := load(path) as AudioStream
			if stream == null:
				_fail("Could not load combat audio: %s" % path)
				return
			duration = stream.get_length()
		print("combat_audio_duration: %s %.3fs" % [path.get_file(), duration])
		if duration <= 0.0 or duration > float(checks[path_value]):
			_fail("Combat audio duration is unsuitable: %s %.3fs" % [path, duration])
			return
	var voice_db := RogueSoundscape.wav_peak_db("res://assets/audio/designed/hyah_1.wav")
	var hit_db := RogueSoundscape.wav_peak_db("res://assets/audio/designed/hit_1.wav")
	var whoosh_db := RogueSoundscape.wav_peak_db("res://assets/audio/designed/whoosh_1.wav")
	print("combat_audio_mix: voice=%.1fdB hit=%.1fdB whoosh=%.1fdB" % [voice_db, hit_db, whoosh_db])
	if hit_db > voice_db - 4.0 or hit_db < voice_db - 10.0:
		_fail("Blade ding must stay lighter than the shout")
		return
	if whoosh_db > voice_db - 10.0 or whoosh_db > hit_db - 6.0:
		_fail("Designed mix hierarchy is voice > hit > whoosh")
		return
	print("combat_audio_duration_smoke: PASS")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
