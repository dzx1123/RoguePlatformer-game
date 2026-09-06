extends SceneTree

## Original combat palette for the boy swordsman.
## Not Kenney/swish packs, not konakuma vocals, not Nintendo audio.
## Mix is baked into the files: voice louder than blade, blade louder than whoosh.

const OUT := "res://assets/audio/designed/"
const RATE := 44100

## Linear peaks. Voice stays on top; hit is a close confirm, whoosh stays quiet.
const PEAK_VOICE := 0.92
const PEAK_VOICE_JUMP := 0.86
const PEAK_VOICE_HURT := 0.86
const PEAK_VOICE_DOWN := 0.78
const PEAK_HIT := 0.45
const PEAK_WHOOSH := 0.20
const PEAK_JUMP_AIR := 0.16
const PEAK_CAST := 0.34
const PEAK_BITE := 0.50
const PEAK_SPIT := 0.42
const PEAK_FLESH := 0.55
const PEAK_SLIME := 0.52
const PEAK_CREATURE := 0.78
const PEAK_CREATURE_HURT := 0.28
const PEAK_CREATURE_DOWN := 0.32

var _noise_state: int = 2463534242
var _peaks: Dictionary = {}


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_write("hyah_1.wav", _shout("attack", 412.0, 0.13, 17), PEAK_VOICE)
	_write("hyah_2.wav", _shout("attack", 438.0, 0.12, 29), PEAK_VOICE)
	_write("hyah_3.wav", _shout("attack", 396.0, 0.14, 41), PEAK_VOICE)
	_write("hyaaah_1.wav", _shout("skill", 404.0, 0.20, 53), PEAK_VOICE)
	_write("hyaaah_2.wav", _shout("skill", 428.0, 0.18, 67), PEAK_VOICE)
	_write("hyaaah_3.wav", _shout("skill", 388.0, 0.22, 79), PEAK_VOICE)
	_write("hup.wav", _shout("jump", 442.0, 0.12, 97), PEAK_VOICE_JUMP)
	_write("hup_2.wav", _shout("jump", 458.0, 0.11, 103), PEAK_VOICE_JUMP)
	_write("hurt_1.wav", _shout("hurt", 452.0, 0.14, 109), PEAK_VOICE_HURT)
	_write("hurt_2.wav", _shout("hurt", 430.0, 0.15, 127), PEAK_VOICE_HURT)
	_write("down_1.wav", _shout("defeat", 348.0, 0.28, 139), PEAK_VOICE_DOWN)
	_write("down_2.wav", _shout("defeat", 332.0, 0.30, 151), PEAK_VOICE_DOWN)
	_write("whoosh_1.wav", _whoosh(0.12, 1.00, 163), PEAK_WHOOSH, false)
	_write("whoosh_2.wav", _whoosh(0.10, 0.92, 181), PEAK_WHOOSH, false)
	_write("whoosh_3.wav", _whoosh(0.13, 0.96, 199), PEAK_WHOOSH, false)
	_write("jump_air.wav", _whoosh(0.09, 0.80, 173), PEAK_JUMP_AIR, false)
	_write("hit_1.wav", _blade_hit(0.08, 1.00, 211), PEAK_HIT, false)
	_write("hit_2.wav", _blade_hit(0.07, 0.96, 223), PEAK_HIT, false)
	_write("cast_1.wav", _cast(0.20, 1.00, 241), PEAK_CAST)
	_write("cast_2.wav", _cast(0.18, 0.94, 257), PEAK_CAST)
	_write("bite.wav", _bite(0.14, 1.00, 271), PEAK_BITE)
	_write("bite_2.wav", _bite(0.13, 0.94, 277), PEAK_BITE)
	_write("spit.wav", _spit(0.15, 1.00, 283), PEAK_SPIT)
	_write("spit_2.wav", _spit(0.14, 0.92, 289), PEAK_SPIT)
	_write("flesh_hit.wav", _flesh_hit(0.10, 1.00, 293), PEAK_FLESH)
	_write("slime_hit.wav", _slime_hit(0.11, 1.00, 307), PEAK_SLIME)
	_write("goblin_atk_1.wav", _creature("goblin_atk", 188.0, 0.18, 311), PEAK_CREATURE)
	_write("goblin_atk_2.wav", _creature("goblin_atk", 168.0, 0.16, 313), PEAK_CREATURE)
	_write("goblin_hurt_1.wav", _monster_cry("goblin_hurt", 540.0, 0.09, 317), PEAK_CREATURE_HURT, false)
	_write("goblin_hurt_2.wav", _monster_cry("goblin_hurt", 500.0, 0.08, 331), PEAK_CREATURE_HURT, false)
	_write("goblin_down_1.wav", _monster_cry("goblin_down", 420.0, 0.16, 333), PEAK_CREATURE_DOWN, false)
	_write("goblin_down_2.wav", _monster_cry("goblin_down", 390.0, 0.15, 335), PEAK_CREATURE_DOWN, false)
	_write("slime_atk_1.wav", _creature("slime_atk", 132.0, 0.18, 337), PEAK_CREATURE)
	_write("slime_atk_2.wav", _creature("slime_atk", 118.0, 0.16, 347), PEAK_CREATURE)
	_write("slime_hurt_1.wav", _monster_cry("slime_hurt", 980.0, 0.10, 349), PEAK_CREATURE_HURT, false)
	_write("slime_hurt_2.wav", _monster_cry("slime_hurt", 1080.0, 0.09, 353), PEAK_CREATURE_HURT, false)
	_write("slime_down_1.wav", _monster_cry("slime_down", 720.0, 0.16, 359), PEAK_CREATURE_DOWN, false)
	_write("slime_down_2.wav", _monster_cry("slime_down", 660.0, 0.15, 367), PEAK_CREATURE_DOWN, false)
	_write("land_1.wav", _thump(0.11, 1.00, 401), 0.22, false)
	_write("land_2.wav", _thump(0.10, 0.92, 409), 0.22, false)
	_write("step_1.wav", _step(0.06, 1.00, 419), 0.12, false)
	_write("step_2.wav", _step(0.055, 0.90, 421), 0.12, false)
	_write("ui_click.wav", _ui_click(0.06, 1.00, 431), 0.18, false)
	_write("ui_deny.wav", _ui_deny(0.08, 1.00, 433), 0.16, false)
	_write("card.wav", _card(0.14, 1.00, 439), 0.22, false)
	_write("chest.wav", _chest(0.22, 1.00, 443), 0.28, false)
	_write("portal.wav", _portal(0.32, 1.00, 449), 0.30)
	_write("skill_twin.wav", _cast_twin(0.16, 1.00, 457), 0.32)
	_write("skill_great.wav", _cast_great(0.24, 1.00, 461), 0.36)
	if not _assert_mix():
		quit(1)
		return
	print("render_designed_audio: PASS")
	quit(0)


func _write(name_value: String, samples: PackedFloat32Array, peak: float, compress: bool = true) -> void:
	if compress:
		_compress(samples, 0.30, 2.4)
	_fade_edges(samples, 0.002)
	_normalize(samples, peak)
	_peaks[name_value] = _peak_of(samples)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = _pcm16(samples)
	var path := ProjectSettings.globalize_path(OUT + name_value)
	if wav.save_to_wav(path) != OK:
		push_error("Could not save %s" % path)
		quit(1)
		return
	print(
		"wrote %s n=%d peak=%.1fdB rms=%.1fdB"
		% [name_value, samples.size(), _db(_peaks[name_value]), _db(_rms(samples))]
	)


func _assert_mix() -> bool:
	var voice_peak: float = float(_peaks["hyah_1.wav"])
	var hit_peak: float = float(_peaks["hit_1.wav"])
	var whoosh_peak: float = float(_peaks["whoosh_1.wav"])
	var voice_db: float = _db(voice_peak)
	var hit_db: float = _db(hit_peak)
	var whoosh_db: float = _db(whoosh_peak)
	print("MIX voice=%.1fdB hit=%.1fdB whoosh=%.1fdB" % [voice_db, hit_db, whoosh_db])
	if hit_db > voice_db - 4.0:
		push_error("Mix failed: blade ding must stay lighter than the shout")
		return false
	if hit_db < voice_db - 10.0:
		push_error("Mix failed: blade ding disappeared under the shout")
		return false
	if whoosh_db > voice_db - 10.0:
		push_error("Mix failed: whoosh must be quieter than the shout")
		return false
	if whoosh_db > hit_db - 6.0:
		push_error("Mix failed: whoosh must sit under the blade hit")
		return false
	print("HIERARCHY voice > hit > whoosh : PASS")
	return true


func _shout(kind: String, f0: float, length: float, seed_value: int) -> PackedFloat32Array:
	_noise_state = seed_value * 1103515245 + 12345
	var count: int = maxi(64, int(round(length * float(RATE))))
	var samples := PackedFloat32Array()
	samples.resize(count)
	var r1 := _new_res()
	var r2 := _new_res()
	var r3 := _new_res()
	var r4 := _new_res()
	var r2p := _new_res()
	var phase := 0.0
	var prev_flow := 0.0
	var tilt := 0.0
	var hp_x := 0.0
	var hp_y := 0.0
	var keys: Array = _shout_keys(kind)
	var oq: float = 0.68
	if kind == "hurt":
		oq = 0.72
	elif kind == "defeat":
		oq = 0.70
	elif kind == "jump":
		oq = 0.66
	var tilt_p: float = exp(-TAU * 2050.0 / float(RATE))
	var hp_r: float = exp(-TAU * 250.0 / float(RATE))
	for index in range(count):
		var age: float = float(index) / float(RATE)
		var progress: float = age / length
		var frame: Dictionary = _interp_keys(keys, age, length)
		var freq: float = f0 * float(frame["f0mul"])
		freq *= 1.0 + 0.008 * sin(float(index) * 0.081 + float(seed_value))
		phase += freq / float(RATE)
		if phase >= 1.0:
			phase -= floor(phase)
		var flow: float = _rosenberg(phase, oq)
		var rad: float = (flow - prev_flow) * 0.095
		prev_flow = flow
		var open_gate: float = 1.0 if phase < oq else 0.14
		var breath: float = _white() * float(frame["b"]) * open_gate * 0.12
		var voiced: float = rad * float(frame["v"])
		if progress < 0.04 and kind != "jump":
			voiced *= progress / 0.04
		var mixed: float = voiced + breath
		tilt = (1.0 - tilt_p) * mixed + tilt_p * tilt
		_set_res(r1, float(frame["f1"]), 80.0)
		_set_res(r2, float(frame["f2"]), 95.0)
		_set_res(r3, float(frame["f3"]), 140.0)
		_set_res(r4, 3750.0, 220.0)
		_set_res(r2p, float(frame["f2"]), 85.0)
		var filtered: float = _res(r1, tilt)
		filtered = _res(r2, filtered)
		filtered = _res(r3, filtered)
		filtered = _res(r4, filtered)
		filtered += _res(r2p, tilt) * 0.22
		var hp: float = filtered - hp_x + hp_r * hp_y
		hp_x = filtered
		hp_y = hp
		var env: float = _shout_env(kind, progress)
		samples[index] = tanh(hp * env * 1.55) * 0.94
	return samples


func _shout_keys(kind: String) -> Array:
	match kind:
		"attack":
			return [
				{"t": 0.00, "f0mul": 1.05, "f1": 540.0, "f2": 2360.0, "f3": 3280.0, "v": 0.42, "b": 0.48},
				{"t": 0.16, "f0mul": 1.10, "f1": 460.0, "f2": 2740.0, "f3": 3520.0, "v": 0.92, "b": 0.16},
				{"t": 0.40, "f0mul": 1.02, "f1": 880.0, "f2": 1780.0, "f3": 3240.0, "v": 1.00, "b": 0.10},
				{"t": 0.74, "f0mul": 0.97, "f1": 820.0, "f2": 1700.0, "f3": 3140.0, "v": 0.84, "b": 0.12},
				{"t": 1.00, "f0mul": 0.92, "f1": 720.0, "f2": 1620.0, "f3": 3020.0, "v": 0.22, "b": 0.18},
			]
		"skill":
			return [
				{"t": 0.00, "f0mul": 0.98, "f1": 520.0, "f2": 2280.0, "f3": 3220.0, "v": 0.40, "b": 0.46},
				{"t": 0.14, "f0mul": 1.06, "f1": 470.0, "f2": 2620.0, "f3": 3480.0, "v": 0.90, "b": 0.16},
				{"t": 0.42, "f0mul": 1.08, "f1": 900.0, "f2": 1740.0, "f3": 3200.0, "v": 1.00, "b": 0.12},
				{"t": 0.76, "f0mul": 0.96, "f1": 840.0, "f2": 1660.0, "f3": 3080.0, "v": 0.78, "b": 0.14},
				{"t": 1.00, "f0mul": 0.90, "f1": 740.0, "f2": 1580.0, "f3": 2960.0, "v": 0.18, "b": 0.20},
			]
		"jump":
			return [
				{"t": 0.00, "f0mul": 1.08, "f1": 540.0, "f2": 1680.0, "f3": 3180.0, "v": 0.62, "b": 0.36},
				{"t": 0.24, "f0mul": 1.16, "f1": 680.0, "f2": 1580.0, "f3": 3080.0, "v": 1.00, "b": 0.12},
				{"t": 0.62, "f0mul": 1.04, "f1": 620.0, "f2": 1480.0, "f3": 2980.0, "v": 0.82, "b": 0.14},
				{"t": 1.00, "f0mul": 0.94, "f1": 540.0, "f2": 1380.0, "f3": 2880.0, "v": 0.20, "b": 0.18},
			]
		"hurt":
			return [
				{"t": 0.00, "f0mul": 1.18, "f1": 620.0, "f2": 2100.0, "f3": 3400.0, "v": 0.32, "b": 0.76},
				{"t": 0.30, "f0mul": 1.08, "f1": 960.0, "f2": 1760.0, "f3": 3280.0, "v": 1.00, "b": 0.32},
				{"t": 1.00, "f0mul": 0.78, "f1": 760.0, "f2": 1580.0, "f3": 3060.0, "v": 0.18, "b": 0.42},
			]
		"defeat":
			return [
				{"t": 0.00, "f0mul": 1.04, "f1": 600.0, "f2": 1860.0, "f3": 3200.0, "v": 0.38, "b": 0.60},
				{"t": 0.28, "f0mul": 0.94, "f1": 820.0, "f2": 1640.0, "f3": 3080.0, "v": 0.88, "b": 0.32},
				{"t": 1.00, "f0mul": 0.78, "f1": 620.0, "f2": 1480.0, "f3": 2860.0, "v": 0.12, "b": 0.44},
			]
	return [
		{"t": 0.00, "f0mul": 1.0, "f1": 500.0, "f2": 1400.0, "f3": 2400.0, "v": 1.0, "b": 0.2},
		{"t": 1.00, "f0mul": 1.0, "f1": 500.0, "f2": 1400.0, "f3": 2400.0, "v": 1.0, "b": 0.2},
	]


func _interp_keys(keys: Array, age: float, length: float) -> Dictionary:
	var t: float = clampf(age / maxf(length, 0.001), 0.0, 1.0)
	var prev: Dictionary = keys[0]
	for index in range(1, keys.size()):
		var nxt: Dictionary = keys[index]
		var t1: float = float(nxt["t"])
		if t <= t1 or index == keys.size() - 1:
			var t0: float = float(prev["t"])
			var w: float = clampf((t - t0) / maxf(0.0001, t1 - t0), 0.0, 1.0)
			return {
				"f0mul": lerpf(float(prev["f0mul"]), float(nxt["f0mul"]), w),
				"f1": lerpf(float(prev["f1"]), float(nxt["f1"]), w),
				"f2": lerpf(float(prev["f2"]), float(nxt["f2"]), w),
				"f3": lerpf(float(prev["f3"]), float(nxt["f3"]), w),
				"v": lerpf(float(prev["v"]), float(nxt["v"]), w),
				"b": lerpf(float(prev["b"]), float(nxt["b"]), w),
			}
		prev = nxt
	return prev


func _shout_env(kind: String, progress: float) -> float:
	var attack: float = 0.05
	var hold: float = 0.34
	match kind:
		"skill":
			hold = 0.40
		"jump":
			attack = 0.06
			hold = 0.38
		"hurt":
			hold = 0.22
		"defeat":
			hold = 0.28
	if progress < attack:
		return progress / attack
	if progress < attack + hold:
		return 1.0
	var rest: float = (progress - attack - hold) / maxf(0.08, 1.0 - attack - hold)
	return (1.0 - rest) * (1.0 - rest)


func _rosenberg(phase: float, oq: float) -> float:
	if phase >= oq:
		return 0.0
	var peak_at: float = oq * 0.55
	if phase < peak_at:
		return 0.5 * (1.0 - cos(PI * phase / maxf(peak_at, 0.001)))
	return 0.5 * (1.0 + cos(PI * (phase - peak_at) / maxf(oq - peak_at, 0.001)))


func _whoosh(length: float, gain: float, seed_value: int) -> PackedFloat32Array:
	_noise_state = seed_value * 1664525 + 1013904223
	var count: int = maxi(64, int(round(length * float(RATE))))
	var samples := PackedFloat32Array()
	samples.resize(count)
	var lp := 0.0
	var hp_x := 0.0
	var hp_y := 0.0
	var hp_r: float = exp(-TAU * 480.0 / float(RATE))
	for index in range(count):
		var progress: float = float(index) / float(maxi(1, count - 1))
		var env: float = progress / 0.08 if progress < 0.08 else (1.0 - progress) * (1.0 - progress) / 0.8464
		env = clampf(env, 0.0, 1.0)
		var cutoff: float = lerpf(0.28, 0.05, progress)
		var air: float = _white()
		lp += cutoff * (air - lp)
		var hp: float = lp - hp_x + hp_r * hp_y
		hp_x = lp
		hp_y = hp
		samples[index] = clampf(hp * env * gain, -0.95, 0.95)
	return samples


func _blade_hit(length: float, gain: float, seed_value: int) -> PackedFloat32Array:
	# Crisp sword ding: high metallic tick, almost no bass punch.
	_noise_state = seed_value * 214013 + 2531011
	var count: int = maxi(64, int(round(length * float(RATE))))
	var samples := PackedFloat32Array()
	samples.resize(count)
	var nail_hz: float = 2680.0 if seed_value == 211 else 2940.0
	var hp_x := 0.0
	var hp_y := 0.0
	var hp_r: float = exp(-TAU * 900.0 / float(RATE))
	for index in range(count):
		var age: float = float(index) / float(RATE)
		var click: float = _white() * exp(-age * 120.0)
		var ding: float = sin(TAU * nail_hz * age) * exp(-age * 38.0)
		var ding2: float = sin(TAU * nail_hz * 1.48 * age) * exp(-age * 52.0)
		var ding3: float = sin(TAU * 4120.0 * age) * exp(-age * 70.0)
		var mixed: float = click * 0.42 + ding * 0.70 + ding2 * 0.38 + ding3 * 0.22
		var hp: float = mixed - hp_x + hp_r * hp_y
		hp_x = mixed
		hp_y = hp
		samples[index] = clampf(hp * gain, -0.95, 0.95)
	return samples


func _cast(length: float, gain: float, seed_value: int) -> PackedFloat32Array:
	_noise_state = seed_value
	var count: int = maxi(64, int(round(length * float(RATE))))
	var samples := PackedFloat32Array()
	samples.resize(count)
	for index in range(count):
		var age: float = float(index) / float(RATE)
		var progress: float = float(index) / float(maxi(1, count - 1))
		var env: float = sin(progress * PI)
		var root: float = sin(TAU * 659.25 * age) * exp(-age * 6.5)
		var fifth: float = sin(TAU * 987.77 * age) * exp(-age * 8.0)
		var spark: float = sin(TAU * 1318.51 * age) * exp(-age * 11.0)
		var air: float = _white() * exp(-age * 14.0) * 0.12
		samples[index] = clampf((root * 0.42 + fifth * 0.28 + spark * 0.22 + air) * env * gain, -0.95, 0.95)
	return samples


func _bite(length: float, gain: float, seed_value: int) -> PackedFloat32Array:
	_noise_state = seed_value * 1103515245 + 12345
	var count: int = maxi(64, int(round(length * float(RATE))))
	var samples := PackedFloat32Array()
	samples.resize(count)
	var growl_hz: float = 148.0 if seed_value == 271 else 128.0
	var lp := 0.0
	for index in range(count):
		var age: float = float(index) / float(RATE)
		var snap: float = _white() * exp(-age * 80.0)
		var jaw: float = sin(TAU * 210.0 * age) * exp(-age * 34.0)
		var growl: float = sin(TAU * growl_hz * age) * exp(-age * 14.0)
		var wet: float = _white()
		lp += 0.14 * (wet - lp)
		samples[index] = clampf(
			(snap * 0.55 + jaw * 0.38 + growl * 0.42 + lp * exp(-age * 16.0) * 0.32) * gain,
			-0.95,
			0.95
		)
	return samples


func _spit(length: float, gain: float, seed_value: int) -> PackedFloat32Array:
	_noise_state = seed_value * 214013 + 2531011
	var count: int = maxi(64, int(round(length * float(RATE))))
	var samples := PackedFloat32Array()
	samples.resize(count)
	var lp := 0.0
	for index in range(count):
		var progress: float = float(index) / float(maxi(1, count - 1))
		var age: float = float(index) / float(RATE)
		var gather: float = 1.0 if progress < 0.28 else 0.0
		var burst: float = 0.0 if progress < 0.24 else sin(((progress - 0.24) / 0.76) * PI)
		var cutoff: float = lerpf(0.10, 0.28, clampf((progress - 0.24) * 3.0, 0.0, 1.0))
		var air: float = _white()
		lp += cutoff * (air - lp)
		var pop: float = sin(TAU * 520.0 * age) * exp(-age * 22.0) * burst
		samples[index] = clampf((lp * (gather * 0.22 + burst) + pop * 0.28) * gain, -0.95, 0.95)
	return samples


func _flesh_hit(length: float, gain: float, seed_value: int) -> PackedFloat32Array:
	_noise_state = seed_value * 1664525 + 1013904223
	var count: int = maxi(64, int(round(length * float(RATE))))
	var samples := PackedFloat32Array()
	samples.resize(count)
	var lp := 0.0
	for index in range(count):
		var age: float = float(index) / float(RATE)
		var thump: float = sin(TAU * 126.0 * age) * exp(-age * 20.0)
		var rib: float = sin(TAU * 248.0 * age) * exp(-age * 26.0)
		var wet: float = _white()
		lp += 0.18 * (wet - lp)
		samples[index] = clampf((thump * 0.62 + rib * 0.34 + lp * exp(-age * 24.0) * 0.40) * gain, -0.95, 0.95)
	return samples


func _slime_hit(length: float, gain: float, seed_value: int) -> PackedFloat32Array:
	_noise_state = seed_value * 214013 + 2531011
	var count: int = maxi(64, int(round(length * float(RATE))))
	var samples := PackedFloat32Array()
	samples.resize(count)
	var lp := 0.0
	for index in range(count):
		var age: float = float(index) / float(RATE)
		var bubble: float = sin(TAU * 390.0 * age) * exp(-age * 16.0)
		var slap: float = sin(TAU * 160.0 * age) * exp(-age * 22.0)
		var wet: float = _white()
		lp += 0.22 * (wet - lp)
		samples[index] = clampf((bubble * 0.38 + slap * 0.42 + lp * exp(-age * 18.0) * 0.48) * gain, -0.95, 0.95)
	return samples


func _monster_cry(kind: String, f0: float, length: float, seed_value: int) -> PackedFloat32Array:
	# Short noisy gasp/squelch. No pitched oscillator — that was the electronic buzz.
	_noise_state = seed_value * 1103515245 + 12345
	var count: int = maxi(64, int(round(length * float(RATE))))
	var samples := PackedFloat32Array()
	samples.resize(count)
	var lp := 0.0
	var hp_x := 0.0
	var hp_y := 0.0
	var is_slime: bool = kind.begins_with("slime")
	var is_down: bool = kind.ends_with("down")
	var hp_r: float = exp(-TAU * (300.0 if is_slime else 1400.0) / float(RATE))
	for index in range(count):
		var progress: float = float(index) / float(maxi(1, count - 1))
		var env: float = progress / 0.06 if progress < 0.06 else 1.0
		if not is_down and progress > 0.28:
			env = (1.0 - (progress - 0.28) / 0.72)
			env *= env
		elif is_down and progress > 0.22:
			env = (1.0 - (progress - 0.22) / 0.78)
			env *= env
		env = clampf(env, 0.0, 1.0)
		var air: float = _white()
		var start_cut: float = 0.16 if is_slime else 0.30
		var end_cut: float = 0.05 if is_slime else 0.09
		if is_down:
			start_cut *= 0.85
			end_cut *= 0.80
		lp += lerpf(start_cut, end_cut, progress) * (air - lp)
		var hp: float = lp - hp_x + hp_r * hp_y
		hp_x = lp
		hp_y = hp
		samples[index] = clampf(hp * env, -0.95, 0.95)
	return samples


func _creature(kind: String, f0: float, length: float, seed_value: int) -> PackedFloat32Array:
	_noise_state = seed_value * 1103515245 + 12345
	var count: int = maxi(64, int(round(length * float(RATE))))
	var samples := PackedFloat32Array()
	samples.resize(count)
	var r1 := _new_res()
	var r2 := _new_res()
	var phase := 0.0
	var prev_flow := 0.0
	var lp := 0.0
	var is_slime: bool = kind.begins_with("slime")
	var is_hurt: bool = kind.ends_with("hurt")
	for index in range(count):
		var age: float = float(index) / float(RATE)
		var progress: float = age / maxf(length, 0.001)
		var env: float = progress / 0.08 if progress < 0.08 else (1.0 - progress) * (1.0 - progress) / 0.8464
		env = clampf(env, 0.0, 1.0)
		var freq: float = f0
		if is_hurt:
			freq = f0 * lerpf(1.12, 0.72, progress)
		else:
			freq = f0 * lerpf(1.04, 0.82, progress)
		phase += freq / float(RATE)
		if phase >= 1.0:
			phase -= floor(phase)
		var flow: float = _rosenberg(phase, 0.72 if is_slime else 0.64)
		var rad: float = (flow - prev_flow) * 0.08
		prev_flow = flow
		var grit: float = _white()
		lp += (0.22 if is_slime else 0.12) * (grit - lp)
		if is_slime:
			_set_res(r1, 520.0 + progress * 60.0, 140.0)
			_set_res(r2, 1680.0 - progress * 180.0, 160.0)
			var wet: float = _res(r1, rad * 0.45 + lp * 0.55)
			wet = _res(r2, wet)
			samples[index] = clampf((wet * 0.78 + lp * 0.28) * env, -0.95, 0.95)
		elif is_hurt:
			# DNF goblin hit cry: short nasal "ueh", not a bass growl.
			_set_res(r1, 560.0, 80.0)
			_set_res(r2, 1920.0, 110.0)
			var yelp: float = _res(r1, rad + lp * 0.10)
			yelp = _res(r2, yelp)
			samples[index] = clampf((yelp * 0.90 + lp * 0.10) * env, -0.95, 0.95)
		else:
			_set_res(r1, 580.0, 90.0)
			_set_res(r2, 1080.0, 120.0)
			var bark: float = _res(r1, rad + lp * 0.28)
			bark = _res(r2, bark)
			samples[index] = clampf((bark * 0.82 + lp * 0.22) * env, -0.95, 0.95)
	return samples


func _thump(length: float, gain: float, seed_value: int) -> PackedFloat32Array:
	_noise_state = seed_value * 1664525 + 1013904223
	var count: int = maxi(64, int(round(length * float(RATE))))
	var samples := PackedFloat32Array()
	samples.resize(count)
	var lp := 0.0
	for index in range(count):
		var age: float = float(index) / float(RATE)
		var boot: float = sin(TAU * 88.0 * age) * exp(-age * 22.0)
		var leather: float = sin(TAU * 210.0 * age) * exp(-age * 36.0)
		var grit: float = _white()
		lp += 0.16 * (grit - lp)
		samples[index] = clampf((boot * 0.70 + leather * 0.28 + lp * exp(-age * 28.0) * 0.32) * gain, -0.95, 0.95)
	return samples


func _step(length: float, gain: float, seed_value: int) -> PackedFloat32Array:
	_noise_state = seed_value * 214013 + 2531011
	var count: int = maxi(64, int(round(length * float(RATE))))
	var samples := PackedFloat32Array()
	samples.resize(count)
	var lp := 0.0
	for index in range(count):
		var age: float = float(index) / float(RATE)
		var tap: float = sin(TAU * 140.0 * age) * exp(-age * 48.0)
		var grit: float = _white()
		lp += 0.22 * (grit - lp)
		samples[index] = clampf((tap * 0.48 + lp * exp(-age * 40.0) * 0.55) * gain, -0.95, 0.95)
	return samples


func _ui_click(length: float, gain: float, seed_value: int) -> PackedFloat32Array:
	_noise_state = seed_value
	var count: int = maxi(64, int(round(length * float(RATE))))
	var samples := PackedFloat32Array()
	samples.resize(count)
	for index in range(count):
		var age: float = float(index) / float(RATE)
		var tick: float = sin(TAU * 2140.0 * age) * exp(-age * 70.0)
		var wood: float = sin(TAU * 980.0 * age) * exp(-age * 48.0)
		samples[index] = clampf((tick * 0.62 + wood * 0.28 + _white() * exp(-age * 90.0) * 0.18) * gain, -0.95, 0.95)
	return samples


func _ui_deny(length: float, gain: float, seed_value: int) -> PackedFloat32Array:
	_noise_state = seed_value
	var count: int = maxi(64, int(round(length * float(RATE))))
	var samples := PackedFloat32Array()
	samples.resize(count)
	for index in range(count):
		var age: float = float(index) / float(RATE)
		var low: float = sin(TAU * 280.0 * age) * exp(-age * 18.0)
		var drop: float = sin(TAU * 196.0 * age) * exp(-age * 14.0)
		samples[index] = clampf((low * 0.55 + drop * 0.42) * gain, -0.95, 0.95)
	return samples


func _card(length: float, gain: float, seed_value: int) -> PackedFloat32Array:
	_noise_state = seed_value * 1103515245 + 12345
	var count: int = maxi(64, int(round(length * float(RATE))))
	var samples := PackedFloat32Array()
	samples.resize(count)
	var lp := 0.0
	for index in range(count):
		var age: float = float(index) / float(RATE)
		var rustle: float = _white()
		lp += 0.28 * (rustle - lp)
		var pluck: float = sin(TAU * 523.25 * age) * exp(-age * 16.0)
		var paper: float = lp * exp(-age * 12.0)
		samples[index] = clampf((paper * 0.55 + pluck * 0.38) * gain, -0.95, 0.95)
	return samples


func _chest(length: float, gain: float, seed_value: int) -> PackedFloat32Array:
	_noise_state = seed_value * 1664525 + 1013904223
	var count: int = maxi(64, int(round(length * float(RATE))))
	var samples := PackedFloat32Array()
	samples.resize(count)
	var lp := 0.0
	for index in range(count):
		var age: float = float(index) / float(RATE)
		var knock: float = sin(TAU * 180.0 * age) * exp(-age * 20.0)
		var lid: float = _white()
		lp += 0.14 * (lid - lp)
		var chime: float = 0.0
		if age > 0.06:
			var chime_age: float = age - 0.06
			chime = sin(TAU * 784.0 * chime_age) * exp(-chime_age * 10.0)
		samples[index] = clampf((knock * 0.48 + lp * exp(-age * 14.0) * 0.32 + chime * 0.38) * gain, -0.95, 0.95)
	return samples


func _portal(length: float, gain: float, seed_value: int) -> PackedFloat32Array:
	_noise_state = seed_value
	var count: int = maxi(64, int(round(length * float(RATE))))
	var samples := PackedFloat32Array()
	samples.resize(count)
	var lp := 0.0
	for index in range(count):
		var age: float = float(index) / float(RATE)
		var progress: float = float(index) / float(maxi(1, count - 1))
		var env: float = sin(progress * PI)
		var root: float = sin(TAU * lerpf(196.0, 392.0, progress) * age)
		var air: float = _white()
		lp += 0.08 * (air - lp)
		samples[index] = clampf((root * 0.42 + sin(TAU * 523.25 * age) * 0.18 + lp * 0.22) * env * gain, -0.95, 0.95)
	return samples


func _cast_twin(length: float, gain: float, seed_value: int) -> PackedFloat32Array:
	_noise_state = seed_value
	var count: int = maxi(64, int(round(length * float(RATE))))
	var samples := PackedFloat32Array()
	samples.resize(count)
	var lp := 0.0
	for index in range(count):
		var age: float = float(index) / float(RATE)
		var slice_a: float = sin(TAU * 1480.0 * age) * exp(-age * 28.0)
		var slice_b := 0.0
		if age > 0.05:
			var late: float = age - 0.05
			slice_b = sin(TAU * 1760.0 * late) * exp(-late * 26.0)
		var air: float = _white()
		lp += 0.18 * (air - lp)
		samples[index] = clampf((slice_a * 0.42 + slice_b * 0.40 + lp * exp(-age * 16.0) * 0.28) * gain, -0.95, 0.95)
	return samples


func _cast_great(length: float, gain: float, seed_value: int) -> PackedFloat32Array:
	_noise_state = seed_value * 214013 + 2531011
	var count: int = maxi(64, int(round(length * float(RATE))))
	var samples := PackedFloat32Array()
	samples.resize(count)
	var lp := 0.0
	for index in range(count):
		var age: float = float(index) / float(RATE)
		var rumble: float = sin(TAU * 72.0 * age) * exp(-age * 8.0)
		var steel: float = sin(TAU * 220.0 * age) * exp(-age * 12.0)
		var air: float = _white()
		lp += 0.10 * (air - lp)
		samples[index] = clampf((rumble * 0.55 + steel * 0.32 + lp * exp(-age * 10.0) * 0.28) * gain, -0.95, 0.95)
	return samples


func _new_res() -> Dictionary:
	return {"y1": 0.0, "y2": 0.0, "a1": 0.0, "a2": 0.0, "g": 1.0}


func _set_res(res: Dictionary, freq: float, bw: float) -> void:
	var r: float = exp(-PI * bw / float(RATE))
	var a1: float = 2.0 * r * cos(TAU * freq / float(RATE))
	var a2: float = -(r * r)
	res["a1"] = a1
	res["a2"] = a2
	res["g"] = 1.0 - a1 - a2


func _res(res: Dictionary, x: float) -> float:
	var y: float = float(res["g"]) * x + float(res["a1"]) * float(res["y1"]) + float(res["a2"]) * float(res["y2"])
	res["y2"] = res["y1"]
	res["y1"] = y
	return y


func _white() -> float:
	_noise_state = (_noise_state * 1664525 + 1013904223) & 0x7fffffff
	return (float(_noise_state) / 1073741824.0) - 1.0


func _fade_edges(samples: PackedFloat32Array, seconds: float) -> void:
	var fade: int = mini(samples.size() / 4, maxi(8, int(round(seconds * float(RATE)))))
	for index in range(fade):
		var w: float = float(index) / float(fade)
		samples[index] *= w
		samples[samples.size() - 1 - index] *= w


func _compress(samples: PackedFloat32Array, threshold: float, ratio: float) -> void:
	for index in range(samples.size()):
		var value: float = samples[index]
		var magnitude: float = absf(value)
		if magnitude > threshold:
			var compressed: float = threshold + (magnitude - threshold) / ratio
			samples[index] = signf(value) * compressed


func _normalize(samples: PackedFloat32Array, peak: float) -> void:
	var loudest := 0.0001
	for value in samples:
		loudest = maxf(loudest, absf(value))
	var gain: float = peak / loudest
	for index in range(samples.size()):
		samples[index] = clampf(samples[index] * gain, -0.95, 0.95)


func _peak_of(samples: PackedFloat32Array) -> float:
	var loudest := 0.0001
	for value in samples:
		loudest = maxf(loudest, absf(value))
	return loudest


func _rms(samples: PackedFloat32Array) -> float:
	var total := 0.0
	for value in samples:
		total += value * value
	return sqrt(total / float(maxi(1, samples.size())))


func _db(value: float) -> float:
	return linear_to_db(maxf(value, 0.0001))


func _pcm16(samples: PackedFloat32Array) -> PackedByteArray:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for index in range(samples.size()):
		var quantized: int = clampi(int(round(samples[index] * 32767.0)), -32767, 32767)
		bytes[index * 2] = quantized & 0xFF
		bytes[index * 2 + 1] = (quantized >> 8) & 0xFF
	return bytes
