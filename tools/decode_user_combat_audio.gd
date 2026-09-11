extends SceneTree

func _initialize() -> void:
	for pair in [
		["D:/谷歌下载/刀剑刺中出血；刀剑砍到身体，流血了；刀剑砍杀音效；挥刀劈砍音_爱给网_aigei_com.mp3", "flesh_cut"],
		["D:/谷歌下载/60大剑挥舞_爱给网_aigei_com.mp3", "greatsword_swing"],
		["D:/谷歌下载/哥布林攻击B(GoblinAttackB)_爱给网_aigei_com.mp3", "goblin_attack"],
		["D:/谷歌下载/哥布林伤C(GoblinWoundC)_爱给网_aigei_com.mp3", "goblin_hurt"]
	]:
		if not FileAccess.file_exists(pair[0]):
			continue
		var stream := AudioStreamMP3.new()
		stream.data = FileAccess.get_file_as_bytes(pair[0])
		print(pair[1], " duration=", stream.get_length())
		if stream.get_length() <= 0.0:
			continue
		var playback := stream.instantiate_playback()
		playback.start()
		var frames := playback.mix_audio(1.0, int(ceil(stream.get_length() * AudioServer.get_mix_rate())))
		var bytes := PackedByteArray()
		bytes.resize(frames.size() * 4)
		for i in frames.size():
			bytes.encode_s16(i * 4, int(clampf(frames[i].x, -1.0, 1.0) * 32767))
			bytes.encode_s16(i * 4 + 2, int(clampf(frames[i].y, -1.0, 1.0) * 32767))
		var wav := AudioStreamWAV.new()
		wav.format = AudioStreamWAV.FORMAT_16_BITS
		wav.stereo = true
		wav.mix_rate = int(AudioServer.get_mix_rate())
		wav.data = bytes
		wav.save_to_wav("res://test_output/" + pair[1] + "_decoded.wav")
	quit()
