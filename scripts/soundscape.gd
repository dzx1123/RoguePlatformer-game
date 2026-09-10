extends Node

## Lightweight procedural soundtrack plus a designed combat palette.
## Voice, blade, and whoosh are one set: shout on top, steel under it, swing quiet.
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
## Designed mix ladder, already baked into the wav peaks:
## voice ≈ -0.7 dBFS, crisp ding ≈ -7 dBFS, whoosh ≈ -14 dBFS.
## Runtime offsets keep the same order and never restack old packs.
const MIX_VOICE_ATTACK_DB := 1.5
const MIX_VOICE_SKILL_DB := 1.5
const MIX_VOICE_JUMP_DB := 1.0
const MIX_VOICE_HURT_DB := 1.0
const MIX_VOICE_DEFEAT_DB := 1.0
const MIX_SWING_DB := -5.0
const MIX_HIT_DB := -2.0
const MIX_JUMP_AIR_DB := -6.0
const MIX_SKILL_SFX_DB := -3.0
const MIX_LAND_DB := -8.0
const MIX_FOOTSTEP_DB := -14.0
const MIX_UI_DB := -10.0
const MIX_UI_DENY_DB := -8.0
const MIX_CARD_DB := -7.0
const MIX_CHEST_DB := -6.0
const MIX_PORTAL_DB := -5.0
const MIX_BITE_DB := 0.0
const MIX_SPIT_DB := -1.0
const MIX_ENEMY_HURT_DB := -8.0
const MIX_ENEMY_VOICE_DB := -2.0
const MIX_ENEMY_HURT_VOICE_DB := -6.0
const MIX_ENEMY_DOWN_VOICE_DB := -5.0
const HIT_CRY_DELAY := 0.10
const BGM_FADE := 1.15
const BGM_SILENCE_DB := -48.0
const BGM_COVER_PATH := "res://assets/audio/music/cover.wav"
const BGM_EXPLORE_PATH := "res://assets/audio/music/explore.wav"
const BGM_BOSS_PATH := "res://assets/audio/music/boss.wav"
const PLAYER_ATTACK_VOICE_PATHS: PackedStringArray = [
	"res://assets/audio/designed/hyah_1.wav",
	"res://assets/audio/designed/hyah_2.wav",
	"res://assets/audio/designed/hyah_3.wav",
]
const PLAYER_SKILL_VOICE_PATHS: PackedStringArray = [
	"res://assets/audio/designed/hyaaah_1.wav",
	"res://assets/audio/designed/hyaaah_2.wav",
	"res://assets/audio/designed/hyaaah_3.wav",
]
const PLAYER_HURT_VOICE_PATHS: PackedStringArray = [
	"res://assets/audio/designed/hurt_1.wav",
	"res://assets/audio/designed/hurt_2.wav",
]
const PLAYER_DEFEAT_VOICE_PATHS: PackedStringArray = [
	"res://assets/audio/designed/down_1.wav",
	"res://assets/audio/designed/down_2.wav",
]
const PLAYER_JUMP_VOICE_PATHS: PackedStringArray = [
	"res://assets/audio/designed/hup.wav",
	"res://assets/audio/designed/hup_2.wav",
]
const SWORD_SWING_SFX_PATHS: PackedStringArray = [
	"res://assets/audio/designed/whoosh_1.wav",
	"res://assets/audio/designed/whoosh_2.wav",
	"res://assets/audio/designed/whoosh_3.wav",
]
const HIT_SFX_PATHS: PackedStringArray = [
	"res://assets/audio/designed/hit_1.wav",
	"res://assets/audio/designed/hit_2.wav",
]
const SKILL_SFX_PATHS: PackedStringArray = [
	"res://assets/audio/designed/cast_1.wav",
	"res://assets/audio/designed/cast_2.wav",
]
const SKILL_TWIN_SFX_PATHS: PackedStringArray = [
	"res://assets/audio/designed/skill_twin.wav",
]
const SKILL_GREAT_SFX_PATHS: PackedStringArray = [
	"res://assets/audio/designed/skill_great.wav",
]
const JUMP_AIR_SFX_PATHS: PackedStringArray = [
	"res://assets/audio/designed/jump_air.wav",
]
const LAND_SFX_PATHS: PackedStringArray = [
	"res://assets/audio/designed/land_1.wav",
	"res://assets/audio/designed/land_2.wav",
]
const FOOTSTEP_SFX_PATHS: PackedStringArray = [
	"res://assets/audio/designed/step_1.wav",
	"res://assets/audio/designed/step_2.wav",
]
const UI_CLICK_SFX_PATHS: PackedStringArray = [
	"res://assets/audio/designed/ui_click.wav",
]
const UI_DENY_SFX_PATHS: PackedStringArray = [
	"res://assets/audio/designed/ui_deny.wav",
]
const CARD_SFX_PATHS: PackedStringArray = [
	"res://assets/audio/designed/card.wav",
]
const CHEST_SFX_PATHS: PackedStringArray = [
	"res://assets/audio/designed/chest.wav",
]
const PORTAL_SFX_PATHS: PackedStringArray = [
	"res://assets/audio/designed/portal.wav",
]
const ENEMY_BITE_SFX_PATHS: PackedStringArray = [
	"res://assets/audio/designed/bite.wav",
	"res://assets/audio/designed/bite_2.wav",
]
const ENEMY_SPIT_SFX_PATHS: PackedStringArray = [
	"res://assets/audio/designed/spit.wav",
	"res://assets/audio/designed/spit_2.wav",
]
const ENEMY_FLESH_HURT_PATHS: PackedStringArray = [
	"res://assets/audio/designed/flesh_hit.wav",
]
const ENEMY_SLIME_HURT_PATHS: PackedStringArray = [
	"res://assets/audio/designed/slime_hit.wav",
]
const GOBLIN_ATTACK_VOICE_PATHS: PackedStringArray = [
	"res://assets/audio/designed/goblin_atk_1.wav",
	"res://assets/audio/designed/goblin_atk_2.wav",
]
const GOBLIN_HURT_VOICE_PATHS: PackedStringArray = [
	"res://assets/audio/designed/goblin_hurt_1.wav",
	"res://assets/audio/designed/goblin_hurt_2.wav",
]
const SLIME_ATTACK_VOICE_PATHS: PackedStringArray = [
	"res://assets/audio/designed/slime_atk_1.wav",
	"res://assets/audio/designed/slime_atk_2.wav",
]
const SLIME_HURT_VOICE_PATHS: PackedStringArray = [
	"res://assets/audio/designed/slime_hurt_1.wav",
	"res://assets/audio/designed/slime_hurt_2.wav",
]
const GOBLIN_DOWN_VOICE_PATHS: PackedStringArray = [
	"res://assets/audio/designed/goblin_down_1.wav",
	"res://assets/audio/designed/goblin_down_2.wav",
]
const SLIME_DOWN_VOICE_PATHS: PackedStringArray = [
	"res://assets/audio/designed/slime_down_1.wav",
	"res://assets/audio/designed/slime_down_2.wav",
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
var _player_attack_voices: Array[AudioStream] = []
var _player_skill_voices: Array[AudioStream] = []
var _player_hurt_voices: Array[AudioStream] = []
var _player_defeat_voices: Array[AudioStream] = []
var _player_jump_voices: Array[AudioStream] = []
const USER_GREAT_SWING_PATH := "res://assets/audio/designed/greatsword_swing_user.wav"
const USER_FLESH_CUT_PATH := "res://assets/audio/designed/flesh_cut_user.wav"
const IMPACT_MIN_INTERVAL_MSEC := 80
var _greatsword_swing_sfx: Array[AudioStream] = []
var _flesh_cut_sfx: Array[AudioStream] = []
var _last_impact_msec: int = -1000
var _sword_swing_sfx: Array[AudioStream] = []
var _hit_sfx: Array[AudioStream] = []
var _skill_sfx: Array[AudioStream] = []
var _skill_twin_sfx: Array[AudioStream] = []
var _skill_great_sfx: Array[AudioStream] = []
var _jump_air_sfx: Array[AudioStream] = []
var _land_sfx: Array[AudioStream] = []
var _footstep_sfx: Array[AudioStream] = []
var _ui_click_sfx: Array[AudioStream] = []
var _ui_deny_sfx: Array[AudioStream] = []
var _card_sfx: Array[AudioStream] = []
var _chest_sfx: Array[AudioStream] = []
var _portal_sfx: Array[AudioStream] = []
var _enemy_bite_sfx: Array[AudioStream] = []
var _enemy_spit_sfx: Array[AudioStream] = []
var _enemy_flesh_hurt_sfx: Array[AudioStream] = []
var _enemy_slime_hurt_sfx: Array[AudioStream] = []
var _goblin_attack_voices: Array[AudioStream] = []
var _goblin_hurt_voices: Array[AudioStream] = []
var _slime_attack_voices: Array[AudioStream] = []
var _slime_hurt_voices: Array[AudioStream] = []
var _goblin_down_voices: Array[AudioStream] = []
var _slime_down_voices: Array[AudioStream] = []
var _vocal_players: Array[AudioStreamPlayer] = []
var _next_vocal_player: int = 0
var _voice_variant_indices := {
	&"attack": 0,
	&"skill": 0,
	&"hurt": 0,
	&"defeat": 0,
	&"jump": 0,
	&"enemy_hurt": 0,
	&"enemy_down": 0,
}
var _last_player_voice_path: String = ""
var _attack_vocal_request_count: int = 0
var _sfx_players: Array[AudioStreamPlayer] = []
var _next_sfx_player: int = 0
var _swing_player: AudioStreamPlayer
var _hit_player: AudioStreamPlayer
var _playback: AudioStreamGeneratorPlayback
var _voices: Array[Dictionary] = []
var _music_time: float = 0.0
var _vocal_duck_remaining: float = 0.0
var _music_state: int = MusicState.MENU
var _pending_hurt_clips: Array[AudioStream] = []
var _pending_hurt_pitch: float = 1.0
var _pending_hurt_db: float = 0.0
var _hurt_delay_remaining: float = -1.0
var _bgm_pcm: Array[PackedFloat32Array] = []
var _bgm_streams: Array[AudioStream] = []
var _bgm_player: AudioStreamPlayer
var _bgm_players: Array[AudioStreamPlayer] = []
var _bgm_live_index: int = 0
var _bgm_track: int = 0
var _bgm_prev_track: int = -1
var _bgm_head: float = 0.0
var _bgm_prev_head: float = 0.0
var _bgm_xfade: float = 1.0
var _bgm_fade: float = 1.0
var _bgm_fade_start_db: float = -6.0
var _bgm_outgoing_start_db: float = BGM_SILENCE_DB
var _bgm_has_outgoing: bool = false
var _bgm_target_db: float = -6.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_player_attack_voices = _load_designed_list(PLAYER_ATTACK_VOICE_PATHS)
	_player_skill_voices = _load_designed_list(PLAYER_SKILL_VOICE_PATHS)
	_player_hurt_voices = _load_designed_list(PLAYER_HURT_VOICE_PATHS)
	_player_defeat_voices = _load_designed_list(PLAYER_DEFEAT_VOICE_PATHS)
	_player_jump_voices = _load_designed_list(PLAYER_JUMP_VOICE_PATHS)
	_sword_swing_sfx = _load_designed_list(SWORD_SWING_SFX_PATHS)
	_greatsword_swing_sfx = _load_designed_list(PackedStringArray([USER_GREAT_SWING_PATH]))
	_flesh_cut_sfx = _load_designed_list(PackedStringArray([USER_FLESH_CUT_PATH]))
	_hit_sfx = _load_designed_list(HIT_SFX_PATHS)
	_skill_sfx = _load_designed_list(SKILL_SFX_PATHS)
	_skill_twin_sfx = _load_designed_list(SKILL_TWIN_SFX_PATHS)
	_skill_great_sfx = _load_designed_list(SKILL_GREAT_SFX_PATHS)
	_jump_air_sfx = _load_designed_list(JUMP_AIR_SFX_PATHS)
	_land_sfx = _load_designed_list(LAND_SFX_PATHS)
	_footstep_sfx = _load_designed_list(FOOTSTEP_SFX_PATHS)
	_ui_click_sfx = _load_designed_list(UI_CLICK_SFX_PATHS)
	_ui_deny_sfx = _load_designed_list(UI_DENY_SFX_PATHS)
	_card_sfx = _load_designed_list(CARD_SFX_PATHS)
	_chest_sfx = _load_designed_list(CHEST_SFX_PATHS)
	_portal_sfx = _load_designed_list(PORTAL_SFX_PATHS)
	_enemy_bite_sfx = _load_designed_list(ENEMY_BITE_SFX_PATHS)
	_enemy_spit_sfx = _load_designed_list(ENEMY_SPIT_SFX_PATHS)
	_enemy_flesh_hurt_sfx = _load_designed_list(ENEMY_FLESH_HURT_PATHS)
	_enemy_slime_hurt_sfx = _load_designed_list(ENEMY_SLIME_HURT_PATHS)
	_goblin_attack_voices = _load_designed_list(GOBLIN_ATTACK_VOICE_PATHS)
	_goblin_hurt_voices = _load_designed_list(GOBLIN_HURT_VOICE_PATHS)
	_slime_attack_voices = _load_designed_list(SLIME_ATTACK_VOICE_PATHS)
	_slime_hurt_voices = _load_designed_list(SLIME_HURT_VOICE_PATHS)
	_goblin_down_voices = _load_designed_list(GOBLIN_DOWN_VOICE_PATHS)
	_slime_down_voices = _load_designed_list(SLIME_DOWN_VOICE_PATHS)
	_player = AudioStreamPlayer.new()
	_player.name = "MoonlitSoundscape"
	_player.bus = &"Music"
	var stream := AudioStreamGenerator.new()
	stream.mix_rate = MIX_RATE
	stream.buffer_length = 0.35
	_player.stream = stream
	_player.volume_db = -4.0
	add_child(_player)
	_player.play()
	_playback = _player.get_stream_playback()
	# A small pool prevents a follow-up attack or a hurt reaction from cutting off
	# the vocal that started one frame earlier. Voice playback never changes game time.
	for vocal_index in range(6):
		var vocal_player := AudioStreamPlayer.new()
		vocal_player.name = "YoungAdventurerVoice_%02d" % vocal_index
		vocal_player.bus = &"Voice"
		add_child(vocal_player)
		_vocal_players.append(vocal_player)
	for player_index in range(10):
		var sfx_player := AudioStreamPlayer.new()
		sfx_player.name = "CombatSample_%02d" % player_index
		sfx_player.bus = &"SFX"
		add_child(sfx_player)
		_sfx_players.append(sfx_player)
	_swing_player = _make_sfx_player("SwingChannel")
	_hit_player = _make_sfx_player("HitChannel")
	_ensure_audio_bus(&"Music")
	_ensure_audio_bus(&"SFX")
	_ensure_audio_bus(&"Voice")
	_bgm_pcm = [
		_wav_pcm(BGM_COVER_PATH),
		_wav_pcm(BGM_EXPLORE_PATH),
		_wav_pcm(BGM_BOSS_PATH),
	]
	_bgm_streams = [
		_make_loop_stream(BGM_COVER_PATH),
		_make_loop_stream(BGM_EXPLORE_PATH),
		_make_loop_stream(BGM_BOSS_PATH),
	]
	for slot_index in range(2):
		var bed := AudioStreamPlayer.new()
		bed.name = "MoonBGM_%d" % slot_index
		bed.bus = &"Music"
		bed.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(bed)
		_bgm_players.append(bed)
	_bgm_player = _bgm_players[0]
	_bgm_track = 0
	_bgm_head = 0.0
	_play_bgm_track(0, true)


func play_sword_swing(weapon_id: StringName = &"") -> void:
	if weapon_id == WeaponCatalog.GREATSWORD and not _greatsword_swing_sfx.is_empty():
		_play_on_player(_swing_player, _greatsword_swing_sfx, MIX_SWING_DB, 1.0)
	else:
		_add_voice(VoiceType.SWORD_SWING, 0.08, 0.04)
		_play_on_player(_swing_player, _sword_swing_sfx, MIX_SWING_DB, 1.0)


func play_impact(is_slime: bool = false, is_boss: bool = false) -> void:
	# One slash can damage several targets in the same frame. Keep one clear impact.
	var now := Time.get_ticks_msec()
	if now - _last_impact_msec < IMPACT_MIN_INTERVAL_MSEC:
		return
	_last_impact_msec = now
	# Let the swing finish underneath the contact sound instead of cutting its tail.
	var bank: Array[AudioStream] = _hit_sfx if is_slime else _flesh_cut_sfx
	if bank.is_empty():
		bank = _hit_sfx
	_play_on_player(_hit_player, bank, MIX_HIT_DB, 0.94 if is_boss else 1.0)
	_pending_hurt_clips = _slime_hurt_voices if is_slime else _goblin_hurt_voices
	_pending_hurt_pitch = 0.88 if is_boss else 1.0
	_pending_hurt_db = MIX_ENEMY_HURT_VOICE_DB if not is_boss else MIX_ENEMY_HURT_VOICE_DB + 1.5
	_hurt_delay_remaining = HIT_CRY_DELAY

func play_dash() -> void:
	_add_voice(VoiceType.DASH, 0.20, 0.22)


func play_skill(weapon_id: StringName = &"") -> void:
	_add_voice(VoiceType.SKILL, 0.18, 0.10)
	var bank: Array[AudioStream] = _skill_sfx
	var pitch := 1.0
	match weapon_id:
		WeaponCatalog.TWIN_BLADES:
			if not _skill_twin_sfx.is_empty():
				bank = _skill_twin_sfx
			pitch = 1.06
		WeaponCatalog.GREATSWORD:
			if not _skill_great_sfx.is_empty():
				bank = _skill_great_sfx
			pitch = 0.88
		_:
			pitch = 1.0
	if weapon_id == WeaponCatalog.GREATSWORD:
		_play_on_player(_swing_player, _greatsword_swing_sfx, MIX_SWING_DB, 0.94)
	_play_combat_sample(bank, MIX_SKILL_SFX_DB - (3.0 if weapon_id == WeaponCatalog.GREATSWORD else 0.0), pitch)


func play_jump() -> void:
	_add_voice(VoiceType.JUMP, 0.14, 0.20)


func play_land() -> void:
	_add_voice(VoiceType.LAND, 0.12, 0.10)
	_play_combat_sample(_land_sfx, MIX_LAND_DB, 1.0)


func play_footstep() -> void:
	_add_voice(VoiceType.FOOTSTEP, 0.07, 0.08)
	_play_combat_sample(_footstep_sfx, MIX_FOOTSTEP_DB, 1.0)


func play_ui() -> void:
	_add_voice(VoiceType.UI, 0.08, 0.10)
	_play_combat_sample(_ui_click_sfx, MIX_UI_DB, 1.0)


func play_ui_deny() -> void:
	_add_voice(VoiceType.UI, 0.08, 0.10)
	_play_combat_sample(_ui_deny_sfx, MIX_UI_DENY_DB, 1.0)


func play_card() -> void:
	_add_voice(VoiceType.UI, 0.12, 0.12)
	_play_combat_sample(_card_sfx, MIX_CARD_DB, 1.0)


func play_chest() -> void:
	_add_voice(VoiceType.CHEST, 0.22, 0.18)
	_play_combat_sample(_chest_sfx, MIX_CHEST_DB, 1.0)


func play_portal() -> void:
	_add_voice(VoiceType.PORTAL, 0.30, 0.18)
	_play_combat_sample(_portal_sfx, MIX_PORTAL_DB, 1.0)


func set_music_state(next_state: int) -> void:
	var resolved: int = clampi(next_state, MusicState.MENU, MusicState.BOSS)
	if resolved == _music_state:
		return
	_music_state = resolved
	_play_bgm_track(_track_for_music_state(_music_state), false)


func get_music_state() -> int:
	return _music_state


func get_loaded_music_count() -> int:
	var loaded := 0
	for buffer in _bgm_pcm:
		if buffer.size() > 1000:
			loaded += 1
	return loaded


func play_player_attack_voice() -> void:
	_attack_vocal_request_count += 1
	_play_player_voice(_player_attack_voices, &"attack", 1.0, MIX_VOICE_ATTACK_DB)


func play_player_skill_voice() -> void:
	_play_player_voice(_player_skill_voices, &"skill", 1.0, MIX_VOICE_SKILL_DB)


func play_player_hurt_voice() -> void:
	_play_player_voice(_player_hurt_voices, &"hurt", 1.0, MIX_VOICE_HURT_DB)


func play_player_defeat_voice() -> void:
	_play_player_voice(_player_defeat_voices, &"defeat", 0.98, MIX_VOICE_DEFEAT_DB)


func play_enemy_attack_voice(is_slime: bool = false, is_boss: bool = false) -> void:
	_add_voice(VoiceType.ENEMY_BITE, 0.20 if not is_boss else 0.28, 0.48 if not is_boss else 0.62)
	var bank: Array[AudioStream] = _slime_attack_voices if is_slime else _goblin_attack_voices
	_play_combat_sample(
		bank,
		MIX_ENEMY_VOICE_DB if not is_boss else MIX_ENEMY_VOICE_DB + 2.0,
		1.0 if not is_boss else 0.78
	)


func play_enemy_bite(is_boss: bool = false) -> void:
	_add_voice(VoiceType.ENEMY_BITE, 0.16 if not is_boss else 0.22, 0.12 if not is_boss else 0.18)
	_play_combat_sample(
		_enemy_bite_sfx,
		MIX_BITE_DB if not is_boss else MIX_BITE_DB + 2.0,
		1.0 if not is_boss else 0.82
	)


func play_enemy_spit(is_boss: bool = false) -> void:
	_add_voice(VoiceType.ENEMY_SPIT, 0.16 if not is_boss else 0.22, 0.18 if not is_boss else 0.28)
	_play_combat_sample(
		_enemy_spit_sfx,
		MIX_SPIT_DB if not is_boss else MIX_SPIT_DB + 2.0,
		1.0 if not is_boss else 0.86
	)


func play_enemy_defeat(is_boss: bool = false, is_slime: bool = false) -> void:
	var down_voice: Array[AudioStream] = _slime_down_voices if is_slime else _goblin_down_voices
	_play_combat_sample(
		down_voice,
		MIX_ENEMY_DOWN_VOICE_DB if not is_boss else MIX_ENEMY_DOWN_VOICE_DB + 1.5,
		0.88 if is_boss else 1.0
	)
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
		_player_attack_voices.size()
		+ _player_skill_voices.size()
		+ _player_hurt_voices.size()
		+ _player_defeat_voices.size()
	)


func get_loaded_combat_sample_count() -> int:
	return (
		_sword_swing_sfx.size()
		+ _greatsword_swing_sfx.size()
		+ _flesh_cut_sfx.size()
		+ _hit_sfx.size()
		+ _skill_sfx.size()
		+ _skill_twin_sfx.size()
		+ _skill_great_sfx.size()
		+ _jump_air_sfx.size()
		+ _land_sfx.size()
		+ _footstep_sfx.size()
		+ _ui_click_sfx.size()
		+ _ui_deny_sfx.size()
		+ _card_sfx.size()
		+ _chest_sfx.size()
		+ _portal_sfx.size()
		+ _enemy_bite_sfx.size()
		+ _enemy_spit_sfx.size()
		+ _enemy_flesh_hurt_sfx.size()
		+ _enemy_slime_hurt_sfx.size()
		+ _goblin_attack_voices.size()
		+ _goblin_hurt_voices.size()
		+ _slime_attack_voices.size()
		+ _slime_hurt_voices.size()
		+ _goblin_down_voices.size()
		+ _slime_down_voices.size()
		+ ENEMY_FLESH_BURST_SFX.size()
		+ ENEMY_SLIME_SPLAT_SFX.size()
		+ 1
	)


func _process(delta: float) -> void:
	_music_time += delta
	_vocal_duck_remaining = maxf(0.0, _vocal_duck_remaining - delta)
	if _hurt_delay_remaining >= 0.0:
		_hurt_delay_remaining -= delta
		if _hurt_delay_remaining <= 0.0:
			_play_combat_sample(
				_pending_hurt_clips,
				_pending_hurt_db,
				_pending_hurt_pitch
			)
			_pending_hurt_clips = []
			_hurt_delay_remaining = -1.0
	_advance_bgm_fade(delta)
	if is_instance_valid(_bgm_player) and _bgm_player.stream != null and not _bgm_player.playing:
		_bgm_player.play()
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
	# Designed boy-hero clips are already pitched. Playback stays independent of animation time.
	vocal_player.stop()
	vocal_player.stream = voice_clip
	vocal_player.pitch_scale = pitch
	vocal_player.volume_db = volume_boost_db
	vocal_player.play()
	if voice_clip.has_meta(&"clip_path"):
		_last_player_voice_path = String(voice_clip.get_meta(&"clip_path"))
	else:
		_last_player_voice_path = voice_clip.resource_path
	_vocal_duck_remaining = maxf(
		_vocal_duck_remaining,
		voice_clip.get_length() / vocal_player.pitch_scale + 0.06
	)


func _play_combat_sample(samples: Array, volume_db: float, pitch: float) -> void:
	if _sfx_players.is_empty() or samples.is_empty():
		return
	var sample_index: int = int(floor(_music_time * 31.0 + float(_next_sfx_player))) % samples.size()
	_play_on_player(_sfx_players[_next_sfx_player], samples, volume_db, pitch, sample_index)
	_next_sfx_player = (_next_sfx_player + 1) % _sfx_players.size()


func _play_on_player(
	player: AudioStreamPlayer,
	samples: Array,
	volume_db: float,
	pitch: float,
	sample_index: int = -1
) -> void:
	if player == null or samples.is_empty():
		return
	var resolved_index: int = sample_index
	if resolved_index < 0:
		resolved_index = int(floor(_music_time * 31.0)) % samples.size()
	var sample: AudioStream = samples[resolved_index] as AudioStream
	if sample == null:
		return
	player.stop()
	player.stream = sample
	player.volume_db = volume_db
	player.pitch_scale = pitch
	player.play()


func _ensure_audio_bus(bus_name: StringName) -> void:
	if AudioServer.get_bus_index(bus_name) >= 0:
		return
	AudioServer.add_bus()
	var bus_index: int = AudioServer.bus_count - 1
	AudioServer.set_bus_name(bus_index, bus_name)
	AudioServer.set_bus_send(bus_index, &"Master")


func _make_loop_stream(path: String) -> AudioStream:
	var stream := load_wav_file(path)
	if stream == null:
		return null
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = stream.data.size() / 2
	return stream


func _bgm_volume_db(track: int) -> float:
	if track == 0:
		return -6.0
	if track == 2:
		return -1.0
	if _music_state == MusicState.COMBAT:
		return -1.0
	return -4.5


func _play_bgm_track(track: int, force: bool) -> void:
	if track < 0 or track >= _bgm_streams.size() or _bgm_streams[track] == null:
		return
	if _bgm_players.is_empty():
		return
	_bgm_target_db = _bgm_volume_db(track)
	var live: AudioStreamPlayer = _bgm_players[_bgm_live_index]
	var same_bed: bool = track == _bgm_track and not force
	if same_bed and is_instance_valid(live) and live.playing:
		if absf(live.volume_db - _bgm_target_db) > 0.15:
			_bgm_fade = 0.0
			_bgm_fade_start_db = live.volume_db
			_bgm_has_outgoing = false
		return
	if track != _bgm_track:
		_bgm_prev_track = _bgm_track
		_bgm_prev_head = _bgm_head
		_bgm_head = 0.0
		_bgm_xfade = 0.0
	var outgoing: AudioStreamPlayer = live
	_bgm_has_outgoing = is_instance_valid(outgoing) and outgoing.playing and not force
	_bgm_outgoing_start_db = outgoing.volume_db if _bgm_has_outgoing else BGM_SILENCE_DB
	if not _bgm_has_outgoing and is_instance_valid(outgoing):
		outgoing.stop()
	_bgm_live_index = 1 - _bgm_live_index if _bgm_has_outgoing else _bgm_live_index
	live = _bgm_players[_bgm_live_index]
	_bgm_player = live
	_bgm_track = track
	live.stop()
	live.stream = _bgm_streams[track]
	live.volume_db = BGM_SILENCE_DB if not force else _bgm_target_db
	live.play()
	_bgm_fade_start_db = live.volume_db
	_bgm_fade = 1.0 if force else 0.0


func _advance_bgm_fade(delta: float) -> void:
	if _bgm_players.is_empty():
		return
	var live: AudioStreamPlayer = _bgm_players[_bgm_live_index]
	if _bgm_fade >= 1.0:
		if is_instance_valid(live):
			live.volume_db = _bgm_target_db
		return
	_bgm_fade = minf(1.0, _bgm_fade + delta / BGM_FADE)
	var weight: float = _bgm_fade * _bgm_fade * (3.0 - 2.0 * _bgm_fade)
	if is_instance_valid(live):
		live.volume_db = lerpf(_bgm_fade_start_db, _bgm_target_db, weight)
	if _bgm_has_outgoing:
		var outgoing: AudioStreamPlayer = _bgm_players[1 - _bgm_live_index]
		if is_instance_valid(outgoing):
			outgoing.volume_db = lerpf(_bgm_outgoing_start_db, BGM_SILENCE_DB, weight)
			if _bgm_fade >= 1.0:
				outgoing.stop()
				_bgm_has_outgoing = false


func _make_sfx_player(player_name: String) -> AudioStreamPlayer:
	var sfx_player := AudioStreamPlayer.new()
	sfx_player.name = player_name
	sfx_player.bus = &"SFX"
	add_child(sfx_player)
	return sfx_player


func _track_for_music_state(state: int) -> int:
	if state == MusicState.MENU:
		return 0
	if state == MusicState.BOSS:
		return 2
	return 1


func _wav_pcm(path: String) -> PackedFloat32Array:
	var decoded := PackedFloat32Array()
	var stream := load_wav_file(path)
	if stream == null or stream.data.is_empty():
		return decoded
	var bytes: PackedByteArray = stream.data
	decoded.resize(bytes.size() / 2)
	for index in range(decoded.size()):
		var sample: int = bytes[index * 2] | (bytes[index * 2 + 1] << 8)
		if sample >= 32768:
			sample -= 65536
		decoded[index] = float(sample) / 32767.0
	return decoded


func _mix_bgm_pcm() -> float:
	var current: PackedFloat32Array = _bgm_pcm[_bgm_track]
	if current.is_empty():
		return 0.0
	var mixed: float = current[int(_bgm_head) % current.size()]
	_bgm_head += 1.0
	if _bgm_head >= float(current.size()):
		_bgm_head = 0.0
	if _bgm_xfade < 1.0 and _bgm_prev_track >= 0 and _bgm_prev_track < _bgm_pcm.size():
		var previous: PackedFloat32Array = _bgm_pcm[_bgm_prev_track]
		if not previous.is_empty():
			var previous_sample: float = previous[int(_bgm_prev_head) % previous.size()]
			_bgm_prev_head += 1.0
			_bgm_xfade = minf(1.0, _bgm_xfade + 1.0 / (MIX_RATE * BGM_FADE))
			mixed = lerpf(previous_sample, mixed, _bgm_xfade)
	var gain := 0.58
	match _music_state:
		MusicState.MENU:
			gain = 0.52
		MusicState.COMBAT:
			gain = 0.64
		MusicState.BOSS:
			gain = 0.74
		_:
			gain = 0.60
	if _vocal_duck_remaining > 0.0:
		gain *= 0.72
	return mixed * gain


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
			var cloth: float = noise * (0.70 + progress * 0.10)
			return cloth * envelope * volume
		VoiceType.IMPACT:
			var tick: float = sin(TAU * 2860.0 * age) * exp(-age * 55.0)
			var click: float = noise * exp(-age * 80.0)
			return (tick * 0.55 + click * 0.28) * envelope * volume
		VoiceType.DASH:
			var dash_frequency: float = lerpf(160.0, 690.0, progress)
			return (sin(TAU * dash_frequency * age) * 0.22 + noise * 0.82) * envelope * volume
		VoiceType.SKILL:
			var root_note: float = sin(TAU * 329.63 * age)
			var fifth_note: float = sin(TAU * 493.88 * age + progress * 5.0)
			var crystal_note: float = sin(TAU * 1318.51 * age)
			var spark: float = sin(TAU * 1760.0 * age) * exp(-age * 18.0)
			return (root_note * 0.30 + fifth_note * 0.28 + crystal_note * 0.24 + spark * 0.22 + noise * 0.12) * envelope * volume
		VoiceType.JUMP:
			var jump_frequency: float = lerpf(360.0, 880.0, progress)
			var hop: float = sin(TAU * jump_frequency * age)
			var click: float = sin(TAU * 1560.0 * age) * exp(-age * 26.0)
			return (hop * 0.58 + click * 0.32 + noise * 0.18) * envelope * volume
		VoiceType.LAND:
			var land_frequency: float = lerpf(150.0, 70.0, progress)
			return (sin(TAU * land_frequency * age) * 0.55 + noise * 0.38) * envelope * volume
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
	if is_instance_valid(_bgm_player) and _bgm_player.playing:
		return 0.0
	if _bgm_pcm.size() > _bgm_track and _bgm_pcm[_bgm_track].size() > 64:
		return _mix_bgm_pcm()
	# Fallback moonlit pad if the authored beds are missing.
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


func _load_designed_list(paths: PackedStringArray) -> Array[AudioStream]:
	var loaded: Array[AudioStream] = []
	for path in paths:
		var stream := load_wav_file(String(path))
		if stream != null:
			loaded.append(stream)
	return loaded


static func load_wav_file(path: String) -> AudioStreamWAV:
	var abs_path := ProjectSettings.globalize_path(path)
	var file := FileAccess.open(abs_path, FileAccess.READ)
	if file == null:
		push_error("Missing designed clip %s" % path)
		return null
	var bytes: PackedByteArray = file.get_buffer(file.get_length())
	file.close()
	if bytes.size() < 44:
		push_error("Designed clip is too short: %s" % path)
		return null
	var mix_rate := 44100
	var channels := 1
	var bits := 16
	var pcm := PackedByteArray()
	var offset := 12
	while offset + 8 <= bytes.size():
		var chunk := _chunk_id(bytes, offset)
		var chunk_size: int = _u32(bytes, offset + 4)
		var body := offset + 8
		if chunk == "fmt " and body + 16 <= bytes.size():
			channels = maxi(1, _u16(bytes, body + 2))
			mix_rate = maxi(1, _u32(bytes, body + 4))
			bits = maxi(8, _u16(bytes, body + 14))
		elif chunk == "data":
			var end: int = mini(bytes.size(), body + maxi(0, chunk_size))
			pcm = bytes.slice(body, end)
			break
		offset = body + chunk_size
		if chunk_size % 2 == 1:
			offset += 1
	if pcm.is_empty():
		push_error("Designed clip has no PCM data: %s" % path)
		return null
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS if bits == 16 else AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = mix_rate
	stream.stereo = channels > 1
	stream.data = pcm
	stream.resource_name = path.get_file()
	# This stream is decoded manually rather than loaded by ResourceLoader. Giving
	# multiple runtime instances the same resource_path makes Godot report a cyclic
	# resource/path collision when tests or menus instantiate Main more than once.
	# clip_path remains the stable source identifier used by voice diagnostics.
	stream.set_meta(&"clip_path", path)
	return stream


static func wav_peak_db(path: String) -> float:
	var stream := load_wav_file(path)
	if stream == null or stream.data.is_empty():
		return -80.0
	var loudest := 1
	var bytes: PackedByteArray = stream.data
	var index := 0
	while index + 1 < bytes.size():
		var sample: int = bytes[index] | (bytes[index + 1] << 8)
		if sample >= 32768:
			sample -= 65536
		loudest = maxi(loudest, absi(sample))
		index += 2
	return linear_to_db(float(loudest) / 32767.0)


static func wav_duration(path: String) -> float:
	var stream := load_wav_file(path)
	if stream == null:
		return 0.0
	return stream.get_length()


static func _chunk_id(bytes: PackedByteArray, offset: int) -> String:
	return (
		String.chr(bytes[offset])
		+ String.chr(bytes[offset + 1])
		+ String.chr(bytes[offset + 2])
		+ String.chr(bytes[offset + 3])
	)


static func _u16(bytes: PackedByteArray, offset: int) -> int:
	return bytes[offset] | (bytes[offset + 1] << 8)


static func _u32(bytes: PackedByteArray, offset: int) -> int:
	return (
		bytes[offset]
		| (bytes[offset + 1] << 8)
		| (bytes[offset + 2] << 16)
		| (bytes[offset + 3] << 24)
	)
