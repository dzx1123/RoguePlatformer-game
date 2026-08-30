extends SceneTree


func _initialize() -> void:
	var checks := {
		"res://assets/audio/sword_cc0/sword_swing_1.wav": 0.80,
		"res://assets/audio/sword_cc0/sword_swing_2.wav": 0.80,
		"res://assets/audio/sword_cc0/sword_swing_3.wav": 0.80,
		"res://assets/audio/gore_cc0/flesh_burst.ogg": 1.50,
		"res://assets/audio/gore_cc0/flesh_burst_2.ogg": 1.50,
		"res://assets/audio/gore_cc0/crunch.ogg": 1.50,
		"res://assets/audio/gore_cc0/slime_splat_1.wav": 1.50,
		"res://assets/audio/gore_cc0/slime_splat_2.wav": 1.50,
	}
	for path_value in checks:
		var path := String(path_value)
		var stream := load(path) as AudioStream
		if stream == null:
			_fail("Could not load combat audio: %s" % path)
			return
		var duration := stream.get_length()
		print("combat_audio_duration: %s %.3fs" % [path.get_file(), duration])
		if duration <= 0.0 or duration > float(checks[path_value]):
			_fail("Combat audio duration is unsuitable: %s %.3fs" % [path, duration])
			return
	print("combat_audio_duration_smoke: PASS")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
