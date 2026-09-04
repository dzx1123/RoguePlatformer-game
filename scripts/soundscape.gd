extends Node

## Lightweight procedural soundtrack and combat SFX. It avoids placeholder clips while
## keeping the whole audio palette coherent with the moonlit stone-and-crystal setting.
class_name RogueSoundscape

enum VoiceType {
	SWORD_SWING,
	IMPACT,
	DASH,
	SKILL,
	JUMP,
	LAND,
	FOOTSTEP,
	UI,
	CHEST,
	PORTAL,
	ENEMY_BITE,
	ENEMY_SPIT,
	ENEMY_DEFEAT,
}

enum MusicState {
	MENU,
	EXPLORE,
	COMBAT,
	BOSS,
}

const MIX_RATE := 22050.0
const MAX_SAMPLE_AMPLITUDE := 0.82
const PLAYER_ATTACK_VOICES := [
	preload("res://assets/audio/player_voice/attack.wav"),
	preload("res://assets/audio/player_voice/attack_2.wav"),
	preload("res://assets/audio/player_voice/attack_3.wav"),
]
const PLAYER_SKILL_VOICES := [
	preload("res://assets/audio/player_voice/skill.wav"),
	preload("res://assets/audio/player_voice/skill_2.wav"),
	preload("res://assets/audio/player_voice/skill_3.wav"),
]
const PLAYER_HURT_VOICES := [
	preload("res://assets/audio/player_voice/hurt.wav"),
	preload("res://assets/audio/player_voice/hurt_2.wav"),
]
const PLAYER_DEFEAT_VOICES := [
	preload("res://assets/audio/player_voice/defeat.wav"),
	preload("res://assets/audio/player_voice/defeat_2.wav"),
]
const SWORD_SWING_SFX := [
	preload("res://assets/audio/sword_cc0/sword_swing_1.wav"),
	preload("res://assets/audio/sword_cc0/sword_swing_2.wav"),
	preload("res://assets/audio/sword_cc0/sword_swing_3.wav"),
]
const HIT_SFX := [
	preload("res://assets/audio/combat_cc0/chop.ogg"),
	preload("res://assets/audio/combat_cc0/impactSoft_medium_003.ogg"),
]
const SKILL_SFX := [
	preload("res://assets/audio/combat_cc0/impactGlass_light_002.ogg"),
	preload("res://assets/audio/combat_cc0/impactMetal_medium_002.ogg"),
]
const ENEMY_FLESH_BURST_SFX := [
	preload("res://assets/audio/gore_cc0/flesh_burst.ogg"),
	preload("res://assets/audio/gore_cc0/flesh_burst_2.ogg"),
]
const ENEMY_SLIME_SPLAT_SFX := [
	preload("res://assets/audio/gore_cc0/slime_splat_1.wav"),
	preload("res://assets/audio/gore_cc0/slime_splat_2.wav"),
]
const ENEMY_CRUNCH_SFX: AudioStream = preload("res://assets/audio/gore_cc0/crunch.ogg")

var _player: AudioStreamPlayer
var _vocal_players: Array[AudioStreamPlayer] = []
var _next_vocal_player: int = 0
var _voice_variant_indices := {
	&"attack": 0,
	&"skill": 0,
	&"hurt": 0,
	&"defeat": 0,
}
var _last_player_voice_path: String = ""
var _attack_vocal_request_count: int = 0
var _sfx_players: Array[AudioStreamPlayer] = []
var _next_sfx_player: int = 0
var _playback: AudioStreamGeneratorPlayback
var _voices: Array[Dictionary] = []
var _music_time: float = 0.0
var _vocal_duck_remaining: float = 0.0
var _music_state: int = MusicState.MENU


func _ready() -> void:
	_player = AudioStreamPlayer.new()
	_player.name = "MoonlitSoundscape"
	_player.bus = &"Music"
	var stream := AudioStreamGenerator.new()
	stream.mix_rate = MIX_RATE
	stream.buffer_length = 0.35
	_player.stream = stream
	_player.volume_db = -7.5
	add_child(_player)
	_player.play()
	_playback = _player.get_stream_playback()
	# A small pool prevents a follow-up attack or a hurt reaction from cutting off
	# the vocal that started one frame earlier. Voice playback never changes game time.
	for vocal_index in range(4):
		var vocal_player := AudioStreamPlayer.new()
		vocal_player.name = "YoungAdventurerVoice_%02d" % vocal_index
		vocal_player.bus = &"Voice"
		add_child(vocal_player)
		_vocal_players.append(vocal_player)
	for player_index in range(8):
		var sfx_player := AudioStreamPlayer.new()
		sfx_player.name = "CombatSample_%02d" % player_index
		sfx_player.bus = &"SFX"
		add_child(sfx_player)
		_sfx_players.append(sfx_player)


func play_sword_swing() -> void:
	# Empty swings stay quieter so a confirmed hit reads as the loudest layer.
	_play_combat_sample(SWORD_SWING_SFX, -11.0, 1.04)


func play_impact() -> void:
	_add_voice(VoiceType.IMPACT, 0.16, 0.66)
	_play_combat_sample(HIT_SFX, 0.5, 0.94)


func play_dash() -> void:
	_add_voice(VoiceType.DASH, 0.20, 0.34)


func play_skill() -> void:
	_add_voice(VoiceType.SKILL, 0.48, 0.48)
	_play_combat_sample(SKILL_SFX, -2.0, 1.06)


func play_jump() -> void:
	_add_voice(VoiceType.JUMP, 0.10, 0.22)


func play_land() -> void:
	_add_voice(VoiceType.LAND, 0.12, 0.28)


func play_footstep() -> void:
	_add_voice(VoiceType.FOOTSTEP, 0.07, 0.14)


func play_ui() -> void:
	_add_voice(VoiceType.UI, 0.08, 0.18)


func play_chest() -> void:
	_add_voice(VoiceType.CHEST, 0.22, 0.34)


func play_portal() -> void:
	_add_voice(VoiceType.PORTAL, 0.30, 0.32)


func set_music_state(next_state: int) -> void:
	_music_state = clampi(next_state, MusicState.MENU, MusicState.BOSS)


func get_music_state() -> int:
	return _music_state


func play_player_attack_voice() -> void:
	_attack_vocal_request_count += 1
	# A short battle shout every other swing keeps rapid attacks from turning into
	# repetitive vocal chatter. Confirmed-hit SFX remain the loudest combat layer.
	if _attack_vocal_request_count % 2 == 0:
		return
	_play_player_voice(PLAYER_ATTACK_VOICES, &"attack", 1.0, -7.0)


func play_player_skill_voice() -> void:
	_play_player_voice(PLAYER_SKILL_VOICES, &"skill", 1.0, -5.0)


func play_player_hurt_voice() -> void:
	_play_player_voice(PLAYER_HURT_VOICES, &"hurt", 1.0, -6.0)


func play_player_defeat_voice() -> void:
	_play_player_voice(PLAYER_DEFEAT_VOICES, &"defeat", 1.0, -5.0)


func play_enemy_bite(is_boss: bool = false) -> void:
	_add_voice(VoiceType.ENEMY_BITE, 0.18 if not is_boss else 0.26, 0.34 if not is_boss else 0.52)
	_play_combat_sample(HIT_SFX, -9.0 if not is_boss else -5.0, 0.78 if not is_boss else 0.62)


func play_enemy_spit(is_boss: bool = false) -> void:
	_add_voice(VoiceType.ENEMY_SPIT, 0.20 if not is_boss else 0.30, 0.30 if not is_boss else 0.44)


func play_enemy_defeat(is_boss: bool = false) -> void:
	# Layered organic burst: wet flesh pop, slime spray, then a quiet short crunch.
	# Bosses use the same palette at a lower pitch so the sound matches their mass.
	_play_combat_sample(
		ENEMY_FLESH_BURST_SFX,
		-3.0 if not is_boss else -0.5,
		0.94 if not is_boss else 0.72
	)
	_play_combat_sample(
		ENEMY_SLIME_SPLAT_SFX,
		-5.5 if not is_boss else -2.0,
		1.02 if not is_boss else 0.78
	)
	_play_combat_sample(
		[ENEMY_CRUNCH_SFX],
		-9.0 if not is_boss else -5.0,
		1.0 if not is_boss else 0.76
	)


func get_active_voice_count() -> int:
	return _voices.size()


func get_current_player_voice_path() -> String:
	return _last_player_voice_path


func get_player_voice_sample_count() -> int:
	return (
		PLAYER_ATTACK_VOICES.size()
		+ PLAYER_SKILL_VOICES.size()
		+ PLAYER_HURT_VOICES.size()
		+ PLAYER_DEFEAT_VOICES.size()
	)


func get_loaded_combat_sample_count() -> int:
	return (
		SWORD_SWING_SFX.size()
		+ HIT_SFX.size()
		+ SKILL_SFX.size()
		+ ENEMY_FLESH_BURST_SFX.size()
		+ ENEMY_SLIME_SPLAT_SFX.size()
		+ 1
	)


func _process(delta: float) -> void:
	_music_time += delta
	_vocal_duck_remaining = maxf(0.0, _vocal_duck_remaining - delta)
	if _playback == null:
		_playback = _player.get_stream_playback()
	if _playback == null:
		return
	var frames: int = _playback.get_frames_available()
	for _frame in range(frames):
		var sample_time: float = 1.0 / MIX_RATE
		var music_mix: float = _mix_music(_music_time)
		if _vocal_duck_remaining > 0.0:
			music_mix *= 0.72
		var sample: float = music_mix + _mix_voices(sample_time)
		sample = clampf(sample, -MAX_SAMPLE_AMPLITUDE, MAX_SAMPLE_AMPLITUDE)
		_playback.push_frame(Vector2(sample, sample))


func _add_voice(type: int, duration: float, volume: float) -> void:
	_voices.append({
		"type": type,
		"duration": duration,
		"age": 0.0,
		"volume": volume,
		"seed": _music_time * 13.13 + float(_voices.size()) * 1.97,
	})


func _play_player_voice(
	voice_clips: Array,
	category: StringName,
	pitch: float,
	volume_boost_db: float
) -> void:
	if _vocal_players.is_empty() or voice_clips.is_empty():
		return
	var variant_index: int = int(_voice_variant_indices.get(category, 0)) % voice_clips.size()
	var voice_clip: AudioStream = voice_clips[variant_index] as AudioStream
	_voice_variant_indices[category] = (variant_index + 1) % voice_clips.size()
	if voice_clip == null:
		return
	var vocal_player: AudioStreamPlayer = _vocal_players[_next_vocal_player]
	_next_vocal_player = (_next_vocal_player + 1) % _vocal_players.size()
	# These are matching original takes from one actor, so only a subtle pitch trim is
	# needed. The short clips start immediately and remain independent of animation time.
	vocal_player.stop()
	vocal_player.stream = voice_clip
	vocal_player.pitch_scale = pitch
	vocal_player.volume_db = volume_boost_db
	vocal_player.play()
	_last_player_voice_path = voice_clip.resource_path
	_vocal_duck_remaining = maxf(
		_vocal_duck_remaining,
		voice_clip.get_length() / vocal_player.pitch_scale + 0.06
	)


func _play_combat_sample(samples: Array, volume_db: float, pitch: float) -> void:
	if _sfx_players.is_empty() or samples.is_empty():
		return
	var sample_index: int = int(floor(_music_time * 31.0 + float(_next_sfx_player))) % samples.size()
	var sample: AudioStream = samples[sample_index] as AudioStream
	if sample == null:
		return
	var sfx_player: AudioStreamPlayer = _sfx_players[_next_sfx_player]
	_next_sfx_player = (_next_sfx_player + 1) % _sfx_players.size()
	sfx_player.stop()
	sfx_player.stream = sample
	sfx_player.volume_db = volume_db
	sfx_player.pitch_scale = pitch
	sfx_player.play()


func _mix_voices(step: float) -> float:
	var mixed: float = 0.0
	for voice_index in range(_voices.size() - 1, -1, -1):
		var voice: Dictionary = _voices[voice_index]
		var age: float = float(voice["age"])
		var duration: float = float(voice["duration"])
		if age >= duration:
			_voices.remove_at(voice_index)
			continue
		mixed += _sample_voice(voice, age)
		voice["age"] = age + step
		_voices[voice_index] = voice
	return mixed


func _sample_voice(voice: Dictionary, age: float) -> float:
	var duration: float = float(voice["duration"])
	var progress: float = clampf(age / duration, 0.0, 1.0)
	var volume: float = float(voice["volume"])
	var seed: float = float(voice["seed"])
	var type: int = int(voice["type"])
	var envelope: float = sin(progress * PI)
	var noise: float = _noise(age, seed)
	match type:
		VoiceType.SWORD_SWING:
			var swing_frequency: float = lerpf(820.0, 240.0, progress)
			return (sin(TAU * swing_frequency * age) * 0.55 + noise * 0.45) * envelope * volume
		VoiceType.IMPACT:
			var impact_frequency: float = lerpf(180.0, 78.0, progress)
			var click: float = sin(TAU * 1760.0 * age) * exp(-age * 40.0)
			return (sin(TAU * impact_frequency * age) * 0.72 + click + noise * 0.22) * envelope * volume
		VoiceType.DASH:
			var dash_frequency: float = lerpf(160.0, 690.0, progress)
			return (sin(TAU * dash_frequency * age) * 0.22 + noise * 0.82) * envelope * volume
		VoiceType.SKILL:
			var root_note: float = sin(TAU * 293.66 * age)
			var fifth_note: float = sin(TAU * 440.0 * age + progress * 4.0)
			var crystal_note: float = sin(TAU * 1174.66 * age)
			return (root_note * 0.38 + fifth_note * 0.30 + crystal_note * 0.18 + noise * 0.14) * envelope * volume
		VoiceType.JUMP:
			var jump_frequency: float = lerpf(260.0, 520.0, progress)
			return (sin(TAU * jump_frequency * age) * 0.72 + noise * 0.15) * envelope * volume
		VoiceType.LAND:
			var land_frequency: float = lerpf(140.0, 70.0, progress)
			return (sin(TAU * land_frequency * age) * 0.70 + noise * 0.30) * envelope * volume
		VoiceType.FOOTSTEP:
			var step_frequency: float = lerpf(190.0, 90.0, progress)
			return (sin(TAU * step_frequency * age) * 0.40 + noise * 0.55) * envelope * volume
		VoiceType.UI:
			var ui_frequency: float = lerpf(880.0, 1320.0, progress)
			return sin(TAU * ui_frequency * age) * envelope * volume
		VoiceType.CHEST:
			var chest_frequency: float = lerpf(240.0, 420.0, progress)
			return (sin(TAU * chest_frequency * age) * 0.55 + sin(TAU * 720.0 * age) * 0.22 + noise * 0.18) * envelope * volume
		VoiceType.PORTAL:
			var portal_root: float = sin(TAU * 196.0 * age)
			var portal_air: float = sin(TAU * 523.25 * age + progress * 3.0)
			return (portal_root * 0.42 + portal_air * 0.28 + noise * 0.16) * envelope * volume
		VoiceType.ENEMY_BITE:
			var bite_frequency: float = lerpf(118.0, 54.0, progress)
			return (sin(TAU * bite_frequency * age) * 0.64 + noise * 0.54) * envelope * volume
		VoiceType.ENEMY_SPIT:
			var bubble_frequency: float = lerpf(340.0, 130.0, progress)
			return (sin(TAU * bubble_frequency * age) * 0.50 + sin(TAU * bubble_frequency * 2.1 * age) * 0.22 + noise * 0.18) * envelope * volume
		VoiceType.ENEMY_DEFEAT:
			var dissolve_frequency: float = lerpf(280.0, 68.0, progress)
			return (sin(TAU * dissolve_frequency * age) * 0.45 + sin(TAU * 840.0 * age) * 0.15 + noise * 0.52) * envelope * volume
	return 0.0


func _mix_music(time: float) -> float:
	# A restrained 4-bar moonlit ambience. Intensity follows menu / explore / combat / boss.
	var bar_length: float = 3.6 if _music_state == MusicState.MENU else 3.2
	var bar: int = int(floor(time / bar_length))
	var roots := [73.42, 87.31, 65.41, 82.41]
	if _music_state == MusicState.BOSS:
		roots = [55.00, 61.74, 49.00, 65.41]
	var root: float = float(roots[posmod(bar, roots.size())])
	var pad_gain: float = 0.042
	var bell_gain: float = 0.022
	var air_gain: float = 0.007
	match _music_state:
		MusicState.MENU:
			pad_gain = 0.036
			bell_gain = 0.018
			air_gain = 0.006
		MusicState.COMBAT:
			pad_gain = 0.062
			bell_gain = 0.028
			air_gain = 0.010
		MusicState.BOSS:
			pad_gain = 0.074
			bell_gain = 0.038
			air_gain = 0.012
	var pad: float = sin(TAU * root * time) * pad_gain
	pad += sin(TAU * root * 1.5 * time) * pad_gain * 0.55
	pad += sin(TAU * root * 2.0 * time) * pad_gain * 0.28
	var pulse_time: float = fposmod(time, 1.60 if _music_state != MusicState.BOSS else 1.20)
	var bell_envelope: float = exp(-pulse_time * 3.8) if pulse_time < 0.56 else 0.0
	var bell: float = sin(TAU * root * 4.0 * time) * bell_envelope * bell_gain
	if _music_state == MusicState.COMBAT or _music_state == MusicState.BOSS:
		var pulse: float = sin(TAU * time * (2.0 if _music_state == MusicState.BOSS else 1.5))
		pad += pulse * 0.008
	var air: float = _noise(time, 4.2) * air_gain
	return pad + bell + air


func _noise(time: float, seed: float) -> float:
	return (
		sin(time * 1217.0 + seed * 2.1)
		+ sin(time * 733.0 + seed * 5.7)
		+ sin(time * 1931.0 + seed * 0.9)
	) / 3.0
