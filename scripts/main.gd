extends Node2D

const WORLD_SIZE := Vector2(1280.0, 720.0)
const DISPLAY_SIZE := Vector2(1280.0, 840.0)
const HUD_DOCK_TOP := 720.0
const HEALTH_FILL_WIDTH := 354.0
const ENEMY_SCRIPT := preload("res://scripts/rogue_enemy.gd")
const ENEMY_PROJECTILE_SCRIPT := preload("res://scripts/enemy_projectile.gd")
const ROOM_CATALOG_SCRIPT := preload("res://scripts/run_room_catalog.gd")
const CHEST_SCRIPT := preload("res://scripts/reward_chest.gd")
const COMBAT_VFX_SCRIPT := preload("res://scripts/combat_vfx.gd")
const DAMAGE_NUMBER_SCRIPT := preload("res://scripts/damage_number.gd")
const SOUNDSCAPE_SCRIPT := preload("res://scripts/soundscape.gd")
const ABILITY_SLOT_SCRIPT := preload("res://scripts/ability_slot.gd")
const SETTINGS_STORE_SCRIPT := preload("res://scripts/settings_store.gd")
const PAUSE_INPUT_HANDLER_SCRIPT := preload("res://scripts/pause_input_handler.gd")
const MOONLIT_GOTHIC_BRIDGE_BACKGROUND := preload("res://assets/backgrounds/moonlit_gothic_bridge.png")
const BUILD_LABEL := "月蚀混战扩展版 2026.08.31C"
const ROOMS_PER_RUN := 20
const GOBLIN_CHAPTER_START := 5
const MIXED_CHAPTER_START := 10
const FINAL_CHAPTER_START := 15
const ROOM_PLAYER_SPAWN := Vector2(150.0, 580.0)
const ROOM_ENTRY_RECOVERY := 10
const DEATH_RESTART_DELAY := 1.05
const MAX_RUN_LIVES := 3
const ENEMY_ROLE_MELEE := 0
const ENEMY_ROLE_RANGED := 1
const ENEMY_RANK_NORMAL := 0
const ENEMY_RANK_ELITE := 1
const ENEMY_RANK_BOSS := 2
const ENEMY_FAMILY_SLIME := 0
const ENEMY_FAMILY_GOBLIN := 1

enum EncounterType {
	NORMAL,
	TREASURE,
	ELITE,
	SHOP,
	BOSS,
}

enum Difficulty {
	EASY,
	MEDIUM,
	HARD,
}

@export var save_enabled: bool = true

@onready var player: RoguePlayer = $Player
@onready var controls_label: Label = $HUD/Controls
@onready var title_label: Label = $HUD/Title
@onready var hud: CanvasLayer = $HUD

var platform_rects: Array[Rect2] = []
var _platform_bodies: Array[StaticBody2D] = []
var _rng := RandomNumberGenerator.new()
var _enemies: Array[RogueEnemy] = []
var _projectiles: Array[Area2D] = []
var _room_pool: Array[Dictionary] = []
var _room_sequence: Array[int] = []
var _current_room_index: int = -1
var _current_room_data: Dictionary = {}
var _run_generation: int = 0
var _run_number: int = 0
var _run_active: bool = false
var _choosing_upgrade: bool = false
var _run_complete: bool = false
var _death_restart_pending: bool = false
var _last_upgrade_name: String = ""
var _current_encounter: int = EncounterType.NORMAL
var _chest: RewardChest
var _awaiting_chest: bool = false
var _shopping: bool = false
var _gold: int = 10
var _run_shards: int = 0
var _progression: ProgressionStore
var _boss_enemy: RogueEnemy

var _health_label: Label
var _health_fill: ColorRect
var _lives_label: Label
var _status_label: Label
var _room_label: Label
var _currency_label: Label
var _equipment_label: Label
var _boss_health_background: ColorRect
var _boss_health_fill: ColorRect
var _boss_health_label: Label
var _upgrade_overlay: Control
var _upgrade_title: Label
var _upgrade_hint: Label
var _upgrade_buttons: Array[Button] = []
var _upgrade_choices: Array[Dictionary] = []
var _entry_overlay: Control
var _entry_title: Label
var _entry_subtitle: Label
var _start_button: Button
var _difficulty_buttons: Array[Button] = []
var _entry_flow_active: bool = false
var _selected_difficulty: int = Difficulty.MEDIUM
var _camera_base_position := Vector2.ZERO
var _camera_shake_remaining: float = 0.0
var _camera_shake_duration: float = 0.0
var _camera_shake_strength: float = 0.0
var _attack_slot: Control
var _dash_slot: Control
var _skill_slot: Control
var _weapon_slot_panels: Array[Panel] = []
var _weapon_slot_labels: Array[Label] = []
var _weapon_hud_state_key: String = ""
var _lives_remaining: int = MAX_RUN_LIVES
var _settings: RefCounted
var _pause_overlay: Control
var _settings_overlay: Control
var _settings_key_buttons: Dictionary = {}
var _settings_volume_slider: HSlider
var _settings_damage_numbers_toggle: CheckButton
var _settings_guide_label: RichTextLabel
var _settings_from_pause: bool = false
var _awaiting_rebind_action: StringName = &""
var _is_game_paused: bool = false
var _pause_input_handler: Node
var _soundscape: RogueSoundscape


func _ready() -> void:
	# The gameplay root must be pausable. HUD owns the always-processing input bridge.
	process_mode = Node.PROCESS_MODE_PAUSABLE
	hud.process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize()
	_settings = SETTINGS_STORE_SCRIPT.new() as RefCounted
	_settings.call(&"load_settings")
	_soundscape = SOUNDSCAPE_SCRIPT.new() as RogueSoundscape
	add_child(_soundscape)
	_configure_inputs()
	_pause_input_handler = PAUSE_INPUT_HANDLER_SCRIPT.new() as Node
	hud.add_child(_pause_input_handler)
	_pause_input_handler.key_pressed.connect(_on_always_key_pressed)
	_configure_camera()
	_create_combat_hud()
	_create_upgrade_ui()
	_create_entry_ui()
	_create_pause_ui()
	_create_settings_ui()
	player.auto_respawn = false
	player.attack_hit.connect(_on_player_attack_hit)
	player.skill_hit.connect(_on_player_skill_hit)
	player.action_started.connect(_on_player_action_started)
	player.vocal_requested.connect(_on_player_vocal_requested)
	player.health_changed.connect(_on_player_health_changed)
	player.died.connect(_on_player_died)
	_progression = ProgressionStore.new()
	if save_enabled:
		_progression.load_progress()
	_room_pool = ROOM_CATALOG_SCRIPT.create_room_pool()
	_lives_remaining = MAX_RUN_LIVES
	if save_enabled:
		_show_start_screen()
	else:
		_start_new_run()


func _process(_delta: float) -> void:
	_update_camera_shake(_delta)
	if _is_game_paused:
		return
	if not _entry_flow_active and Input.is_action_just_pressed(&"restart"):
		_start_new_run()
		return
	if Input.is_action_just_pressed(&"interact"):
		if _awaiting_chest:
			_open_current_chest()
		elif _shopping:
			_leave_shop()
	if Input.is_action_just_pressed(&"cycle_weapon"):
		_cycle_weapon()
	if is_instance_valid(_chest):
		_chest.set_opener_position(player.global_position)
	_update_equipment_hud()
	_update_ability_hud()
	_update_lives_hud()


func _on_player_action_started(action: StringName) -> void:
	if not is_instance_valid(_soundscape):
		return
	match action:
		&"attack":
			_soundscape.play_sword_swing()
			_soundscape.play_player_attack_voice()
		&"dash":
			_soundscape.play_dash()
		&"skill":
			_soundscape.play_skill()
			_soundscape.play_player_skill_voice()
		&"jump":
			_soundscape.play_jump()


func _on_player_vocal_requested(cue: StringName) -> void:
	if not is_instance_valid(_soundscape):
		return
	match cue:
		&"hurt":
			_soundscape.play_player_hurt_voice()
		&"defeat":
			_soundscape.play_player_defeat_voice()


func _on_enemy_sound_requested(cue: StringName, is_boss: bool) -> void:
	if not is_instance_valid(_soundscape):
		return
	match cue:
		&"bite":
			_soundscape.play_enemy_bite(is_boss)
		&"spit":
			_soundscape.play_enemy_spit(is_boss)


func _unhandled_key_input(event: InputEvent) -> void:
	if not _choosing_upgrade or not event.is_pressed() or event.is_echo():
		return
	match event.keycode:
		KEY_1, KEY_KP_1:
			choose_upgrade(0)
		KEY_2, KEY_KP_2:
			choose_upgrade(1)
		KEY_3, KEY_KP_3:
			choose_upgrade(2)


func _configure_inputs() -> void:
	_register_action(&"move_left", [KEY_A, KEY_LEFT])
	_register_action(&"move_right", [KEY_D, KEY_RIGHT])
	_register_action(&"jump", [KEY_SPACE])
	_register_action(&"aim_up", [KEY_W, KEY_UP])
	_register_action(&"aim_down", [KEY_S, KEY_DOWN])
	_register_action(&"attack", [KEY_J])
	_register_action(&"dash", [KEY_K])
	_register_action(&"skill", [KEY_L])
	_register_action(&"interact", [KEY_E])
	_register_action(&"cycle_weapon", [KEY_Q])
	_register_action(&"restart", [KEY_R])
	_register_action(&"pause", [KEY_ESCAPE])
	_settings.call(&"apply")


func _register_action(action: StringName, key_codes: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)

	for key_code in key_codes:
		var event_already_registered: bool = false
		for existing_event in InputMap.action_get_events(action):
			if existing_event is InputEventKey and existing_event.keycode == key_code:
				event_already_registered = true
				break
		if event_already_registered:
			continue
		var event := InputEventKey.new()
		event.keycode = key_code
		InputMap.action_add_event(action, event)


func _on_always_key_pressed(event: InputEventKey) -> void:
	if not _awaiting_rebind_action.is_empty():
		if event.keycode == KEY_ESCAPE:
			_awaiting_rebind_action = &""
			_refresh_settings_key_buttons()
		else:
			_settings.call(&"rebind", _awaiting_rebind_action, event.keycode)
			_awaiting_rebind_action = &""
			_refresh_settings_key_buttons()
		get_viewport().set_input_as_handled()
		return
	if not event.is_action_pressed(&"pause"):
		return
	if _settings_overlay.visible:
		_close_settings()
	elif _entry_flow_active:
		return
	elif _is_game_paused:
		_resume_game()
	else:
		_pause_game()
	get_viewport().set_input_as_handled()


func _configure_camera() -> void:
	var camera: Camera2D = player.get_node_or_null("Camera2D") as Camera2D
	if camera == null:
		return
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = int(WORLD_SIZE.x)
	# The extra 120 pixels belong to the fixed HUD dock. Keeping the camera limits
	# equal to the full display pins the 720-pixel room to the top of the window.
	camera.limit_bottom = int(DISPLAY_SIZE.y)
	_camera_base_position = camera.position


func _update_camera_shake(delta: float) -> void:
	var camera: Camera2D = player.get_node_or_null("Camera2D") as Camera2D
	if camera == null:
		return
	if _camera_shake_remaining <= 0.0:
		camera.position = _camera_base_position
		return
	_camera_shake_remaining = maxf(0.0, _camera_shake_remaining - delta)
	var intensity: float = _camera_shake_strength * (_camera_shake_remaining / _camera_shake_duration)
	camera.position = _camera_base_position + Vector2(
		_rng.randf_range(-intensity, intensity),
		_rng.randf_range(-intensity, intensity)
	)
	if _camera_shake_remaining <= 0.0:
		camera.position = _camera_base_position


func _trigger_camera_shake(strength: float, duration: float = 0.09) -> void:
	_camera_shake_strength = maxf(_camera_shake_strength, strength)
	_camera_shake_duration = maxf(_camera_shake_duration, duration)
	_camera_shake_remaining = maxf(_camera_shake_remaining, duration)


func _create_hud_panel(
	panel_name: String,
	panel_position: Vector2,
	panel_size: Vector2,
	border_color: Color,
	accent_color: Color
) -> Panel:
	var panel := Panel.new()
	panel.name = panel_name
	panel.position = panel_position
	panel.size = panel_size
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.018, 0.042, 0.065, 0.90)
	panel_style.border_color = border_color
	panel_style.set_border_width_all(1)
	panel_style.corner_radius_top_left = 9
	panel_style.corner_radius_top_right = 9
	panel_style.corner_radius_bottom_left = 9
	panel_style.corner_radius_bottom_right = 9
	panel_style.shadow_color = Color(0.0, 0.0, 0.0, 0.36)
	panel_style.shadow_size = 7
	panel_style.shadow_offset = Vector2(0.0, 3.0)
	panel.add_theme_stylebox_override("panel", panel_style)
	hud.add_child(panel)
	var accent := ColorRect.new()
	accent.position = Vector2(0.0, 10.0)
	accent.size = Vector2(4.0, panel_size.y - 20.0)
	accent.color = accent_color
	accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(accent)
	return panel


func _create_combat_hud() -> void:
	# Gameplay stays visually clean; the complete control guide now lives in Settings.
	title_label.text = ""
	title_label.visible = false
	controls_label.text = ""
	controls_label.visible = false

	# The combat dock occupies its own 120-pixel strip below the 1280x720 room.
	# It is intentionally opaque so gameplay silhouettes never compete with HUD text.
	var bottom_hud := Panel.new()
	bottom_hud.name = "BottomHUD"
	bottom_hud.position = Vector2(0.0, HUD_DOCK_TOP)
	bottom_hud.size = Vector2(DISPLAY_SIZE.x, DISPLAY_SIZE.y - HUD_DOCK_TOP)
	bottom_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bottom_style := StyleBoxFlat.new()
	bottom_style.bg_color = Color(0.008, 0.019, 0.032, 1.0)
	bottom_style.border_color = Color(0.21, 0.58, 0.67, 0.72)
	bottom_style.border_width_top = 2
	bottom_style.shadow_color = Color(0.0, 0.0, 0.0, 0.72)
	bottom_style.shadow_size = 12
	bottom_style.shadow_offset = Vector2(0.0, -4.0)
	bottom_hud.add_theme_stylebox_override("panel", bottom_style)
	hud.add_child(bottom_hud)

	var top_rune := ColorRect.new()
	top_rune.position = Vector2(28.0, 4.0)
	top_rune.size = Vector2(1224.0, 2.0)
	top_rune.color = Color(0.31, 0.82, 0.90, 0.54)
	top_rune.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom_hud.add_child(top_rune)

	_create_hud_panel(
		"VitalsPanel",
		Vector2(28.0, 728.0),
		Vector2(390.0, 104.0),
		Color(0.23, 0.58, 0.66, 0.60),
		Color("#46cdd9")
	)
	_create_hud_panel(
		"AbilityPanel",
		Vector2(432.0, 722.0),
		Vector2(416.0, 114.0),
		Color(0.40, 0.55, 0.75, 0.72),
		Color("#86a8ff")
	)
	var weapon_panel: Panel = _create_hud_panel(
		"WeaponPanel",
		Vector2(862.0, 728.0),
		Vector2(390.0, 104.0),
		Color(0.63, 0.47, 0.24, 0.68),
		Color("#e8b65c")
	)

	var health_background := ColorRect.new()
	health_background.name = "HealthBackground"
	health_background.position = Vector2(42.0, 755.0)
	health_background.size = Vector2(362.0, 28.0)
	health_background.color = Color(0.012, 0.033, 0.047, 0.98)
	health_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(health_background)

	_health_fill = ColorRect.new()
	_health_fill.name = "HealthFill"
	_health_fill.position = Vector2(4.0, 4.0)
	_health_fill.size = Vector2(HEALTH_FILL_WIDTH, 20.0)
	_health_fill.color = Color(0.18, 0.82, 0.50, 0.96)
	_health_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	health_background.add_child(_health_fill)

	_health_label = Label.new()
	_health_label.name = "HealthLabel"
	_health_label.position = Vector2(4.0, 0.0)
	_health_label.size = Vector2(354.0, 28.0)
	_health_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_health_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_health_label.add_theme_font_size_override("font_size", 15)
	_health_label.add_theme_color_override("font_color", Color.WHITE)
	_health_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.84))
	_health_label.add_theme_constant_override("outline_size", 2)
	_health_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	health_background.add_child(_health_label)

	_create_hud_panel(
		"RoomCard",
		Vector2(1002.0, 16.0),
		Vector2(246.0, 70.0),
		Color(0.26, 0.68, 0.78, 0.72),
		Color("#61d6e8")
	)
	_create_hud_panel(
		"StatusToast",
		Vector2(42.0, 802.0),
		Vector2(362.0, 25.0),
		Color(0.78, 0.57, 0.24, 0.48),
		Color("#efb85d")
	)

	_status_label = Label.new()
	_status_label.name = "CombatStatus"
	_status_label.position = Vector2(52.0, 804.0)
	_status_label.size = Vector2(340.0, 21.0)
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_status_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_status_label.clip_text = true
	_status_label.add_theme_font_size_override("font_size", 12)
	_status_label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.50, 1.0))
	_status_label.add_theme_color_override("font_outline_color", Color(0.025, 0.045, 0.07, 0.96))
	_status_label.add_theme_constant_override("outline_size", 1)
	_status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(_status_label)

	_room_label = Label.new()
	_room_label.name = "RoomProgress"
	_room_label.position = Vector2(1018.0, 24.0)
	_room_label.size = Vector2(214.0, 54.0)
	_room_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_room_label.add_theme_font_size_override("font_size", 14)
	_room_label.add_theme_color_override("font_color", Color(0.78, 0.90, 0.96, 1.0))
	_room_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(_room_label)

	_currency_label = Label.new()
	_currency_label.name = "Currency"
	_currency_label.position = Vector2(42.0, 785.0)
	_currency_label.size = Vector2(362.0, 16.0)
	_currency_label.clip_text = true
	_currency_label.add_theme_font_size_override("font_size", 13)
	_currency_label.add_theme_color_override("font_color", Color(1.0, 0.83, 0.43, 1.0))
	_currency_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(_currency_label)

	_equipment_label = Label.new()
	_equipment_label.name = "Equipment"
	_equipment_label.position = Vector2(880.0, 734.0)
	_equipment_label.size = Vector2(352.0, 20.0)
	_equipment_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_equipment_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_equipment_label.clip_text = true
	_equipment_label.add_theme_font_size_override("font_size", 13)
	_equipment_label.add_theme_color_override("font_color", Color(0.96, 0.82, 0.53, 1.0))
	_equipment_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(_equipment_label)

	_lives_label = Label.new()
	_lives_label.name = "Lives"
	_lives_label.position = Vector2(42.0, 734.0)
	_lives_label.size = Vector2(362.0, 18.0)
	_lives_label.add_theme_font_size_override("font_size", 13)
	_lives_label.clip_text = true
	_lives_label.add_theme_color_override("font_color", Color(1.0, 0.76, 0.46, 1.0))
	_lives_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(_lives_label)

	_boss_health_background = ColorRect.new()
	_boss_health_background.name = "BossHealth"
	_boss_health_background.position = Vector2(390.0, 22.0)
	_boss_health_background.size = Vector2(500.0, 28.0)
	_boss_health_background.color = Color(0.05, 0.02, 0.03, 0.92)
	_boss_health_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(_boss_health_background)

	_boss_health_fill = ColorRect.new()
	_boss_health_fill.position = Vector2(4.0, 4.0)
	_boss_health_fill.size = Vector2(492.0, 20.0)
	_boss_health_fill.color = Color(0.88, 0.18, 0.22, 0.96)
	_boss_health_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_health_background.add_child(_boss_health_fill)

	_boss_health_label = Label.new()
	_boss_health_label.position = Vector2(8.0, 1.0)
	_boss_health_label.size = Vector2(484.0, 26.0)
	_boss_health_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boss_health_label.add_theme_font_size_override("font_size", 15)
	_boss_health_label.add_theme_color_override("font_color", Color.WHITE)
	_boss_health_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_health_background.add_child(_boss_health_label)
	_boss_health_background.visible = false

	var ability_heading := Label.new()
	ability_heading.position = Vector2(450.0, 726.0)
	ability_heading.size = Vector2(380.0, 20.0)
	ability_heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ability_heading.text = "战技  ·  COMBAT ARTS"
	ability_heading.add_theme_font_size_override("font_size", 12)
	ability_heading.add_theme_color_override("font_color", Color(0.63, 0.78, 0.98, 0.90))
	ability_heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(ability_heading)

	_create_weapon_hud(weapon_panel)
	_create_ability_hud()


func _create_weapon_hud(weapon_panel: Panel) -> void:
	_weapon_slot_panels.clear()
	_weapon_slot_labels.clear()
	for weapon_index in range(WeaponCatalog.all_weapon_ids().size()):
		var slot := Panel.new()
		slot.name = "WeaponSlot_%d" % weapon_index
		slot.position = Vector2(18.0 + float(weapon_index) * 92.0, 31.0)
		slot.size = Vector2(84.0, 58.0)
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		weapon_panel.add_child(slot)
		_weapon_slot_panels.append(slot)

		var slot_label := Label.new()
		slot_label.name = "Label"
		slot_label.position = Vector2(4.0, 3.0)
		slot_label.size = Vector2(76.0, 52.0)
		slot_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		slot_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		slot_label.add_theme_font_size_override("font_size", 11)
		slot_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(slot_label)
		_weapon_slot_labels.append(slot_label)

	var switch_panel := Panel.new()
	switch_panel.name = "WeaponSwitch"
	switch_panel.position = Vector2(296.0, 31.0)
	switch_panel.size = Vector2(72.0, 58.0)
	switch_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var switch_style := StyleBoxFlat.new()
	switch_style.bg_color = Color(0.025, 0.075, 0.098, 0.96)
	switch_style.border_color = Color(0.37, 0.78, 0.85, 0.70)
	switch_style.set_border_width_all(1)
	switch_style.corner_radius_top_left = 6
	switch_style.corner_radius_top_right = 6
	switch_style.corner_radius_bottom_left = 6
	switch_style.corner_radius_bottom_right = 6
	switch_panel.add_theme_stylebox_override("panel", switch_style)
	weapon_panel.add_child(switch_panel)

	var switch_label := Label.new()
	switch_label.position = Vector2(3.0, 3.0)
	switch_label.size = Vector2(66.0, 52.0)
	switch_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	switch_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	switch_label.text = "Q\n切换"
	switch_label.add_theme_font_size_override("font_size", 12)
	switch_label.add_theme_color_override("font_color", Color(0.65, 0.90, 0.95, 1.0))
	switch_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	switch_panel.add_child(switch_label)


func _create_ability_hud() -> void:
	var ability_bar := Control.new()
	ability_bar.name = "AbilityBar"
	ability_bar.position = Vector2(503.0, 752.0)
	ability_bar.size = Vector2(274.0, 76.0)
	ability_bar.mouse_filter = Control.MOUSE_FILTER_PASS
	hud.add_child(ability_bar)

	_attack_slot = ABILITY_SLOT_SCRIPT.new() as Control
	_attack_slot.name = "AttackAbility"
	_attack_slot.position = Vector2(0.0, 0.0)
	_attack_slot.size = Vector2(78.0, 76.0)
	ability_bar.add_child(_attack_slot)

	_dash_slot = ABILITY_SLOT_SCRIPT.new() as Control
	_dash_slot.name = "DashAbility"
	_dash_slot.position = Vector2(98.0, 0.0)
	_dash_slot.size = Vector2(78.0, 76.0)
	ability_bar.add_child(_dash_slot)

	_skill_slot = ABILITY_SLOT_SCRIPT.new() as Control
	_skill_slot.name = "SkillAbility"
	_skill_slot.position = Vector2(196.0, 0.0)
	_skill_slot.size = Vector2(78.0, 76.0)
	ability_bar.add_child(_skill_slot)
	_update_ability_hud()


func _create_upgrade_ui() -> void:
	_upgrade_overlay = Control.new()
	_upgrade_overlay.name = "UpgradeChoice"
	_upgrade_overlay.position = Vector2.ZERO
	_upgrade_overlay.size = DISPLAY_SIZE
	_upgrade_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	hud.add_child(_upgrade_overlay)

	var dimmer := ColorRect.new()
	dimmer.size = DISPLAY_SIZE
	dimmer.color = Color(0.015, 0.025, 0.04, 0.82)
	dimmer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_upgrade_overlay.add_child(dimmer)

	var panel := ColorRect.new()
	panel.position = Vector2(155.0, 165.0)
	panel.size = Vector2(970.0, 390.0)
	panel.color = Color(0.055, 0.095, 0.13, 0.98)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_upgrade_overlay.add_child(panel)

	_upgrade_title = Label.new()
	_upgrade_title.position = Vector2(190.0, 195.0)
	_upgrade_title.size = Vector2(900.0, 50.0)
	_upgrade_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_upgrade_title.add_theme_font_size_override("font_size", 29)
	_upgrade_title.add_theme_color_override("font_color", Color(0.90, 0.97, 1.0, 1.0))
	_upgrade_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_upgrade_overlay.add_child(_upgrade_title)

	_upgrade_hint = Label.new()
	_upgrade_hint.position = Vector2(190.0, 490.0)
	_upgrade_hint.size = Vector2(900.0, 38.0)
	_upgrade_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_upgrade_hint.add_theme_font_size_override("font_size", 17)
	_upgrade_hint.add_theme_color_override("font_color", Color(0.62, 0.78, 0.86, 1.0))
	_upgrade_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_upgrade_overlay.add_child(_upgrade_hint)

	for choice_index in range(3):
		var button := Button.new()
		button.name = "Upgrade_%d" % (choice_index + 1)
		button.position = Vector2(190.0 + float(choice_index) * 300.0, 275.0)
		button.size = Vector2(280.0, 185.0)
		button.add_theme_font_size_override("font_size", 18)
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.pressed.connect(_on_upgrade_button_pressed.bind(choice_index))
		_upgrade_overlay.add_child(button)
		_upgrade_buttons.append(button)

	_hide_upgrade_overlay()


func _create_entry_ui() -> void:
	_entry_overlay = Control.new()
	_entry_overlay.name = "EntryFlow"
	_entry_overlay.position = Vector2.ZERO
	_entry_overlay.size = DISPLAY_SIZE
	_entry_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	hud.add_child(_entry_overlay)

	var background := ColorRect.new()
	background.size = DISPLAY_SIZE
	background.color = Color(0.018, 0.035, 0.06, 0.98)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_entry_overlay.add_child(background)

	var accent_left := ColorRect.new()
	accent_left.position = Vector2(135.0, 155.0)
	accent_left.size = Vector2(5.0, 405.0)
	accent_left.color = Color(0.22, 0.78, 0.92, 0.9)
	accent_left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_entry_overlay.add_child(accent_left)

	_entry_title = Label.new()
	_entry_title.position = Vector2(180.0, 185.0)
	_entry_title.size = Vector2(920.0, 82.0)
	_entry_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_entry_title.add_theme_font_size_override("font_size", 46)
	_entry_title.add_theme_color_override("font_color", Color(0.84, 0.95, 1.0, 1.0))
	_entry_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_entry_overlay.add_child(_entry_title)

	_entry_subtitle = Label.new()
	_entry_subtitle.position = Vector2(230.0, 278.0)
	_entry_subtitle.size = Vector2(820.0, 62.0)
	_entry_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_entry_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_entry_subtitle.add_theme_font_size_override("font_size", 18)
	_entry_subtitle.add_theme_color_override("font_color", Color(0.55, 0.74, 0.84, 1.0))
	_entry_subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_entry_overlay.add_child(_entry_subtitle)

	_start_button = Button.new()
	_start_button.name = "StartGame"
	_start_button.position = Vector2(470.0, 410.0)
	_start_button.size = Vector2(340.0, 74.0)
	_start_button.add_theme_font_size_override("font_size", 25)
	_start_button.pressed.connect(_show_difficulty_selection)
	_entry_overlay.add_child(_start_button)

	var entry_settings := Button.new()
	entry_settings.name = "EntrySettings"
	entry_settings.position = Vector2(470.0, 495.0)
	entry_settings.size = Vector2(340.0, 52.0)
	entry_settings.text = "设置"
	entry_settings.add_theme_font_size_override("font_size", 19)
	entry_settings.pressed.connect(_open_settings.bind(false))
	_entry_overlay.add_child(entry_settings)

	var entry_quit := Button.new()
	entry_quit.name = "EntryQuit"
	entry_quit.position = Vector2(470.0, 558.0)
	entry_quit.size = Vector2(340.0, 42.0)
	entry_quit.text = "退出游戏"
	entry_quit.add_theme_font_size_override("font_size", 16)
	entry_quit.pressed.connect(_quit_game)
	_entry_overlay.add_child(entry_quit)

	var difficulty_data := [
		{"name": "简单", "description": "敌人生命与伤害降低，适合熟悉操作", "color": Color(0.36, 0.86, 0.58, 1.0)},
		{"name": "中等", "description": "标准挑战，推荐第一次游玩", "color": Color(0.35, 0.72, 0.98, 1.0)},
		{"name": "困难", "description": "敌人更耐打且攻击更致命", "color": Color(1.0, 0.42, 0.35, 1.0)},
	]
	for difficulty_index in range(difficulty_data.size()):
		var data: Dictionary = difficulty_data[difficulty_index]
		var button := Button.new()
		button.name = "Difficulty_%d" % difficulty_index
		button.position = Vector2(230.0 + float(difficulty_index) * 280.0, 390.0)
		button.size = Vector2(260.0, 138.0)
		button.add_theme_font_size_override("font_size", 19)
		button.add_theme_color_override("font_color", data["color"])
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.text = "%s\n\n%s" % [data["name"], data["description"]]
		button.pressed.connect(_start_game_with_difficulty.bind(difficulty_index))
		button.visible = false
		_entry_overlay.add_child(button)
		_difficulty_buttons.append(button)

	_entry_overlay.visible = false


func _create_pause_ui() -> void:
	_pause_overlay = Control.new()
	_pause_overlay.name = "PauseMenu"
	_pause_overlay.position = Vector2.ZERO
	_pause_overlay.size = DISPLAY_SIZE
	_pause_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_pause_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	hud.add_child(_pause_overlay)

	var dimmer := ColorRect.new()
	dimmer.size = DISPLAY_SIZE
	dimmer.color = Color(0.01, 0.02, 0.04, 0.72)
	dimmer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pause_overlay.add_child(dimmer)

	var panel := ColorRect.new()
	panel.position = Vector2(425.0, 180.0)
	panel.size = Vector2(430.0, 340.0)
	panel.color = Color(0.045, 0.085, 0.12, 0.98)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pause_overlay.add_child(panel)

	var title := Label.new()
	title.position = Vector2(455.0, 215.0)
	title.size = Vector2(370.0, 52.0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.text = "已暂停"
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color(0.85, 0.95, 1.0, 1.0))
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pause_overlay.add_child(title)

	var resume_button := _create_menu_button("Resume", "继续游戏", Vector2(495.0, 285.0), Vector2(290.0, 54.0))
	resume_button.pressed.connect(_resume_game)
	_pause_overlay.add_child(resume_button)
	var settings_button := _create_menu_button("PauseSettings", "设置", Vector2(495.0, 352.0), Vector2(290.0, 48.0))
	settings_button.pressed.connect(_open_settings.bind(true))
	_pause_overlay.add_child(settings_button)
	var menu_button := _create_menu_button("ReturnToMenu", "返回主菜单", Vector2(495.0, 413.0), Vector2(290.0, 48.0))
	menu_button.pressed.connect(_return_to_main_menu)
	_pause_overlay.add_child(menu_button)
	_pause_overlay.visible = false


func _create_settings_ui() -> void:
	_settings_overlay = Control.new()
	_settings_overlay.name = "SettingsMenu"
	_settings_overlay.position = Vector2.ZERO
	_settings_overlay.size = DISPLAY_SIZE
	_settings_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_settings_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	hud.add_child(_settings_overlay)

	var dimmer := ColorRect.new()
	dimmer.size = DISPLAY_SIZE
	dimmer.color = Color(0.006, 0.014, 0.028, 0.88)
	dimmer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_settings_overlay.add_child(dimmer)
	var panel := Panel.new()
	panel.position = Vector2(70.0, 30.0)
	panel.size = Vector2(1140.0, 660.0)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.026, 0.061, 0.092, 0.98)
	panel_style.border_color = Color(0.26, 0.64, 0.72, 0.72)
	panel_style.set_border_width_all(2)
	panel_style.corner_radius_top_left = 14
	panel_style.corner_radius_top_right = 14
	panel_style.corner_radius_bottom_left = 14
	panel_style.corner_radius_bottom_right = 14
	panel_style.shadow_color = Color(0.0, 0.0, 0.0, 0.52)
	panel_style.shadow_size = 18
	panel.add_theme_stylebox_override("panel", panel_style)
	_settings_overlay.add_child(panel)

	var title := Label.new()
	title.position = Vector2(100.0, 50.0)
	title.size = Vector2(1080.0, 46.0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.text = "设置与操作"
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(0.85, 0.95, 1.0, 1.0))
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_settings_overlay.add_child(title)

	var volume_label := Label.new()
	volume_label.position = Vector2(125.0, 123.0)
	volume_label.size = Vector2(180.0, 30.0)
	volume_label.text = "主音量"
	volume_label.add_theme_font_size_override("font_size", 18)
	volume_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_settings_overlay.add_child(volume_label)
	_settings_volume_slider = HSlider.new()
	_settings_volume_slider.name = "MasterVolume"
	_settings_volume_slider.position = Vector2(245.0, 127.0)
	_settings_volume_slider.size = Vector2(390.0, 24.0)
	_settings_volume_slider.min_value = 0.0
	_settings_volume_slider.max_value = 1.0
	_settings_volume_slider.step = 0.05
	_settings_volume_slider.value_changed.connect(_on_master_volume_changed)
	_settings_overlay.add_child(_settings_volume_slider)
	_settings_damage_numbers_toggle = CheckButton.new()
	_settings_damage_numbers_toggle.name = "DamageNumbersToggle"
	_settings_damage_numbers_toggle.position = Vector2(680.0, 118.0)
	_settings_damage_numbers_toggle.size = Vector2(210.0, 34.0)
	_settings_damage_numbers_toggle.text = "显示伤害数字"
	_settings_damage_numbers_toggle.add_theme_font_size_override("font_size", 17)
	_settings_damage_numbers_toggle.toggled.connect(_on_damage_numbers_toggled)
	_settings_overlay.add_child(_settings_damage_numbers_toggle)

	var hint := Label.new()
	hint.position = Vector2(125.0, 180.0)
	hint.size = Vector2(590.0, 32.0)
	hint.text = "点击键位按钮后按下新的按键；同一个键不会同时分配给多个动作。"
	hint.add_theme_font_size_override("font_size", 15)
	hint.add_theme_color_override("font_color", Color(0.58, 0.74, 0.84, 1.0))
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_settings_overlay.add_child(hint)

	var guide_panel := Panel.new()
	guide_panel.name = "OperationGuidePanel"
	guide_panel.position = Vector2(755.0, 174.0)
	guide_panel.size = Vector2(405.0, 376.0)
	guide_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var guide_style := StyleBoxFlat.new()
	guide_style.bg_color = Color(0.016, 0.038, 0.060, 0.94)
	guide_style.border_color = Color(0.74, 0.52, 0.22, 0.70)
	guide_style.set_border_width_all(1)
	guide_style.corner_radius_top_left = 10
	guide_style.corner_radius_top_right = 10
	guide_style.corner_radius_bottom_left = 10
	guide_style.corner_radius_bottom_right = 10
	guide_panel.add_theme_stylebox_override("panel", guide_style)
	_settings_overlay.add_child(guide_panel)
	_settings_guide_label = RichTextLabel.new()
	_settings_guide_label.name = "OperationGuide"
	_settings_guide_label.position = Vector2(782.0, 196.0)
	_settings_guide_label.size = Vector2(351.0, 334.0)
	_settings_guide_label.bbcode_enabled = true
	_settings_guide_label.fit_content = false
	_settings_guide_label.scroll_active = false
	_settings_guide_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_settings_guide_label.add_theme_font_size_override("normal_font_size", 15)
	_settings_guide_label.add_theme_color_override("default_color", Color(0.74, 0.86, 0.91, 1.0))
	_settings_overlay.add_child(_settings_guide_label)

	var actions := [
		[&"move_left", "向左"], [ &"move_right", "向右"], [ &"jump", "跳跃"], [ &"attack", "攻击"], [ &"aim_up", "上劈方向"], [ &"aim_down", "下劈方向"],
		[&"dash", "闪避冲刺"], [ &"skill", "主动技能"], [ &"interact", "互动"], [ &"cycle_weapon", "切换武器"], [ &"restart", "重开本局"], [ &"pause", "暂停菜单"],
	]
	for action_index in range(actions.size()):
		var row: int = action_index % 6
		var column: int = int(action_index / 6)
		var position := Vector2(125.0 + float(column) * 310.0, 220.0 + float(row) * 50.0)
		var action_name: StringName = actions[action_index][0]
		var action_label := Label.new()
		action_label.position = position
		action_label.size = Vector2(112.0, 40.0)
		action_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		action_label.text = String(actions[action_index][1])
		action_label.add_theme_font_size_override("font_size", 17)
		action_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_settings_overlay.add_child(action_label)
		var key_button := Button.new()
		key_button.name = "Bind_%s" % action_name
		key_button.position = position + Vector2(118.0, 0.0)
		key_button.size = Vector2(165.0, 40.0)
		key_button.add_theme_font_size_override("font_size", 16)
		key_button.pressed.connect(_begin_rebind.bind(action_name))
		_settings_overlay.add_child(key_button)
		_settings_key_buttons[action_name] = key_button

	var reset_button := _create_menu_button("ResetBindings", "恢复默认键位", Vector2(315.0, 608.0), Vector2(250.0, 48.0))
	reset_button.pressed.connect(_reset_bindings)
	_settings_overlay.add_child(reset_button)
	var back_button := _create_menu_button("CloseSettings", "返回", Vector2(715.0, 608.0), Vector2(250.0, 48.0))
	back_button.pressed.connect(_close_settings)
	_settings_overlay.add_child(back_button)
	_refresh_settings_operation_guide()
	_settings_overlay.visible = false


func _create_menu_button(node_name: String, button_text: String, button_position: Vector2, button_size: Vector2) -> Button:
	var button := Button.new()
	button.name = node_name
	button.position = button_position
	button.size = button_size
	button.text = button_text
	button.add_theme_font_size_override("font_size", 18)
	return button


func _pause_game() -> void:
	if _entry_flow_active or _run_complete:
		return
	_is_game_paused = true
	_pause_overlay.visible = true
	get_tree().paused = true


func _resume_game() -> void:
	get_tree().paused = false
	_is_game_paused = false
	_pause_overlay.visible = false
	_settings_overlay.visible = false
	_awaiting_rebind_action = &""


func _return_to_main_menu() -> void:
	_resume_game()
	_clear_chest()
	_clear_projectiles()
	_clear_enemies()
	_clear_platform_colliders()
	_entry_flow_active = true
	player.set_input_enabled(false)
	_show_start_screen()


func _open_settings(from_pause: bool) -> void:
	_settings_from_pause = from_pause
	_awaiting_rebind_action = &""
	_settings_volume_slider.value = float(_settings.call(&"get_master_volume"))
	_settings_damage_numbers_toggle.button_pressed = bool(_settings.call(&"get_damage_numbers_enabled"))
	_refresh_settings_key_buttons()
	_settings_overlay.visible = true


func _close_settings() -> void:
	_awaiting_rebind_action = &""
	_settings_overlay.visible = false
	if not _settings_from_pause:
		_show_start_screen()


func _begin_rebind(action_name: StringName) -> void:
	_awaiting_rebind_action = action_name
	_refresh_settings_key_buttons()


func _refresh_settings_key_buttons() -> void:
	for action_value in _settings_key_buttons:
		var action_name: StringName = StringName(String(action_value))
		var button: Button = _settings_key_buttons[action_value] as Button
		if action_name == _awaiting_rebind_action:
			button.text = "按下新按键…"
		else:
			button.text = String(_settings.call(&"get_binding_name", action_name))
	_refresh_settings_operation_guide()


func _refresh_settings_operation_guide() -> void:
	if not is_instance_valid(_settings_guide_label) or _settings == null:
		return
	var left_key: String = String(_settings.call(&"get_binding_name", &"move_left"))
	var right_key: String = String(_settings.call(&"get_binding_name", &"move_right"))
	var jump_key: String = String(_settings.call(&"get_binding_name", &"jump"))
	var attack_key: String = String(_settings.call(&"get_binding_name", &"attack"))
	var up_key: String = String(_settings.call(&"get_binding_name", &"aim_up"))
	var down_key: String = String(_settings.call(&"get_binding_name", &"aim_down"))
	var dash_key: String = String(_settings.call(&"get_binding_name", &"dash"))
	var skill_key: String = String(_settings.call(&"get_binding_name", &"skill"))
	var interact_key: String = String(_settings.call(&"get_binding_name", &"interact"))
	var weapon_key: String = String(_settings.call(&"get_binding_name", &"cycle_weapon"))
	var restart_key: String = String(_settings.call(&"get_binding_name", &"restart"))
	var pause_key: String = String(_settings.call(&"get_binding_name", &"pause"))
	_settings_guide_label.text = (
		"[font_size=22][color=#f2c66d]操作说明[/color][/font_size]\n"
		+ "[color=#68d8e8]移动与探索[/color]\n"
		+ "[color=#ffffff]%s / %s[/color]  左右移动\n" % [left_key, right_key]
		+ "[color=#ffffff]%s[/color]  跳跃；空中可再次跳跃\n" % jump_key
		+ "[color=#ffffff]%s[/color]  开宝箱、互动、离开商店\n\n" % interact_key
		+ "[color=#68d8e8]战斗动作[/color]\n"
		+ "[color=#ffffff]%s[/color]  普通攻击\n" % attack_key
		+ "[color=#ffffff]%s + %s[/color]  上劈    [color=#ffffff]%s + %s[/color]  下劈\n"
		% [up_key, attack_key, down_key, attack_key]
		+ "[color=#ffffff]%s[/color]  闪避冲刺（短暂无敌）\n" % dash_key
		+ "[color=#ffffff]%s[/color]  主动技能    [color=#ffffff]%s[/color]  切换武器\n\n"
		% [skill_key, weapon_key]
		+ "[color=#68d8e8]系统[/color]\n"
		+ "[color=#ffffff]1 / 2 / 3[/color]  选择强化或购买商品\n"
		+ "[color=#ffffff]%s[/color]  暂停与设置    [color=#ffffff]%s[/color]  重新开局"
		% [pause_key, restart_key]
	)


func _on_master_volume_changed(value: float) -> void:
	_settings.call(&"set_master_volume", value)


func _on_damage_numbers_toggled(enabled: bool) -> void:
	_settings.call(&"set_damage_numbers_enabled", enabled)


func _reset_bindings() -> void:
	_settings.call(&"reset_bindings")
	_awaiting_rebind_action = &""
	_refresh_settings_key_buttons()


func _quit_game() -> void:
	get_tree().quit()


func _show_start_screen() -> void:
	_entry_flow_active = true
	player.set_input_enabled(false)
	_entry_overlay.visible = true
	_entry_title.text = "月蚀回廊"
	_entry_subtitle.text = "LUNAR ECLIPSE CORRIDOR  ·  %s" % BUILD_LABEL
	_start_button.text = "开始冒险"
	_start_button.visible = true
	var entry_settings: Button = _entry_overlay.get_node("EntrySettings") as Button
	var entry_quit: Button = _entry_overlay.get_node("EntryQuit") as Button
	entry_settings.visible = true
	entry_quit.visible = true
	for button in _difficulty_buttons:
		button.visible = false


func _show_difficulty_selection() -> void:
	_entry_title.text = "选择难度"
	_entry_subtitle.text = "难度会随 20 个房间累计提升敌人的生命、伤害、速度与进攻欲望。"
	_start_button.visible = false
	(_entry_overlay.get_node("EntrySettings") as Button).visible = false
	(_entry_overlay.get_node("EntryQuit") as Button).visible = false
	for button in _difficulty_buttons:
		button.visible = true


func _start_game_with_difficulty(difficulty: int) -> void:
	_selected_difficulty = clampi(difficulty, Difficulty.EASY, Difficulty.HARD)
	_lives_remaining = MAX_RUN_LIVES
	_entry_flow_active = false
	_entry_overlay.visible = false
	_start_new_run()


func _get_difficulty_health_multiplier() -> float:
	var room_progress: float = float(maxi(_current_room_index, 0))
	match _selected_difficulty:
		Difficulty.EASY:
			return 0.65 + room_progress * 0.032
		Difficulty.HARD:
			return 1.35 + room_progress * 0.16
		_:
			return 1.0 + room_progress * 0.115


func _get_difficulty_damage_multiplier() -> float:
	var room_progress: float = float(maxi(_current_room_index, 0))
	match _selected_difficulty:
		Difficulty.EASY:
			return 0.55 + room_progress * 0.020
		Difficulty.HARD:
			return 1.25 + room_progress * 0.115
		_:
			return 1.0 + room_progress * 0.08


func _get_difficulty_speed_multiplier() -> float:
	var room_progress: float = float(maxi(_current_room_index, 0))
	match _selected_difficulty:
		Difficulty.EASY:
			return 0.78 + room_progress * 0.010
		Difficulty.HARD:
			return 1.08 + room_progress * 0.03
		_:
			return 1.0 + room_progress * 0.023


func _get_difficulty_aggression_multiplier() -> float:
	var room_progress: float = float(maxi(_current_room_index, 0))
	match _selected_difficulty:
		Difficulty.EASY:
			return 0.55 + room_progress * 0.020
		Difficulty.HARD:
			return 1.12 + room_progress * 0.05
		_:
			return 1.0 + room_progress * 0.04


func get_selected_difficulty_name() -> String:
	match _selected_difficulty:
		Difficulty.EASY:
			return "简单"
		Difficulty.HARD:
			return "困难"
		_:
			return "中等"


func _start_new_run() -> void:
	_run_generation += 1
	_run_number += 1
	_run_active = false
	_choosing_upgrade = false
	_run_complete = false
	_death_restart_pending = false
	_last_upgrade_name = ""
	_current_encounter = EncounterType.NORMAL
	_awaiting_chest = false
	_shopping = false
	_gold = 10
	_run_shards = 0
	_hide_upgrade_overlay()
	_clear_chest()
	_clear_projectiles()
	_clear_enemies()
	_clear_platform_colliders()
	player.set_input_enabled(false)
	player.configure_weapon(_progression.get_selected_weapon())
	player.reset_run_progression()
	_boss_health_background.visible = false
	_room_sequence = ROOM_CATALOG_SCRIPT.build_room_sequence(
		_room_pool.size(),
		ROOMS_PER_RUN,
		_rng
	)
	_current_room_index = -1
	_current_room_data = {}
	_update_economy_hud()
	_advance_to_next_room()


func _advance_to_next_room() -> void:
	_current_room_index += 1
	if _current_room_index >= _room_sequence.size():
		_complete_run()
		return
	_load_room(_room_sequence[_current_room_index])


func _load_room(pool_index: int) -> void:
	if pool_index < 0 or pool_index >= _room_pool.size():
		push_error("Invalid room pool index: %d" % pool_index)
		return

	_run_active = false
	_choosing_upgrade = false
	_awaiting_chest = false
	_shopping = false
	_clear_chest()
	_clear_projectiles()
	_clear_enemies()
	_clear_platform_colliders()
	_current_room_data = ROOM_CATALOG_SCRIPT.build_room_variant(
		_room_pool[pool_index],
		_rng,
		_current_room_index + 1
	)
	_current_encounter = _get_encounter_for_room(_current_room_index)
	platform_rects.clear()
	var room_platforms: Array = _current_room_data.get("platforms", []) as Array
	for platform_value in room_platforms:
		var platform_rect: Rect2 = platform_value
		platform_rects.append(platform_rect)
	_create_platform_colliders()
	if not platform_rects.is_empty():
		player.set_base_ground_surface_y(platform_rects[0].position.y)

	var recovery: int = 0 if _current_room_index == 0 else ROOM_ENTRY_RECOVERY
	player.enter_room(ROOM_PLAYER_SPAWN, recovery)
	_spawn_room_enemies()
	var room_title: String = _current_room_data.get("title", "未知房间")
	if _current_encounter == EncounterType.SHOP:
		player.set_input_enabled(false)
		_run_active = false
		_show_shop()
	else:
		player.set_input_enabled(true)
		_run_active = true
		if _last_upgrade_name.is_empty():
			_status_label.text = "进入 %s·%s——清除全部敌人" % [
				room_title,
				_get_encounter_name(_current_encounter),
			]
		else:
			_status_label.text = "已获得「%s」；进入 %s" % [_last_upgrade_name, room_title]
			_last_upgrade_name = ""
	_update_controls()
	_update_room_label()
	queue_redraw()


func _create_platform_colliders() -> void:
	for platform_index in range(platform_rects.size()):
		_create_static_rect(
			platform_rects[platform_index],
			"Platform_%02d" % platform_index,
			platform_index > 0
		)
	_create_static_rect(Rect2(-64.0, 0.0, 64.0, WORLD_SIZE.y), "BoundaryLeft")
	_create_static_rect(Rect2(WORLD_SIZE.x, 0.0, 64.0, WORLD_SIZE.y), "BoundaryRight")


func _create_static_rect(rect: Rect2, body_name: String, is_drop_through: bool = false) -> void:
	var body := StaticBody2D.new()
	body.name = body_name
	body.collision_layer = 1
	body.collision_mask = 2
	body.position = rect.get_center()

	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	collision.shape = shape
	collision.one_way_collision = is_drop_through
	collision.one_way_collision_margin = 8.0 if is_drop_through else 0.0
	body.add_child(collision)
	if is_drop_through:
		body.add_to_group(&"drop_through_platform")
	add_child(body)
	_platform_bodies.append(body)


func _clear_platform_colliders() -> void:
	for body in _platform_bodies:
		if is_instance_valid(body):
			body.queue_free()
	_platform_bodies.clear()
	platform_rects.clear()


func _spawn_room_enemies() -> void:
	if _current_encounter == EncounterType.SHOP:
		return
	if _current_encounter == EncounterType.BOSS:
		_spawn_boss()
		return
	var base_spawn_values: Array = _current_room_data.get("enemies", []) as Array
	var spawn_values: Array[Dictionary] = []
	for spawn_value: Variant in base_spawn_values:
		spawn_values.append((spawn_value as Dictionary).duplicate(true))
	var reinforcement_count: int = _get_room_reinforcement_count(_current_room_index)
	for reinforcement_index in range(reinforcement_count):
		if platform_rects.is_empty():
			break
		var random_surface: int = _rng.randi_range(0, platform_rects.size() - 1)
		spawn_values.append({
			"surface": random_surface,
			"ratio": _rng.randf_range(0.22, 0.78),
			"role": (
				ENEMY_ROLE_RANGED
				if posmod(reinforcement_index + _current_room_index, 3) == 1
				else ENEMY_ROLE_MELEE
			),
		})
	var elite_count: int = 0
	if _current_encounter == EncounterType.ELITE:
		elite_count = 3 if _current_room_index >= FINAL_CHAPTER_START else 2
	for spawn_index in range(spawn_values.size()):
		var descriptor: Dictionary = spawn_values[spawn_index]
		var surface_index: int = int(descriptor.get("surface", 0))
		if surface_index < 0 or surface_index >= platform_rects.size():
			continue
		var surface: Rect2 = platform_rects[surface_index]
		var minimum_x: float = surface.position.x + 42.0
		var maximum_x: float = surface.end.x - 42.0
		if maximum_x <= minimum_x:
			continue
		var horizontal_ratio: float = float(descriptor.get("ratio", 0.5))
		var role: int = int(descriptor.get("role", ENEMY_ROLE_MELEE))
		var rank: int = ENEMY_RANK_NORMAL
		if spawn_index < elite_count:
			rank = ENEMY_RANK_ELITE
		var family: int = _get_enemy_family_for_spawn(_current_room_index, spawn_index)
		var vertical_offset: float = 28.0 if rank == ENEMY_RANK_ELITE else 22.0
		_spawn_enemy(
			Vector2(lerpf(minimum_x, maximum_x, horizontal_ratio), surface.position.y - vertical_offset),
			minimum_x,
			maximum_x,
			role,
			rank,
			family
		)


func _spawn_enemy(
	spawn_position: Vector2,
	patrol_left: float,
	patrol_right: float,
	role: int,
	rank: int = ENEMY_RANK_NORMAL,
	family: int = ENEMY_FAMILY_SLIME
) -> void:
	var enemy: RogueEnemy = ENEMY_SCRIPT.new() as RogueEnemy
	var variant: int = 1
	if role != ENEMY_ROLE_RANGED:
		variant = 0 if _rng.randi_range(0, 1) == 0 else 2
	if family == ENEMY_FAMILY_GOBLIN:
		if rank == ENEMY_RANK_BOSS:
			enemy.name = "RedFangWarChief"
		elif rank == ENEMY_RANK_ELITE:
			enemy.name = "EliteRedFangBrute_%02d" % (_enemies.size() + 1)
		else:
			enemy.name = (
				"RedFangArcher_%02d"
				if role == ENEMY_ROLE_RANGED
				else "RedFangClubSoldier_%02d"
			) % (_enemies.size() + 1)
	elif rank == ENEMY_RANK_BOSS:
		enemy.name = "RedCrystalSlimeKing"
	elif rank == ENEMY_RANK_ELITE:
		enemy.name = "EliteRedCrystalSlime_%02d" % (_enemies.size() + 1)
	else:
		enemy.name = (
			"RangedRedCrystalSlime_%02d"
			if role == ENEMY_ROLE_RANGED
			else "MeleeRedCrystalSlime_%02d"
		) % (_enemies.size() + 1)
	enemy.position = spawn_position
	enemy.setup(
		variant,
		_rng.randf_range(0.0, TAU),
		patrol_left,
		patrol_right,
		role,
		rank,
		_get_difficulty_health_multiplier(),
		_get_difficulty_damage_multiplier(),
		family,
		_get_difficulty_speed_multiplier(),
		_get_difficulty_aggression_multiplier()
	)
	enemy.set_target(player)
	enemy.defeated.connect(_on_enemy_defeated.bind(enemy))
	enemy.projectile_requested.connect(_on_enemy_projectile_requested)
	enemy.sound_requested.connect(_on_enemy_sound_requested)
	if rank == ENEMY_RANK_BOSS:
		enemy.health_changed.connect(_on_boss_health_changed)
		_boss_enemy = enemy
	add_child(enemy)
	_enemies.append(enemy)
	if rank == ENEMY_RANK_BOSS:
		_boss_health_background.visible = true
		_on_boss_health_changed(enemy.get_current_health(), enemy.get_max_health())


func _spawn_boss() -> void:
	if platform_rects.is_empty():
		return
	var boss_surface: Rect2 = platform_rects[0]
	for surface in platform_rects:
		if surface.size.x > boss_surface.size.x:
			boss_surface = surface
	var minimum_x: float = maxf(boss_surface.position.x + 85.0, 190.0)
	var maximum_x: float = minf(boss_surface.end.x - 85.0, WORLD_SIZE.x - 105.0)
	var spawn_x: float = lerpf(minimum_x, maximum_x, 0.68)
	var family: int = _get_primary_enemy_family_for_room(_current_room_index)
	_spawn_enemy(
		Vector2(spawn_x, boss_surface.position.y - 52.0),
		minimum_x,
		maximum_x,
		ENEMY_ROLE_MELEE,
		ENEMY_RANK_BOSS,
		family
	)
	if _current_room_index < MIXED_CHAPTER_START:
		return
	var escort_family: int = (
		ENEMY_FAMILY_GOBLIN if family == ENEMY_FAMILY_SLIME else ENEMY_FAMILY_SLIME
	)
	var escort_roles: Array[int] = [ENEMY_ROLE_MELEE, ENEMY_ROLE_RANGED]
	var escort_ratios: Array[float] = [0.28, 0.86]
	for escort_index in range(escort_roles.size()):
		var escort_rank: int = (
			ENEMY_RANK_ELITE
			if _current_room_index >= FINAL_CHAPTER_START or escort_index == 0
			else ENEMY_RANK_NORMAL
		)
		var escort_x: float = lerpf(
			minimum_x,
			maximum_x,
			escort_ratios[escort_index]
		)
		_spawn_enemy(
			Vector2(escort_x, boss_surface.position.y - 28.0),
			minimum_x,
			maximum_x,
			escort_roles[escort_index],
			escort_rank,
			escort_family
		)


func _clear_enemies() -> void:
	for enemy in _enemies:
		if is_instance_valid(enemy):
			enemy.queue_free()
	_enemies.clear()
	_boss_enemy = null
	if is_instance_valid(_boss_health_background):
		_boss_health_background.visible = false


func _on_player_attack_hit(origin: Vector2, facing: float) -> void:
	if not _run_active:
		return
	var damage_amount: int = player.get_attack_damage()
	for enemy: RogueEnemy in _enemies.duplicate():
		if not is_instance_valid(enemy):
			_enemies.erase(enemy)
			continue
		if enemy.receive_player_attack(
			origin,
			facing,
			damage_amount,
			player.get_attack_reach(),
			player.get_attack_type()
		):
			player.confirm_attack_connected()
			_spawn_hit_vfx(enemy.global_position, facing, enemy, 1.0, damage_amount)


func _on_player_skill_hit(
	origin: Vector2,
	facing: float,
	damage: int,
	reach_scale: float
) -> void:
	if not _run_active:
		return
	for enemy: RogueEnemy in _enemies.duplicate():
		if not is_instance_valid(enemy):
			_enemies.erase(enemy)
			continue
		if enemy.receive_player_attack(origin, facing, damage, reach_scale):
			_spawn_hit_vfx(enemy.global_position, facing, enemy, 1.20, damage)


func _on_enemy_defeated(enemy: RogueEnemy) -> void:
	if not _enemies.has(enemy):
		return
	if is_instance_valid(_soundscape):
		_soundscape.play_enemy_defeat(enemy.is_boss())
	_spawn_defeat_vfx(enemy.global_position, enemy)
	_gold += enemy.get_gold_reward()
	_run_shards += enemy.get_essence_reward()
	if enemy.is_boss():
		_boss_health_background.visible = false
		_boss_enemy = null
	_enemies.erase(enemy)
	_update_economy_hud()
	_update_controls()
	if _enemies.is_empty():
		call_deferred(&"_on_room_cleared")


func _spawn_hit_vfx(
	hit_position: Vector2,
	facing: float,
	enemy: RogueEnemy,
	scale_multiplier: float = 1.0,
	damage_amount: int = 1
) -> void:
	var rank_scale: float = 1.0
	if enemy.is_boss():
		rank_scale = 1.50
	elif enemy.is_elite():
		rank_scale = 1.22
	var effect: Node2D = COMBAT_VFX_SCRIPT.new() as Node2D
	add_child(effect)
	effect.global_position = hit_position + Vector2(0.0, -12.0)
	effect.z_index = 8
	effect.call(&"play_hit", facing, scale_multiplier * rank_scale)
	if is_instance_valid(_soundscape):
		_soundscape.play_impact()
	if bool(_settings.call(&"get_damage_numbers_enabled")):
		_spawn_damage_number(hit_position, damage_amount, scale_multiplier, rank_scale)
	_trigger_camera_shake(8.0 * rank_scale)


func _spawn_damage_number(
	hit_position: Vector2,
	damage_amount: int,
	scale_multiplier: float,
	rank_scale: float
) -> void:
	var number: Node2D = DAMAGE_NUMBER_SCRIPT.new() as Node2D
	var is_skill_hit: bool = scale_multiplier > 1.05
	var accent := Color("#dffcff") if not is_skill_hit else Color("#ffd86c")
	number.call(&"setup", damage_amount, accent, hit_position.x * 0.017 + rank_scale)
	add_child(number)
	number.global_position = hit_position + Vector2(0.0, -32.0)


func _spawn_defeat_vfx(defeat_position: Vector2, enemy: RogueEnemy) -> void:
	var scale_multiplier: float = 1.0
	var accent := Color("#ff364c")
	if enemy.is_boss():
		scale_multiplier = 1.85
		accent = Color("#ff694f")
	elif enemy.is_elite():
		scale_multiplier = 1.32
		accent = Color("#d896ff")
	elif enemy.is_ranged_enemy():
		accent = Color("#69d9ff")
	var effect: Node2D = COMBAT_VFX_SCRIPT.new() as Node2D
	add_child(effect)
	effect.global_position = defeat_position + Vector2(0.0, -14.0)
	effect.z_index = 8
	effect.call(&"play_defeat", accent, scale_multiplier)
	_trigger_camera_shake(11.0 * scale_multiplier, 0.13)


func _on_room_cleared() -> void:
	if not _run_active or _choosing_upgrade or _run_complete or not _enemies.is_empty():
		return
	_run_active = false
	_clear_projectiles()
	if _current_encounter == EncounterType.TREASURE and not _awaiting_chest:
		_spawn_reward_chest()
		return
	player.set_input_enabled(false)
	if _current_room_index >= _room_sequence.size() - 1:
		_complete_run()
	else:
		_show_upgrade_choice()


func _show_upgrade_choice() -> void:
	_shopping = false
	_upgrade_choices = _pick_upgrade_choices()
	if _upgrade_choices.size() < 3:
		push_error("Upgrade pool did not provide three choices")
		return
	_choosing_upgrade = true
	_upgrade_overlay.visible = true
	_upgrade_title.text = "房间已清理——选择一项强化"
	_upgrade_hint.text = "点击卡片，或按数字键 1 / 2 / 3"
	for choice_index in range(_upgrade_buttons.size()):
		var button: Button = _upgrade_buttons[choice_index]
		var choice: Dictionary = _upgrade_choices[choice_index]
		button.visible = true
		button.disabled = false
		button.text = "[%d]  %s\n\n%s" % [
			choice_index + 1,
			String(choice.get("name", "强化")),
			String(choice.get("description", "")),
		]
	_update_controls()


func _show_shop() -> void:
	_shopping = true
	_choosing_upgrade = true
	_upgrade_choices.clear()
	var base_choices: Array[Dictionary] = _pick_upgrade_choices()
	for choice_index in range(base_choices.size()):
		var shop_offer: Dictionary = base_choices[choice_index].duplicate(true)
		shop_offer["cost"] = 16 + choice_index * 4
		_upgrade_choices.append(shop_offer)
	_upgrade_overlay.visible = true
	_upgrade_title.text = "星尘旅商——购买一项强化"
	_upgrade_hint.text = "金币不足时按 E 离开；数字键 1 / 2 / 3 购买"
	for choice_index in range(_upgrade_buttons.size()):
		var button: Button = _upgrade_buttons[choice_index]
		var choice: Dictionary = _upgrade_choices[choice_index]
		var cost: int = int(choice.get("cost", 0))
		button.visible = true
		button.disabled = _gold < cost
		button.text = "[%d]  %s\n\n%s\n\n%d 金币" % [
			choice_index + 1,
			String(choice.get("name", "商品")),
			String(choice.get("description", "")),
			cost,
		]
	_status_label.text = "旅商已抵达——当前拥有 %d 金币" % _gold
	_update_controls()


func _pick_upgrade_choices() -> Array[Dictionary]:
	var upgrade_pool: Array[Dictionary] = _create_upgrade_pool()
	var available_indices: Array[int] = []
	for upgrade_index in range(upgrade_pool.size()):
		available_indices.append(upgrade_index)
	for index in range(available_indices.size() - 1, 0, -1):
		var swap_index: int = _rng.randi_range(0, index)
		var held_index: int = available_indices[index]
		available_indices[index] = available_indices[swap_index]
		available_indices[swap_index] = held_index

	var choices: Array[Dictionary] = []
	for choice_index in range(mini(3, available_indices.size())):
		choices.append(upgrade_pool[available_indices[choice_index]])
	return choices


func _create_upgrade_pool() -> Array[Dictionary]:
	return [
		{
			"id": &"tempered_edge",
			"name": "锋刃磨砺",
			"description": "攻击伤害 +8",
		},
		{
			"id": &"vitality_rune",
			"name": "生命铸纹",
			"description": "最大生命 +20，并恢复 20",
		},
		{
			"id": &"swift_step",
			"name": "迅捷步法",
			"description": "移动速度 +32",
		},
		{
			"id": &"dash_core",
			"name": "冲刺核心",
			"description": "冲刺速度 +90",
		},
		{
			"id": &"battle_rhythm",
			"name": "战斗节奏",
			"description": "攻击冷却缩短 12%",
		},
	]


func _on_upgrade_button_pressed(choice_index: int) -> void:
	choose_upgrade(choice_index)


func choose_upgrade(choice_index: int) -> bool:
	if not _choosing_upgrade or choice_index < 0 or choice_index >= _upgrade_choices.size():
		return false
	var choice: Dictionary = _upgrade_choices[choice_index]
	if _shopping:
		var cost: int = int(choice.get("cost", 0))
		if _gold < cost:
			_status_label.text = "金币不足：需要 %d，当前 %d" % [cost, _gold]
			return false
		_gold -= cost
	var upgrade_id: StringName = choice.get("id", &"")
	if not player.apply_run_upgrade(upgrade_id):
		return false
	_last_upgrade_name = String(choice.get("name", "强化"))
	_choosing_upgrade = false
	_shopping = false
	_upgrade_choices.clear()
	_hide_upgrade_overlay()
	_update_economy_hud()
	_advance_to_next_room()
	return true


func _leave_shop() -> void:
	if not _shopping:
		return
	_last_upgrade_name = "未购物"
	_shopping = false
	_choosing_upgrade = false
	_upgrade_choices.clear()
	_hide_upgrade_overlay()
	_advance_to_next_room()


func _complete_run() -> void:
	if _run_complete:
		return
	_run_active = false
	_choosing_upgrade = false
	_run_complete = true
	_clear_projectiles()
	player.set_input_enabled(false)
	_upgrade_overlay.visible = true
	_upgrade_title.text = "本局完成"
	_upgrade_hint.text = "已通过 %d 个房间。按 R 开启随机新一局" % ROOMS_PER_RUN
	for button in _upgrade_buttons:
		button.visible = false
	var unlocked_names: String = _bank_run_progress(true)
	_status_label.text = "胜利——首领已击败，本局星屑已结算%s" % unlocked_names
	_update_economy_hud()
	_update_controls()
	_update_room_label()


func _hide_upgrade_overlay() -> void:
	if is_instance_valid(_upgrade_overlay):
		_upgrade_overlay.visible = false
	for button in _upgrade_buttons:
		button.disabled = true


func _spawn_reward_chest() -> void:
	_clear_chest()
	if platform_rects.is_empty():
		_show_upgrade_choice()
		return
	var chest_surface: Rect2 = platform_rects[0]
	for surface in platform_rects:
		if surface.position.x <= 640.0 and surface.end.x >= 640.0:
			chest_surface = surface
			break
	var chest_x: float = clampf(640.0, chest_surface.position.x + 42.0, chest_surface.end.x - 42.0)
	_chest = CHEST_SCRIPT.new() as RewardChest
	_chest.name = "RewardChest"
	_chest.position = Vector2(chest_x, chest_surface.position.y - 27.0)
	_chest.setup(
		24,
		24,
		String(_settings.call(&"get_binding_name", &"interact"))
	)
	_chest.opened.connect(_on_chest_opened)
	add_child(_chest)
	_awaiting_chest = true
	player.set_input_enabled(true)
	_status_label.text = "宝藏已出现——跟随宝箱上方提示"
	_update_controls()


func _open_current_chest() -> bool:
	if not _awaiting_chest or not is_instance_valid(_chest):
		return false
	return _chest.try_open(player.global_position)


func open_current_chest_for_test() -> bool:
	if not _awaiting_chest or not is_instance_valid(_chest):
		return false
	return _chest.force_open()


func _on_chest_opened(gold_reward: int, heal_reward: int) -> void:
	if not _awaiting_chest:
		return
	_awaiting_chest = false
	_gold += gold_reward
	var restored_health: int = player.heal(heal_reward)
	player.set_input_enabled(false)
	_status_label.text = "宝箱：金币 +%d，生命恢复 %d" % [gold_reward, restored_health]
	_update_economy_hud()
	call_deferred(&"_show_upgrade_choice")


func _clear_chest() -> void:
	if is_instance_valid(_chest):
		_chest.queue_free()
	_chest = null
	_awaiting_chest = false


func _on_enemy_projectile_requested(
	origin: Vector2,
	projectile_velocity: Vector2,
	damage: int,
	projectile_style: int
) -> void:
	if not _run_active:
		return
	var projectile: Area2D = ENEMY_PROJECTILE_SCRIPT.new() as Area2D
	add_child(projectile)
	projectile.global_position = origin
	projectile.call(&"setup", projectile_velocity, damage, player, projectile_style)
	projectile.connect(&"removed", _on_projectile_removed)
	_projectiles.append(projectile)


func _on_projectile_removed(projectile: Area2D) -> void:
	_projectiles.erase(projectile)


func _clear_projectiles() -> void:
	for projectile in _projectiles:
		if is_instance_valid(projectile):
			projectile.queue_free()
	_projectiles.clear()


func _on_player_health_changed(current_health: int, maximum_health: int) -> void:
	if not is_instance_valid(_health_label) or not is_instance_valid(_health_fill):
		return
	var health_ratio: float = clampf(
		float(current_health) / float(maxi(maximum_health, 1)),
		0.0,
		1.0
	)
	_health_fill.size.x = HEALTH_FILL_WIDTH * health_ratio
	_health_fill.color = (
		Color(0.90, 0.24, 0.22, 0.96)
		if health_ratio <= 0.30
		else Color(0.18, 0.82, 0.50, 0.96)
	)
	_health_label.text = "生命  %d / %d" % [current_health, maximum_health]


func _update_lives_hud() -> void:
	if not is_instance_valid(_lives_label):
		return
	var marks := ""
	for life_index in range(MAX_RUN_LIVES):
		marks += "●" if life_index < _lives_remaining else "○"
	_lives_label.text = "命数  %s   难度：%s" % [marks, get_selected_difficulty_name()]


func _on_boss_health_changed(current_health: int, maximum_health: int) -> void:
	if not is_instance_valid(_boss_health_background):
		return
	var health_ratio: float = clampf(
		float(current_health) / float(maxi(1, maximum_health)),
		0.0,
		1.0
	)
	_boss_health_fill.size.x = 492.0 * health_ratio
	var boss_name: String = "赤晶史莱姆王"
	if is_instance_valid(_boss_enemy) and _boss_enemy.get_enemy_family() == ENEMY_FAMILY_GOBLIN:
		boss_name = "赤牙战争酋长"
	_boss_health_label.text = "%s  %d / %d" % [boss_name, current_health, maximum_health]


func _on_player_died() -> void:
	if _death_restart_pending:
		return
	_run_active = false
	_choosing_upgrade = false
	_shopping = false
	_death_restart_pending = true
	_lives_remaining = maxi(0, _lives_remaining - 1)
	player.set_input_enabled(false)
	_clear_chest()
	_clear_projectiles()
	_hide_upgrade_overlay()
	var unlocked_names: String = _bank_run_progress(false)
	_status_label.text = "战败——本局星屑已结算%s，即将重新生成路线" % unlocked_names
	_update_economy_hud()
	_update_controls()
	_update_lives_hud()
	_status_label.text = "战败 — 剩余命数 %d / %d" % [_lives_remaining, MAX_RUN_LIVES]
	var expected_generation: int = _run_generation
	get_tree().create_timer(DEATH_RESTART_DELAY).timeout.connect(
		_finish_death_sequence.bind(expected_generation)
	)


func _restart_run_after_death(expected_generation: int) -> void:
	if not _death_restart_pending or expected_generation != _run_generation:
		return
	_start_new_run()


func _finish_death_sequence(expected_generation: int) -> void:
	if not _death_restart_pending or expected_generation != _run_generation:
		return
	if _lives_remaining > 0:
		_start_new_run()
		return
	_death_restart_pending = false
	_clear_chest()
	_clear_projectiles()
	_clear_enemies()
	_clear_platform_colliders()
	_entry_flow_active = true
	player.set_input_enabled(false)
	_entry_overlay.visible = true
	_show_difficulty_selection()
	_entry_title.text = "命数耗尽"
	_entry_subtitle.text = "本局已结束。选择难度后，将从三条命重新开始。"


func _update_controls() -> void:
	# Context prompts are shown where they are used (cards, overlays, and chest bubble).
	# The full control reference remains available in Settings without covering gameplay.
	title_label.visible = false
	controls_label.visible = false


func _update_room_label() -> void:
	if _current_room_data.is_empty():
		_room_label.text = ""
		return
	var room_title: String = _current_room_data.get("title", "未知房间")
	var chapter_name: String = _get_chapter_name(_current_room_index)
	if _run_complete:
		_room_label.text = "轮次完成  ·  RUN %02d\n月蚀回廊已净化" % _run_number
	else:
		_room_label.text = "房间 %02d / %02d  ·  %s\n%s  ·  %s" % [
			_current_room_index + 1,
			ROOMS_PER_RUN,
			_get_encounter_name(_current_encounter),
			chapter_name,
			room_title,
		]


func _update_economy_hud() -> void:
	if not is_instance_valid(_currency_label) or _progression == null:
		return
	_currency_label.text = "金币 %d    局外星屑 %d（本局待结算 %d）" % [
		_gold,
		_progression.get_meta_shards(),
		_run_shards,
	]


func _update_equipment_hud() -> void:
	if not is_instance_valid(_equipment_label) or _progression == null:
		return
	_equipment_label.text = "武器库  ·  当前：%s" % player.get_weapon_name()
	_update_weapon_slots()


func _update_weapon_slots() -> void:
	if _progression == null:
		return
	var weapon_ids: Array[StringName] = WeaponCatalog.all_weapon_ids()
	if _weapon_slot_panels.size() != weapon_ids.size() or _weapon_slot_labels.size() != weapon_ids.size():
		return
	var unlocked: Array[StringName] = _progression.get_unlocked_weapons()
	var active_weapon: StringName = player.get_weapon_id()
	var state_parts: Array[String] = [String(active_weapon)]
	for weapon_id in weapon_ids:
		state_parts.append("1" if unlocked.has(weapon_id) else "0")
	var state_key: String = "|".join(state_parts)
	if state_key == _weapon_hud_state_key:
		return
	_weapon_hud_state_key = state_key

	for weapon_index in range(weapon_ids.size()):
		var weapon_id: StringName = weapon_ids[weapon_index]
		var weapon_data: Dictionary = WeaponCatalog.get_weapon(weapon_id)
		var accent: Color = weapon_data.get("accent", Color("#78d9ef"))
		var is_unlocked: bool = unlocked.has(weapon_id)
		var is_active: bool = weapon_id == active_weapon
		var slot: Panel = _weapon_slot_panels[weapon_index]
		var slot_label: Label = _weapon_slot_labels[weapon_index]
		var slot_style := StyleBoxFlat.new()
		slot_style.bg_color = (
			Color(accent, 0.20)
			if is_active
			else Color(0.026, 0.054, 0.070, 0.98) if is_unlocked
			else Color(0.018, 0.027, 0.036, 0.96)
		)
		slot_style.border_color = (
			Color(accent, 0.96)
			if is_active
			else Color(0.37, 0.55, 0.62, 0.58) if is_unlocked
			else Color(0.22, 0.27, 0.31, 0.60)
		)
		slot_style.set_border_width_all(2 if is_active else 1)
		slot_style.corner_radius_top_left = 6
		slot_style.corner_radius_top_right = 6
		slot_style.corner_radius_bottom_left = 6
		slot_style.corner_radius_bottom_right = 6
		if is_active:
			slot_style.shadow_color = Color(accent, 0.35)
			slot_style.shadow_size = 5
		slot.add_theme_stylebox_override("panel", slot_style)

		var slot_state := "未解锁"
		if is_active:
			slot_state = "装备中"
		elif is_unlocked:
			slot_state = "可切换"
		var weapon_name: String = WeaponCatalog.get_weapon_name(weapon_id)
		slot_label.text = "%s\n%s" % [weapon_name, slot_state]
		slot_label.add_theme_color_override(
			"font_color",
			accent.lightened(0.18) if is_active else Color(0.67, 0.76, 0.79, 1.0) if is_unlocked else Color(0.34, 0.39, 0.42, 1.0)
		)
		slot.tooltip_text = "%s · %s" % [weapon_name, slot_state]


func _update_ability_hud() -> void:
	if not is_instance_valid(_attack_slot) or not is_instance_valid(_dash_slot) or not is_instance_valid(_skill_slot):
		return
	var weapon_data: Dictionary = WeaponCatalog.get_weapon(player.get_weapon_id())
	var weapon_accent: Color = weapon_data.get("accent", Color("#78d9ef"))
	_attack_slot.call(
		&"configure",
		0,
		"普通攻击",
		"J",
		"使用%s发动普通攻击，可配合 W / S 改变挥砍方向。" % player.get_weapon_name(),
		weapon_accent
	)
	_attack_slot.call(
		&"set_cooldown",
		player.get_attack_cooldown_remaining(),
		player.get_attack_cooldown_duration()
	)
	_dash_slot.call(
		&"configure",
		1,
		"闪避冲刺",
		"K",
		"向当前朝向高速闪避。冷却：2.0 秒。",
		Color("#65dcff")
	)
	_dash_slot.call(
		&"set_cooldown",
		player.get_dash_cooldown_remaining(),
		player.get_dash_cooldown_duration()
	)
	_skill_slot.call(
		&"configure",
		2,
		player.get_skill_name(),
		"L",
		"向前突进并释放多重月弧，造成高额范围伤害。",
		weapon_accent.lightened(0.12)
	)
	_skill_slot.call(
		&"set_cooldown",
		player.get_skill_cooldown_remaining(),
		player.get_skill_cooldown_duration()
	)


func _cycle_weapon() -> void:
	if _progression == null or _choosing_upgrade or player.is_dead():
		return
	var unlocked: Array[StringName] = _progression.get_unlocked_weapons()
	if unlocked.size() <= 1:
		_status_label.text = "尚未解锁其他武器；击败精英并完成更多轮次可解锁"
		return
	var current_index: int = unlocked.find(player.get_weapon_id())
	var next_index: int = posmod(current_index + 1, unlocked.size())
	var next_weapon: StringName = unlocked[next_index]
	if player.configure_weapon(next_weapon):
		_progression.select_weapon(next_weapon)
		if save_enabled:
			_progression.save_progress()
		_status_label.text = "切换武器：%s" % player.get_weapon_name()
		_update_equipment_hud()


func _bank_run_progress(victory: bool) -> String:
	if _progression == null:
		return ""
	var earned_shards: int = _run_shards + (8 if victory else 0)
	var newly_unlocked: Array[StringName] = _progression.bank_run(earned_shards, victory)
	_run_shards = 0
	if save_enabled:
		var save_error: Error = _progression.save_progress()
		if save_error != OK:
			push_error("Could not save progression: %s" % error_string(save_error))
	if newly_unlocked.is_empty():
		return ""
	var unlocked_names: Array[String] = []
	for weapon_id in newly_unlocked:
		unlocked_names.append(WeaponCatalog.get_weapon_name(weapon_id))
	return "；解锁「%s」" % "、".join(unlocked_names)


func _get_encounter_for_room(room_index: int) -> int:
	match posmod(room_index, 5):
		1:
			return EncounterType.TREASURE
		2:
			return EncounterType.ELITE
		3:
			return EncounterType.SHOP
		4:
			return EncounterType.BOSS
		_:
			return EncounterType.NORMAL


func _get_enemy_family_for_room(room_index: int) -> int:
	return _get_primary_enemy_family_for_room(room_index)


func _get_primary_enemy_family_for_room(room_index: int) -> int:
	if room_index < GOBLIN_CHAPTER_START:
		return ENEMY_FAMILY_SLIME
	if room_index < MIXED_CHAPTER_START:
		return ENEMY_FAMILY_GOBLIN
	if room_index < FINAL_CHAPTER_START:
		return ENEMY_FAMILY_SLIME
	return ENEMY_FAMILY_GOBLIN


func _get_enemy_family_for_spawn(room_index: int, spawn_index: int) -> int:
	if room_index < MIXED_CHAPTER_START:
		return _get_primary_enemy_family_for_room(room_index)
	return (
		ENEMY_FAMILY_SLIME
		if posmod(room_index + spawn_index, 2) == 0
		else ENEMY_FAMILY_GOBLIN
	)


func _get_room_reinforcement_count(room_index: int) -> int:
	if room_index >= FINAL_CHAPTER_START:
		return 2
	if room_index >= MIXED_CHAPTER_START:
		return 1
	return 0


func _get_chapter_name(room_index: int) -> String:
	if room_index < GOBLIN_CHAPTER_START:
		return "晶史莱姆巢穴"
	if room_index < MIXED_CHAPTER_START:
		return "赤牙营地"
	if room_index < FINAL_CHAPTER_START:
		return "冲突边境"
	return "月蚀混战区"


func _get_encounter_name(encounter: int) -> String:
	match encounter:
		EncounterType.TREASURE:
			return "宝藏房"
		EncounterType.ELITE:
			return "精英房"
		EncounterType.SHOP:
			return "商店"
		EncounterType.BOSS:
			return "首领房"
		_:
			return "战斗房"


func get_room_sequence_ids() -> Array[StringName]:
	var room_ids: Array[StringName] = []
	for pool_index in _room_sequence:
		var room: Dictionary = _room_pool[pool_index]
		var room_id: StringName = room.get("id", &"")
		room_ids.append(room_id)
	return room_ids


func get_current_room_number() -> int:
	return _current_room_index + 1


func is_choosing_upgrade() -> bool:
	return _choosing_upgrade


func is_run_complete() -> bool:
	return _run_complete


func get_upgrade_choices() -> Array[Dictionary]:
	return _upgrade_choices.duplicate(true)


func is_awaiting_chest() -> bool:
	return _awaiting_chest


func is_shopping() -> bool:
	return _shopping


func get_gold() -> int:
	return _gold


func get_current_encounter_name() -> String:
	return _get_encounter_name(_current_encounter)


func get_progression_snapshot() -> Dictionary:
	return _progression.get_snapshot() if _progression != null else {}


func _draw_gothic_platform(rect: Rect2, room_accent: Color) -> void:
	var visible_height: float = minf(rect.size.y, WORLD_SIZE.y - rect.position.y)
	if visible_height <= 0.0:
		return
	var facade := Rect2(rect.position, Vector2(rect.size.x, visible_height))
	var rune_color := room_accent.lerp(Color("#50d9ed"), 0.65)
	var stone_edge := Color("#07111b")
	var stone_face := Color("#132a3a")
	var stone_mid := Color("#1b3a4b")
	var gold_trim := Color("#c79b48")

	# The cap is the walkable stone lip. It shares the collider's exact top edge.
	draw_rect(facade, stone_edge)
	draw_rect(Rect2(rect.position + Vector2(2.0, 3.0), Vector2(rect.size.x - 4.0, maxf(0.0, visible_height - 3.0))), stone_face)
	draw_rect(Rect2(rect.position, Vector2(rect.size.x, minf(8.0, visible_height))), Color("#29495a"))
	draw_line(rect.position + Vector2(0.0, 1.0), rect.position + Vector2(rect.size.x, 1.0), gold_trim, 1.5)
	draw_line(rect.position + Vector2(0.0, 6.0), rect.position + Vector2(rect.size.x, 6.0), Color("#5e8290"), 1.0)

	var block_width: float = 42.0
	var block_x: float = rect.position.x + 4.0
	var row_index: int = 0
	while block_x < rect.end.x - 3.0:
		var offset: float = 0.0 if row_index % 2 == 0 else block_width * 0.5
		for row_y in range(14, int(visible_height), 15):
			var seam_x: float = block_x + offset
			if seam_x > rect.position.x + 3.0 and seam_x < rect.end.x - 3.0:
				draw_line(
					Vector2(seam_x, rect.position.y + float(row_y)),
					Vector2(seam_x, rect.position.y + minf(float(row_y + 12), visible_height - 2.0)),
					Color("#0a1a25"),
					1.0
				)
		row_index += 1
		block_x += block_width
	for row_y in range(14, int(visible_height), 15):
		draw_line(
			Vector2(rect.position.x + 3.0, rect.position.y + float(row_y)),
			Vector2(rect.end.x - 3.0, rect.position.y + float(row_y)),
			Color("#0a1a25"),
			1.0
		)

	var rune_x: float = rect.position.x + 24.0
	while rune_x < rect.end.x - 16.0:
		if visible_height >= 22.0:
			var rune_center := Vector2(rune_x, rect.position.y + 15.0)
			draw_colored_polygon(
				PackedVector2Array([
					rune_center + Vector2(0.0, -4.0), rune_center + Vector2(4.0, 0.0),
					rune_center + Vector2(0.0, 4.0), rune_center + Vector2(-4.0, 0.0),
				]),
				rune_color
			)
			draw_circle(rune_center, 1.4, Color("#d8f7ff"))
		rune_x += 96.0


func _draw() -> void:
	var room_accent := Color("#78bdc3")
	if not _current_room_data.is_empty():
		room_accent = _current_room_data.get("accent", room_accent)
	draw_texture_rect(MOONLIT_GOTHIC_BRIDGE_BACKGROUND, Rect2(Vector2.ZERO, WORLD_SIZE), false)
	draw_rect(Rect2(Vector2.ZERO, WORLD_SIZE), Color(0.015, 0.04, 0.10, 0.12))
	for rect in platform_rects:
		_draw_gothic_platform(rect, room_accent)
