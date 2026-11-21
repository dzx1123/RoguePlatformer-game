extends RefCounted

const SETTINGS_LAYOUT := preload("res://scripts/settings_page_layout.gd")

## Canonical chapter-one pause/settings construction and settings actions.
## Hosts own navigation, scene suspension and HUD presentation.

static func _create_pause_ui(host: Node) -> void:
	host._pause_overlay = Control.new()
	host._pause_overlay.name = "PauseMenu"
	host._pause_overlay.position = Vector2.ZERO
	host._pause_overlay.size = host.DISPLAY_SIZE
	host._pause_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	host._pause_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	host.hud.add_child(host._pause_overlay)

	var dimmer = ColorRect.new()
	dimmer.name = "PauseDimmer"
	dimmer.size = host.DISPLAY_SIZE
	dimmer.color = Color(0.004, 0.012, 0.028, 0.82)
	dimmer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host._pause_overlay.add_child(dimmer)

	var panel = Panel.new()
	panel.name = "PausePanel"
	panel.position = Vector2(430.0, 150.0)
	panel.size = Vector2(420.0, 470.0)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override(
		"panel",
		host._create_surface_style(
			Color(0.010, 0.040, 0.075, 0.985),
			Color(0.38, 0.85, 0.98, 0.72),
			18,
			2,
			18
		)
	)
	host._pause_overlay.add_child(panel)
	var accent_rule = ColorRect.new()
	accent_rule.position = Vector2(28.0, 24.0)
	accent_rule.size = Vector2(364.0, 2.0)
	accent_rule.color = Color(0.42, 0.90, 1.0, 0.74)
	accent_rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(accent_rule)
	var kicker = Label.new()
	kicker.position = Vector2(0.0, 38.0)
	kicker.size = Vector2(420.0, 22.0)
	kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	kicker.text = "月蚀回廊 · 暂驻片刻"
	kicker.add_theme_font_size_override("font_size", 13)
	kicker.add_theme_color_override("font_color", Color(0.48, 0.82, 0.94, 0.90))
	kicker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(kicker)

	var title = Label.new()
	title.position = Vector2(455.0, 220.0)
	title.size = Vector2(370.0, 50.0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.text = "已暂停"
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color(0.85, 0.95, 1.0, 1.0))
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host._pause_overlay.add_child(title)

	var resume_button = host._create_menu_button("Resume", "继续游戏", Vector2(475.0, 292.0), Vector2(330.0, 54.0))
	resume_button.pressed.connect(host._resume_game)
	host._pause_overlay.add_child(resume_button)
	host._pause_overview_button = host._create_menu_button(
		"PauseBuildOverview",
		"构筑总览",
		Vector2(475.0, 492.0),
		Vector2(330.0, 48.0)
	)
	host._pause_overview_button.pressed.connect(host._open_build_overview.bind(true))
	host._pause_overlay.add_child(host._pause_overview_button)
	var settings_button = host._create_menu_button("PauseSettings", "设置与操作", Vector2(475.0, 358.0), Vector2(330.0, 48.0))
	settings_button.pressed.connect(host._open_settings.bind(true))
	host._pause_overlay.add_child(settings_button)
	var menu_button = host._create_menu_button("ReturnToMenu", "返回主菜单", Vector2(475.0, 425.0), Vector2(330.0, 48.0))
	menu_button.pressed.connect(host._return_to_main_menu)
	host._pause_overlay.add_child(menu_button)
	host._configure_vertical_focus([resume_button, settings_button, menu_button, host._pause_overview_button])
	host._pause_overlay.visible = false


static func _create_settings_ui(host: Node) -> void:
	host._settings_overlay = Control.new()
	host._settings_overlay.name = "SettingsMenu"
	host._settings_overlay.position = Vector2.ZERO
	host._settings_overlay.size = host.DISPLAY_SIZE
	host._settings_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	host._settings_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	host.hud.add_child(host._settings_overlay)

	var dimmer = ColorRect.new()
	dimmer.name = "SettingsDimmer"
	dimmer.size = host.DISPLAY_SIZE
	dimmer.color = Color("#08090B")
	dimmer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host._settings_overlay.add_child(dimmer)
	var panel = Panel.new()
	panel.position = Vector2.ZERO
	panel.size = host.DISPLAY_SIZE
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel_style = StyleBoxFlat.new()
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
	host._settings_overlay.add_child(panel)
	panel.visible = false

	var header_card = host._create_settings_glass_card(
		"SettingsHeader", Vector2(360.0, 48.0), Vector2(560.0, 86.0), Color("#74e3ff")
	)
	var audio_card = host._create_settings_glass_card(
		"SettingsAudioCard", Vector2(64.0, 164.0), Vector2(580.0, 150.0), Color("#67dff4")
	)
	var system_card = host._create_settings_glass_card(
		"SettingsSystemCard", Vector2(660.0, 164.0), Vector2(556.0, 154.0), Color("#73dff3")
	)
	var bindings_card = host._create_settings_glass_card(
		"SettingsBindingsCard", Vector2(64.0, 340.0), Vector2(602.0, 332.0), Color("#7aa8ff")
	)
	var guide_card = host._create_settings_glass_card(
		"SettingsGuideCard", Vector2(690.0, 340.0), Vector2(526.0, 332.0), Color("#8ddff2")
	)
	host._create_settings_card_heading(audio_card, "音频", host.UI.ACCENT_MOON)
	host._create_settings_card_heading(system_card, "显示与辅助", host.UI.ACCENT_MOON)
	host._create_settings_card_heading(bindings_card, "按键映射", host.UI.ACCENT_MOON)
	host._create_settings_card_heading(guide_card, "战斗提示", host.UI.ACCENT_MOON)
	var title = Label.new()
	title.position = Vector2(380.0, 60.0)
	title.size = Vector2(520.0, 42.0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.text = "设置与操作"
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.89, 0.97, 1.0, 1.0))
	title.add_theme_color_override("font_outline_color", Color(0.0, 0.03, 0.07, 0.70))
	title.add_theme_constant_override("outline_size", 2)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host._settings_overlay.add_child(title)
	var subtitle = Label.new()
	subtitle.position = Vector2(380.0, 101.0)
	subtitle.size = Vector2(520.0, 20.0)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.text = "调整你的月蚀路线 · 所有说明收纳于此"
	subtitle.add_theme_font_size_override("font_size", 13)
	subtitle.add_theme_color_override("font_color", Color(0.54, 0.79, 0.91, 0.92))
	subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host._settings_overlay.add_child(subtitle)

	host._settings_volume_slider = host._create_settings_audio_slider(
		"MasterVolume", "主音量", Vector2(88.0, 204.0), 166.0,
		host._on_master_volume_changed
	)
	host._settings_music_slider = host._create_settings_audio_slider(
		"MusicVolume", "音乐", Vector2(366.0, 204.0), 166.0,
		host._on_music_volume_changed
	)
	host._settings_effects_slider = host._create_settings_audio_slider(
		"EffectsVolume", "音效", Vector2(88.0, 254.0), 166.0,
		host._on_effects_volume_changed
	)
	host._settings_voice_slider = host._create_settings_audio_slider(
		"VoiceVolume", "语音", Vector2(366.0, 254.0), 166.0,
		host._on_voice_volume_changed
	)
	host._settings_damage_numbers_toggle = host._create_settings_toggle(
		"DamageNumbersToggle", "显示伤害数字", Vector2(900.0, 248.0),
		host._on_damage_numbers_toggled
	)
	host._settings_tutorial_toggle = host._create_settings_toggle(
		"TutorialToggle", "教学提示", Vector2(684.0, 362.0),
		host._on_tutorial_toggled
	)

	var resolution_label = Label.new()
	resolution_label.position = Vector2(684.0, 202.0)
	resolution_label.size = Vector2(74.0, 34.0)
	resolution_label.text = "分辨率"
	resolution_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	resolution_label.add_theme_font_size_override("font_size", 16)
	host._settings_overlay.add_child(resolution_label)
	host._settings_resolution_selector = OptionButton.new()
	host._settings_resolution_selector.name = "ResolutionSelector"
	host._settings_resolution_selector.position = Vector2(762.0, 202.0)
	host._settings_resolution_selector.size = Vector2(160.0, 34.0)
	var resolution_options: Array = host._settings.call(&"get_resolution_options") as Array
	for resolution_value: Variant in resolution_options:
		var resolution: Vector2i = resolution_value
		host._settings_resolution_selector.add_item("%d × %d" % [resolution.x, resolution.y])
	host._settings_resolution_selector.item_selected.connect(host._on_resolution_selected)
	host._style_settings_action_button(host._settings_resolution_selector)
	host._settings_overlay.add_child(host._settings_resolution_selector)
	host._settings_fullscreen_toggle = host._create_settings_toggle(
		"FullscreenToggle", "全屏", Vector2(940.0, 200.0),
		host._on_fullscreen_toggled
	)
	host._settings_vsync_toggle = host._create_settings_toggle(
		"VsyncToggle", "垂直同步", Vector2(1070.0, 200.0),
		host._on_vsync_toggled
	)
	host._settings_reduced_effects_toggle = host._create_settings_toggle(
		"ReducedEffectsToggle", "减弱闪光/震动", Vector2(684.0, 248.0),
		host._on_reduced_effects_toggled
	)
	host._settings_large_text_toggle = host._create_settings_toggle(
		"LargeTextToggle", "大号字", Vector2(684.0, 286.0),
		host._on_large_text_toggled
	)
	host._settings_high_contrast_toggle = host._create_settings_toggle(
		"HighContrastToggle", "高对比", Vector2(860.0, 286.0),
		host._on_high_contrast_toggled
	)
	host._settings_color_blind_toggle = host._create_settings_toggle(
		"ColorBlindToggle", "色觉辅助", Vector2(1030.0, 286.0),
		host._on_color_blind_toggled
	)
	var hud_scale_label = Label.new()
	hud_scale_label.name = "HUDScaleLabel"
	hud_scale_label.text = "HUD 缩放"
	hud_scale_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hud_scale_label.add_theme_font_size_override("font_size", 16)
	host._settings_overlay.add_child(hud_scale_label)
	host._settings_hud_scale_selector = OptionButton.new()
	host._settings_hud_scale_selector.name = "HUDScaleSelector"
	for label_text: String in ["90% · 紧凑", "100% · 标准", "110% · 放大"]:
		host._settings_hud_scale_selector.add_item(label_text)
	host._settings_hud_scale_selector.item_selected.connect(host._on_hud_scale_selected)
	host._style_settings_action_button(host._settings_hud_scale_selector)
	host._settings_overlay.add_child(host._settings_hud_scale_selector)
	host._settings_controller_status_label = Label.new()
	host._settings_controller_status_label.name = "ControllerStatus"
	host._settings_controller_status_label.position = Vector2(684.0, 322.0)
	host._settings_controller_status_label.size = Vector2(510.0, 17.0)
	host._settings_controller_status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	host._settings_controller_status_label.add_theme_font_size_override("font_size", 12)
	host._settings_controller_status_label.add_theme_color_override(
		"font_color", Color(0.56, 0.82, 0.88, 1.0)
	)
	host._settings_overlay.add_child(host._settings_controller_status_label)

	host._settings_display_status_label = Label.new()
	host._settings_display_status_label.name = "DisplayStatus"
	host._settings_display_status_label.position = Vector2(684.0, 339.0)
	host._settings_display_status_label.size = Vector2(510.0, 15.0)
	host._settings_display_status_label.add_theme_font_size_override("font_size", 11)
	host._settings_display_status_label.add_theme_color_override(
		"font_color", Color(0.58, 0.74, 0.84, 1.0)
	)
	host._settings_display_status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host._settings_overlay.add_child(host._settings_display_status_label)

	var guide_panel = Panel.new()
	guide_panel.name = "OperationGuidePanel"
	guide_panel.position = Vector2(702.0, 352.0)
	guide_panel.size = Vector2(502.0, 308.0)
	guide_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var guide_style = StyleBoxFlat.new()
	guide_style.bg_color = Color(0.008, 0.028, 0.057, 0.18)
	guide_style.border_color = Color(0.52, 0.84, 0.96, 0.18)
	guide_style.set_border_width_all(1)
	guide_style.corner_radius_top_left = 12
	guide_style.corner_radius_top_right = 12
	guide_style.corner_radius_bottom_left = 12
	guide_style.corner_radius_bottom_right = 12
	guide_panel.add_theme_stylebox_override("panel", guide_style)
	host._settings_overlay.add_child(guide_panel)
	guide_panel.visible = false
	host._settings_guide_label = RichTextLabel.new()
	host._settings_guide_label.name = "OperationGuide"
	host._settings_guide_label.position = Vector2(710.0, 388.0)
	host._settings_guide_label.size = Vector2(240.0, 264.0)
	host._settings_guide_label.bbcode_enabled = true
	host._settings_guide_label.fit_content = false
	host._settings_guide_label.scroll_active = false
	host._settings_guide_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host._settings_overlay.add_child(host._settings_guide_label)
	host._settings_combat_guide_label = RichTextLabel.new()
	host._settings_combat_guide_label.name = "OperationGuideCombat"
	host._settings_combat_guide_label.position = Vector2(974.0, 388.0)
	host._settings_combat_guide_label.size = Vector2(222.0, 264.0)
	host._settings_combat_guide_label.bbcode_enabled = true
	host._settings_combat_guide_label.scroll_active = false
	host._settings_combat_guide_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host._settings_overlay.add_child(host._settings_combat_guide_label)
	var guide_font = SystemFont.new()
	guide_font.font_names = PackedStringArray(["Microsoft YaHei", "Noto Sans CJK SC", "sans-serif"])
	for column: RichTextLabel in [host._settings_guide_label, host._settings_combat_guide_label]:
		column.add_theme_font_override("normal_font", guide_font)
		column.add_theme_font_override("bold_font", guide_font)
		column.add_theme_font_size_override("normal_font_size", 16)
		column.add_theme_font_size_override("bold_font_size", 16)
		column.add_theme_constant_override("line_separation", 1)
		column.add_theme_color_override("default_color", Color("#edf7fc"))

	var actions = [
		[&"build_overview", "构筑总览"],
		[&"move_left", "向左"], [ &"move_right", "向右"], [ &"jump", "跳跃"], [ &"attack", "攻击"], [ &"aim_up", "上劈方向"], [ &"aim_down", "下劈方向"],
		[&"dash", "闪避冲刺"], [ &"skill", "主动技能"], [ &"interact", "互动"], [ &"cycle_weapon", "切换武器"], [ &"restart", "重开本局"], [ &"pause", "暂停菜单"],
	]
	for action_index in range(actions.size()):
		# Three columns keep every binding inside the left card. The previous
		# four-column grid let the final column overlap the field guide.
		var row: int = action_index % 5
		var column: int = int(action_index / 5)
		var position = Vector2(84.0 + float(column) * 194.0, 382.0 + float(row) * 51.0)
		var action_name: StringName = actions[action_index][0]
		var action_label = Label.new()
		action_label.position = position
		action_label.size = Vector2(62.0, 38.0)
		action_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		action_label.text = String(actions[action_index][1])
		action_label.add_theme_font_size_override("font_size", 14)
		action_label.add_theme_color_override("font_color", Color(0.74, 0.86, 0.94, 0.96))
		action_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		host._settings_overlay.add_child(action_label)
		var key_button = Button.new()
		key_button.name = "Bind_%s" % action_name
		key_button.position = position + Vector2(66.0, 0.0)
		key_button.size = Vector2(122.0, 38.0)
		key_button.add_theme_font_size_override("font_size", 14)
		host._style_settings_action_button(key_button)
		key_button.pressed.connect(host._begin_rebind.bind(action_name))
		host._settings_overlay.add_child(key_button)
		host._settings_key_buttons[action_name] = key_button

	var reset_button = host._create_menu_button("ResetBindings", "恢复默认键位", Vector2(390.0, 700.0), Vector2(220.0, 44.0))
	reset_button.pressed.connect(host._reset_bindings)
	host._settings_overlay.add_child(reset_button)
	var back_button = host._create_menu_button("CloseSettings", "返回", Vector2(670.0, 700.0), Vector2(220.0, 44.0))
	back_button.pressed.connect(host._close_settings)
	host._settings_overlay.add_child(back_button)
	var about = Label.new()
	about.name = "SettingsAbout"
	about.position = Vector2(390.0, 762.0)
	about.size = Vector2(500.0, 20.0)
	about.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	about.text = host.BUILD_LABEL
	about.add_theme_font_size_override("font_size", host.UI.MICRO)
	about.add_theme_color_override("font_color", host.UI.TEXT_SECONDARY)
	about.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host._settings_overlay.add_child(about)
	SETTINGS_LAYOUT.apply(host._settings_overlay)
	for tab_name in SETTINGS_LAYOUT.TAB_NAMES:
		host._settings_overlay.get_node(tab_name).pressed.connect(_cancel_rebind.bind(host))
	host._refresh_settings_operation_guide()
	host._refresh_display_status()
	host._settings_overlay.visible = false


static func _create_settings_glass_card(host: Node, card_name: String,
	card_position: Vector2,
	card_size: Vector2,
	accent: Color
) -> Panel:
	var card = Panel.new()
	card.name = card_name
	card.position = card_position
	card.size = card_size
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_theme_stylebox_override(
		"panel",
		host._create_surface_style(
			Color(0.012, 0.044, 0.078, 0.72),
			Color(accent, 0.30),
			16,
			1,
			10
		)
	)
	host._settings_overlay.add_child(card)
	var accent_mark = ColorRect.new()
	accent_mark.position = Vector2(20.0, 13.0)
	accent_mark.size = Vector2(46.0, 2.0)
	accent_mark.color = Color(accent, 0.82)
	accent_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(accent_mark)
	return card


static func _create_settings_card_heading(host: Node, card: Panel, heading_text: String, accent: Color) -> void:
	var heading = Label.new()
	heading.name = "Heading"
	heading.position = Vector2(20.0, 18.0)
	heading.size = Vector2(card.size.x - 40.0, 24.0)
	heading.text = heading_text
	heading.add_theme_font_size_override("font_size", 15)
	heading.add_theme_color_override("font_color", Color(accent, 0.94))
	heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(heading)


static func _style_settings_action_button(host: Node, button: BaseButton) -> void:
	button.add_theme_stylebox_override(
		"normal",
		host._create_surface_style(
			Color(0.014, 0.052, 0.088, 0.42),
			Color(0.45, 0.79, 0.94, 0.26),
			9,
			1,
			4
		)
	)
	button.add_theme_stylebox_override(
		"hover",
		host._create_surface_style(
			Color(0.06, 0.17, 0.25, 0.70),
			Color(0.48, 0.90, 1.0, 0.86),
			9,
			1,
			8
		)
	)
	button.add_theme_stylebox_override(
		"pressed",
		host._create_surface_style(
			Color(0.11, 0.27, 0.35, 0.84),
			Color(0.86, 0.97, 1.0, 0.92),
			9,
			1,
			3
		)
	)
	button.add_theme_stylebox_override(
		"focus",
		host._create_surface_style(
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


static func _create_settings_knob_texture(host: Node, accent: Color) -> ImageTexture:
	var image = Image.create(16, 16, false, Image.FORMAT_RGBA8)
	for y in range(16):
		for x in range(16):
			var point = Vector2(float(x) + 0.5, float(y) + 0.5)
			var distance_to_center = point.distance_to(Vector2(8.0, 8.0))
			if distance_to_center <= 6.6:
				image.set_pixel(x, y, Color(accent, 0.98))
			elif distance_to_center <= 7.6:
				image.set_pixel(x, y, Color(0.80, 0.96, 1.0, 0.38))
	return ImageTexture.create_from_image(image)


static func _create_settings_switch_texture(host: Node, is_enabled: bool, accent: Color) -> ImageTexture:
	var image = Image.create(36, 20, false, Image.FORMAT_RGBA8)
	var body_color = (
		Color(accent, 0.84)
		if is_enabled
		else Color(0.18, 0.30, 0.40, 0.92)
	)
	var knob_center = Vector2(26.0 if is_enabled else 10.0, 10.0)
	for y in range(20):
		for x in range(36):
			var point = Vector2(float(x) + 0.5, float(y) + 0.5)
			var inside_body = (
				point.distance_to(Vector2(10.0, 10.0)) <= 9.0
				or point.distance_to(Vector2(26.0, 10.0)) <= 9.0
				or (point.x >= 10.0 and point.x <= 26.0 and point.y >= 1.0 and point.y <= 19.0)
			)
			if inside_body:
				image.set_pixel(x, y, body_color)
			if point.distance_to(knob_center) <= 6.0:
				image.set_pixel(x, y, Color(0.94, 0.99, 1.0, 1.0))
	return ImageTexture.create_from_image(image)


static func _create_settings_audio_slider(host: Node, node_name: String,
	label_text: String,
	group_position: Vector2,
	slider_width: float,
	changed_callback: Callable
) -> HSlider:
	var label = Label.new()
	label.position = group_position
	label.size = Vector2(62.0, 32.0)
	label.text = label_text
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color(0.76, 0.88, 0.95, 0.96))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host._settings_overlay.add_child(label)
	var slider = HSlider.new()
	slider.name = node_name
	slider.position = group_position + Vector2(62.0, 5.0)
	slider.size = Vector2(slider_width, 24.0)
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.add_theme_stylebox_override(
		"slider",
		host._create_surface_style(Color(0.007, 0.028, 0.050, 0.72), Color(0.33, 0.70, 0.84, 0.30), 6, 1)
	)
	slider.add_theme_stylebox_override(
		"grabber_area",
		host._create_surface_style(Color(0.16, 0.61, 0.72, 0.52), Color(0.45, 0.90, 0.98, 0.58), 6, 1)
	)
	slider.add_theme_stylebox_override(
		"grabber_area_highlight",
		host._create_surface_style(Color(0.22, 0.72, 0.86, 0.66), Color(0.70, 0.97, 1.0, 0.78), 6, 1)
	)
	slider.add_theme_icon_override("grabber", host._create_settings_knob_texture(Color("#7ceaff")))
	slider.add_theme_icon_override("grabber_highlight", host._create_settings_knob_texture(Color("#d5f9ff")))
	slider.value_changed.connect(changed_callback)
	host._settings_overlay.add_child(slider)
	return slider


static func _create_settings_toggle(host: Node, node_name: String,
	button_text: String,
	button_position: Vector2,
	toggled_callback: Callable
) -> CheckButton:
	var toggle = CheckButton.new()
	toggle.name = node_name
	toggle.position = button_position
	toggle.size = Vector2(180.0 if button_text.length() > 4 else 130.0, 36.0)
	toggle.text = button_text
	toggle.add_theme_font_size_override("font_size", 14)
	toggle.add_theme_color_override("font_color", Color(0.76, 0.88, 0.95, 0.96))
	toggle.add_theme_color_override("font_hover_color", Color(0.96, 1.0, 1.0, 1.0))
	toggle.add_theme_constant_override("h_separation", 8)
	var switch_accent = Color("#78e3f7")
	toggle.add_theme_icon_override("unchecked", host._create_settings_switch_texture(false, switch_accent))
	toggle.add_theme_icon_override("checked", host._create_settings_switch_texture(true, switch_accent))
	toggle.add_theme_icon_override("unchecked_disabled", host._create_settings_switch_texture(false, Color(0.38, 0.46, 0.52, 1.0)))
	toggle.add_theme_icon_override("checked_disabled", host._create_settings_switch_texture(true, Color(0.38, 0.46, 0.52, 1.0)))
	toggle.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	toggle.toggled.connect(toggled_callback)
	host._settings_overlay.add_child(toggle)
	return toggle


static func _create_menu_button(host: Node, node_name: String, button_text: String, button_position: Vector2, button_size: Vector2) -> Button:
	var button = Button.new()
	button.name = node_name
	button.position = button_position
	button.size = button_size
	button.text = button_text
	button.add_theme_font_size_override("font_size", 18)
	host._style_settings_action_button(button)
	return button


static func _configure_vertical_focus(host: Node, controls: Array) -> void:
	if controls.size() < 2:
		return
	for control_index in range(controls.size()):
		var control: Control = controls[control_index] as Control
		var previous: Control = controls[posmod(control_index - 1, controls.size())] as Control
		var next: Control = controls[(control_index + 1) % controls.size()] as Control
		control.focus_neighbor_top = control.get_path_to(previous)
		control.focus_neighbor_bottom = control.get_path_to(next)


static func _create_surface_style(host: Node, background_color: Color,
	border_color: Color,
	corner_radius: int = 12,
	border_width: int = 1,
	shadow_size: int = 0
) -> StyleBoxFlat:
	return host.UI.surface(background_color, border_color, corner_radius, border_width, shadow_size)


static func _open_settings(host: Node, from_pause: bool) -> void:
	host._settings_from_pause = from_pause
	if from_pause:
		host._pause_overlay.visible = false
	host._awaiting_rebind_action = &""
	host._settings_volume_slider.set_value_no_signal(float(host._settings.call(&"get_master_volume")))
	host._settings_music_slider.set_value_no_signal(float(host._settings.call(&"get_music_volume")))
	host._settings_effects_slider.set_value_no_signal(float(host._settings.call(&"get_effects_volume")))
	host._settings_voice_slider.set_value_no_signal(float(host._settings.call(&"get_voice_volume")))
	host._settings_damage_numbers_toggle.set_pressed_no_signal(
		bool(host._settings.call(&"get_damage_numbers_enabled"))
	)
	host._settings_tutorial_toggle.set_pressed_no_signal(
		bool(host._settings.call(&"get_tutorial_enabled"))
	)
	host._settings_resolution_selector.select(int(host._settings.call(&"get_resolution_index")))
	host._settings_fullscreen_toggle.set_pressed_no_signal(
		bool(host._settings.call(&"get_fullscreen_enabled"))
	)
	host._settings_vsync_toggle.set_pressed_no_signal(bool(host._settings.call(&"get_vsync_enabled")))
	host._settings_reduced_effects_toggle.set_pressed_no_signal(
		bool(host._settings.call(&"get_reduced_effects_enabled"))
	)
	host._settings_large_text_toggle.set_pressed_no_signal(
		bool(host._settings.call(&"get_large_text_enabled"))
	)
	host._settings_high_contrast_toggle.set_pressed_no_signal(
		bool(host._settings.call(&"get_high_contrast_enabled"))
	)
	host._settings_color_blind_toggle.set_pressed_no_signal(
		bool(host._settings.call(&"get_color_blind_enabled"))
	)
	host._settings_hud_scale_selector.select(int(host._settings.call(&"get_hud_scale_index")))
	host._settings_overlay.visible = true
	host._fit_to_viewport()
	host._refresh_input_prompts()
	host._refresh_display_status()
	host._ensure_context_focus()


static func _close_settings(host: Node) -> void:
	host._awaiting_rebind_action = &""
	host._settings_overlay.visible = false
	host._fit_to_viewport()
	if not host._settings_from_pause:
		host._show_start_screen()
	else:
		host._pause_overlay.visible = true
		host._ensure_context_focus()


static func _begin_rebind(host: Node, action_name: StringName) -> void:
	host._awaiting_rebind_action = action_name
	host._refresh_settings_key_buttons()

static func _cancel_rebind(host: Node) -> void:
	if not host._awaiting_rebind_action.is_empty():
		host._awaiting_rebind_action = &""
		host._refresh_settings_key_buttons()


static func _refresh_settings_key_buttons(host: Node) -> void:
	for action_value in host._settings_key_buttons:
		var action_name: StringName = StringName(String(action_value))
		var button: Button = host._settings_key_buttons[action_value] as Button
		if action_name == host._awaiting_rebind_action:
			button.text = "按下新按键…"
		else:
			button.text = String(host._settings.call(&"get_combined_binding_name", action_name))
	host._refresh_settings_operation_guide()


static func _refresh_settings_operation_guide(host: Node) -> void:
	if not is_instance_valid(host._settings_guide_label) or host._settings == null:
		return
	var heading = host._settings_overlay.get_node("SettingsGuideCard/Heading") as Label
	heading.text = "操作说明 · %s" % ("Xbox 手柄" if host._using_controller_input else "键盘与鼠标")
	heading.add_theme_font_size_override("font_size", 16)
	var left_key: String = host._get_action_prompt(&"move_left")
	var right_key: String = host._get_action_prompt(&"move_right")
	var jump_key: String = host._get_action_prompt(&"jump")
	var attack_key: String = host._get_action_prompt(&"attack")
	var up_key: String = host._get_action_prompt(&"aim_up")
	var down_key: String = host._get_action_prompt(&"aim_down")
	var dash_key: String = host._get_action_prompt(&"dash")
	var skill_key: String = host._get_action_prompt(&"skill")
	var interact_key: String = host._get_action_prompt(&"interact")
	var weapon_key: String = host._get_action_prompt(&"cycle_weapon")
	var restart_key: String = host._get_action_prompt(&"restart")
	var pause_key: String = host._get_action_prompt(&"pause")
	host._settings_guide_label.text = (
		"[color=#72e4f4]移动与探索[/color]\n"
		+ ("LS / 十字键  左右移动\n" if host._using_controller_input else "%s / %s  左右移动\n" % [left_key, right_key])
		+ "%s  跳跃 / 二段跳\n" % jump_key
		+ "%s + %s  下平台\n" % [down_key, jump_key]
		+ "%s  开宝箱 / 进入光柱\n" % interact_key
		+ "[color=#72e4f4]菜单与选择[/color]\n"
		+ "%s  暂停与设置\n" % pause_key
		+ "%s  构筑总览\n" % host._get_action_prompt(&"build_overview")
		+ (
			"X / Y / B  直接选牌\nLS / 十字键导航 · A 确认"
			if host._using_controller_input
			else "1 / 2 / 3  选牌 / 购买"
		)
	)
	host._settings_combat_guide_label.text = (
		"[color=#72e4f4]战斗动作[/color]\n"
		+ "%s  普通攻击\n" % attack_key
		+ "%s + %s  上劈\n" % [up_key, attack_key]
		+ "%s + %s  下劈\n" % [down_key, attack_key]
		+ "%s  冲刺（短暂无敌）\n" % dash_key
		+ "%s  主动技能\n" % skill_key
		+ "%s  切换武器\n" % weapon_key
		+ "[color=#72e4f4]其他操作[/color]\n"
		+ "%s  离开商店\n" % interact_key
		+ "%s  重新开局" % restart_key
	)


static func _get_action_prompt(host: Node, action_name: StringName) -> String:
	if host._settings == null:
		return ""
	return String(host._settings.call(
		&"get_action_prompt", action_name, host._using_controller_input
	))


static func _queue_display_apply(host: Node) -> void:
	host._display_apply_generation += 1
	host._apply_display_after_frame(host._display_apply_generation)


static func _apply_display_after_frame(host: Node, expected_generation: int) -> void:
	await host.get_tree().process_frame
	if expected_generation != host._display_apply_generation or host._settings == null:
		return
	host._settings.call(&"apply_display")
	await host.get_tree().process_frame
	if expected_generation == host._display_apply_generation:
		host._refresh_display_status()


static func _refresh_display_status(host: Node) -> void:
	if not is_instance_valid(host._settings_display_status_label) or host._settings == null:
		return
	if Engine.is_embedded_in_editor():
		host._settings_display_status_label.text = (
			"编辑器嵌入运行不支持全屏/窗口尺寸；关闭 Embed Game on Next Play 后即可生效。"
		)
		host._settings_display_status_label.add_theme_color_override(
			"font_color", Color(1.0, 0.72, 0.40, 1.0)
		)
		return
	var target: Vector2i = host._settings.call(&"get_requested_resolution")
	var fullscreen_enabled: bool = bool(host._settings.call(&"get_fullscreen_enabled"))
	host._settings_display_status_label.text = (
		"全屏已应用（使用当前显示器尺寸）；%d × %d 将在窗口模式生效。" % [target.x, target.y]
		if fullscreen_enabled
		else "窗口分辨率已应用：%d × %d。" % [target.x, target.y]
	)
	host._settings_display_status_label.add_theme_color_override(
		"font_color", Color(0.45, 0.88, 0.72, 1.0)
	)


static func _on_master_volume_changed(host: Node, value: float) -> void:
	host._settings.call(&"set_master_volume", value)


static func _on_music_volume_changed(host: Node, value: float) -> void:
	host._settings.call(&"set_music_volume", value)


static func _on_effects_volume_changed(host: Node, value: float) -> void:
	host._settings.call(&"set_effects_volume", value)


static func _on_voice_volume_changed(host: Node, value: float) -> void:
	host._settings.call(&"set_voice_volume", value)


static func _on_damage_numbers_toggled(host: Node, enabled: bool) -> void:
	host._settings.call(&"set_damage_numbers_enabled", enabled)


static func _on_resolution_selected(host: Node, option_index: int) -> void:
	host._settings.call(&"set_resolution_index", option_index)
	host._queue_display_apply()


static func _on_fullscreen_toggled(host: Node, enabled: bool) -> void:
	host._settings.call(&"set_fullscreen_enabled", enabled)
	host._queue_display_apply()


static func _on_vsync_toggled(host: Node, enabled: bool) -> void:
	host._settings.call(&"set_vsync_enabled", enabled)
	host._queue_display_apply()


static func _on_large_text_toggled(host: Node, enabled: bool) -> void:
	host._settings.call(&"set_large_text_enabled", enabled)
	host._apply_accessibility_presentation()


static func _on_high_contrast_toggled(host: Node, enabled: bool) -> void:
	host._settings.call(&"set_high_contrast_enabled", enabled)
	host._apply_accessibility_presentation()


static func _on_color_blind_toggled(host: Node, enabled: bool) -> void:
	host._settings.call(&"set_color_blind_enabled", enabled)
	host._apply_accessibility_presentation()


static func _on_hud_scale_selected(host: Node, option_index: int) -> void:
	host._settings.call(&"set_hud_scale_index", option_index)
	host._apply_accessibility_presentation()


static func _reset_bindings(host: Node) -> void:
	host._settings.call(&"reset_bindings")
	host._awaiting_rebind_action = &""
	host._refresh_settings_key_buttons()
