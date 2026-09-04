extends Node2D

const WORLD_SIZE := Vector2(1280.0, 720.0)
const DISPLAY_SIZE := Vector2(1280.0, 840.0)
const ENEMY_SCRIPT := preload("res://scripts/rogue_enemy.gd")
const ENEMY_PROJECTILE_SCRIPT := preload("res://scripts/enemy_projectile.gd")
const ROOM_CATALOG_SCRIPT := preload("res://scripts/run_room_catalog.gd")
const CHEST_SCRIPT := preload("res://scripts/reward_chest.gd")
const ROOM_EXIT_PORTAL_SCRIPT := preload("res://scripts/room_exit_portal.gd")
const COMBAT_VFX_SCRIPT := preload("res://scripts/combat_vfx.gd")
const DAMAGE_NUMBER_SCRIPT := preload("res://scripts/damage_number.gd")
const SOUNDSCAPE_SCRIPT := preload("res://scripts/soundscape.gd")
const SETTINGS_STORE_SCRIPT := preload("res://scripts/settings_store.gd")
const RUN_TELEMETRY_SCRIPT := preload("res://scripts/run_telemetry.gd")
const COMBAT_BUDGET_SCRIPT := preload("res://scripts/combat_budget.gd")
const PAUSE_INPUT_HANDLER_SCRIPT := preload("res://scripts/pause_input_handler.gd")
const ENCOUNTER_DIRECTOR_SCRIPT := preload("res://scripts/run_encounter_director.gd")
const UPGRADE_SERVICE_SCRIPT := preload("res://scripts/run_upgrade_service.gd")
const RUN_FLOW_STATE_SCRIPT := preload("res://scripts/run_flow_state.gd")
const RUN_HUD_BUILDER_SCRIPT := preload("res://scripts/run_hud_builder.gd")
const RUN_HUD_PRESENTER_SCRIPT := preload("res://scripts/run_hud_presenter.gd")
const RUN_BUILD_OVERVIEW_SCRIPT := preload("res://scripts/run_build_overview.gd")
const EVENT_CATALOG_SCRIPT := preload("res://scripts/event_catalog.gd")
const CONTINUE_STORE_SCRIPT := preload("res://scripts/run_continue_store.gd")
const DEATH_RECAP_SCRIPT := preload("res://scripts/death_recap.gd")
const TUTORIAL_SCRIPT := preload("res://scripts/run_tutorial.gd")
const MOONLIT_GOTHIC_BRIDGE_BACKGROUND := preload("res://assets/backgrounds/moonlit_gothic_bridge.png")
const MENU_MOONLIT_SANCTUM_BACKGROUND := preload("res://assets/backgrounds/menu_moonlit_sanctum_v1.png")
const BUILD_LABEL := "月蚀混战测试版 0.4.1 · 2026.09.03"
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
const ENEMY_ARCHETYPE_STANDARD := 0
const ENEMY_ARCHETYPE_SHIELD_GUARD := 1
const ENEMY_ARCHETYPE_FLYER := 2
const ENEMY_ARCHETYPE_CASTER := 3
const ENEMY_ARCHETYPE_AMBUSHER := 4
const CHOICE_ACTIONS: Array[StringName] = [&"choice_1", &"choice_2", &"choice_3"]
const CHOICE_CONTROLLER_LABELS: Array[String] = ["X", "Y", "B"]

enum EncounterType {
	NORMAL,
	TREASURE,
	ELITE,
	SHOP,
	BOSS,
	EVENT,
	CHALLENGE,
	RISK_CHEST,
	HOLDOUT,
}

enum Difficulty {
	EASY,
	MEDIUM,
	HARD,
}

enum RoomObjective {
	CLEAR_ALL,
	TIME_TRIAL,
	HOLDOUT,
	ELITE_HUNT,
	BRANCH_REWARD,
}

@export var save_enabled: bool = true

@onready var player: RoguePlayer = $Player
@onready var controls_label: Label = $HUD/Controls
@onready var title_label: Label = $HUD/Title
@onready var hud: CanvasLayer = $HUD

var platform_rects: Array[Rect2] = []
var _platform_bodies: Array[StaticBody2D] = []
var _rng := RandomNumberGenerator.new()
var _visual_rng := RandomNumberGenerator.new()
var _seed_rng := RandomNumberGenerator.new()
var _enemies: Array[RogueEnemy] = []
var _projectiles: Array[Area2D] = []
var _room_pool: Array[Dictionary] = []
var _room_sequence: Array[int] = []
var _encounter_sequence: Array[int] = []
var _run_seed: int = 0
var _next_run_seed: int = -1
var _current_room_index: int = -1
var _current_room_data: Dictionary = {}
var _run_generation: int = 0
var _run_number: int = 0
var _flow_state: RunFlowState = RUN_FLOW_STATE_SCRIPT.new() as RunFlowState
var _hud_presenter: RunHUDPresenter
var _last_upgrade_name: String = ""
var _current_encounter: int = EncounterType.NORMAL
var _current_combat_profile: Dictionary = {}
var _chest: RewardChest
var _room_exit_portal: RoomExitPortal
var _pending_risk_gold: int = 0
var _pending_risk_heal: int = 0
var _challenge_reward_granted: bool = false
var _current_objective: int = RoomObjective.CLEAR_ALL
var _objective_timer_remaining: float = 0.0
var _objective_hold_progress: float = 0.0
var _objective_hold_duration: float = 0.0
var _objective_resolved: bool = false
var _objective_failed: bool = false
var _objective_reward_granted: bool = false
var _objective_anchor: Vector2 = Vector2.ZERO
var _objective_radius: float = 0.0
var _objective_trap_zones: Array[Rect2] = []
var _objective_trap_pulse_remaining: float = 0.0
var _objective_trap_flash_remaining: float = 0.0
var _hunt_target: RogueEnemy
var _gold: int = 10
var _run_shards: int = 0
var _progression: ProgressionStore
var _telemetry
var _boss_enemy: RogueEnemy

var _upgrade_overlay: Control
var _upgrade_title: Label
var _upgrade_hint: Label
var _upgrade_buttons: Array[Button] = []
var _upgrade_choices: Array[Dictionary] = []
var _upgrade_tween: Tween
var _entry_overlay: Control
var _entry_title: Label
var _entry_subtitle: Label
var _entry_progress_panel: Panel
var _start_button: Button
var _continue_button: Button
var _difficulty_buttons: Array[Button] = []
var _death_recap
var _tutorial
var _continue_store
var _entry_flow_active: bool = false
var _entry_tween: Tween
var _selected_difficulty: int = Difficulty.MEDIUM
var _camera_base_position := Vector2.ZERO
var _camera_shake_remaining: float = 0.0
var _camera_shake_duration: float = 0.0
var _camera_shake_strength: float = 0.0
var _lives_remaining: int = MAX_RUN_LIVES
var _settings: RefCounted
var _pause_overlay: Control
var _pause_overview_button: Button
var _settings_overlay: Control
var _build_overview: RunBuildOverview
var _settings_key_buttons: Dictionary = {}
var _settings_volume_slider: HSlider
var _settings_music_slider: HSlider
var _settings_effects_slider: HSlider
var _settings_voice_slider: HSlider
var _settings_resolution_selector: OptionButton
var _settings_fullscreen_toggle: CheckButton
var _settings_vsync_toggle: CheckButton
var _settings_reduced_effects_toggle: CheckButton
var _settings_damage_numbers_toggle: CheckButton
var _settings_guide_label: RichTextLabel
var _settings_combat_guide_label: RichTextLabel
var _settings_controller_status_label: Label
var _settings_display_status_label: Label
var _settings_from_pause: bool = false
var _awaiting_rebind_action: StringName = &""
var _is_game_paused: bool = false
var _build_overview_opened_from_pause: bool = false
var _using_controller_input: bool = false
var _display_apply_generation: int = 0
var _pause_input_handler: Node
var _soundscape: RogueSoundscape


func _set_run_phase(next_phase: int) -> void:
	_flow_state.transition_to(next_phase)
	queue_redraw()


func _ready() -> void:
	# The gameplay root must be pausable. HUD owns the always-processing input bridge.
	process_mode = Node.PROCESS_MODE_PAUSABLE
	hud.process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize()
	_visual_rng.randomize()
	_seed_rng.randomize()
	_settings = SETTINGS_STORE_SCRIPT.new() as RefCounted
	_settings.call(&"load_settings")
	player.set_reduced_effects_enabled(
		bool(_settings.call(&"get_reduced_effects_enabled"))
	)
	_soundscape = SOUNDSCAPE_SCRIPT.new() as RogueSoundscape
	add_child(_soundscape)
	_configure_inputs()
	_pause_input_handler = PAUSE_INPUT_HANDLER_SCRIPT.new() as Node
	hud.add_child(_pause_input_handler)
	_pause_input_handler.key_pressed.connect(_on_always_key_pressed)
	_pause_input_handler.input_device_changed.connect(_on_input_device_changed)
	_pause_input_handler.controller_pause_pressed.connect(_on_controller_pause_pressed)
	_pause_input_handler.controller_cancel_pressed.connect(_on_controller_cancel_pressed)
	_pause_input_handler.controller_overview_pressed.connect(_on_controller_overview_pressed)
	_pause_input_handler.controller_action_pressed.connect(_on_always_controller_button_pressed)
	if not Input.joy_connection_changed.is_connected(_on_joy_connection_changed):
		Input.joy_connection_changed.connect(_on_joy_connection_changed)
	_configure_camera()
	RUN_HUD_BUILDER_SCRIPT.build(hud, title_label, controls_label)
	_hud_presenter = RUN_HUD_PRESENTER_SCRIPT.new() as RunHUDPresenter
	if not _hud_presenter.bind(hud):
		push_error("Combat HUD presenter could not bind the expected node contract")
	_update_ability_hud()
	_create_upgrade_ui()
	_create_entry_ui()
	_create_pause_ui()
	_create_settings_ui()
	_create_build_overview()
	_create_death_recap()
	_create_tutorial()
	_using_controller_input = not Input.get_connected_joypads().is_empty()
	_pause_input_handler.call(&"set_initial_device", _using_controller_input)
	_refresh_input_prompts()
	player.auto_respawn = false
	player.attack_hit.connect(_on_player_attack_hit)
	player.skill_hit.connect(_on_player_skill_hit)
	player.action_started.connect(_on_player_action_started)
	player.vocal_requested.connect(_on_player_vocal_requested)
	player.health_changed.connect(_on_player_health_changed)
	player.damage_received.connect(_on_player_damage_received)
	player.died.connect(_on_player_died)
	_progression = ProgressionStore.new()
	_continue_store = CONTINUE_STORE_SCRIPT.new(
		CONTINUE_STORE_SCRIPT.DEFAULT_SAVE_PATH,
		save_enabled
	)
	_telemetry = RUN_TELEMETRY_SCRIPT.new(
		RUN_TELEMETRY_SCRIPT.DEFAULT_SAVE_PATH,
		save_enabled
	)
	if save_enabled:
		_progression.load_progress()
		_continue_store.load_snapshot()
		if _telemetry.load_data() and _telemetry.is_run_active():
			var interrupted_run: Dictionary = _telemetry.get_current_run_snapshot()
			var interrupted_weapon := StringName(String(
				interrupted_run.get("ending_weapon_id", WeaponCatalog.SWORD)
			))
			_telemetry.finish_run(false, interrupted_weapon, &"interrupted")
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
	if _telemetry != null:
		_telemetry.tick(_delta)
	if _flow_state.run_active:
		_update_room_objective(_delta)
	if _flow_state.choosing_upgrade and _process_choice_shortcuts():
		return
	if not _entry_flow_active and Input.is_action_just_pressed(&"restart"):
		_start_new_run()
		return
	if Input.is_action_just_pressed(&"interact"):
		if _flow_state.awaiting_exit:
			_activate_room_exit()
		elif _flow_state.awaiting_chest:
			_open_current_chest()
		elif _flow_state.shopping:
			_leave_shop()
	if Input.is_action_just_pressed(&"cycle_weapon"):
		_cycle_weapon()
	if is_instance_valid(_chest):
		_chest.set_opener_position(player.global_position)
	if is_instance_valid(_room_exit_portal):
		_room_exit_portal.set_opener_position(player.global_position)
	_update_equipment_hud()
	_update_ability_hud()
	_update_lives_hud()
	_update_music_state()


func _process_choice_shortcuts() -> bool:
	for choice_index in range(CHOICE_ACTIONS.size()):
		if Input.is_action_just_pressed(CHOICE_ACTIONS[choice_index]):
			choose_upgrade(choice_index)
			return true
	return false


func _on_player_action_started(action: StringName) -> void:
	if is_instance_valid(_tutorial):
		_tutorial.notify_action(action)
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
		&"land":
			_soundscape.play_land()
		&"footstep":
			_soundscape.play_footstep()


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
	_register_action(&"build_overview", [KEY_TAB])
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
	if _flow_state.awaiting_exit and event.is_action_pressed(&"interact") and not _is_game_paused:
		_activate_room_exit()
		get_viewport().set_input_as_handled()
		return
	if is_instance_valid(_build_overview) and _build_overview.visible:
		if event.keycode == KEY_ESCAPE or event.is_action_pressed(&"build_overview"):
			_close_build_overview()
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(&"build_overview"):
		if not _entry_flow_active and not _settings_overlay.visible:
			_open_build_overview(_is_game_paused)
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


func _on_controller_pause_pressed() -> void:
	if _settings_overlay.visible:
		_close_settings()
	elif _entry_flow_active:
		return
	elif _is_game_paused:
		_resume_game()
	else:
		_pause_game()
	get_viewport().set_input_as_handled()


func _on_controller_cancel_pressed() -> void:
	if _settings_overlay.visible:
		_close_settings()
	elif _is_game_paused:
		_resume_game()
	else:
		return
	get_viewport().set_input_as_handled()


func _on_controller_overview_pressed() -> void:
	if _entry_flow_active or _settings_overlay.visible:
		return
	if is_instance_valid(_build_overview) and _build_overview.visible:
		_close_build_overview()
	else:
		_open_build_overview(_is_game_paused)
	get_viewport().set_input_as_handled()


func _on_always_controller_button_pressed(event: InputEventJoypadButton) -> void:
	if not _flow_state.awaiting_exit or not event.is_action_pressed(&"interact") or _is_game_paused:
		return
	_activate_room_exit()
	get_viewport().set_input_as_handled()


func _on_input_device_changed(using_controller: bool) -> void:
	_using_controller_input = using_controller
	_refresh_input_prompts()


func _on_joy_connection_changed(_device: int, connected: bool) -> void:
	if connected:
		_using_controller_input = true
	elif Input.get_connected_joypads().is_empty():
		_using_controller_input = false
	_refresh_input_prompts()


func _refresh_input_prompts() -> void:
	_update_ability_hud()
	_refresh_settings_key_buttons()
	_refresh_choice_overlay_prompts()
	if is_instance_valid(_pause_overview_button):
		_pause_overview_button.text = "构筑总览  [%s]" % _get_action_prompt(&"build_overview")
	if is_instance_valid(_chest):
		_chest.set_interaction_prompt(_get_action_prompt(&"interact"))
	if is_instance_valid(_room_exit_portal):
		_room_exit_portal.set_prompt_text(
			"%s 进入下一房" % _get_action_prompt(&"interact")
		)
	if is_instance_valid(_settings_controller_status_label):
		var connected_count: int = Input.get_connected_joypads().size()
		if connected_count > 0:
			_settings_controller_status_label.text = (
				"手柄：已连接 · 当前显示 Xbox 键位"
				if _using_controller_input
				else "手柄：已连接 · 按任意手柄键切换提示"
			)
		else:
			_settings_controller_status_label.text = "手柄：未连接 · Xbox 映射已启用"
	_ensure_context_focus()


func _ensure_context_focus() -> void:
	if not _using_controller_input:
		return
	var focus_owner: Control = get_viewport().gui_get_focus_owner()
	if is_instance_valid(_settings_overlay) and _settings_overlay.visible:
		if focus_owner == null or not _settings_overlay.is_ancestor_of(focus_owner):
			_settings_resolution_selector.grab_focus()
		return
	if is_instance_valid(_upgrade_overlay) and _upgrade_overlay.visible:
		if focus_owner != null and _upgrade_overlay.is_ancestor_of(focus_owner):
			return
		for button in _upgrade_buttons:
			if button.visible and not button.disabled:
				button.grab_focus()
				return
	if is_instance_valid(_pause_overlay) and _pause_overlay.visible:
		if focus_owner == null or not _pause_overlay.is_ancestor_of(focus_owner):
			(_pause_overlay.get_node("Resume") as Button).grab_focus()
		return
	if is_instance_valid(_entry_overlay) and _entry_overlay.visible:
		if focus_owner != null and _entry_overlay.is_ancestor_of(focus_owner) and focus_owner.visible:
			return
		if is_instance_valid(_continue_button) and _continue_button.visible:
			_continue_button.grab_focus()
		elif _start_button.visible:
			_start_button.grab_focus()
		else:
			for button in _difficulty_buttons:
				if button.visible:
					button.grab_focus()
					return


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
		_visual_rng.randf_range(-intensity, intensity),
		_visual_rng.randf_range(-intensity, intensity)
	)
	if _camera_shake_remaining <= 0.0:
		camera.position = _camera_base_position


func _trigger_camera_shake(strength: float, duration: float = 0.09) -> void:
	if _settings != null and bool(_settings.call(&"get_reduced_effects_enabled")):
		strength *= 0.25
		duration *= 0.70
	_camera_shake_strength = maxf(_camera_shake_strength, strength)
	_camera_shake_duration = maxf(_camera_shake_duration, duration)
	_camera_shake_remaining = maxf(_camera_shake_remaining, duration)


func _create_upgrade_ui() -> void:
	_upgrade_overlay = Control.new()
	_upgrade_overlay.name = "UpgradeChoice"
	_upgrade_overlay.position = Vector2.ZERO
	_upgrade_overlay.size = DISPLAY_SIZE
	_upgrade_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	hud.add_child(_upgrade_overlay)

	var dimmer := ColorRect.new()
	dimmer.name = "UpgradeDimmer"
	dimmer.size = DISPLAY_SIZE
	dimmer.color = Color(0.006, 0.014, 0.035, 0.82)
	dimmer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_upgrade_overlay.add_child(dimmer)

	var panel := Panel.new()
	panel.name = "UpgradePanel"
	panel.position = Vector2(80.0, 110.0)
	panel.size = Vector2(1120.0, 518.0)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override(
		"panel",
		_create_surface_style(
			Color(0.018, 0.055, 0.095, 0.975),
			Color(0.30, 0.86, 1.0, 0.82),
			18,
			2,
			18
		)
	)
	_upgrade_overlay.add_child(panel)

	var upper_rule := ColorRect.new()
	upper_rule.position = Vector2(42.0, 22.0)
	upper_rule.size = Vector2(1036.0, 2.0)
	upper_rule.color = Color(0.42, 0.91, 1.0, 0.72)
	upper_rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(upper_rule)

	var kicker := Label.new()
	kicker.name = "UpgradeKicker"
	kicker.position = Vector2(0.0, 38.0)
	kicker.size = Vector2(1120.0, 28.0)
	kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	kicker.text = "LUNAR RELIC  ·  CHOOSE ONE"
	kicker.add_theme_font_size_override("font_size", 15)
	kicker.add_theme_color_override("font_color", Color(0.42, 0.85, 1.0, 0.92))
	kicker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(kicker)

	_upgrade_title = Label.new()
	_upgrade_title.position = Vector2(55.0, 70.0)
	_upgrade_title.size = Vector2(1010.0, 52.0)
	_upgrade_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_upgrade_title.add_theme_font_size_override("font_size", 33)
	_upgrade_title.add_theme_color_override("font_color", Color(0.90, 0.97, 1.0, 1.0))
	_upgrade_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(_upgrade_title)

	_upgrade_hint = Label.new()
	_upgrade_hint.position = Vector2(70.0, 458.0)
	_upgrade_hint.size = Vector2(980.0, 34.0)
	_upgrade_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_upgrade_hint.add_theme_font_size_override("font_size", 16)
	_upgrade_hint.add_theme_color_override("font_color", Color(0.62, 0.78, 0.86, 1.0))
	_upgrade_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(_upgrade_hint)

	for choice_index in range(3):
		var button := Button.new()
		button.name = "Upgrade_%d" % (choice_index + 1)
		button.position = Vector2(50.0 + float(choice_index) * 340.0, 156.0)
		button.size = Vector2(300.0, 270.0)
		button.pivot_offset = button.size * 0.5
		button.add_theme_font_size_override("font_size", 19)
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.pressed.connect(_on_upgrade_button_pressed.bind(choice_index))
		button.mouse_entered.connect(_on_upgrade_card_hovered.bind(button, true))
		button.mouse_exited.connect(_on_upgrade_card_hovered.bind(button, false))
		button.focus_entered.connect(_on_upgrade_card_hovered.bind(button, true))
		button.focus_exited.connect(_on_upgrade_card_hovered.bind(button, false))
		_create_upgrade_card_content(button)
		_style_upgrade_card(button, {})
		panel.add_child(button)
		_upgrade_buttons.append(button)
	_configure_horizontal_focus(_upgrade_buttons)

	_hide_upgrade_overlay()


func _create_surface_style(
	background_color: Color,
	border_color: Color,
	corner_radius: int = 12,
	border_width: int = 1,
	shadow_size: int = 0
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background_color
	style.border_color = border_color
	style.set_border_width_all(border_width)
	style.corner_radius_top_left = corner_radius
	style.corner_radius_top_right = corner_radius
	style.corner_radius_bottom_left = corner_radius
	style.corner_radius_bottom_right = corner_radius
	if shadow_size > 0:
		style.shadow_color = Color(0.0, 0.012, 0.035, 0.72)
		style.shadow_size = shadow_size
		style.shadow_offset = Vector2(0.0, 6.0)
	return style


func _style_upgrade_card(button: Button, choice: Dictionary) -> void:
	var rarity_name: String = String(choice.get("rarity_name", "普通"))
	if _flow_state.event_active:
		rarity_name = "事件"
	var accent := Color(0.44, 0.84, 0.96, 1.0)
	match rarity_name:
		"稀有":
			accent = Color(0.53, 0.55, 1.0, 1.0)
		"传说":
			accent = Color(1.0, 0.69, 0.26, 1.0)
		"事件":
			accent = Color(0.72, 0.46, 1.0, 1.0)
	button.add_theme_stylebox_override(
		"normal",
		_create_surface_style(
			Color(0.025, 0.085, 0.14, 0.98),
			Color(accent, 0.68),
			14,
			2,
			10
		)
	)
	button.add_theme_stylebox_override(
		"hover",
		_create_surface_style(
			Color(0.055, 0.15, 0.22, 1.0),
			Color(accent, 1.0),
			14,
			3,
			14
		)
	)
	button.add_theme_stylebox_override(
		"pressed",
		_create_surface_style(
			Color(0.10, 0.22, 0.30, 1.0),
			Color(1.0, 1.0, 1.0, 0.95),
			14,
			3,
			8
		)
	)
	button.add_theme_stylebox_override(
		"disabled",
		_create_surface_style(
			Color(0.025, 0.042, 0.06, 0.88),
			Color(0.25, 0.34, 0.40, 0.52),
			14,
			1
		)
	)
	button.add_theme_color_override("font_color", Color(0.86, 0.96, 1.0, 1.0))
	button.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0, 1.0))
	button.add_theme_color_override("font_pressed_color", Color(1.0, 0.96, 0.80, 1.0))
	button.add_theme_color_override("font_disabled_color", Color(0.40, 0.48, 0.54, 1.0))
	var accent_bar: ColorRect = button.get_node_or_null("CardAccent") as ColorRect
	var separator: ColorRect = button.get_node_or_null("CardSeparator") as ColorRect
	var rarity_label: Label = button.get_node_or_null("CardRarity") as Label
	var title_label: Label = button.get_node_or_null("CardTitle") as Label
	var footer_label: Label = button.get_node_or_null("CardFooter") as Label
	if accent_bar != null:
		accent_bar.color = Color(accent, 0.92)
	if separator != null:
		separator.color = Color(accent, 0.62)
	if rarity_label != null:
		rarity_label.add_theme_color_override("font_color", Color(accent, 1.0))
	if title_label != null:
		title_label.add_theme_color_override("font_color", Color(0.92, 0.98, 1.0, 1.0))
	if footer_label != null:
		footer_label.add_theme_color_override("font_color", Color(accent, 0.84))


func _create_upgrade_card_content(button: Button) -> void:
	var accent_bar := ColorRect.new()
	accent_bar.name = "CardAccent"
	accent_bar.position = Vector2(18.0, 16.0)
	accent_bar.size = Vector2(264.0, 4.0)
	accent_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(accent_bar)

	var rarity_label := Label.new()
	rarity_label.name = "CardRarity"
	rarity_label.position = Vector2(20.0, 27.0)
	rarity_label.size = Vector2(260.0, 22.0)
	rarity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rarity_label.add_theme_font_size_override("font_size", 14)
	rarity_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(rarity_label)

	var separator := ColorRect.new()
	separator.name = "CardSeparator"
	separator.position = Vector2(30.0, 57.0)
	separator.size = Vector2(240.0, 1.0)
	separator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(separator)

	var title_label := Label.new()
	title_label.name = "CardTitle"
	title_label.position = Vector2(24.0, 71.0)
	title_label.size = Vector2(252.0, 56.0)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_label.add_theme_font_size_override("font_size", 23)
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(title_label)

	var sigil_label := Label.new()
	sigil_label.name = "CardSigil"
	sigil_label.position = Vector2(0.0, 128.0)
	sigil_label.size = Vector2(300.0, 24.0)
	sigil_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sigil_label.text = "◇"
	sigil_label.add_theme_font_size_override("font_size", 22)
	sigil_label.add_theme_color_override("font_color", Color(0.60, 0.90, 1.0, 0.82))
	sigil_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(sigil_label)

	var description_label := Label.new()
	description_label.name = "CardDescription"
	description_label.position = Vector2(26.0, 156.0)
	description_label.size = Vector2(248.0, 60.0)
	description_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	description_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description_label.add_theme_font_size_override("font_size", 16)
	description_label.add_theme_color_override("font_color", Color(0.68, 0.82, 0.90, 1.0))
	description_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(description_label)

	var footer_label := Label.new()
	footer_label.name = "CardFooter"
	footer_label.position = Vector2(20.0, 230.0)
	footer_label.size = Vector2(260.0, 22.0)
	footer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer_label.add_theme_font_size_override("font_size", 13)
	footer_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(footer_label)


func _set_upgrade_card_content(
	button: Button,
	shortcut: String,
	rarity_name: String,
	card_name: String,
	description: String,
	footer_text: String
) -> void:
	button.text = ""
	button.tooltip_text = "%s · %s" % [card_name, description]
	(button.get_node("CardRarity") as Label).text = "[%s]  %s" % [shortcut, rarity_name]
	(button.get_node("CardTitle") as Label).text = card_name
	(button.get_node("CardDescription") as Label).text = description
	(button.get_node("CardFooter") as Label).text = footer_text


func _on_upgrade_card_hovered(button: Button, emphasized: bool) -> void:
	if button.disabled or not button.visible:
		return
	var choice_index: int = _upgrade_buttons.find(button)
	if choice_index < 0:
		return
	var resting_position := Vector2(50.0 + float(choice_index) * 340.0, 156.0)
	var target_position := resting_position + (Vector2(0.0, -8.0) if emphasized else Vector2.ZERO)
	var target_scale := Vector2.ONE * (1.028 if emphasized else 1.0)
	var tween := button.create_tween().set_parallel(true)
	tween.tween_property(button, "position", target_position, 0.12)
	tween.tween_property(button, "scale", target_scale, 0.12)


func _play_upgrade_overlay_intro() -> void:
	if not is_instance_valid(_upgrade_overlay) or not _upgrade_overlay.visible:
		return
	if _upgrade_tween != null and _upgrade_tween.is_valid():
		_upgrade_tween.kill()
	var dimmer: ColorRect = _upgrade_overlay.get_node("UpgradeDimmer") as ColorRect
	var panel: Panel = _upgrade_overlay.get_node("UpgradePanel") as Panel
	if dimmer == null or panel == null:
		return
	dimmer.modulate = Color(1.0, 1.0, 1.0, 0.0)
	panel.pivot_offset = panel.size * 0.5
	panel.modulate = Color(1.0, 1.0, 1.0, 0.0)
	panel.scale = Vector2.ONE * 0.96
	_upgrade_title.modulate = Color(1.0, 1.0, 1.0, 0.0)
	_upgrade_hint.modulate = Color(1.0, 1.0, 1.0, 0.0)
	for choice_index in range(_upgrade_buttons.size()):
		var button: Button = _upgrade_buttons[choice_index]
		if not button.visible:
			continue
		var resting_position := Vector2(50.0 + float(choice_index) * 340.0, 156.0)
		button.position = resting_position + Vector2(0.0, 42.0)
		button.scale = Vector2.ONE * 0.90
		button.modulate = Color(1.0, 1.0, 1.0, 0.0)
	_upgrade_tween = create_tween().set_parallel(true)
	_upgrade_tween.tween_property(dimmer, "modulate:a", 1.0, 0.22)
	_upgrade_tween.tween_property(panel, "modulate:a", 1.0, 0.20)
	_upgrade_tween.tween_property(panel, "scale", Vector2.ONE, 0.30)
	_upgrade_tween.tween_property(_upgrade_title, "modulate:a", 1.0, 0.24).set_delay(0.06)
	_upgrade_tween.tween_property(_upgrade_hint, "modulate:a", 1.0, 0.20).set_delay(0.16)
	for choice_index in range(_upgrade_buttons.size()):
		var button: Button = _upgrade_buttons[choice_index]
		if not button.visible:
			continue
		var resting_position := Vector2(50.0 + float(choice_index) * 340.0, 156.0)
		var delay: float = 0.14 + float(choice_index) * 0.09
		_upgrade_tween.tween_property(button, "modulate:a", 1.0, 0.20).set_delay(delay)
		_upgrade_tween.tween_property(button, "position", resting_position, 0.30).set_delay(delay)
		_upgrade_tween.tween_property(button, "scale", Vector2.ONE, 0.30).set_delay(delay)


func _create_entry_ui() -> void:
	_entry_overlay = Control.new()
	_entry_overlay.name = "EntryFlow"
	_entry_overlay.position = Vector2.ZERO
	_entry_overlay.size = DISPLAY_SIZE
	_entry_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	hud.add_child(_entry_overlay)

	var menu_artwork := TextureRect.new()
	menu_artwork.name = "MenuArtwork"
	menu_artwork.position = Vector2.ZERO
	menu_artwork.size = DISPLAY_SIZE
	menu_artwork.texture = MENU_MOONLIT_SANCTUM_BACKGROUND
	menu_artwork.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	menu_artwork.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	menu_artwork.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_entry_overlay.add_child(menu_artwork)

	var vignette := ColorRect.new()
	vignette.name = "MenuVignette"
	vignette.size = DISPLAY_SIZE
	vignette.color = Color(0.004, 0.014, 0.040, 0.43)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_entry_overlay.add_child(vignette)

	var frame := Panel.new()
	frame.name = "EntryFrame"
	frame.position = Vector2(418.0, 364.0)
	frame.size = Vector2(444.0, 210.0)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_theme_stylebox_override(
		"panel",
		_create_surface_style(
			Color(0.008, 0.030, 0.070, 0.34),
			Color(0.36, 0.84, 1.0, 0.26),
			20,
			1,
			14
		)
	)
	_entry_overlay.add_child(frame)

	var kicker := Label.new()
	kicker.name = "EntryKicker"
	kicker.position = Vector2(300.0, 164.0)
	kicker.size = Vector2(680.0, 24.0)
	kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	kicker.text = "LUNAR ECLIPSE  //  ROGUELITE PROTOCOL"
	kicker.add_theme_font_size_override("font_size", 14)
	kicker.add_theme_color_override("font_color", Color(0.54, 0.86, 1.0, 0.88))
	kicker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_entry_overlay.add_child(kicker)

	_entry_title = Label.new()
	_entry_title.position = Vector2(250.0, 198.0)
	_entry_title.size = Vector2(780.0, 76.0)
	_entry_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_entry_title.add_theme_font_size_override("font_size", 54)
	_entry_title.add_theme_color_override("font_color", Color(0.90, 0.97, 1.0, 1.0))
	_entry_title.add_theme_color_override("font_outline_color", Color(0.004, 0.016, 0.042, 0.72))
	_entry_title.add_theme_constant_override("outline_size", 4)
	_entry_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_entry_overlay.add_child(_entry_title)

	_entry_subtitle = Label.new()
	_entry_subtitle.position = Vector2(270.0, 274.0)
	_entry_subtitle.size = Vector2(740.0, 50.0)
	_entry_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_entry_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_entry_subtitle.add_theme_font_size_override("font_size", 17)
	_entry_subtitle.add_theme_color_override("font_color", Color(0.68, 0.82, 0.91, 0.94))
	_entry_subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_entry_overlay.add_child(_entry_subtitle)

	_start_button = Button.new()
	_start_button.name = "StartGame"
	_start_button.position = Vector2(442.0, 382.0)
	_start_button.size = Vector2(396.0, 58.0)
	_start_button.pivot_offset = _start_button.size * 0.5
	_start_button.add_theme_font_size_override("font_size", 22)
	_start_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_style_entry_button(_start_button, Color(0.28, 0.88, 1.0, 1.0), true)
	_start_button.pressed.connect(_show_difficulty_selection)
	_entry_overlay.add_child(_start_button)

	_continue_button = Button.new()
	_continue_button.name = "ContinueRun"
	_continue_button.position = Vector2(442.0, 382.0)
	_continue_button.size = Vector2(396.0, 58.0)
	_continue_button.pivot_offset = _continue_button.size * 0.5
	_continue_button.add_theme_font_size_override("font_size", 22)
	_continue_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_style_entry_button(_continue_button, Color(0.86, 0.74, 0.38, 1.0), true)
	_continue_button.pressed.connect(_continue_saved_run)
	_continue_button.visible = false
	_entry_overlay.add_child(_continue_button)

	var entry_settings := Button.new()
	entry_settings.name = "EntrySettings"
	entry_settings.position = Vector2(442.0, 452.0)
	entry_settings.size = Vector2(396.0, 42.0)
	entry_settings.pivot_offset = entry_settings.size * 0.5
	entry_settings.text = "设置"
	entry_settings.add_theme_font_size_override("font_size", 19)
	entry_settings.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_style_entry_button(entry_settings, Color(0.43, 0.70, 0.82, 1.0), false)
	entry_settings.pressed.connect(_open_settings.bind(false))
	_entry_overlay.add_child(entry_settings)

	var entry_quit := Button.new()
	entry_quit.name = "EntryQuit"
	entry_quit.position = Vector2(442.0, 506.0)
	entry_quit.size = Vector2(396.0, 34.0)
	entry_quit.pivot_offset = entry_quit.size * 0.5
	entry_quit.text = "退出游戏"
	entry_quit.add_theme_font_size_override("font_size", 16)
	entry_quit.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_style_entry_button(entry_quit, Color(0.52, 0.60, 0.68, 1.0), false)
	entry_quit.pressed.connect(_quit_game)
	_entry_overlay.add_child(entry_quit)

	var footer := Label.new()
	footer.name = "EntryFooter"
	footer.position = Vector2(240.0, 598.0)
	footer.size = Vector2(800.0, 24.0)
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.text = "选择难度后开始新的月蚀路线 · 操作说明与无障碍选项位于设置"
	footer.add_theme_font_size_override("font_size", 14)
	footer.add_theme_color_override("font_color", Color(0.45, 0.67, 0.78, 0.92))
	footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_entry_overlay.add_child(footer)

	_entry_progress_panel = Panel.new()
	_entry_progress_panel.name = "ProfileSummary"
	_entry_progress_panel.position = Vector2(350.0, 640.0)
	_entry_progress_panel.size = Vector2(580.0, 76.0)
	_entry_progress_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_entry_progress_panel.add_theme_stylebox_override(
		"panel",
		_create_surface_style(
			Color(0.006, 0.035, 0.070, 0.94),
			Color(0.40, 0.84, 0.98, 0.72),
			14,
			1,
			10
		)
	)
	_entry_overlay.add_child(_entry_progress_panel)
	var profile_heading := Label.new()
	profile_heading.name = "Heading"
	profile_heading.position = Vector2(18.0, 9.0)
	profile_heading.size = Vector2(544.0, 20.0)
	profile_heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	profile_heading.text = "自动存档 01  ·  局外进度"
	profile_heading.add_theme_font_size_override("font_size", 14)
	profile_heading.add_theme_color_override("font_color", Color(0.58, 0.90, 1.0, 1.0))
	profile_heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_entry_progress_panel.add_child(profile_heading)
	var profile_value := Label.new()
	profile_value.name = "Value"
	profile_value.position = Vector2(18.0, 31.0)
	profile_value.size = Vector2(544.0, 38.0)
	profile_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	profile_value.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	profile_value.add_theme_font_size_override("font_size", 14)
	profile_value.add_theme_color_override("font_color", Color(0.86, 0.95, 1.0, 1.0))
	profile_value.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_entry_progress_panel.add_child(profile_value)

	var difficulty_data := [
		{"name": "简单", "description": "低攻击欲望 · 较长预警\n前五房用于熟悉操作", "color": Color(0.36, 0.86, 0.58, 1.0)},
		{"name": "中等", "description": "标准成长曲线 · 稳步加压\n推荐首次完整挑战", "color": Color(0.35, 0.72, 0.98, 1.0)},
		{"name": "困难", "description": "积极追击 · 更短攻击间隔\n面向熟悉构筑的玩家", "color": Color(1.0, 0.42, 0.35, 1.0)},
	]
	for difficulty_index in range(difficulty_data.size()):
		var data: Dictionary = difficulty_data[difficulty_index]
		var button := Button.new()
		button.name = "Difficulty_%d" % difficulty_index
		button.position = Vector2(170.0 + float(difficulty_index) * 314.0, 388.0)
		button.size = Vector2(298.0, 174.0)
		button.pivot_offset = button.size * 0.5
		button.add_theme_font_size_override("font_size", 20)
		button.add_theme_color_override("font_color", data["color"])
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.text = "%s\n\n%s" % [data["name"], data["description"]]
		_style_entry_button(button, data["color"], true)
		button.pressed.connect(_start_game_with_difficulty.bind(difficulty_index))
		button.visible = false
		_entry_overlay.add_child(button)
		_difficulty_buttons.append(button)
	_configure_horizontal_focus(_difficulty_buttons)
	_configure_vertical_focus([_continue_button, _start_button, entry_settings, entry_quit])

	_entry_overlay.visible = false


func _style_entry_button(button: Button, accent: Color, prominent: bool) -> void:
	var normal_color := (
		Color(0.028, 0.115, 0.18, 0.54)
		if prominent
		else Color(0.012, 0.052, 0.090, 0.34)
	)
	var hover_color := (
		Color(0.075, 0.24, 0.34, 0.76)
		if prominent
		else Color(0.038, 0.13, 0.20, 0.60)
	)
	button.add_theme_stylebox_override(
		"normal",
		_create_surface_style(normal_color, Color(accent, 0.46), 14, 1, 8)
	)
	button.add_theme_stylebox_override(
		"hover",
		_create_surface_style(hover_color, Color(accent, 0.94), 14, 1, 14)
	)
	button.add_theme_stylebox_override(
		"pressed",
		_create_surface_style(Color(0.12, 0.30, 0.40, 0.86), Color(1.0, 1.0, 1.0, 0.78), 14, 1, 4)
	)
	button.add_theme_stylebox_override(
		"focus",
		_create_surface_style(hover_color, Color(0.90, 0.98, 1.0, 0.90), 14, 1, 12)
	)
	button.add_theme_color_override("font_color", Color(0.82, 0.94, 1.0, 1.0))
	button.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0, 1.0))
	button.add_theme_color_override("font_pressed_color", Color(0.94, 0.99, 1.0, 1.0))


func _reset_entry_layout() -> void:
	_entry_title.position = Vector2(250.0, 198.0)
	_entry_subtitle.position = Vector2(270.0, 274.0)
	var has_continue: bool = (
		is_instance_valid(_continue_button)
		and _continue_button.visible
	)
	_start_button.position = Vector2(442.0, 448.0 if has_continue else 382.0)
	_start_button.size = Vector2(396.0, 48.0 if has_continue else 58.0)
	if is_instance_valid(_continue_button):
		_continue_button.position = Vector2(442.0, 382.0)
	var entry_settings: Button = _entry_overlay.get_node("EntrySettings") as Button
	var entry_quit: Button = _entry_overlay.get_node("EntryQuit") as Button
	entry_settings.position = Vector2(442.0, 508.0 if has_continue else 452.0)
	entry_quit.position = Vector2(442.0, 558.0 if has_continue else 506.0)
	var frame: Panel = _entry_overlay.get_node("EntryFrame") as Panel
	if frame != null:
		frame.position = Vector2(418.0, 364.0)
		frame.size = Vector2(444.0, 210.0)
	if is_instance_valid(_entry_progress_panel):
		_entry_progress_panel.position = Vector2(350.0, 668.0 if has_continue else 640.0)
	for difficulty_index in range(_difficulty_buttons.size()):
		_difficulty_buttons[difficulty_index].position = Vector2(
			170.0 + float(difficulty_index) * 314.0,
			388.0
		)


func _play_entry_transition(showing_difficulty: bool) -> void:
	if _entry_tween != null and _entry_tween.is_valid():
		_entry_tween.kill()
	var frame: Panel = _entry_overlay.get_node("EntryFrame") as Panel
	var kicker: Label = _entry_overlay.get_node("EntryKicker") as Label
	var footer: Label = _entry_overlay.get_node("EntryFooter") as Label
	var controls: Array[Control] = [_entry_title, _entry_subtitle, kicker, footer]
	if showing_difficulty:
		for button in _difficulty_buttons:
			controls.append(button)
	else:
		if is_instance_valid(_continue_button) and _continue_button.visible:
			controls.append(_continue_button)
		controls.append(_start_button)
		controls.append(_entry_overlay.get_node("EntrySettings") as Button)
		controls.append(_entry_overlay.get_node("EntryQuit") as Button)
		controls.append(_entry_progress_panel)
	if frame != null and frame.visible:
		frame.pivot_offset = frame.size * 0.5
		frame.modulate = Color(1.0, 1.0, 1.0, 0.0)
		frame.scale = Vector2.ONE * 0.985
	for control in controls:
		if control == null or not control.visible:
			continue
		control.modulate = Color(1.0, 1.0, 1.0, 0.0)
		control.position += Vector2(0.0, 12.0)
		control.scale = Vector2.ONE * 0.985
	_entry_tween = create_tween().set_parallel(true)
	if frame != null and frame.visible:
		_entry_tween.tween_property(frame, "modulate:a", 1.0, 0.26)
		_entry_tween.tween_property(frame, "scale", Vector2.ONE, 0.30)
	var visible_index: int = 0
	for control in controls:
		if control == null or not control.visible:
			continue
		var delay: float = 0.08 + float(visible_index) * 0.06
		_entry_tween.tween_property(control, "modulate:a", 1.0, 0.20).set_delay(delay)
		_entry_tween.tween_property(control, "position:y", control.position.y - 12.0, 0.26).set_delay(delay)
		_entry_tween.tween_property(control, "scale", Vector2.ONE, 0.28).set_delay(delay)
		visible_index += 1


func _create_pause_ui() -> void:
	_pause_overlay = Control.new()
	_pause_overlay.name = "PauseMenu"
	_pause_overlay.position = Vector2.ZERO
	_pause_overlay.size = DISPLAY_SIZE
	_pause_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_pause_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	hud.add_child(_pause_overlay)

	var dimmer := ColorRect.new()
	dimmer.name = "PauseDimmer"
	dimmer.size = DISPLAY_SIZE
	dimmer.color = Color(0.004, 0.012, 0.028, 0.82)
	dimmer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pause_overlay.add_child(dimmer)

	var panel := Panel.new()
	panel.name = "PausePanel"
	panel.position = Vector2(405.0, 150.0)
	panel.size = Vector2(470.0, 470.0)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override(
		"panel",
		_create_surface_style(
			Color(0.010, 0.040, 0.075, 0.985),
			Color(0.38, 0.85, 0.98, 0.72),
			18,
			2,
			18
		)
	)
	_pause_overlay.add_child(panel)
	var accent_rule := ColorRect.new()
	accent_rule.position = Vector2(28.0, 24.0)
	accent_rule.size = Vector2(414.0, 2.0)
	accent_rule.color = Color(0.42, 0.90, 1.0, 0.74)
	accent_rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(accent_rule)
	var kicker := Label.new()
	kicker.position = Vector2(0.0, 38.0)
	kicker.size = Vector2(470.0, 22.0)
	kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	kicker.text = "RUN SUSPENDED  ·  月蚀回响"
	kicker.add_theme_font_size_override("font_size", 13)
	kicker.add_theme_color_override("font_color", Color(0.48, 0.82, 0.94, 0.90))
	kicker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(kicker)

	var title := Label.new()
	title.position = Vector2(455.0, 220.0)
	title.size = Vector2(370.0, 50.0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.text = "已暂停"
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color(0.85, 0.95, 1.0, 1.0))
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pause_overlay.add_child(title)

	var resume_button := _create_menu_button("Resume", "继续游戏", Vector2(475.0, 292.0), Vector2(330.0, 54.0))
	resume_button.pressed.connect(_resume_game)
	_pause_overlay.add_child(resume_button)
	_pause_overview_button = _create_menu_button(
		"PauseBuildOverview",
		"构筑总览",
		Vector2(475.0, 492.0),
		Vector2(330.0, 48.0)
	)
	_pause_overview_button.pressed.connect(_open_build_overview.bind(true))
	_pause_overlay.add_child(_pause_overview_button)
	var settings_button := _create_menu_button("PauseSettings", "设置与操作", Vector2(475.0, 358.0), Vector2(330.0, 48.0))
	settings_button.pressed.connect(_open_settings.bind(true))
	_pause_overlay.add_child(settings_button)
	var menu_button := _create_menu_button("ReturnToMenu", "返回主菜单", Vector2(475.0, 425.0), Vector2(330.0, 48.0))
	menu_button.pressed.connect(_return_to_main_menu)
	_pause_overlay.add_child(menu_button)
	_configure_vertical_focus([resume_button, settings_button, menu_button, _pause_overview_button])
	_pause_overlay.visible = false


func _create_build_overview() -> void:
	_build_overview = RUN_BUILD_OVERVIEW_SCRIPT.new() as RunBuildOverview
	_build_overview.name = "BuildOverview"
	_build_overview.close_requested.connect(_close_build_overview)
	hud.add_child(_build_overview)


func _refresh_build_overview() -> void:
	if not is_instance_valid(_build_overview) or _settings == null:
		return
	_build_overview.refresh(player, _get_action_prompt(&"build_overview"))


func _open_build_overview(from_pause: bool = false) -> void:
	if (
		not is_instance_valid(_build_overview)
		or _entry_flow_active
		or _flow_state.run_complete
		or _build_overview.visible
	):
		return
	_build_overview_opened_from_pause = from_pause
	_refresh_build_overview()
	_build_overview.visible = true
	if from_pause:
		_pause_overlay.visible = false
	else:
		_is_game_paused = true
		get_tree().paused = true
	_build_overview.focus_close_button()


func _close_build_overview() -> void:
	if not is_instance_valid(_build_overview) or not _build_overview.visible:
		return
	var return_to_pause: bool = _build_overview_opened_from_pause
	_build_overview.visible = false
	_build_overview_opened_from_pause = false
	if return_to_pause:
		_pause_overlay.visible = true
		_ensure_context_focus()
	else:
		get_tree().paused = false
		_is_game_paused = false


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
	dimmer.color = Color(0.004, 0.012, 0.028, 0.88)
	dimmer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_settings_overlay.add_child(dimmer)
	var panel := Panel.new()
	panel.position = Vector2.ZERO
	panel.size = DISPLAY_SIZE
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	panel_style.border_color = Color(0.0, 0.0, 0.0, 0.0)
	panel_style.set_border_width_all(0)
	panel_style.corner_radius_top_left = 14
	panel_style.corner_radius_top_right = 14
	panel_style.corner_radius_bottom_left = 14
	panel_style.corner_radius_bottom_right = 14
	panel_style.shadow_color = Color(0.0, 0.0, 0.0, 0.52)
	panel_style.shadow_size = 18
	panel.add_theme_stylebox_override("panel", panel_style)
	_settings_overlay.add_child(panel)
	panel.visible = false

	var header_card := _create_settings_glass_card(
		"SettingsHeader", Vector2(360.0, 48.0), Vector2(560.0, 86.0), Color("#74e3ff")
	)
	var audio_card := _create_settings_glass_card(
		"SettingsAudioCard", Vector2(64.0, 164.0), Vector2(580.0, 150.0), Color("#67dff4")
	)
	var system_card := _create_settings_glass_card(
		"SettingsSystemCard", Vector2(660.0, 164.0), Vector2(556.0, 154.0), Color("#73dff3")
	)
	var bindings_card := _create_settings_glass_card(
		"SettingsBindingsCard", Vector2(64.0, 340.0), Vector2(602.0, 332.0), Color("#7aa8ff")
	)
	var guide_card := _create_settings_glass_card(
		"SettingsGuideCard", Vector2(690.0, 340.0), Vector2(526.0, 332.0), Color("#8ddff2")
	)
	_create_settings_card_heading(audio_card, "音频 / AUDIO", Color("#75e5f5"))
	_create_settings_card_heading(system_card, "显示与辅助 / SYSTEM", Color("#75e5f5"))
	_create_settings_card_heading(bindings_card, "按键映射 / INPUT BINDINGS", Color("#9ab9ff"))
	_create_settings_card_heading(guide_card, "战斗提示 / FIELD GUIDE", Color("#b5edff"))

	var title := Label.new()
	title.position = Vector2(380.0, 60.0)
	title.size = Vector2(520.0, 42.0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.text = "设置与操作"
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.89, 0.97, 1.0, 1.0))
	title.add_theme_color_override("font_outline_color", Color(0.0, 0.03, 0.07, 0.70))
	title.add_theme_constant_override("outline_size", 2)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_settings_overlay.add_child(title)
	var subtitle := Label.new()
	subtitle.position = Vector2(380.0, 101.0)
	subtitle.size = Vector2(520.0, 20.0)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.text = "调整你的月蚀路线 · 所有说明收纳于此"
	subtitle.add_theme_font_size_override("font_size", 13)
	subtitle.add_theme_color_override("font_color", Color(0.54, 0.79, 0.91, 0.92))
	subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_settings_overlay.add_child(subtitle)

	_settings_volume_slider = _create_settings_audio_slider(
		"MasterVolume", "主音量", Vector2(88.0, 204.0), 166.0,
		_on_master_volume_changed
	)
	_settings_music_slider = _create_settings_audio_slider(
		"MusicVolume", "音乐", Vector2(366.0, 204.0), 166.0,
		_on_music_volume_changed
	)
	_settings_effects_slider = _create_settings_audio_slider(
		"EffectsVolume", "音效", Vector2(88.0, 254.0), 166.0,
		_on_effects_volume_changed
	)
	_settings_voice_slider = _create_settings_audio_slider(
		"VoiceVolume", "语音", Vector2(366.0, 254.0), 166.0,
		_on_voice_volume_changed
	)
	_settings_damage_numbers_toggle = CheckButton.new()
	_settings_damage_numbers_toggle.name = "DamageNumbersToggle"
	_settings_damage_numbers_toggle.position = Vector2(936.0, 248.0)
	_settings_damage_numbers_toggle.size = Vector2(210.0, 34.0)
	_settings_damage_numbers_toggle.text = "显示伤害数字"
	_settings_damage_numbers_toggle.add_theme_font_size_override("font_size", 17)
	_settings_damage_numbers_toggle.toggled.connect(_on_damage_numbers_toggled)
	_settings_overlay.add_child(_settings_damage_numbers_toggle)

	var resolution_label := Label.new()
	resolution_label.position = Vector2(684.0, 202.0)
	resolution_label.size = Vector2(74.0, 34.0)
	resolution_label.text = "分辨率"
	resolution_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	resolution_label.add_theme_font_size_override("font_size", 16)
	_settings_overlay.add_child(resolution_label)
	_settings_resolution_selector = OptionButton.new()
	_settings_resolution_selector.name = "ResolutionSelector"
	_settings_resolution_selector.position = Vector2(762.0, 202.0)
	_settings_resolution_selector.size = Vector2(160.0, 34.0)
	var resolution_options: Array = _settings.call(&"get_resolution_options") as Array
	for resolution_value: Variant in resolution_options:
		var resolution: Vector2i = resolution_value
		_settings_resolution_selector.add_item("%d × %d" % [resolution.x, resolution.y])
	_settings_resolution_selector.item_selected.connect(_on_resolution_selected)
	_style_settings_action_button(_settings_resolution_selector)
	_settings_overlay.add_child(_settings_resolution_selector)
	_settings_fullscreen_toggle = _create_settings_toggle(
		"FullscreenToggle", "全屏", Vector2(940.0, 200.0),
		_on_fullscreen_toggled
	)
	_settings_vsync_toggle = _create_settings_toggle(
		"VsyncToggle", "垂直同步", Vector2(1070.0, 200.0),
		_on_vsync_toggled
	)
	_settings_reduced_effects_toggle = _create_settings_toggle(
		"ReducedEffectsToggle", "减弱闪光/震动", Vector2(684.0, 248.0),
		_on_reduced_effects_toggled
	)
	_settings_controller_status_label = Label.new()
	_settings_controller_status_label.name = "ControllerStatus"
	_settings_controller_status_label.position = Vector2(684.0, 281.0)
	_settings_controller_status_label.size = Vector2(510.0, 17.0)
	_settings_controller_status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_settings_controller_status_label.add_theme_font_size_override("font_size", 12)
	_settings_controller_status_label.add_theme_color_override(
		"font_color", Color(0.56, 0.82, 0.88, 1.0)
	)
	_settings_overlay.add_child(_settings_controller_status_label)

	_settings_display_status_label = Label.new()
	_settings_display_status_label.name = "DisplayStatus"
	_settings_display_status_label.position = Vector2(684.0, 298.0)
	_settings_display_status_label.size = Vector2(510.0, 15.0)
	_settings_display_status_label.add_theme_font_size_override("font_size", 11)
	_settings_display_status_label.add_theme_color_override(
		"font_color", Color(0.58, 0.74, 0.84, 1.0)
	)
	_settings_display_status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_settings_overlay.add_child(_settings_display_status_label)

	var guide_panel := Panel.new()
	guide_panel.name = "OperationGuidePanel"
	guide_panel.position = Vector2(702.0, 352.0)
	guide_panel.size = Vector2(502.0, 308.0)
	guide_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var guide_style := StyleBoxFlat.new()
	guide_style.bg_color = Color(0.008, 0.028, 0.057, 0.18)
	guide_style.border_color = Color(0.52, 0.84, 0.96, 0.18)
	guide_style.set_border_width_all(1)
	guide_style.corner_radius_top_left = 12
	guide_style.corner_radius_top_right = 12
	guide_style.corner_radius_bottom_left = 12
	guide_style.corner_radius_bottom_right = 12
	guide_panel.add_theme_stylebox_override("panel", guide_style)
	_settings_overlay.add_child(guide_panel)
	guide_panel.visible = false
	_settings_guide_label = RichTextLabel.new()
	_settings_guide_label.name = "OperationGuide"
	_settings_guide_label.position = Vector2(710.0, 388.0)
	_settings_guide_label.size = Vector2(240.0, 264.0)
	_settings_guide_label.bbcode_enabled = true
	_settings_guide_label.fit_content = false
	_settings_guide_label.scroll_active = false
	_settings_guide_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_settings_overlay.add_child(_settings_guide_label)
	_settings_combat_guide_label = RichTextLabel.new()
	_settings_combat_guide_label.name = "OperationGuideCombat"
	_settings_combat_guide_label.position = Vector2(974.0, 388.0)
	_settings_combat_guide_label.size = Vector2(222.0, 264.0)
	_settings_combat_guide_label.bbcode_enabled = true
	_settings_combat_guide_label.scroll_active = false
	_settings_combat_guide_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_settings_overlay.add_child(_settings_combat_guide_label)
	var guide_font := SystemFont.new()
	guide_font.font_names = PackedStringArray(["Microsoft YaHei", "Noto Sans CJK SC", "sans-serif"])
	for column: RichTextLabel in [_settings_guide_label, _settings_combat_guide_label]:
		column.add_theme_font_override("normal_font", guide_font)
		column.add_theme_font_override("bold_font", guide_font)
		column.add_theme_font_size_override("normal_font_size", 16)
		column.add_theme_font_size_override("bold_font_size", 16)
		column.add_theme_constant_override("line_separation", 1)
		column.add_theme_color_override("default_color", Color("#edf7fc"))
	var guide_divider := ColorRect.new()
	guide_divider.position = Vector2(958.0, 394.0)
	guide_divider.size = Vector2(1.0, 248.0)
	guide_divider.color = Color(0.32, 0.65, 0.76, 0.45)
	guide_divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_settings_overlay.add_child(guide_divider)

	var actions := [
		[&"build_overview", "构筑总览"],
		[&"move_left", "向左"], [ &"move_right", "向右"], [ &"jump", "跳跃"], [ &"attack", "攻击"], [ &"aim_up", "上劈方向"], [ &"aim_down", "下劈方向"],
		[&"dash", "闪避冲刺"], [ &"skill", "主动技能"], [ &"interact", "互动"], [ &"cycle_weapon", "切换武器"], [ &"restart", "重开本局"], [ &"pause", "暂停菜单"],
	]
	for action_index in range(actions.size()):
		# Three columns keep every binding inside the left card. The previous
		# four-column grid let the final column overlap the field guide.
		var row: int = action_index % 5
		var column: int = int(action_index / 5)
		var position := Vector2(84.0 + float(column) * 194.0, 382.0 + float(row) * 51.0)
		var action_name: StringName = actions[action_index][0]
		var action_label := Label.new()
		action_label.position = position
		action_label.size = Vector2(62.0, 38.0)
		action_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		action_label.text = String(actions[action_index][1])
		action_label.add_theme_font_size_override("font_size", 14)
		action_label.add_theme_color_override("font_color", Color(0.74, 0.86, 0.94, 0.96))
		action_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_settings_overlay.add_child(action_label)
		var key_button := Button.new()
		key_button.name = "Bind_%s" % action_name
		key_button.position = position + Vector2(66.0, 0.0)
		key_button.size = Vector2(122.0, 38.0)
		key_button.add_theme_font_size_override("font_size", 14)
		_style_settings_action_button(key_button)
		key_button.pressed.connect(_begin_rebind.bind(action_name))
		_settings_overlay.add_child(key_button)
		_settings_key_buttons[action_name] = key_button

	var reset_button := _create_menu_button("ResetBindings", "恢复默认键位", Vector2(390.0, 700.0), Vector2(220.0, 44.0))
	reset_button.pressed.connect(_reset_bindings)
	_settings_overlay.add_child(reset_button)
	var back_button := _create_menu_button("CloseSettings", "返回", Vector2(670.0, 700.0), Vector2(220.0, 44.0))
	back_button.pressed.connect(_close_settings)
	_settings_overlay.add_child(back_button)
	_refresh_settings_operation_guide()
	_refresh_display_status()
	_settings_overlay.visible = false


func _create_settings_glass_card(
	card_name: String,
	card_position: Vector2,
	card_size: Vector2,
	accent: Color
) -> Panel:
	var card := Panel.new()
	card.name = card_name
	card.position = card_position
	card.size = card_size
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_theme_stylebox_override(
		"panel",
		_create_surface_style(
			Color(0.008, 0.030, 0.064, 0.48),
			Color(accent, 0.30),
			16,
			1,
			10
		)
	)
	_settings_overlay.add_child(card)
	var accent_mark := ColorRect.new()
	accent_mark.position = Vector2(20.0, 13.0)
	accent_mark.size = Vector2(46.0, 2.0)
	accent_mark.color = Color(accent, 0.82)
	accent_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(accent_mark)
	return card


func _create_settings_card_heading(card: Panel, heading_text: String, accent: Color) -> void:
	var heading := Label.new()
	heading.name = "Heading"
	heading.position = Vector2(20.0, 18.0)
	heading.size = Vector2(card.size.x - 40.0, 20.0)
	heading.text = heading_text
	heading.add_theme_font_size_override("font_size", 13)
	heading.add_theme_color_override("font_color", Color(accent, 0.94))
	heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(heading)


func _style_settings_action_button(button: BaseButton) -> void:
	button.add_theme_stylebox_override(
		"normal",
		_create_surface_style(
			Color(0.014, 0.052, 0.088, 0.42),
			Color(0.45, 0.79, 0.94, 0.26),
			9,
			1,
			4
		)
	)
	button.add_theme_stylebox_override(
		"hover",
		_create_surface_style(
			Color(0.06, 0.17, 0.25, 0.70),
			Color(0.48, 0.90, 1.0, 0.86),
			9,
			1,
			8
		)
	)
	button.add_theme_stylebox_override(
		"pressed",
		_create_surface_style(
			Color(0.11, 0.27, 0.35, 0.84),
			Color(0.86, 0.97, 1.0, 0.92),
			9,
			1,
			3
		)
	)
	button.add_theme_stylebox_override(
		"focus",
		_create_surface_style(
			Color(0.045, 0.13, 0.21, 0.66),
			Color(0.84, 0.96, 1.0, 0.88),
			9,
			1,
			7
		)
	)
	button.add_theme_color_override("font_color", Color(0.80, 0.91, 0.97, 1.0))
	button.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0, 1.0))
	button.add_theme_color_override("font_pressed_color", Color(0.92, 0.99, 1.0, 1.0))
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func _create_settings_knob_texture(accent: Color) -> ImageTexture:
	var image := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	for y in range(16):
		for x in range(16):
			var point := Vector2(float(x) + 0.5, float(y) + 0.5)
			var distance_to_center := point.distance_to(Vector2(8.0, 8.0))
			if distance_to_center <= 6.6:
				image.set_pixel(x, y, Color(accent, 0.98))
			elif distance_to_center <= 7.6:
				image.set_pixel(x, y, Color(0.80, 0.96, 1.0, 0.38))
	return ImageTexture.create_from_image(image)


func _create_settings_switch_texture(is_enabled: bool, accent: Color) -> ImageTexture:
	var image := Image.create(36, 20, false, Image.FORMAT_RGBA8)
	var body_color := (
		Color(accent, 0.84)
		if is_enabled
		else Color(0.18, 0.30, 0.40, 0.92)
	)
	var knob_center := Vector2(26.0 if is_enabled else 10.0, 10.0)
	for y in range(20):
		for x in range(36):
			var point := Vector2(float(x) + 0.5, float(y) + 0.5)
			var inside_body := (
				point.distance_to(Vector2(10.0, 10.0)) <= 9.0
				or point.distance_to(Vector2(26.0, 10.0)) <= 9.0
				or (point.x >= 10.0 and point.x <= 26.0 and point.y >= 1.0 and point.y <= 19.0)
			)
			if inside_body:
				image.set_pixel(x, y, body_color)
			if point.distance_to(knob_center) <= 6.0:
				image.set_pixel(x, y, Color(0.94, 0.99, 1.0, 1.0))
	return ImageTexture.create_from_image(image)


func _create_settings_audio_slider(
	node_name: String,
	label_text: String,
	group_position: Vector2,
	slider_width: float,
	changed_callback: Callable
) -> HSlider:
	var label := Label.new()
	label.position = group_position
	label.size = Vector2(62.0, 32.0)
	label.text = label_text
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color(0.76, 0.88, 0.95, 0.96))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_settings_overlay.add_child(label)
	var slider := HSlider.new()
	slider.name = node_name
	slider.position = group_position + Vector2(62.0, 5.0)
	slider.size = Vector2(slider_width, 24.0)
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.add_theme_stylebox_override(
		"slider",
		_create_surface_style(Color(0.007, 0.028, 0.050, 0.72), Color(0.33, 0.70, 0.84, 0.30), 6, 1)
	)
	slider.add_theme_stylebox_override(
		"grabber_area",
		_create_surface_style(Color(0.16, 0.61, 0.72, 0.52), Color(0.45, 0.90, 0.98, 0.58), 6, 1)
	)
	slider.add_theme_stylebox_override(
		"grabber_area_highlight",
		_create_surface_style(Color(0.22, 0.72, 0.86, 0.66), Color(0.70, 0.97, 1.0, 0.78), 6, 1)
	)
	slider.add_theme_icon_override("grabber", _create_settings_knob_texture(Color("#7ceaff")))
	slider.add_theme_icon_override("grabber_highlight", _create_settings_knob_texture(Color("#d5f9ff")))
	slider.value_changed.connect(changed_callback)
	_settings_overlay.add_child(slider)
	return slider


func _create_settings_toggle(
	node_name: String,
	button_text: String,
	button_position: Vector2,
	toggled_callback: Callable
) -> CheckButton:
	var toggle := CheckButton.new()
	toggle.name = node_name
	toggle.position = button_position
	toggle.size = Vector2(180.0 if button_text.length() > 4 else 130.0, 36.0)
	toggle.text = button_text
	toggle.add_theme_font_size_override("font_size", 14)
	toggle.add_theme_color_override("font_color", Color(0.76, 0.88, 0.95, 0.96))
	toggle.add_theme_color_override("font_hover_color", Color(0.96, 1.0, 1.0, 1.0))
	toggle.add_theme_constant_override("h_separation", 8)
	var switch_accent := Color("#78e3f7")
	toggle.add_theme_icon_override("unchecked", _create_settings_switch_texture(false, switch_accent))
	toggle.add_theme_icon_override("checked", _create_settings_switch_texture(true, switch_accent))
	toggle.add_theme_icon_override("unchecked_disabled", _create_settings_switch_texture(false, Color(0.38, 0.46, 0.52, 1.0)))
	toggle.add_theme_icon_override("checked_disabled", _create_settings_switch_texture(true, Color(0.38, 0.46, 0.52, 1.0)))
	toggle.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	toggle.toggled.connect(toggled_callback)
	_settings_overlay.add_child(toggle)
	return toggle


func _create_menu_button(node_name: String, button_text: String, button_position: Vector2, button_size: Vector2) -> Button:
	var button := Button.new()
	button.name = node_name
	button.position = button_position
	button.size = button_size
	button.text = button_text
	button.add_theme_font_size_override("font_size", 18)
	_style_settings_action_button(button)
	return button


func _configure_horizontal_focus(buttons: Array) -> void:
	if buttons.size() < 2:
		return
	for button_index in range(buttons.size()):
		var button: Control = buttons[button_index] as Control
		var previous: Control = buttons[posmod(button_index - 1, buttons.size())] as Control
		var next: Control = buttons[(button_index + 1) % buttons.size()] as Control
		button.focus_neighbor_left = button.get_path_to(previous)
		button.focus_neighbor_right = button.get_path_to(next)


func _configure_vertical_focus(controls: Array) -> void:
	if controls.size() < 2:
		return
	for control_index in range(controls.size()):
		var control: Control = controls[control_index] as Control
		var previous: Control = controls[posmod(control_index - 1, controls.size())] as Control
		var next: Control = controls[(control_index + 1) % controls.size()] as Control
		control.focus_neighbor_top = control.get_path_to(previous)
		control.focus_neighbor_bottom = control.get_path_to(next)


func _pause_game() -> void:
	if _entry_flow_active or _flow_state.run_complete:
		return
	_is_game_paused = true
	_pause_overlay.visible = true
	get_tree().paused = true
	_ensure_context_focus()


func _resume_game() -> void:
	get_tree().paused = false
	_is_game_paused = false
	_pause_overlay.visible = false
	_settings_overlay.visible = false
	if is_instance_valid(_build_overview):
		_build_overview.visible = false
	_build_overview_opened_from_pause = false
	_awaiting_rebind_action = &""


func _return_to_main_menu() -> void:
	_persist_continue_snapshot()
	_resume_game()
	_set_run_phase(RunFlowState.Phase.IDLE)
	_hide_upgrade_overlay()
	_clear_chest()
	_clear_room_exit_portal()
	_clear_projectiles()
	_clear_enemies()
	_clear_platform_colliders()
	_entry_flow_active = true
	player.set_input_enabled(false)
	_show_start_screen()


func _open_settings(from_pause: bool) -> void:
	_settings_from_pause = from_pause
	if from_pause:
		_pause_overlay.visible = false
	_awaiting_rebind_action = &""
	_settings_volume_slider.set_value_no_signal(float(_settings.call(&"get_master_volume")))
	_settings_music_slider.set_value_no_signal(float(_settings.call(&"get_music_volume")))
	_settings_effects_slider.set_value_no_signal(float(_settings.call(&"get_effects_volume")))
	_settings_voice_slider.set_value_no_signal(float(_settings.call(&"get_voice_volume")))
	_settings_damage_numbers_toggle.set_pressed_no_signal(
		bool(_settings.call(&"get_damage_numbers_enabled"))
	)
	_settings_resolution_selector.select(int(_settings.call(&"get_resolution_index")))
	_settings_fullscreen_toggle.set_pressed_no_signal(
		bool(_settings.call(&"get_fullscreen_enabled"))
	)
	_settings_vsync_toggle.set_pressed_no_signal(bool(_settings.call(&"get_vsync_enabled")))
	_settings_reduced_effects_toggle.set_pressed_no_signal(
		bool(_settings.call(&"get_reduced_effects_enabled"))
	)
	_settings_overlay.visible = true
	_refresh_input_prompts()
	_refresh_display_status()
	_ensure_context_focus()


func _close_settings() -> void:
	_awaiting_rebind_action = &""
	_settings_overlay.visible = false
	if not _settings_from_pause:
		_show_start_screen()
	else:
		_pause_overlay.visible = true
		_ensure_context_focus()


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
			button.text = String(_settings.call(&"get_combined_binding_name", action_name))
	_refresh_settings_operation_guide()


func _refresh_settings_operation_guide() -> void:
	if not is_instance_valid(_settings_guide_label) or _settings == null:
		return
	var heading := _settings_overlay.get_node("SettingsGuideCard/Heading") as Label
	heading.text = "操作说明 · %s" % ("Xbox 手柄" if _using_controller_input else "键盘与鼠标")
	heading.add_theme_font_size_override("font_size", 16)
	var left_key: String = _get_action_prompt(&"move_left")
	var right_key: String = _get_action_prompt(&"move_right")
	var jump_key: String = _get_action_prompt(&"jump")
	var attack_key: String = _get_action_prompt(&"attack")
	var up_key: String = _get_action_prompt(&"aim_up")
	var down_key: String = _get_action_prompt(&"aim_down")
	var dash_key: String = _get_action_prompt(&"dash")
	var skill_key: String = _get_action_prompt(&"skill")
	var interact_key: String = _get_action_prompt(&"interact")
	var weapon_key: String = _get_action_prompt(&"cycle_weapon")
	var restart_key: String = _get_action_prompt(&"restart")
	var pause_key: String = _get_action_prompt(&"pause")
	_settings_guide_label.text = (
		"[color=#72e4f4]移动与探索[/color]\n"
		+ ("LS / 十字键  左右移动\n" if _using_controller_input else "%s / %s  左右移动\n" % [left_key, right_key])
		+ "%s  跳跃 / 二段跳\n" % jump_key
		+ "%s + %s  下平台\n" % [down_key, jump_key]
		+ "%s  开宝箱 / 进入光柱\n\n" % interact_key
		+ "[color=#72e4f4]菜单与选择[/color]\n"
		+ "%s  暂停与设置\n" % pause_key
		+ "%s  构筑总览\n" % _get_action_prompt(&"build_overview")
		+ (
			"X / Y / B  直接选牌\nLS / 十字键导航 · A 确认"
			if _using_controller_input
			else "1 / 2 / 3  选牌 / 购买"
		)
	)
	_settings_combat_guide_label.text = (
		"[color=#72e4f4]战斗动作[/color]\n"
		+ "%s  普通攻击\n" % attack_key
		+ "%s + %s  上劈\n" % [up_key, attack_key]
		+ "%s + %s  下劈\n" % [down_key, attack_key]
		+ "%s  冲刺（短暂无敌）\n" % dash_key
		+ "%s  主动技能\n" % skill_key
		+ "%s  切换武器\n\n" % weapon_key
		+ "[color=#72e4f4]其他操作[/color]\n"
		+ "%s  离开商店\n" % interact_key
		+ "%s  重新开局" % restart_key
	)


func _get_action_prompt(action_name: StringName) -> String:
	if _settings == null:
		return ""
	return String(_settings.call(
		&"get_action_prompt", action_name, _using_controller_input
	))


func _queue_display_apply() -> void:
	_display_apply_generation += 1
	_apply_display_after_frame(_display_apply_generation)


func _apply_display_after_frame(expected_generation: int) -> void:
	await get_tree().process_frame
	if expected_generation != _display_apply_generation or _settings == null:
		return
	_settings.call(&"apply_display")
	await get_tree().process_frame
	if expected_generation == _display_apply_generation:
		_refresh_display_status()


func _refresh_display_status() -> void:
	if not is_instance_valid(_settings_display_status_label) or _settings == null:
		return
	if Engine.is_embedded_in_editor():
		_settings_display_status_label.text = (
			"编辑器嵌入运行不支持全屏/窗口尺寸；关闭 Embed Game on Next Play 后即可生效。"
		)
		_settings_display_status_label.add_theme_color_override(
			"font_color", Color(1.0, 0.72, 0.40, 1.0)
		)
		return
	var target: Vector2i = _settings.call(&"get_requested_resolution")
	var fullscreen_enabled: bool = bool(_settings.call(&"get_fullscreen_enabled"))
	_settings_display_status_label.text = (
		"全屏已应用（使用当前显示器尺寸）；%d × %d 将在窗口模式生效。" % [target.x, target.y]
		if fullscreen_enabled
		else "窗口分辨率已应用：%d × %d。" % [target.x, target.y]
	)
	_settings_display_status_label.add_theme_color_override(
		"font_color", Color(0.45, 0.88, 0.72, 1.0)
	)


func _on_master_volume_changed(value: float) -> void:
	_settings.call(&"set_master_volume", value)


func _on_music_volume_changed(value: float) -> void:
	_settings.call(&"set_music_volume", value)


func _on_effects_volume_changed(value: float) -> void:
	_settings.call(&"set_effects_volume", value)


func _on_voice_volume_changed(value: float) -> void:
	_settings.call(&"set_voice_volume", value)


func _on_damage_numbers_toggled(enabled: bool) -> void:
	_settings.call(&"set_damage_numbers_enabled", enabled)


func _on_resolution_selected(option_index: int) -> void:
	_settings.call(&"set_resolution_index", option_index)
	_queue_display_apply()


func _on_fullscreen_toggled(enabled: bool) -> void:
	_settings.call(&"set_fullscreen_enabled", enabled)
	_queue_display_apply()


func _on_vsync_toggled(enabled: bool) -> void:
	_settings.call(&"set_vsync_enabled", enabled)
	_queue_display_apply()


func _on_reduced_effects_toggled(enabled: bool) -> void:
	_settings.call(&"set_reduced_effects_enabled", enabled)
	player.set_reduced_effects_enabled(enabled)
	if enabled:
		_camera_shake_remaining = 0.0
		var camera: Camera2D = player.get_node_or_null("Camera2D") as Camera2D
		if camera != null:
			camera.position = _camera_base_position


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
	(_entry_overlay.get_node("EntryFrame") as Panel).visible = true
	_entry_title.text = "月蚀回廊"
	_entry_subtitle.text = "LUNAR ECLIPSE CORRIDOR  ·  %s" % BUILD_LABEL
	(_entry_overlay.get_node("EntryKicker") as Label).text = "LUNAR ECLIPSE  //  ROGUELITE PROTOCOL"
	(_entry_overlay.get_node("EntryFooter") as Label).text = (
		"可继续未完成的路线，或开始新的月蚀路线"
		if _has_continue_snapshot()
		else "选择难度后开始新的月蚀路线 · 操作说明与无障碍选项位于设置"
	)
	_start_button.text = "开始冒险"
	_start_button.visible = true
	_refresh_continue_button()
	_reset_entry_layout()
	var entry_settings: Button = _entry_overlay.get_node("EntrySettings") as Button
	var entry_quit: Button = _entry_overlay.get_node("EntryQuit") as Button
	entry_settings.visible = true
	entry_quit.visible = true
	_entry_progress_panel.visible = true
	_refresh_entry_progress_summary()
	for button in _difficulty_buttons:
		button.visible = false
	_play_entry_transition(false)
	_ensure_context_focus()
	_update_music_state()


func _show_difficulty_selection() -> void:
	_entry_overlay.visible = true
	_reset_entry_layout()
	(_entry_overlay.get_node("EntryFrame") as Panel).visible = false
	_entry_title.text = "选择难度"
	_entry_subtitle.text = "难度会改变每房战斗预算、精英与远程比例和敌人行为；前期克制，后期逐步升级。"
	(_entry_overlay.get_node("EntryKicker") as Label).text = "SELECT YOUR ROUTE  //  RISK DEFINES THE RUN"
	(_entry_overlay.get_node("EntryFooter") as Label).text = "选择一项难度开始冒险 · 后续可在设置中查看完整操作说明"
	_start_button.visible = false
	if is_instance_valid(_continue_button):
		_continue_button.visible = false
	(_entry_overlay.get_node("EntrySettings") as Button).visible = false
	(_entry_overlay.get_node("EntryQuit") as Button).visible = false
	_entry_progress_panel.visible = false
	for button in _difficulty_buttons:
		button.visible = true
	_play_entry_transition(true)
	_ensure_context_focus()


func _refresh_entry_progress_summary() -> void:
	if not is_instance_valid(_entry_progress_panel):
		return
	var value_label: Label = _entry_progress_panel.get_node("Value") as Label
	if _progression == null:
		value_label.text = "正在读取局外进度…"
		return
	var snapshot: Dictionary = _progression.get_snapshot()
	var shards: int = int(snapshot.get("meta_shards", 0))
	var completed: int = int(snapshot.get("runs_completed", 0))
	var bosses: int = int(snapshot.get("bosses_defeated", 0))
	var unlocked: Array = snapshot.get("unlocked_weapons", []) as Array
	var next_goal := "武器库已全部解锁"
	if not unlocked.has(WeaponCatalog.TWIN_BLADES):
		next_goal = "再获得 %d 星屑解锁影织双刃" % maxi(
			0,
			ProgressionStore.TWIN_BLADES_UNLOCK_SHARDS - shards
		)
	elif not unlocked.has(WeaponCatalog.GREATSWORD):
		next_goal = "再完成 %d 次路线解锁坠星巨刃" % maxi(
			0,
			ProgressionStore.GREATSWORD_UNLOCK_WINS - completed
		)
	value_label.text = "星屑 %d  ·  完成路线 %d  ·  击败首领 %d  ·  武器 %d/%d\n%s" % [
		shards,
		completed,
		bosses,
		unlocked.size(),
		WeaponCatalog.all_weapon_ids().size(),
		next_goal,
	]


func _start_game_with_difficulty(difficulty: int) -> void:
	_selected_difficulty = clampi(difficulty, Difficulty.EASY, Difficulty.HARD)
	_lives_remaining = MAX_RUN_LIVES
	_entry_flow_active = false
	if _entry_tween != null and _entry_tween.is_valid():
		_entry_tween.kill()
	_entry_overlay.visible = false
	_clear_continue_snapshot()
	_start_new_run()


func _get_difficulty_health_multiplier() -> float:
	return float(_get_combat_profile().get("health_multiplier", 1.0))


func _get_difficulty_damage_multiplier() -> float:
	return float(_get_combat_profile().get("damage_multiplier", 1.0))


func _get_difficulty_speed_multiplier() -> float:
	return float(_get_combat_profile().get("speed_multiplier", 1.0))


func _get_difficulty_aggression_multiplier() -> float:
	return float(_get_combat_profile().get("awareness_multiplier", 1.0))


func _get_combat_profile() -> Dictionary:
	return COMBAT_BUDGET_SCRIPT.create_profile(
		_selected_difficulty,
		maxi(_current_room_index, 0),
		_current_encounter
	)


func get_selected_difficulty_name() -> String:
	match _selected_difficulty:
		Difficulty.EASY:
			return "简单"
		Difficulty.HARD:
			return "困难"
		_:
			return "中等"


func _start_new_run() -> void:
	if _telemetry != null and _telemetry.is_run_active():
		_telemetry.finish_run(false, player.get_weapon_id(), &"manual_restart")
	_clear_continue_snapshot()
	if is_instance_valid(_death_recap):
		_death_recap.hide_recap()
	if is_instance_valid(_tutorial):
		_tutorial.hide_lesson()
	_run_generation += 1
	_run_number += 1
	if _next_run_seed >= 0:
		_run_seed = clampi(absi(_next_run_seed), 1, 999999)
		_next_run_seed = -1
	else:
		_run_seed = _seed_rng.randi_range(1, 999999)
	_rng.seed = _run_seed
	_set_run_phase(RunFlowState.Phase.ROOM_LOADING)
	_last_upgrade_name = ""
	_current_encounter = EncounterType.NORMAL
	_current_combat_profile.clear()
	_gold = 10
	_run_shards = 0
	_hide_upgrade_overlay()
	_clear_chest()
	_clear_room_exit_portal()
	_clear_projectiles()
	_clear_enemies()
	_clear_platform_colliders()
	player.set_input_enabled(false)
	player.configure_weapon(_progression.get_selected_weapon())
	player.reset_run_progression()
	_hud_presenter.set_boss_visible(false)
	_encounter_sequence = ENCOUNTER_DIRECTOR_SCRIPT.build_sequence(ROOMS_PER_RUN, _rng)
	_room_sequence = ROOM_CATALOG_SCRIPT.build_room_sequence(
		_room_pool.size(),
		ROOMS_PER_RUN,
		_rng
	)
	_current_room_index = -1
	_current_room_data = {}
	if _telemetry != null:
		_telemetry.begin_run(
			_run_seed,
			get_selected_difficulty_name(),
			player.get_weapon_id()
		)
	_update_economy_hud()
	_advance_to_next_room()


func _advance_to_next_room() -> void:
	if _telemetry != null:
		_telemetry.complete_room(&"advanced")
	_current_room_index += 1
	if _current_room_index >= _room_sequence.size():
		_complete_run()
		return
	_load_room(_room_sequence[_current_room_index])


func _load_room(pool_index: int) -> void:
	if pool_index < 0 or pool_index >= _room_pool.size():
		push_error("Invalid room pool index: %d" % pool_index)
		return

	_set_run_phase(RunFlowState.Phase.ROOM_LOADING)
	_pending_risk_gold = 0
	_pending_risk_heal = 0
	_challenge_reward_granted = false
	_reset_room_objective()
	_clear_chest()
	_clear_room_exit_portal()
	_clear_projectiles()
	_clear_enemies()
	_clear_platform_colliders()
	_current_room_data = ROOM_CATALOG_SCRIPT.build_room_variant(
		_room_pool[pool_index],
		_rng,
		_current_room_index + 1
	)
	_current_encounter = _get_encounter_for_room(_current_room_index)
	_current_objective = _get_room_objective(_current_encounter)
	_current_combat_profile = _get_combat_profile()
	if _telemetry != null:
		_telemetry.begin_room(
			_current_room_index + 1,
			StringName(String(_current_room_data.get("id", "unknown_room"))),
			String(_current_room_data.get("title", "未知房间")),
			_get_encounter_name(_current_encounter)
		)
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
	_configure_room_objective()
	_spawn_room_enemies()
	var room_title: String = _current_room_data.get("title", "未知房间")
	if _current_encounter == EncounterType.SHOP:
		player.set_input_enabled(false)
		_show_shop()
	elif _current_encounter == EncounterType.EVENT:
		player.set_input_enabled(false)
		_show_event_choice()
	else:
		player.set_input_enabled(true)
		if _current_encounter == EncounterType.RISK_CHEST:
			_set_run_phase(RunFlowState.Phase.CHEST)
			_set_status("风险宝箱已出现——开启后击败伏兵才能领取奖励")
		else:
			_set_run_phase(RunFlowState.Phase.COMBAT)
			if _current_objective in [RoomObjective.TIME_TRIAL, RoomObjective.HOLDOUT]:
				_set_status(_get_objective_status_text())
			elif _current_encounter == EncounterType.CHALLENGE:
				_set_status("进入 %s·挑战房——高压敌群，胜利获得额外金币与星屑" % room_title)
			elif _last_upgrade_name.is_empty():
				_set_status("进入 %s·%s——清除全部敌人" % [
					room_title,
					_get_encounter_name(_current_encounter),
				])
			else:
				_set_status("已获得「%s」；进入 %s" % [_last_upgrade_name, room_title])
				_last_upgrade_name = ""
	_maybe_begin_tutorial()
	_update_controls()
	_update_music_state()
	_persist_continue_snapshot()
	_update_room_label()
	queue_redraw()


func _reset_room_objective() -> void:
	_current_objective = RoomObjective.CLEAR_ALL
	_objective_timer_remaining = 0.0
	_objective_hold_progress = 0.0
	_objective_hold_duration = 0.0
	_objective_resolved = false
	_objective_failed = false
	_objective_reward_granted = false
	_objective_anchor = Vector2.ZERO
	_objective_radius = 0.0
	_objective_trap_zones.clear()
	_objective_trap_pulse_remaining = 0.0
	_objective_trap_flash_remaining = 0.0
	_hunt_target = null


func _get_room_objective(encounter: int) -> int:
	match encounter:
		EncounterType.CHALLENGE:
			return RoomObjective.TIME_TRIAL
		EncounterType.HOLDOUT:
			return RoomObjective.HOLDOUT
		EncounterType.ELITE:
			return RoomObjective.ELITE_HUNT
		EncounterType.RISK_CHEST:
			return RoomObjective.BRANCH_REWARD
	return RoomObjective.CLEAR_ALL


func _configure_room_objective() -> void:
	if _current_objective in [RoomObjective.CLEAR_ALL, RoomObjective.BRANCH_REWARD]:
		return
	if platform_rects.is_empty():
		return
	var objective_surface: Rect2 = _get_objective_surface()
	if objective_surface.size.x <= 0.0:
		return
	var anchor_x: float = clampf(
		WORLD_SIZE.x * 0.5,
		objective_surface.position.x + 40.0,
		objective_surface.end.x - 40.0
	)
	_objective_anchor = Vector2(anchor_x, objective_surface.position.y - 18.0)
	if _current_objective == RoomObjective.TIME_TRIAL:
		_objective_timer_remaining = maxf(
			18.0,
			31.0 - float(maxi(_current_room_index, 0)) * 0.40 - float(_selected_difficulty) * 2.0
		)
		_configure_objective_traps(objective_surface)
	elif _current_objective == RoomObjective.HOLDOUT:
		_objective_hold_duration = 7.5 + float(_selected_difficulty) * 0.75
		_objective_radius = 92.0
		_configure_objective_traps(objective_surface)
	queue_redraw()


func _get_objective_surface() -> Rect2:
	var best_surface: Rect2 = platform_rects[0]
	var best_score: float = INF
	for surface: Rect2 in platform_rects:
		var elevated_platform_penalty: float = 0.0 if surface.size.y >= 100.0 else 420.0
		var center_distance: float = absf(surface.get_center().x - WORLD_SIZE.x * 0.5)
		var width_bonus: float = minf(surface.size.x, 280.0) * 0.10
		var score: float = center_distance + elevated_platform_penalty - width_bonus
		if score < best_score:
			best_score = score
			best_surface = surface
	return best_surface


func _configure_objective_traps(surface: Rect2) -> void:
	_objective_trap_zones.clear()
	if surface.size.x < 140.0:
		return
	var minimum_center_x: float = surface.position.x + 44.0
	var maximum_center_x: float = surface.end.x - 44.0
	var trap_offsets: Array[float] = [-0.30, 0.30]
	for offset: float in trap_offsets:
		var center_x: float = clampf(
			_objective_anchor.x + surface.size.x * offset,
			minimum_center_x,
			maximum_center_x
		)
		if absf(center_x - _objective_anchor.x) < 54.0:
			continue
		_objective_trap_zones.append(
			Rect2(center_x - 34.0, surface.position.y - 44.0, 68.0, 58.0)
		)
	_objective_trap_pulse_remaining = 1.65


func _update_room_objective(delta: float) -> void:
	if _current_objective == RoomObjective.TIME_TRIAL and not _objective_failed:
		_objective_timer_remaining = maxf(0.0, _objective_timer_remaining - delta)
		if _objective_timer_remaining <= 0.0:
			_objective_failed = true
			_set_status("限时奖励已失效——仍可清理敌人并继续前进")
			queue_redraw()
		else:
			_set_status(_get_objective_status_text())
	elif _current_objective == RoomObjective.HOLDOUT and not _objective_resolved:
		if _is_player_holding_objective():
			_objective_hold_progress = minf(
				_objective_hold_duration,
				_objective_hold_progress + delta
			)
		if _objective_hold_progress >= _objective_hold_duration:
			_objective_resolved = true
			_grant_objective_reward()
			_set_status("守点完成——清理剩余敌人即可过关")
			if _enemies.is_empty():
				call_deferred(&"_on_room_cleared")
		else:
			_set_status(_get_objective_status_text())
	if not _objective_failed and not _objective_resolved:
		_update_objective_traps(delta)
	queue_redraw()


func _is_player_holding_objective() -> bool:
	if _objective_radius <= 0.0:
		return false
	return (
		absf(player.global_position.x - _objective_anchor.x) <= _objective_radius
		and absf(player.global_position.y - _objective_anchor.y) <= 112.0
	)


func _update_objective_traps(delta: float) -> void:
	if _objective_trap_zones.is_empty() or player.is_dead():
		return
	_objective_trap_flash_remaining = maxf(0.0, _objective_trap_flash_remaining - delta)
	_objective_trap_pulse_remaining = maxf(0.0, _objective_trap_pulse_remaining - delta)
	if _objective_trap_pulse_remaining > 0.0:
		return
	_objective_trap_pulse_remaining = 2.35
	_objective_trap_flash_remaining = 0.34
	var trap_damage: int = 8 + mini(maxi(_current_room_index, 0), 8)
	var player_was_hit: bool = false
	for trap_zone: Rect2 in _objective_trap_zones:
		if trap_zone.grow(18.0).has_point(player.global_position):
			if player.receive_enemy_attack(trap_zone.get_center(), trap_damage, &"arcane_trap"):
				player_was_hit = true
	if player_was_hit:
		_trigger_camera_shake(6.0, 0.10)


func _grant_objective_reward() -> void:
	if _objective_reward_granted:
		return
	var bonus_gold: int = 0
	var bonus_shards: int = 0
	match _current_objective:
		RoomObjective.TIME_TRIAL:
			bonus_gold = 16 + maxi(_current_room_index, 0)
			bonus_shards = 2
		RoomObjective.HOLDOUT:
			bonus_gold = 12 + maxi(_current_room_index, 0)
			bonus_shards = 2
		RoomObjective.ELITE_HUNT:
			bonus_gold = 10 + maxi(_current_room_index, 0)
			bonus_shards = 1
		_:
			return
	_objective_reward_granted = true
	_gold += bonus_gold
	_run_shards += bonus_shards
	_update_economy_hud()


func _get_objective_status_text() -> String:
	match _current_objective:
		RoomObjective.TIME_TRIAL:
			if _objective_failed:
				return "限时奖励失效 · 剩余敌人 %d" % _enemies.size()
			return "限时挑战 %04.1f 秒 · 剩余敌人 %d · 避开地面陷阱" % [
				_objective_timer_remaining,
				_enemies.size(),
			]
		RoomObjective.HOLDOUT:
			var hold_ratio: float = (
				0.0
				if _objective_hold_duration <= 0.0
				else _objective_hold_progress / _objective_hold_duration
			)
			return "守点：站在青色符文范围内 %d%% · 剩余敌人 %d" % [
				roundi(hold_ratio * 100.0),
				_enemies.size(),
			]
		RoomObjective.ELITE_HUNT:
			return "精英追猎——优先击败金色标记的队长"
		RoomObjective.BRANCH_REWARD:
			return "风险宝箱——开启后击败伏兵，获得额外奖励"
	return "清理房间 · 剩余敌人 %d" % _enemies.size()


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
	if _current_encounter == EncounterType.SHOP or _current_encounter == EncounterType.EVENT:
		return
	if _current_encounter == EncounterType.RISK_CHEST:
		_spawn_risk_chest()
		return
	if _current_encounter == EncounterType.BOSS:
		_spawn_boss()
		return
	var base_spawn_values: Array = _current_room_data.get("enemies", []) as Array
	var spawn_candidates: Array[Dictionary] = []
	for spawn_value: Variant in base_spawn_values:
		spawn_candidates.append((spawn_value as Dictionary).duplicate(true))
	var reinforcement_count: int = _get_room_reinforcement_count(_current_room_index)
	for reinforcement_index in range(reinforcement_count):
		if platform_rects.is_empty():
			break
		var random_surface: int = _rng.randi_range(0, platform_rects.size() - 1)
		spawn_candidates.append({
			"surface": random_surface,
			"ratio": _rng.randf_range(0.22, 0.78),
			"role": (
				ENEMY_ROLE_RANGED
				if posmod(reinforcement_index + _current_room_index, 3) == 1
				else ENEMY_ROLE_MELEE
			),
		})
	var spawn_values: Array[Dictionary] = COMBAT_BUDGET_SCRIPT.build_spawn_plan(
		spawn_candidates,
		_current_combat_profile,
		_rng
	)
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
		var rank: int = int(descriptor.get("rank", ENEMY_RANK_NORMAL))
		var family: int = _get_enemy_family_for_spawn(_current_room_index, spawn_index)
		var archetype: int = _get_enemy_archetype_for_spawn(
			_current_room_index,
			spawn_index,
			role,
			rank,
			family
		)
		var vertical_offset: float = 28.0 if rank == ENEMY_RANK_ELITE else 22.0
		_spawn_enemy(
			Vector2(lerpf(minimum_x, maximum_x, horizontal_ratio), surface.position.y - vertical_offset),
			minimum_x,
			maximum_x,
			role,
			rank,
			family,
			spawn_index,
			archetype
		)


func _spawn_enemy(
	spawn_position: Vector2,
	patrol_left: float,
	patrol_right: float,
	role: int,
	rank: int = ENEMY_RANK_NORMAL,
	family: int = ENEMY_FAMILY_SLIME,
	spawn_order: int = -1,
	archetype: int = ENEMY_ARCHETYPE_STANDARD
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
	if archetype != ENEMY_ARCHETYPE_STANDARD:
		enemy.name = "%s_%s" % [_get_enemy_archetype_node_prefix(archetype), enemy.name]
	enemy.position = spawn_position
	var combat_profile: Dictionary = _get_combat_profile()
	var behavior_profile: Dictionary = (
		combat_profile.get("behavior", {}) as Dictionary
	).duplicate(true)
	var resolved_spawn_order: int = _enemies.size() if spawn_order < 0 else spawn_order
	behavior_profile["engagement_delay"] = (
		float(behavior_profile.get("engagement_stagger", 0.0))
		* float(resolved_spawn_order)
	)
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
		_get_difficulty_aggression_multiplier(),
		behavior_profile,
		archetype
	)
	if (
		_current_objective == RoomObjective.ELITE_HUNT
		and rank == ENEMY_RANK_ELITE
		and not is_instance_valid(_hunt_target)
	):
		_hunt_target = enemy
		enemy.name = "HuntCaptain_%s" % enemy.name
	enemy.set_target(player)
	enemy.defeated.connect(_on_enemy_defeated.bind(enemy))
	enemy.projectile_requested.connect(_on_enemy_projectile_requested.bind(enemy))
	enemy.sound_requested.connect(_on_enemy_sound_requested)
	if rank == ENEMY_RANK_BOSS:
		enemy.health_changed.connect(_on_boss_health_changed)
		enemy.boss_phase_changed.connect(_on_boss_phase_changed)
		_boss_enemy = enemy
	add_child(enemy)
	_enemies.append(enemy)
	if rank == ENEMY_RANK_BOSS:
		_hud_presenter.set_boss_visible(true)
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
	var escort_count: int = int(_current_combat_profile.get("boss_escort_count", 0))
	if escort_count <= 0:
		return
	var escort_family: int = (
		ENEMY_FAMILY_GOBLIN if family == ENEMY_FAMILY_SLIME else ENEMY_FAMILY_SLIME
	)
	var escort_roles: Array[int] = [
		ENEMY_ROLE_MELEE,
		ENEMY_ROLE_RANGED,
		ENEMY_ROLE_MELEE,
	]
	var escort_ratios: Array[float] = [0.24, 0.86, 0.46]
	for escort_index in range(mini(escort_count, escort_roles.size())):
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
			escort_family,
			escort_index + 1
		)


func _clear_enemies() -> void:
	for enemy in _enemies:
		if is_instance_valid(enemy):
			enemy.queue_free()
	_enemies.clear()
	_boss_enemy = null
	if _hud_presenter != null:
		_hud_presenter.set_boss_visible(false)


func _on_player_attack_hit(origin: Vector2, facing: float) -> void:
	if not _flow_state.run_active:
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
			_apply_hitstop(enemy, false)
			_spawn_hit_vfx(enemy.global_position, facing, enemy, 1.0, damage_amount)


func _on_player_skill_hit(
	origin: Vector2,
	facing: float,
	damage: int,
	reach_scale: float
) -> void:
	if not _flow_state.run_active:
		return
	for enemy: RogueEnemy in _enemies.duplicate():
		if not is_instance_valid(enemy):
			_enemies.erase(enemy)
			continue
		if enemy.receive_player_weapon_skill(
			origin,
			facing,
			damage,
			reach_scale,
			player.get_weapon_id(),
			player.get_skill_hit_index(),
			player.get_skill_hit_count()
		):
			var impact_facing := signf(enemy.global_position.x - origin.x)
			if is_zero_approx(impact_facing):
				impact_facing = facing
			_apply_hitstop(enemy, true)
			_spawn_hit_vfx(
				enemy.global_position,
				impact_facing,
				enemy,
				player.get_skill_impact_scale(),
				damage
			)


func _on_enemy_defeated(enemy: RogueEnemy) -> void:
	if not _enemies.has(enemy):
		return
	if is_instance_valid(_soundscape):
		_soundscape.play_enemy_defeat(enemy.is_boss())
	_spawn_defeat_vfx(enemy.global_position, enemy)
	_gold += enemy.get_gold_reward()
	_run_shards += enemy.get_essence_reward()
	if _current_objective == RoomObjective.ELITE_HUNT and enemy == _hunt_target:
		_objective_resolved = true
		_grant_objective_reward()
		_set_status("HUNT CAPTAIN DEFEATED | clear the remaining escorts")
		queue_redraw()
	if enemy.is_boss():
		if _telemetry != null:
			_telemetry.record_boss_defeat()
		_hud_presenter.set_boss_visible(false)
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
	if (
		not _flow_state.run_active
		or _flow_state.choosing_upgrade
		or _flow_state.run_complete
		or not _enemies.is_empty()
	):
		return
	if _current_objective == RoomObjective.HOLDOUT and not _objective_resolved:
		_set_status(_get_objective_status_text())
		return
	var resolved_risk_ambush: bool = _flow_state.risk_ambush_active
	_set_run_phase(RunFlowState.Phase.ROOM_LOADING)
	_clear_projectiles()
	if _current_encounter == EncounterType.TREASURE and not _flow_state.awaiting_chest:
		_spawn_reward_chest()
		return
	if _current_encounter == EncounterType.RISK_CHEST and resolved_risk_ambush:
		_gold += _pending_risk_gold
		var restored_health: int = player.heal(_pending_risk_heal)
		_set_status("风险挑战完成：金币 +%d，生命恢复 %d" % [
			_pending_risk_gold,
			restored_health,
		])
		_pending_risk_gold = 0
		_pending_risk_heal = 0
		_update_economy_hud()
	if _current_objective == RoomObjective.TIME_TRIAL and not _objective_failed:
		_grant_objective_reward()
	player.set_input_enabled(false)
	if _current_room_index >= _room_sequence.size() - 1:
		_complete_run()
	else:
		_begin_room_exit()


func _begin_room_exit() -> void:
	if _current_room_index >= _room_sequence.size() - 1:
		_complete_run()
		return
	if _flow_state.awaiting_exit:
		return
	_clear_room_exit_portal()
	var exit_surface: Rect2 = (
		platform_rects[0]
		if not platform_rects.is_empty()
		else Rect2(900.0, 640.0, 220.0, 48.0)
	)
	var best_score: float = 100000.0
	for surface in platform_rects:
		var score: float = (
			absf(surface.get_center().x - 960.0)
			+ absf(surface.position.y - 590.0) * 0.28
		)
		if score < best_score:
			best_score = score
			exit_surface = surface
	var exit_x: float = clampf(exit_surface.get_center().x, 120.0, WORLD_SIZE.x - 120.0)
	_room_exit_portal = ROOM_EXIT_PORTAL_SCRIPT.new() as RoomExitPortal
	_room_exit_portal.name = "RoomExitPortal"
	_room_exit_portal.position = Vector2(exit_x, exit_surface.position.y - 24.0)
	_room_exit_portal.z_index = 3
	_room_exit_portal.setup("%s 进入下一房" % _get_action_prompt(&"interact"))
	add_child(_room_exit_portal)
	_room_exit_portal.set_opener_position(player.global_position)
	_set_run_phase(RunFlowState.Phase.EXIT_PORTAL)
	player.set_input_enabled(true)
	_set_status("清房完成——走近光柱，按 %s 进入下一房" % _get_action_prompt(&"interact"))
	_update_controls()
	_persist_continue_snapshot()


func _activate_room_exit() -> bool:
	if (
		not _flow_state.awaiting_exit or _is_game_paused
		or _settings_overlay.visible or not is_instance_valid(_room_exit_portal)
		or not _room_exit_portal.is_in_range(player.global_position)
	):
		return false
	_set_run_phase(RunFlowState.Phase.ROOM_LOADING)
	player.set_input_enabled(false)
	if is_instance_valid(_room_exit_portal):
		_room_exit_portal.play_activation()
	if is_instance_valid(_soundscape):
		_soundscape.play_portal()
	_set_status("穿过月蚀之门——准备选择强化")
	var expected_generation: int = _run_generation
	get_tree().create_timer(0.22).timeout.connect(_finish_room_exit.bind(expected_generation))
	return true


func _finish_room_exit(expected_generation: int) -> void:
	if expected_generation != _run_generation or _flow_state.phase != RunFlowState.Phase.ROOM_LOADING:
		return
	_clear_room_exit_portal()
	_show_upgrade_choice()


func _show_upgrade_choice() -> void:
	_upgrade_choices = _pick_upgrade_choices()
	if _upgrade_choices.size() < 3:
		push_error("Upgrade pool did not provide three choices")
		return
	if _telemetry != null:
		_telemetry.record_upgrade_offers(_upgrade_choices, player.get_weapon_id())
	_set_run_phase(RunFlowState.Phase.UPGRADE)
	_upgrade_overlay.visible = true
	_upgrade_title.text = "房间已清理——选择一项强化"
	_refresh_choice_overlay_prompts()
	_play_upgrade_overlay_intro()
	_ensure_context_focus()
	_update_controls()
	_persist_continue_snapshot()


func _show_shop() -> void:
	_set_run_phase(RunFlowState.Phase.SHOP)
	_upgrade_choices = UPGRADE_SERVICE_SCRIPT.create_shop_offers(
		player.get_weapon_id(),
		player.get_run_upgrade_counts(),
		_rng
	)
	if _telemetry != null:
		_telemetry.record_upgrade_offers(_upgrade_choices, player.get_weapon_id())
	_upgrade_overlay.visible = true
	_upgrade_title.text = "星尘旅商——购买一项强化"
	_refresh_choice_overlay_prompts()
	_play_upgrade_overlay_intro()
	_ensure_context_focus()
	_set_status("旅商已抵达——当前拥有 %d 金币" % _gold)
	_update_controls()
	_persist_continue_snapshot()


func _show_event_choice() -> void:
	_set_run_phase(RunFlowState.Phase.EVENT)
	_upgrade_choices = EVENT_CATALOG_SCRIPT.create_choices()
	_upgrade_overlay.visible = true
	_upgrade_title.text = "月蚀奇遇——每项回应都有代价"
	_refresh_choice_overlay_prompts()
	_play_upgrade_overlay_intro()
	_ensure_context_focus()
	_set_status("发现月蚀遗迹——选择一种回应，每项都有代价")
	_update_controls()
	_persist_continue_snapshot()


func _refresh_choice_overlay_prompts() -> void:
	if (
		not is_instance_valid(_upgrade_overlay)
		or not _upgrade_overlay.visible
		or not is_instance_valid(_upgrade_hint)
	):
		return
	if _flow_state.run_complete:
		_upgrade_hint.text = "已通过 %d 个房间。按 %s 开启随机新一局" % [
			ROOMS_PER_RUN,
			_get_action_prompt(&"restart"),
		]
		return
	if not _flow_state.choosing_upgrade or _upgrade_choices.size() < _upgrade_buttons.size():
		return

	var shortcut_labels: Array[String] = []
	for choice_index in range(_upgrade_buttons.size()):
		shortcut_labels.append(
			CHOICE_CONTROLLER_LABELS[choice_index]
			if _using_controller_input
			else str(choice_index + 1)
		)
	if _using_controller_input:
		_upgrade_hint.text = (
			"X / Y / B 直接购买 · 左摇杆或十字键切换 · A 确认 · %s 离开"
			% _get_action_prompt(&"interact")
			if _flow_state.shopping
			else "X / Y / B 直接选牌 · 左摇杆或十字键切换 · A 确认"
		)
	elif _flow_state.shopping:
		_upgrade_hint.text = "金币不足时按 %s 离开；数字键 1 / 2 / 3 购买" % _get_action_prompt(&"interact")
	elif _flow_state.event_active:
		_upgrade_hint.text = "事件不会触发战斗；点击卡片，或按数字键 1 / 2 / 3"
	else:
		_upgrade_hint.text = "点击卡片，或按数字键 1 / 2 / 3"

	for choice_index in range(_upgrade_buttons.size()):
		var button: Button = _upgrade_buttons[choice_index]
		var choice: Dictionary = _upgrade_choices[choice_index]
		var shortcut: String = shortcut_labels[choice_index]
		var rarity_name: String = String(choice.get("rarity_name", "普通"))
		var card_name: String = String(choice.get("name", "强化"))
		var description: String = String(choice.get("description", ""))
		var footer_text: String = "选择此遗物"
		button.visible = true
		if _flow_state.shopping:
			var cost: int = int(choice.get("cost", 0))
			button.disabled = _gold < cost
			footer_text = (
				"金币不足  ·  需要 %d" % cost
				if button.disabled
				else "购买此商品  ·  %d 金币" % cost
			)
		elif _flow_state.event_active:
			button.disabled = false
			rarity_name = "事件"
			footer_text = "选择此回应"
		else:
			button.disabled = false
		_set_upgrade_card_content(
			button,
			shortcut,
			rarity_name,
			card_name,
			description,
			footer_text
		)
		_style_upgrade_card(button, choice)


func _pick_upgrade_choices() -> Array[Dictionary]:
	return UPGRADE_SERVICE_SCRIPT.pick_choices(
		player.get_weapon_id(),
		player.get_run_upgrade_counts(),
		_rng
	)


func _on_upgrade_button_pressed(choice_index: int) -> void:
	choose_upgrade(choice_index)


func choose_upgrade(choice_index: int) -> bool:
	if (
		not _flow_state.choosing_upgrade
		or choice_index < 0
		or choice_index >= _upgrade_choices.size()
	):
		return false
	if is_instance_valid(_soundscape):
		_soundscape.play_ui()
	if _flow_state.event_active:
		return _resolve_event_choice(choice_index)
	var choice: Dictionary = _upgrade_choices[choice_index]
	if _flow_state.shopping:
		var cost: int = int(choice.get("cost", 0))
		if _gold < cost:
			_set_status("金币不足：需要 %d，当前 %d" % [cost, _gold])
			return false
		_gold -= cost
	var upgrade_id: StringName = choice.get("id", &"")
	if not player.apply_run_upgrade(upgrade_id):
		return false
	_refresh_build_overview()
	if _telemetry != null:
		_telemetry.record_upgrade_choice(upgrade_id, player.get_weapon_id())
	_last_upgrade_name = String(choice.get("name", "强化"))
	_set_run_phase(RunFlowState.Phase.ROOM_LOADING)
	_upgrade_choices.clear()
	_hide_upgrade_overlay()
	_update_economy_hud()
	_advance_to_next_room()
	return true


func _resolve_event_choice(choice_index: int) -> bool:
	if not _flow_state.event_active or choice_index < 0 or choice_index >= _upgrade_choices.size():
		return false
	var choice: Dictionary = _upgrade_choices[choice_index]
	var amount: int = int(choice.get("amount", 0))
	var effect: StringName = choice.get("effect", &"")
	match effect:
		&"rest", &"heal":
			player.heal(int(choice.get("heal", amount)))
			_gold = maxi(0, _gold + int(choice.get("gold", 0)))
		&"gold":
			_gold += amount
			player.apply_event_cost(int(choice.get("damage", 0)))
		&"shards":
			_run_shards += amount
			player.heal(int(choice.get("heal", 12)))
			player.apply_max_health_delta(int(choice.get("max_health", 0)))
		_:
			return false
	_last_upgrade_name = String(choice.get("name", "奇遇"))
	_set_run_phase(RunFlowState.Phase.ROOM_LOADING)
	_upgrade_choices.clear()
	_hide_upgrade_overlay()
	_update_economy_hud()
	_advance_to_next_room()
	return true


func _leave_shop() -> void:
	if not _flow_state.shopping:
		return
	_last_upgrade_name = "未购物"
	_set_run_phase(RunFlowState.Phase.ROOM_LOADING)
	_upgrade_choices.clear()
	_hide_upgrade_overlay()
	_advance_to_next_room()


func _complete_run() -> void:
	if _flow_state.run_complete:
		return
	_set_run_phase(RunFlowState.Phase.COMPLETE)
	if _telemetry != null:
		_telemetry.finish_run(true, player.get_weapon_id(), &"victory")
	_clear_projectiles()
	player.set_input_enabled(false)
	_upgrade_overlay.visible = true
	_upgrade_title.text = "本局完成"
	_refresh_choice_overlay_prompts()
	for button in _upgrade_buttons:
		button.visible = false
	_play_upgrade_overlay_intro()
	var unlocked_names: String = _bank_run_progress(true)
	_clear_continue_snapshot()
	_set_status("胜利——首领已击败，本局星屑已结算%s" % unlocked_names)
	_update_economy_hud()
	_update_controls()
	_update_room_label()


func _hide_upgrade_overlay() -> void:
	if _upgrade_tween != null and _upgrade_tween.is_valid():
		_upgrade_tween.kill()
	if is_instance_valid(_upgrade_overlay):
		_upgrade_overlay.visible = false
	for button in _upgrade_buttons:
		button.disabled = true


func _spawn_reward_chest() -> void:
	_clear_chest()
	if platform_rects.is_empty():
		_begin_room_exit()
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
		_get_action_prompt(&"interact")
	)
	_chest.opened.connect(_on_chest_opened)
	add_child(_chest)
	_set_run_phase(RunFlowState.Phase.CHEST)
	player.set_input_enabled(true)
	_set_status("宝藏已出现——跟随宝箱上方提示")
	_update_controls()


func _spawn_risk_chest() -> void:
	_clear_chest()
	if platform_rects.is_empty():
		_begin_room_exit()
		return
	var chest_surface: Rect2 = platform_rects[0]
	for surface in platform_rects:
		if surface.position.x <= 640.0 and surface.end.x >= 640.0:
			chest_surface = surface
			break
	var chest_x: float = clampf(640.0, chest_surface.position.x + 42.0, chest_surface.end.x - 42.0)
	_chest = CHEST_SCRIPT.new() as RewardChest
	_chest.name = "RiskChest"
	_chest.position = Vector2(chest_x, chest_surface.position.y - 27.0)
	_chest.setup(
		42,
		28,
		_get_action_prompt(&"interact"),
		true
	)
	_chest.opened.connect(_on_chest_opened)
	add_child(_chest)
	_set_run_phase(RunFlowState.Phase.CHEST)
	player.set_input_enabled(true)
	_update_controls()


func _open_current_chest() -> bool:
	if not _flow_state.awaiting_chest or not is_instance_valid(_chest):
		return false
	return _chest.try_open(player.global_position)


func open_current_chest_for_test() -> bool:
	if not _flow_state.awaiting_chest or not is_instance_valid(_chest):
		return false
	return _chest.force_open()


func _on_chest_opened(gold_reward: int, heal_reward: int) -> void:
	if not _flow_state.awaiting_chest:
		return
	if is_instance_valid(_soundscape):
		_soundscape.play_chest()
	if _current_encounter == EncounterType.RISK_CHEST:
		_pending_risk_gold = gold_reward
		_pending_risk_heal = heal_reward
		_set_run_phase(RunFlowState.Phase.RISK_AMBUSH)
		player.set_input_enabled(true)
		_spawn_risk_ambush()
		_set_status("风险宝箱触发伏兵——清除全部敌人领取奖励")
		_update_controls()
		return
	_gold += gold_reward
	_set_run_phase(RunFlowState.Phase.ROOM_LOADING)
	var restored_health: int = player.heal(heal_reward)
	player.set_input_enabled(false)
	_set_status("宝箱：金币 +%d，生命恢复 %d" % [gold_reward, restored_health])
	_update_economy_hud()
	call_deferred(&"_begin_room_exit")


func _spawn_risk_ambush() -> void:
	if platform_rects.is_empty():
		call_deferred(&"_on_room_cleared")
		return
	var ambush_count: int = int(_current_combat_profile.get("risk_ambush_count", 4))
	var elite_slots: int = int(_current_combat_profile.get("elite_slots", 1))
	for ambush_index in range(ambush_count):
		var surface_index: int = posmod(ambush_index * 2 + _current_room_index, platform_rects.size())
		var surface: Rect2 = platform_rects[surface_index]
		var minimum_x: float = surface.position.x + 42.0
		var maximum_x: float = surface.end.x - 42.0
		if maximum_x <= minimum_x:
			continue
		var role: int = ENEMY_ROLE_RANGED if ambush_index % 3 == 2 else ENEMY_ROLE_MELEE
		var rank: int = ENEMY_RANK_ELITE if ambush_index < elite_slots else ENEMY_RANK_NORMAL
		var family: int = _get_enemy_family_for_spawn(_current_room_index, ambush_index)
		var ratio: float = 0.22 + float(posmod(ambush_index * 37, 57)) / 100.0
		var vertical_offset: float = 28.0 if rank == ENEMY_RANK_ELITE else 22.0
		_spawn_enemy(
			Vector2(lerpf(minimum_x, maximum_x, ratio), surface.position.y - vertical_offset),
			minimum_x,
			maximum_x,
			role,
			rank,
			family,
			ambush_index
		)
	if _enemies.is_empty():
		call_deferred(&"_on_room_cleared")


func _clear_chest() -> void:
	if is_instance_valid(_chest):
		_chest.queue_free()
	_chest = null


func _clear_room_exit_portal() -> void:
	if is_instance_valid(_room_exit_portal):
		_room_exit_portal.queue_free()
	_room_exit_portal = null


func _on_enemy_projectile_requested(
	origin: Vector2,
	projectile_velocity: Vector2,
	damage: int,
	projectile_style: int,
	source_enemy: RogueEnemy = null
) -> void:
	if not _flow_state.run_active:
		return
	var projectile: Area2D = ENEMY_PROJECTILE_SCRIPT.new() as Area2D
	add_child(projectile)
	projectile.global_position = origin
	var damage_cause: StringName = &"enemy_projectile"
	if is_instance_valid(source_enemy):
		if source_enemy.is_boss():
			damage_cause = &"boss_volley"
		elif source_enemy.get_enemy_family() == RogueEnemy.EnemyFamily.GOBLIN:
			damage_cause = &"goblin_arrow"
		else:
			damage_cause = &"slime_projectile"
	projectile.call(
		&"setup",
		projectile_velocity,
		damage,
		player,
		projectile_style,
		damage_cause
	)
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
	if _hud_presenter != null:
		_hud_presenter.update_health(current_health, maximum_health)


func _on_player_damage_received(amount: int, cause: StringName) -> void:
	if _telemetry != null:
		_telemetry.record_damage(amount, cause)


func _update_lives_hud() -> void:
	if _hud_presenter != null:
		_hud_presenter.update_lives(
			_lives_remaining,
			MAX_RUN_LIVES,
			get_selected_difficulty_name()
		)


func _set_status(message: String) -> void:
	if _hud_presenter != null:
		_hud_presenter.set_status(message)


func _on_boss_health_changed(current_health: int, maximum_health: int) -> void:
	var boss_name: String = "赤晶史莱姆王"
	if is_instance_valid(_boss_enemy) and _boss_enemy.get_enemy_family() == ENEMY_FAMILY_GOBLIN:
		boss_name = "赤牙战争酋长"
	var boss_phase: int = _boss_enemy.get_boss_phase() if is_instance_valid(_boss_enemy) else 1
	if _hud_presenter != null:
		_hud_presenter.update_boss(current_health, maximum_health, boss_name, boss_phase)


func _on_boss_phase_changed(phase: int) -> void:
	var phase_name: String = "狂暴阶段" if phase >= 3 else "强化阶段"
	_set_status("首领进入%s——观察地面与瞄准预警" % phase_name)
	_trigger_camera_shake(13.0 if phase >= 3 else 9.0, 0.18)


func _on_player_died() -> void:
	if _flow_state.death_restart_pending:
		return
	if _telemetry != null:
		var death_reason: StringName = player.get_last_death_reason()
		_telemetry.record_death(death_reason)
		_telemetry.finish_run(false, player.get_weapon_id(), death_reason)
	_set_run_phase(RunFlowState.Phase.DEATH_RESTART)
	_lives_remaining = maxi(0, _lives_remaining - 1)
	player.set_input_enabled(false)
	_clear_chest()
	_clear_room_exit_portal()
	_clear_projectiles()
	_hide_upgrade_overlay()
	if is_instance_valid(_tutorial):
		_tutorial.hide_lesson()
	var unlocked_names: String = _bank_run_progress(false)
	_clear_continue_snapshot()
	_present_death_recap(unlocked_names)
	_update_economy_hud()
	_update_controls()
	_update_lives_hud()
	_set_status("战败 — 剩余命数 %d / %d" % [_lives_remaining, MAX_RUN_LIVES])
	_update_music_state()
	var expected_generation: int = _run_generation
	get_tree().create_timer(DEATH_RESTART_DELAY).timeout.connect(
		_finish_death_sequence.bind(expected_generation)
	)


func _restart_run_after_death(expected_generation: int) -> void:
	if not _flow_state.death_restart_pending or expected_generation != _run_generation:
		return
	_start_new_run()


func _finish_death_sequence(expected_generation: int) -> void:
	if not _flow_state.death_restart_pending or expected_generation != _run_generation:
		return
	if is_instance_valid(_death_recap):
		_death_recap.hide_recap()
	if _lives_remaining > 0:
		_start_new_run()
		return
	_set_run_phase(RunFlowState.Phase.IDLE)
	_clear_chest()
	_clear_room_exit_portal()
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
	if _hud_presenter == null:
		return
	var room_title: String = _current_room_data.get("title", "未知房间")
	var chapter_name: String = _get_chapter_name(_current_room_index)
	_hud_presenter.update_room(
		not _current_room_data.is_empty(),
		_flow_state.run_complete,
		_run_number,
		_run_seed,
		_current_room_index + 1,
		ROOMS_PER_RUN,
		_get_encounter_name(_current_encounter),
		chapter_name,
		room_title
	)


func _update_economy_hud() -> void:
	if _hud_presenter == null or _progression == null:
		return
	_hud_presenter.update_economy(
		_gold,
		_progression.get_meta_shards(),
		_run_shards
	)


func _update_equipment_hud() -> void:
	if _hud_presenter == null or _progression == null:
		return
	_hud_presenter.update_equipment(player, _progression)


func _update_ability_hud() -> void:
	if _hud_presenter == null or _settings == null:
		return
	_hud_presenter.update_abilities(player, {
		"attack": _get_action_prompt(&"attack"),
		"dash": _get_action_prompt(&"dash"),
		"skill": _get_action_prompt(&"skill"),
		"aim_up": _get_action_prompt(&"aim_up"),
		"aim_down": _get_action_prompt(&"aim_down"),
		"cycle_weapon": _get_action_prompt(&"cycle_weapon"),
	})


func _cycle_weapon() -> void:
	if _progression == null or _flow_state.choosing_upgrade or player.is_dead():
		return
	var unlocked: Array[StringName] = _progression.get_unlocked_weapons()
	if unlocked.size() <= 1:
		_set_status("尚未解锁其他武器；击败精英并完成更多轮次可解锁")
		return
	var current_index: int = unlocked.find(player.get_weapon_id())
	var next_index: int = posmod(current_index + 1, unlocked.size())
	var next_weapon: StringName = unlocked[next_index]
	if player.configure_weapon(next_weapon):
		_progression.select_weapon(next_weapon)
		if save_enabled:
			_progression.save_progress()
		_set_status("切换武器：%s" % player.get_weapon_name())
		_update_equipment_hud()
		_refresh_build_overview()


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
	if room_index >= 0 and room_index < _encounter_sequence.size():
		return _encounter_sequence[room_index]
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


func _get_enemy_archetype_for_spawn(
	room_index: int,
	spawn_index: int,
	role: int,
	rank: int,
	family: int
) -> int:
	if rank != ENEMY_RANK_NORMAL or room_index < GOBLIN_CHAPTER_START:
		return ENEMY_ARCHETYPE_STANDARD
	var pattern: int = posmod(room_index * 17 + spawn_index * 11 + role * 5 + family * 3, 9)
	if (
		room_index >= FINAL_CHAPTER_START
		and role == ENEMY_ROLE_MELEE
		and pattern <= 2
	):
		return ENEMY_ARCHETYPE_AMBUSHER
	if (
		room_index >= MIXED_CHAPTER_START
		and role == ENEMY_ROLE_RANGED
		and family == ENEMY_FAMILY_GOBLIN
		and pattern <= 3
	):
		return ENEMY_ARCHETYPE_CASTER
	if (
		room_index >= MIXED_CHAPTER_START
		and role == ENEMY_ROLE_RANGED
		and family == ENEMY_FAMILY_SLIME
		and pattern <= 3
	):
		return ENEMY_ARCHETYPE_FLYER
	if family == ENEMY_FAMILY_GOBLIN and role == ENEMY_ROLE_MELEE and pattern <= 3:
		return ENEMY_ARCHETYPE_SHIELD_GUARD
	return ENEMY_ARCHETYPE_STANDARD


func _get_enemy_archetype_node_prefix(archetype: int) -> String:
	match archetype:
		ENEMY_ARCHETYPE_SHIELD_GUARD:
			return "ShieldGuard"
		ENEMY_ARCHETYPE_FLYER:
			return "Flyer"
		ENEMY_ARCHETYPE_CASTER:
			return "Caster"
		ENEMY_ARCHETYPE_AMBUSHER:
			return "Ambusher"
	return "Standard"


func _get_room_reinforcement_count(room_index: int) -> int:
	var profile: Dictionary = COMBAT_BUDGET_SCRIPT.create_profile(
		_selected_difficulty,
		room_index,
		_current_encounter
	)
	return int(profile.get("candidate_reinforcements", 0))


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
		EncounterType.EVENT:
			return "事件房"
		EncounterType.CHALLENGE:
			return "挑战房"
		EncounterType.RISK_CHEST:
			return "风险宝箱"
		EncounterType.HOLDOUT:
			return "Holdout"
		_:
			return "战斗房"


func get_room_sequence_ids() -> Array[StringName]:
	var room_ids: Array[StringName] = []
	for pool_index in _room_sequence:
		var room: Dictionary = _room_pool[pool_index]
		var room_id: StringName = room.get("id", &"")
		room_ids.append(room_id)
	return room_ids


func set_next_run_seed(seed_value: int) -> void:
	_next_run_seed = clampi(absi(seed_value), 1, 999999)


func get_run_seed() -> int:
	return _run_seed


func get_encounter_sequence() -> Array[int]:
	return _encounter_sequence.duplicate()


func get_current_room_number() -> int:
	return _current_room_index + 1


func is_choosing_upgrade() -> bool:
	return _flow_state.choosing_upgrade


func is_run_complete() -> bool:
	return _flow_state.run_complete


func get_upgrade_choices() -> Array[Dictionary]:
	return _upgrade_choices.duplicate(true)


func is_awaiting_chest() -> bool:
	return _flow_state.awaiting_chest


func is_awaiting_exit() -> bool:
	return _flow_state.awaiting_exit


func is_shopping() -> bool:
	return _flow_state.shopping


func is_event_active() -> bool:
	return _flow_state.event_active


func is_risk_ambush_active() -> bool:
	return _flow_state.risk_ambush_active


func get_run_flow_snapshot() -> Dictionary:
	return _flow_state.snapshot()


func get_gold() -> int:
	return _gold


func get_current_encounter_name() -> String:
	return _get_encounter_name(_current_encounter)


func get_current_objective_name() -> String:
	match _current_objective:
		RoomObjective.TIME_TRIAL:
			return "time_trial"
		RoomObjective.HOLDOUT:
			return "holdout"
		RoomObjective.ELITE_HUNT:
			return "elite_hunt"
		RoomObjective.BRANCH_REWARD:
			return "branch_reward"
	return "clear_all"


func get_room_objective_snapshot() -> Dictionary:
	return {
		"objective": get_current_objective_name(),
		"timer_remaining": _objective_timer_remaining,
		"hold_progress": _objective_hold_progress,
		"hold_duration": _objective_hold_duration,
		"resolved": _objective_resolved,
		"failed": _objective_failed,
		"reward_granted": _objective_reward_granted,
		"trap_count": _objective_trap_zones.size(),
		"has_hunt_target": is_instance_valid(_hunt_target),
	}


func complete_room_objective_for_test() -> bool:
	if _current_objective != RoomObjective.HOLDOUT:
		return true
	if _objective_hold_duration <= 0.0:
		return false
	_objective_hold_progress = _objective_hold_duration
	_objective_resolved = true
	_grant_objective_reward()
	if _enemies.is_empty():
		call_deferred(&"_on_room_cleared")
	return true


func get_current_combat_profile() -> Dictionary:
	return _get_combat_profile().duplicate(true)


func open_build_overview_for_test() -> bool:
	_open_build_overview(false)
	return is_instance_valid(_build_overview) and _build_overview.visible


func close_build_overview_for_test() -> bool:
	_close_build_overview()
	return not is_instance_valid(_build_overview) or not _build_overview.visible


func get_build_overview_snapshot() -> Dictionary:
	if not is_instance_valid(_build_overview):
		return {}
	return _build_overview.get_snapshot()


func get_progression_snapshot() -> Dictionary:
	return _progression.get_snapshot() if _progression != null else {}


func get_run_telemetry_snapshot() -> Dictionary:
	return _telemetry.get_current_run_snapshot() if _telemetry != null else {}


func get_run_telemetry_summary() -> Dictionary:
	return _telemetry.get_summary() if _telemetry != null else {}


func get_death_recap_snapshot() -> Dictionary:
	if not is_instance_valid(_death_recap):
		return {}
	return _death_recap.get_snapshot()


func get_tutorial_snapshot() -> Dictionary:
	if not is_instance_valid(_tutorial):
		return {}
	return _tutorial.get_snapshot()


func get_music_state() -> int:
	if not is_instance_valid(_soundscape):
		return RogueSoundscape.MusicState.MENU
	return _soundscape.get_music_state()


func has_continue_snapshot() -> bool:
	return _has_continue_snapshot()


func persist_continue_snapshot_for_test() -> bool:
	_persist_continue_snapshot()
	return _has_continue_snapshot()


func continue_saved_run_for_test() -> bool:
	return _continue_saved_run()


func _create_death_recap() -> void:
	_death_recap = DEATH_RECAP_SCRIPT.new()
	hud.add_child(_death_recap)


func _create_tutorial() -> void:
	_tutorial = TUTORIAL_SCRIPT.new()
	hud.add_child(_tutorial)


func _present_death_recap(unlocked_names: String) -> void:
	if not is_instance_valid(_death_recap):
		return
	var telemetry_snapshot: Dictionary = (
		_telemetry.get_current_run_snapshot() if _telemetry != null else {}
	)
	# finish_run already cleared current telemetry; use the last history entry.
	if telemetry_snapshot.is_empty() and _telemetry != null:
		var history: Array = _telemetry.get_history()
		if not history.is_empty() and history.back() is Dictionary:
			telemetry_snapshot = history.back() as Dictionary
	var current_room: Dictionary = telemetry_snapshot.get("current_room", {}) as Dictionary
	if current_room.is_empty():
		var rooms: Array = telemetry_snapshot.get("rooms", []) as Array
		if not rooms.is_empty() and rooms.back() is Dictionary:
			current_room = rooms.back() as Dictionary
	var reason: String = String(player.get_last_death_reason())
	if reason.is_empty():
		reason = String(current_room.get("death_reason", "unknown"))
	var hint: String = (
		"命数耗尽后将返回难度选择%s"
		% unlocked_names
		if _lives_remaining <= 0
		else "即将用剩余 %d 条命重开一条路线%s" % [_lives_remaining, unlocked_names]
	)
	_death_recap.present({
		"reason": reason,
		"room_title": String(current_room.get("room_title", _current_room_data.get("title", "未知房间"))),
		"encounter": String(current_room.get("encounter", _get_encounter_name(_current_encounter))),
		"room_number": int(current_room.get("room_number", _current_room_index + 1)),
		"lives_remaining": _lives_remaining,
		"room_damage": int(current_room.get("damage_taken", 0)),
		"run_damage": int(telemetry_snapshot.get("damage_taken", 0)),
		"elapsed_seconds": float(telemetry_snapshot.get("elapsed_seconds", 0.0)),
		"damage_sources": current_room.get("damage_sources", {}) as Dictionary,
	}, hint)


func _apply_hitstop(enemy: RogueEnemy, is_skill_hit: bool) -> void:
	if not is_instance_valid(player) or not is_instance_valid(enemy):
		return
	var duration: float = (
		RoguePlayer.HITSTOP_SKILL if is_skill_hit else RoguePlayer.HITSTOP_ATTACK
	)
	player.apply_hitstop(duration, enemy.is_boss())
	var enemy_duration: float = duration
	if enemy.is_boss():
		enemy_duration += RoguePlayer.HITSTOP_BOSS_BONUS
	if player.get_reduced_effects_enabled():
		enemy_duration *= 0.35
	enemy.apply_hitstop(enemy_duration)
	for other_enemy: RogueEnemy in _enemies:
		if other_enemy == enemy or not is_instance_valid(other_enemy):
			continue
		other_enemy.apply_hitstop(enemy_duration * 0.62)


func _update_music_state() -> void:
	if not is_instance_valid(_soundscape):
		return
	if _entry_flow_active or _flow_state.phase in [
		RunFlowState.Phase.IDLE,
		RunFlowState.Phase.COMPLETE,
		RunFlowState.Phase.DEATH_RESTART,
	]:
		_soundscape.set_music_state(RogueSoundscape.MusicState.MENU)
		return
	if _current_encounter == EncounterType.BOSS and _flow_state.run_active:
		_soundscape.set_music_state(RogueSoundscape.MusicState.BOSS)
		return
	if _flow_state.run_active:
		_soundscape.set_music_state(RogueSoundscape.MusicState.COMBAT)
		return
	_soundscape.set_music_state(RogueSoundscape.MusicState.EXPLORE)


func _maybe_begin_tutorial() -> void:
	if (
		not save_enabled
		or not is_instance_valid(_tutorial)
		or _progression == null
		or _progression.get_runs_completed() > 0
		or _current_room_index != 0
		or not _flow_state.run_active
	):
		if is_instance_valid(_tutorial):
			_tutorial.hide_lesson()
		return
	_tutorial.begin_lesson(
		_get_action_prompt(&"move_left") + " / " + _get_action_prompt(&"move_right"),
		_get_action_prompt(&"jump"),
		_get_action_prompt(&"attack")
	)


func _refresh_continue_button() -> void:
	if not is_instance_valid(_continue_button):
		return
	var snapshot: Dictionary = (
		_continue_store.get_snapshot() if _continue_store != null else {}
	)
	var has_continue: bool = _has_continue_snapshot()
	_continue_button.visible = has_continue and _entry_flow_active and _start_button.visible
	if has_continue:
		_continue_button.text = "继续第 %d 房 · %s" % [
			int(snapshot.get("room_index", 0)) + 1,
			WeaponCatalog.get_weapon_name(StringName(String(snapshot.get("weapon_id", "")))),
		]


func _has_continue_snapshot() -> bool:
	return _continue_store != null and _continue_store.has_snapshot()


func _clear_continue_snapshot() -> void:
	if _continue_store != null:
		_continue_store.clear_snapshot()
	_refresh_continue_button()


func _persist_continue_snapshot() -> void:
	if _continue_store == null:
		return
	if (
		_entry_flow_active
		or _flow_state.run_complete
		or _flow_state.death_restart_pending
		or _current_room_index < 0
		or _room_sequence.is_empty()
	):
		return
	var serialized_choices: Array = []
	for choice: Dictionary in _upgrade_choices:
		serialized_choices.append(choice.duplicate(true))
	var snapshot := {
		"version": 1,
		"seed": _run_seed,
		"rng_state": str(_rng.state),
		"difficulty": _selected_difficulty,
		"lives": _lives_remaining,
		"gold": _gold,
		"run_shards": _run_shards,
		"weapon_id": String(player.get_weapon_id()),
		"health": player.get_current_health(),
		"max_health": player.get_max_health(),
		"upgrade_counts": _stringify_upgrade_counts(player.get_run_upgrade_counts()),
		"room_index": _current_room_index,
		"room_sequence": _room_sequence.duplicate(),
		"encounter_sequence": _encounter_sequence.duplicate(),
		"room_data": _serialize_room_data(_current_room_data),
		"resume_phase": _flow_state.phase,
		"last_upgrade_name": _last_upgrade_name,
		"upgrade_choices": serialized_choices,
	}
	_continue_store.save_snapshot(snapshot)


func _stringify_upgrade_counts(counts: Dictionary) -> Dictionary:
	var packed: Dictionary = {}
	for key_value: Variant in counts.keys():
		packed[String(key_value)] = int(counts.get(key_value, 0))
	return packed


func _serialize_room_data(room_data: Dictionary) -> Dictionary:
	var platforms: Array = []
	for platform_value: Variant in room_data.get("platforms", []) as Array:
		var platform: Rect2 = platform_value
		platforms.append({
			"x": platform.position.x,
			"y": platform.position.y,
			"w": platform.size.x,
			"h": platform.size.y,
		})
	var enemies: Array = []
	for enemy_value: Variant in room_data.get("enemies", []) as Array:
		if enemy_value is Dictionary:
			enemies.append((enemy_value as Dictionary).duplicate(true))
	var accent: Color = room_data.get("accent", Color("#78bdc3"))
	return {
		"id": String(room_data.get("id", "unknown_room")),
		"title": String(room_data.get("title", "未知房间")),
		"accent": accent.to_html(false),
		"platforms": platforms,
		"enemies": enemies,
		"mirrored": bool(room_data.get("mirrored", false)),
	}


func _deserialize_room_data(serialized: Dictionary) -> Dictionary:
	var platforms: Array[Rect2] = []
	for platform_value: Variant in serialized.get("platforms", []) as Array:
		if not platform_value is Dictionary:
			continue
		var platform: Dictionary = platform_value as Dictionary
		platforms.append(Rect2(
			float(platform.get("x", 0.0)),
			float(platform.get("y", 0.0)),
			float(platform.get("w", 160.0)),
			float(platform.get("h", 28.0))
		))
	var enemies: Array[Dictionary] = []
	for enemy_value: Variant in serialized.get("enemies", []) as Array:
		if enemy_value is Dictionary:
			enemies.append((enemy_value as Dictionary).duplicate(true))
	return {
		"id": StringName(String(serialized.get("id", "unknown_room"))),
		"title": String(serialized.get("title", "未知房间")),
		"accent": Color("#%s" % String(serialized.get("accent", "78bdc3"))),
		"platforms": platforms,
		"enemies": enemies,
		"mirrored": bool(serialized.get("mirrored", false)),
	}


func _continue_saved_run() -> bool:
	if not _has_continue_snapshot():
		return false
	var snapshot: Dictionary = _continue_store.get_snapshot()
	_entry_flow_active = false
	if _entry_tween != null and _entry_tween.is_valid():
		_entry_tween.kill()
	_entry_overlay.visible = false
	if is_instance_valid(_death_recap):
		_death_recap.hide_recap()
	if is_instance_valid(_tutorial):
		_tutorial.hide_lesson()
	_run_generation += 1
	_run_number += 1
	_run_seed = int(snapshot.get("seed", 1))
	_rng.seed = _run_seed
	var rng_state_text := String(snapshot.get("rng_state", ""))
	if not rng_state_text.is_empty():
		_rng.state = rng_state_text.to_int()
	_selected_difficulty = clampi(int(snapshot.get("difficulty", Difficulty.MEDIUM)), Difficulty.EASY, Difficulty.HARD)
	_lives_remaining = clampi(int(snapshot.get("lives", MAX_RUN_LIVES)), 1, MAX_RUN_LIVES)
	_gold = maxi(0, int(snapshot.get("gold", 10)))
	_run_shards = maxi(0, int(snapshot.get("run_shards", 0)))
	_last_upgrade_name = String(snapshot.get("last_upgrade_name", ""))
	_room_sequence.clear()
	for room_index_value: Variant in snapshot.get("room_sequence", []) as Array:
		_room_sequence.append(int(room_index_value))
	_encounter_sequence.clear()
	for encounter_value: Variant in snapshot.get("encounter_sequence", []) as Array:
		_encounter_sequence.append(int(encounter_value))
	if _room_sequence.is_empty():
		return false
	_current_room_index = clampi(
		int(snapshot.get("room_index", 0)),
		0,
		_room_sequence.size() - 1
	)
	_hide_upgrade_overlay()
	_clear_chest()
	_clear_room_exit_portal()
	_clear_projectiles()
	_clear_enemies()
	_clear_platform_colliders()
	var weapon_id := StringName(String(snapshot.get("weapon_id", WeaponCatalog.SWORD)))
	player.set_input_enabled(false)
	player.configure_weapon(weapon_id)
	var restored_counts: Dictionary = {}
	var packed_counts: Dictionary = snapshot.get("upgrade_counts", {}) as Dictionary
	for key_value: Variant in packed_counts.keys():
		restored_counts[StringName(String(key_value))] = int(packed_counts.get(key_value, 0))
	player.restore_run_progression(restored_counts, int(snapshot.get("health", player.get_max_health())))
	var saved_max_health: int = int(snapshot.get("max_health", player.get_max_health()))
	player.apply_max_health_delta(saved_max_health - player.get_max_health())
	_hud_presenter.set_boss_visible(false)
	_current_room_data = _deserialize_room_data(snapshot.get("room_data", {}) as Dictionary)
	_current_encounter = _get_encounter_for_room(_current_room_index)
	_current_objective = _get_room_objective(_current_encounter)
	_current_combat_profile = _get_combat_profile()
	if _telemetry != null:
		_telemetry.begin_run(_run_seed, get_selected_difficulty_name(), player.get_weapon_id())
		_telemetry.begin_room(
			_current_room_index + 1,
			StringName(String(_current_room_data.get("id", "unknown_room"))),
			String(_current_room_data.get("title", "未知房间")),
			_get_encounter_name(_current_encounter)
		)
	platform_rects.clear()
	var room_platforms: Array = _current_room_data.get("platforms", []) as Array
	for platform_value in room_platforms:
		platform_rects.append(platform_value as Rect2)
	_create_platform_colliders()
	if not platform_rects.is_empty():
		player.set_base_ground_surface_y(platform_rects[0].position.y)
	player.enter_room(ROOM_PLAYER_SPAWN, 0)
	player.set_current_health(int(snapshot.get("health", player.get_current_health())))
	_configure_room_objective()
	var resume_phase: int = int(snapshot.get("resume_phase", RunFlowState.Phase.COMBAT))
	var saved_choices: Array = snapshot.get("upgrade_choices", []) as Array
	_upgrade_choices.clear()
	for choice_value: Variant in saved_choices:
		if choice_value is Dictionary:
			_upgrade_choices.append((choice_value as Dictionary).duplicate(true))
	if resume_phase == RunFlowState.Phase.UPGRADE and _upgrade_choices.size() >= 3:
		player.set_input_enabled(false)
		_set_run_phase(RunFlowState.Phase.UPGRADE)
		_upgrade_overlay.visible = true
		_upgrade_title.text = "房间已清理——选择一项强化"
		_refresh_choice_overlay_prompts()
		_play_upgrade_overlay_intro()
		_ensure_context_focus()
	elif resume_phase == RunFlowState.Phase.SHOP:
		player.set_input_enabled(false)
		if _upgrade_choices.is_empty():
			_show_shop()
		else:
			_set_run_phase(RunFlowState.Phase.SHOP)
			_upgrade_overlay.visible = true
			_upgrade_title.text = "星尘旅商——购买一项强化"
			_refresh_choice_overlay_prompts()
			_play_upgrade_overlay_intro()
			_ensure_context_focus()
	elif resume_phase == RunFlowState.Phase.EVENT:
		player.set_input_enabled(false)
		if _upgrade_choices.is_empty():
			_show_event_choice()
		else:
			_set_run_phase(RunFlowState.Phase.EVENT)
			_upgrade_overlay.visible = true
			_upgrade_title.text = "月蚀奇遇——每项回应都有代价"
			_refresh_choice_overlay_prompts()
			_play_upgrade_overlay_intro()
			_ensure_context_focus()
	elif resume_phase == RunFlowState.Phase.EXIT_PORTAL:
		_begin_room_exit()
	else:
		_spawn_room_enemies()
		player.set_input_enabled(true)
		if _current_encounter == EncounterType.RISK_CHEST:
			_set_run_phase(RunFlowState.Phase.CHEST)
		else:
			_set_run_phase(RunFlowState.Phase.COMBAT)
		_set_status("已继续本局路线——第 %d 房" % (_current_room_index + 1))
	_update_economy_hud()
	_update_controls()
	_update_room_label()
	_update_lives_hud()
	_refresh_build_overview()
	_update_music_state()
	return true


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
	_draw_room_objective_overlay()


func _draw_room_objective_overlay() -> void:
	if not _flow_state.run_active:
		return
	if _current_objective in [RoomObjective.TIME_TRIAL, RoomObjective.HOLDOUT]:
		for trap_zone: Rect2 in _objective_trap_zones:
			if _objective_resolved or _objective_failed:
				continue
			var firing: bool = _objective_trap_flash_remaining > 0.0
			var warning: bool = _objective_trap_pulse_remaining < 0.55
			var trap_color := Color("#ff8054") if firing or warning else Color("#b6795c")
			var floor_y: float = trap_zone.position.y + 44.0
			draw_rect(Rect2(trap_zone.position.x, floor_y - 4.0, trap_zone.size.x, 4.0), trap_color)
			for rune_index in range(4):
				var rune_x: float = trap_zone.position.x + 8.0 + rune_index * 17.0
				var height: float = 40.0 if firing else (14.0 if warning else 7.0)
				draw_colored_polygon(PackedVector2Array([
					Vector2(rune_x - 5.0, floor_y), Vector2(rune_x, floor_y - height),
					Vector2(rune_x + 5.0, floor_y),
				]), Color(trap_color, 0.85 if firing else 0.60))
			draw_string(ThemeDB.fallback_font, Vector2(trap_zone.position.x - 8.0, floor_y + 20.0),
				"周期陷阱", HORIZONTAL_ALIGNMENT_CENTER, trap_zone.size.x + 16.0, 13, Color("#ffc6a4"))
	if _current_objective == RoomObjective.HOLDOUT and _objective_radius > 0.0:
		var hold_ratio: float = (
			0.0
			if _objective_hold_duration <= 0.0
			else _objective_hold_progress / _objective_hold_duration
		)
		var beacon_color: Color = Color(0.34, 0.92, 1.0, 0.72)
		var ground_y: float = _objective_anchor.y + 17.0
		var start_x: float = _objective_anchor.x - _objective_radius
		draw_rect(Rect2(start_x, ground_y - 7.0, _objective_radius * 2.0, 7.0), Color(beacon_color, 0.18))
		draw_rect(Rect2(start_x, ground_y - 4.0, _objective_radius * 2.0 * hold_ratio, 4.0), beacon_color)
		for edge_x: float in [start_x, start_x + _objective_radius * 2.0]:
			draw_line(Vector2(edge_x, ground_y), Vector2(edge_x, ground_y - 12.0), beacon_color, 2.0)
		var caption_rect := Rect2(_objective_anchor + Vector2(-136.0, -112.0), Vector2(272.0, 52.0))
		draw_rect(caption_rect, Color("#071b29"))
		draw_rect(caption_rect, Color("#34758a"), false, 1.0)
		var caption: String = "守点完成 · 清理剩余敌人" if _objective_resolved else "守点符文  %d%%" % roundi(hold_ratio * 100.0)
		draw_string(ThemeDB.fallback_font, caption_rect.position + Vector2(8.0, 20.0), caption,
			HORIZONTAL_ALIGNMENT_CENTER, 256.0, 16, Color("#dbf8ff"))
		draw_string(ThemeDB.fallback_font, caption_rect.position + Vector2(8.0, 41.0),
			"站在青色区域占领 · 离开后暂停", HORIZONTAL_ALIGNMENT_CENTER, 256.0, 14, Color("#a7dfeb"))
	if _current_objective == RoomObjective.ELITE_HUNT and is_instance_valid(_hunt_target):
		var target_marker: Vector2 = to_local(_hunt_target.global_position) + Vector2(0.0, -74.0)
		var marker_color: Color = Color(1.0, 0.74, 0.28, 0.88)
		draw_colored_polygon(
			PackedVector2Array([
				target_marker + Vector2(0.0, -10.0),
				target_marker + Vector2(10.0, 0.0),
				target_marker + Vector2(0.0, 10.0),
				target_marker + Vector2(-10.0, 0.0),
			]),
			marker_color
		)
		draw_arc(target_marker, 15.0, 0.0, TAU, 18, marker_color, 1.8)
