extends Node

var journey: Node
var hud: CanvasLayer
var player: RoguePlayer
var _build_overview: RunBuildOverview
var _overview_from_pause := false

func setup(owner_scene: Node) -> void:
	journey = owner_scene
	hud = journey.campaign_hud
	player = journey.player
	_settings = journey.input_settings
	process_mode = Node.PROCESS_MODE_ALWAYS
	_create_pause_ui()
	_create_settings_ui()
	_build_overview = preload("res://scripts/run_build_overview.gd").new()
	_build_overview.name = "BuildOverview"
	hud.add_child(_build_overview)
	_build_overview.close_requested.connect(_close_build_overview)
	get_viewport().size_changed.connect(_fit_to_viewport)
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	_refresh_input_prompts()
	_fit_to_viewport()

func show_pause(visible_now: bool) -> void:
	_pause_overlay.visible = visible_now
	_settings_overlay.hide()
	_build_overview.hide()
	_awaiting_rebind_action = &""
	if visible_now:
		hud.move_child(_pause_overlay, -1)
		_ensure_context_focus()

func _resume_game() -> void:
	if journey.paused:
		journey._toggle_pause()

func _return_to_main_menu() -> void:
	journey.return_to_menu()

func _show_start_screen() -> void:
	_resume_game()

func _open_build_overview(from_pause: bool = false) -> void:
	if journey.route_complete or player.is_dead() or _build_overview.visible or _settings_overlay.visible:
		return
	_overview_from_pause = from_pause
	if not journey.paused:
		journey._toggle_pause()
	_build_overview.refresh(player, _get_action_prompt(&"build_overview"))
	_pause_overlay.hide()
	_build_overview.show()
	hud.move_child(_build_overview, -1)
	_build_overview.focus_close_button()

func _close_build_overview() -> void:
	_build_overview.hide()
	if _overview_from_pause:
		_pause_overlay.show()
		_pause_overview_button.grab_focus()
	else:
		_resume_game()
	_overview_from_pause = false

func _on_tutorial_toggled(enabled: bool) -> void:
	_settings.set_tutorial_enabled(enabled)
	journey.tutorial_enabled = enabled

func _on_reduced_effects_toggled(enabled: bool) -> void:
	_settings.set_reduced_effects_enabled(enabled)
	player.set_reduced_effects_enabled(enabled)
	if is_instance_valid(journey.reward_feedback):
		journey.reward_feedback.set_reduced_motion(enabled)

func _apply_accessibility_presentation() -> void:
	journey.campaign_presenter.apply_accessibility(_settings.get_large_text_enabled(), _settings.get_high_contrast_enabled(), _settings.get_color_blind_enabled(), _settings.get_hud_scale_factor())
	journey._apply_route_hint_accessibility()

func _fit_to_viewport() -> void:
	var size := get_viewport().get_visible_rect().size
	var gutter := Vector2(maxf(0, (size.x - DISPLAY_SIZE.x) * 0.5), maxf(0, (size.y - DISPLAY_SIZE.y) * 0.5))
	for overlay in [_pause_overlay, _settings_overlay, _build_overview]:
		if is_instance_valid(overlay):
			overlay.position = gutter
			overlay.size = DISPLAY_SIZE
	if is_instance_valid(_settings_overlay) and _settings_overlay.visible:
		hud.move_child(_settings_overlay, -1)

func _on_joy_connection_changed(_device: int, connected: bool) -> void:
	if connected:
		_using_controller_input = true
	elif Input.get_connected_joypads().is_empty():
		_using_controller_input = false
	journey.using_controller = _using_controller_input
	_refresh_input_prompts()

func _refresh_input_prompts() -> void:
	_refresh_settings_key_buttons()
	journey._refresh_reward_choice_prompts()
	_pause_overview_button.text = "构筑总览  [%s]" % _get_action_prompt(&"build_overview")
	_settings_controller_status_label.text = ("手柄：已连接 · 当前显示 Xbox 键位" if _using_controller_input else "手柄：已连接 · 按任意手柄键切换提示") if not Input.get_connected_joypads().is_empty() else "手柄：未连接 · Xbox 映射已启用"
	_ensure_context_focus()

func _ensure_context_focus() -> void:
	var current := get_viewport().gui_get_focus_owner()
	if _settings_overlay.visible:
		if current == null or not _settings_overlay.is_ancestor_of(current):
			preload("res://scripts/settings_page_layout.gd").focus_active_tab(_settings_overlay)
	elif _pause_overlay.visible:
		if current == null or not _pause_overlay.is_ancestor_of(current):
			_pause_overlay.get_node("Resume").grab_focus()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		_using_controller_input = false
		if not _awaiting_rebind_action.is_empty():
			if event.keycode != KEY_ESCAPE:
				_settings.rebind(_awaiting_rebind_action, event.keycode)
			_awaiting_rebind_action = &""
			_refresh_input_prompts()
			get_viewport().set_input_as_handled()
			return
	elif event is InputEventJoypadButton and event.pressed:
		_using_controller_input = true
	elif event is InputEventJoypadMotion and absf(event.axis_value) >= 0.55:
		_using_controller_input = true
	else:
		return
	journey.using_controller = _using_controller_input
	_refresh_input_prompts()
	if event.is_action_pressed(&"pause") and not event.is_echo():
		_back_or_pause()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"build_overview") and not event.is_echo():
		if _build_overview.visible:
			_close_build_overview()
		elif not _settings_overlay.visible:
			_open_build_overview(journey.paused)
		get_viewport().set_input_as_handled()
	elif event is InputEventJoypadButton and event.is_action_pressed(&"ui_cancel") and journey.paused:
		_back_or_pause()
		get_viewport().set_input_as_handled()

func _back_or_pause() -> void:
	if journey.route_complete or player.is_dead():
		journey.return_to_menu()
	elif _settings_overlay.visible:
		_close_settings()
	elif _build_overview.visible:
		_close_build_overview()
	else:
		journey._toggle_pause()

const DISPLAY_SIZE := Vector2(1280, 720)
const BUILD_LABEL := "月蚀混战测试版 0.4.1 · 2026.09.03"
const UI := preload("res://scripts/ui_theme.gd")

var _settings: RefCounted
var _pause_overlay: Control
var _pause_overview_button: Button
var _settings_overlay: Control
var _settings_key_buttons: Dictionary = {}
var _settings_volume_slider: HSlider
var _settings_music_slider: HSlider
var _settings_effects_slider: HSlider
var _settings_voice_slider: HSlider
var _settings_resolution_selector: OptionButton
var _settings_fullscreen_toggle: CheckButton
var _settings_vsync_toggle: CheckButton
var _settings_reduced_effects_toggle: CheckButton
var _settings_large_text_toggle: CheckButton
var _settings_high_contrast_toggle: CheckButton
var _settings_color_blind_toggle: CheckButton
var _settings_hud_scale_selector: OptionButton
var _settings_damage_numbers_toggle: CheckButton
var _settings_tutorial_toggle: CheckButton
var _settings_guide_label: RichTextLabel
var _settings_combat_guide_label: RichTextLabel
var _settings_controller_status_label: Label
var _settings_display_status_label: Label
var _settings_from_pause: bool = false
var _awaiting_rebind_action: StringName = &""
var _using_controller_input: bool = false
var _display_apply_generation: int = 0

func _create_pause_ui() -> void:
	preload("res://scripts/run_menu_view.gd")._create_pause_ui(self)


func _create_settings_ui() -> void:
	preload("res://scripts/run_menu_view.gd")._create_settings_ui(self)


func _create_settings_glass_card(
	card_name: String,
	card_position: Vector2,
	card_size: Vector2,
	accent: Color
) -> Panel:
	return preload("res://scripts/run_menu_view.gd")._create_settings_glass_card(self, card_name, card_position, card_size, accent)


func _create_settings_card_heading(card: Panel, heading_text: String, accent: Color) -> void:
	preload("res://scripts/run_menu_view.gd")._create_settings_card_heading(self, card, heading_text, accent)


func _style_settings_action_button(button: BaseButton) -> void:
	preload("res://scripts/run_menu_view.gd")._style_settings_action_button(self, button)


func _create_settings_knob_texture(accent: Color) -> ImageTexture:
	return preload("res://scripts/run_menu_view.gd")._create_settings_knob_texture(self, accent)


func _create_settings_switch_texture(is_enabled: bool, accent: Color) -> ImageTexture:
	return preload("res://scripts/run_menu_view.gd")._create_settings_switch_texture(self, is_enabled, accent)


func _create_settings_audio_slider(
	node_name: String,
	label_text: String,
	group_position: Vector2,
	slider_width: float,
	changed_callback: Callable
) -> HSlider:
	return preload("res://scripts/run_menu_view.gd")._create_settings_audio_slider(self, node_name, label_text, group_position, slider_width, changed_callback)


func _create_settings_toggle(
	node_name: String,
	button_text: String,
	button_position: Vector2,
	toggled_callback: Callable
) -> CheckButton:
	return preload("res://scripts/run_menu_view.gd")._create_settings_toggle(self, node_name, button_text, button_position, toggled_callback)


func _create_menu_button(node_name: String, button_text: String, button_position: Vector2, button_size: Vector2) -> Button:
	return preload("res://scripts/run_menu_view.gd")._create_menu_button(self, node_name, button_text, button_position, button_size)


func _configure_vertical_focus(controls: Array) -> void:
	preload("res://scripts/run_menu_view.gd")._configure_vertical_focus(self, controls)


func _create_surface_style(
	background_color: Color,
	border_color: Color,
	corner_radius: int = 12,
	border_width: int = 1,
	shadow_size: int = 0
) -> StyleBoxFlat:
	return preload("res://scripts/run_menu_view.gd")._create_surface_style(self, background_color, border_color, corner_radius, border_width, shadow_size)


func _open_settings(from_pause: bool) -> void:
	preload("res://scripts/run_menu_view.gd")._open_settings(self, from_pause)


func _close_settings() -> void:
	preload("res://scripts/run_menu_view.gd")._close_settings(self)


func _begin_rebind(action_name: StringName) -> void:
	preload("res://scripts/run_menu_view.gd")._begin_rebind(self, action_name)


func _refresh_settings_key_buttons() -> void:
	preload("res://scripts/run_menu_view.gd")._refresh_settings_key_buttons(self)


func _refresh_settings_operation_guide() -> void:
	preload("res://scripts/run_menu_view.gd")._refresh_settings_operation_guide(self)


func _get_action_prompt(action_name: StringName) -> String:
	return preload("res://scripts/run_menu_view.gd")._get_action_prompt(self, action_name)


func _queue_display_apply() -> void:
	preload("res://scripts/run_menu_view.gd")._queue_display_apply(self)


func _apply_display_after_frame(expected_generation: int) -> void:
	preload("res://scripts/run_menu_view.gd")._apply_display_after_frame(self, expected_generation)


func _refresh_display_status() -> void:
	preload("res://scripts/run_menu_view.gd")._refresh_display_status(self)


func _on_master_volume_changed(value: float) -> void:
	preload("res://scripts/run_menu_view.gd")._on_master_volume_changed(self, value)


func _on_music_volume_changed(value: float) -> void:
	preload("res://scripts/run_menu_view.gd")._on_music_volume_changed(self, value)


func _on_effects_volume_changed(value: float) -> void:
	preload("res://scripts/run_menu_view.gd")._on_effects_volume_changed(self, value)


func _on_voice_volume_changed(value: float) -> void:
	preload("res://scripts/run_menu_view.gd")._on_voice_volume_changed(self, value)


func _on_damage_numbers_toggled(enabled: bool) -> void:
	preload("res://scripts/run_menu_view.gd")._on_damage_numbers_toggled(self, enabled)


func _on_resolution_selected(option_index: int) -> void:
	preload("res://scripts/run_menu_view.gd")._on_resolution_selected(self, option_index)


func _on_fullscreen_toggled(enabled: bool) -> void:
	preload("res://scripts/run_menu_view.gd")._on_fullscreen_toggled(self, enabled)


func _on_vsync_toggled(enabled: bool) -> void:
	preload("res://scripts/run_menu_view.gd")._on_vsync_toggled(self, enabled)


func _on_large_text_toggled(enabled: bool) -> void:
	preload("res://scripts/run_menu_view.gd")._on_large_text_toggled(self, enabled)


func _on_high_contrast_toggled(enabled: bool) -> void:
	preload("res://scripts/run_menu_view.gd")._on_high_contrast_toggled(self, enabled)


func _on_color_blind_toggled(enabled: bool) -> void:
	preload("res://scripts/run_menu_view.gd")._on_color_blind_toggled(self, enabled)


func _on_hud_scale_selected(option_index: int) -> void:
	preload("res://scripts/run_menu_view.gd")._on_hud_scale_selected(self, option_index)


func _reset_bindings() -> void:
	preload("res://scripts/run_menu_view.gd")._reset_bindings(self)
