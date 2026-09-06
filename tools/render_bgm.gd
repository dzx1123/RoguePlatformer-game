extends SceneTree

## Original looping beds for 月蚀回廊.
## Cover is soft moonlit song. Explore/boss are rock; boss is the faster variant.

const OUT := "res://assets/audio/music/"
const RATE := 22050


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_write("cover.wav", _compose_cover())
	_write("explore.wav", _compose_rock(120.0, false))
	_write("boss.wav", _compose_rock(176.0, true))
	print("render_bgm: PASS")
	quit(0)


func _compose_cover() -> PackedFloat32Array:
	# Soft title song, 60 BPM, 8 bars = 32 beats = 32s? 4 bars at 60 = 16s.
	var bpm := 60.0
	var bars := 4
	var beat := 60.0 / bpm
	var seconds: float = float(bars) * 4.0 * beat
	var buf := _silence(seconds)
	_add_pad(buf, 73.42, 0.0, seconds, 0.11)
	_add_pad(buf, 110.00, 0.0, seconds, 0.07)
	_add_pad(buf, 146.83, 0.0, seconds, 0.045)
	var melody := [293.66, 349.23, 392.00, 440.00, 392.00, 349.23, 293.66, 261.63]
	for index in range(melody.size()):
		_add_bell(buf, float(melody[index]), float(index) * beat * 2.0, beat * 2.2, 0.10)
	for step in range(bars * 4):
		_add_arp(buf, 220.00, float(step) * beat, beat * 0.45, 0.028)
	_add_air(buf, 0.012)
	return _normalize(buf, 0.72)


func _compose_rock(bpm: float, boss: bool) -> PackedFloat32Array:
	# Same D-minor rock riff. Boss is faster and denser.
	var beat := 60.0 / bpm
	var bars := 8
	var seconds: float = float(bars) * 4.0 * beat
	var buf := _silence(seconds)
	var chords := [
		[73.42, 110.00],
		[73.42, 110.00],
		[87.31, 130.81],
		[65.41, 98.00],
		[58.27, 87.31],
		[87.31, 130.81],
		[65.41, 98.00],
		[73.42, 110.00],
	]
	var riff := [146.83, 174.61, 196.00, 220.00, 196.00, 174.61, 146.83, 130.81]
	_add_pad(buf, 36.71 if boss else 46.25, 0.0, seconds, 0.08 if boss else 0.05)
	for bar in range(bars):
		var bar_t: float = float(bar) * 4.0 * beat
		var chord: Array = chords[bar]
		for step in range(4):
			var t: float = bar_t + float(step) * beat
			_add_kick(buf, t, 0.22 if boss else 0.16)
			if boss:
				_add_kick(buf, t + beat * 0.5, 0.10)
			if step == 1 or step == 3:
				_add_snare(buf, t, 0.18 if boss else 0.13)
			_add_hat(buf, t, 0.05)
			_add_hat(buf, t + beat * 0.5, 0.07 if boss else 0.04)
			_add_bass(buf, float(chord[0]), t, beat * 0.72, 0.20 if boss else 0.15)
			_add_power(buf, float(chord[0]), float(chord[1]), t, beat * 0.70, 0.14 if boss else 0.10)
		var riff_hz: float = float(riff[bar])
		_add_lead(buf, riff_hz, bar_t + beat * 0.0, beat * 0.9, 0.09 if boss else 0.07)
		_add_lead(buf, riff_hz * 1.5, bar_t + beat * 2.0, beat * 0.8, 0.07 if boss else 0.05)
	return _normalize(buf, 0.78 if boss else 0.74)


func _silence(seconds: float) -> PackedFloat32Array:
	var samples := PackedFloat32Array()
	samples.resize(maxi(64, int(round(seconds * float(RATE)))))
	return samples


func _add_pad(buf: PackedFloat32Array, hz: float, start: float, dur: float, gain: float) -> void:
	var a0: int = _idx(buf, start)
	var count: int = mini(buf.size() - a0, int(round(dur * float(RATE))))
	for index in range(count):
		var progress: float = float(index) / float(maxi(1, count - 1))
		var env: float = 1.0
		if progress < 0.06:
			env = progress / 0.06
		elif progress > 0.90:
			env = (1.0 - progress) / 0.10
		var t: float = float(a0 + index) / float(RATE)
		buf[a0 + index] += sin(TAU * hz * t) * env * gain


func _add_bell(buf: PackedFloat32Array, hz: float, start: float, dur: float, gain: float) -> void:
	var a0: int = _idx(buf, start)
	var count: int = mini(buf.size() - a0, int(round(dur * float(RATE))))
	for index in range(count):
		var age: float = float(index) / float(RATE)
		var t: float = float(a0 + index) / float(RATE)
		buf[a0 + index] += (sin(TAU * hz * t) + sin(TAU * hz * 2.0 * t) * 0.12) * exp(-age * 1.8) * gain


func _add_arp(buf: PackedFloat32Array, hz: float, start: float, dur: float, gain: float) -> void:
	var a0: int = _idx(buf, start)
	var count: int = mini(buf.size() - a0, int(round(dur * float(RATE))))
	for index in range(count):
		var age: float = float(index) / float(RATE)
		buf[a0 + index] += sin(TAU * hz * age) * exp(-age * 8.0) * gain


func _add_kick(buf: PackedFloat32Array, start: float, gain: float) -> void:
	var a0: int = _idx(buf, start)
	var count: int = mini(buf.size() - a0, int(round(0.14 * float(RATE))))
	for index in range(count):
		var age: float = float(index) / float(RATE)
		var hz: float = lerpf(140.0, 42.0, clampf(age / 0.08, 0.0, 1.0))
		buf[a0 + index] += sin(TAU * hz * age) * exp(-age * 16.0) * gain


func _add_snare(buf: PackedFloat32Array, start: float, gain: float) -> void:
	var a0: int = _idx(buf, start)
	var count: int = mini(buf.size() - a0, int(round(0.10 * float(RATE))))
	var noise := 0.31
	for index in range(count):
		var age: float = float(index) / float(RATE)
		noise = fmod(noise * 1.017 + 0.013, 1.0)
		var air: float = sin(noise * 12289.0)
		buf[a0 + index] += (sin(TAU * 180.0 * age) * 0.35 + air * 0.65) * exp(-age * 28.0) * gain


func _add_hat(buf: PackedFloat32Array, start: float, gain: float) -> void:
	var a0: int = _idx(buf, start)
	var count: int = mini(buf.size() - a0, int(round(0.04 * float(RATE))))
	var noise := 0.51
	var lp := 0.0
	for index in range(count):
		var age: float = float(index) / float(RATE)
		noise = fmod(noise * 1.021 + 0.019, 1.0)
		var air: float = sin(noise * 9337.0)
		lp += 0.35 * (air - lp)
		buf[a0 + index] += (air - lp) * exp(-age * 55.0) * gain


func _add_bass(buf: PackedFloat32Array, hz: float, start: float, dur: float, gain: float) -> void:
	var a0: int = _idx(buf, start)
	var count: int = mini(buf.size() - a0, int(round(dur * float(RATE))))
	for index in range(count):
		var progress: float = float(index) / float(maxi(1, count - 1))
		var env: float = 1.0 if progress < 0.7 else (1.0 - progress) / 0.3
		if progress < 0.02:
			env = progress / 0.02
		var t: float = float(a0 + index) / float(RATE)
		buf[a0 + index] += tanh(sin(TAU * hz * t) * 1.8) * env * gain


func _add_power(buf: PackedFloat32Array, root: float, fifth: float, start: float, dur: float, gain: float) -> void:
	var a0: int = _idx(buf, start)
	var count: int = mini(buf.size() - a0, int(round(dur * float(RATE))))
	for index in range(count):
		var progress: float = float(index) / float(maxi(1, count - 1))
		var env: float = 1.0 if progress < 0.55 else (1.0 - progress) / 0.45
		if progress < 0.03:
			env = progress / 0.03
		var t: float = float(a0 + index) / float(RATE)
		var raw: float = sin(TAU * root * 2.0 * t) + sin(TAU * fifth * 2.0 * t) * 0.9
		buf[a0 + index] += tanh(raw * 1.6) * env * gain


func _add_lead(buf: PackedFloat32Array, hz: float, start: float, dur: float, gain: float) -> void:
	var a0: int = _idx(buf, start)
	var count: int = mini(buf.size() - a0, int(round(dur * float(RATE))))
	for index in range(count):
		var age: float = float(index) / float(RATE)
		var t: float = float(a0 + index) / float(RATE)
		var env: float = exp(-age * 3.2)
		buf[a0 + index] += tanh(sin(TAU * hz * t) * 1.3) * env * gain


func _add_air(buf: PackedFloat32Array, gain: float) -> void:
	var acc := 0.17
	for index in range(buf.size()):
		acc = fmod(acc * 1.0133 + 0.017, 1.0)
		buf[index] += sin(acc * 8191.0) * gain * 0.04


func _idx(buf: PackedFloat32Array, start: float) -> int:
	return clampi(int(round(start * float(RATE))), 0, buf.size() - 1)


func _normalize(buf: PackedFloat32Array, peak: float) -> PackedFloat32Array:
	var fade: int = mini(buf.size() / 12, int(round(0.03 * float(RATE))))
	for index in range(fade):
		var w: float = float(index) / float(maxi(1, fade))
		buf[index] *= w
		buf[buf.size() - 1 - index] *= w
	var loudest := 0.0001
	for value in buf:
		loudest = maxf(loudest, absf(value))
	var gain: float = peak / loudest
	for index in range(buf.size()):
		buf[index] = clampf(buf[index] * gain, -0.92, 0.92)
	return buf


func _write(name_value: String, samples: PackedFloat32Array) -> void:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = samples.size()
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for index in range(samples.size()):
		var quantized: int = clampi(int(round(samples[index] * 32767.0)), -32767, 32767)
		bytes[index * 2] = quantized & 0xFF
		bytes[index * 2 + 1] = (quantized >> 8) & 0xFF
	wav.data = bytes
	var path := ProjectSettings.globalize_path(OUT + name_value)
	if wav.save_to_wav(path) != OK:
		push_error("Could not save %s" % path)
		quit(1)
		return
	print("wrote %s n=%d peak_ready" % [name_value, samples.size()])
