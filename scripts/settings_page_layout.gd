extends RefCounted

## Settings-only layout. Keep control names and callbacks owned by main.gd.
static func apply(page: Control) -> void:
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei", "Noto Sans CJK SC", "sans-serif"])
	font.font_weight = 400
	_style_text(page, font)
	var page_bg := Color("#08090B")
	var card_bg := Color("#14181C")
	var card_stroke := Color("#2C3338")
	for node: Node in page.get_children():
		if node is ColorRect and (String(node.name) == "SettingsDimmer" or node.size.x >= 1280):
			node.color = page_bg
	var cards := {
		"SettingsHeader": Rect2(48, 16, 1184, 70),
		"SettingsAudioCard": Rect2(48, 96, 456, 260),
		"SettingsSystemCard": Rect2(520, 96, 712, 260),
		"SettingsBindingsCard": Rect2(48, 368, 616, 300),
		"SettingsGuideCard": Rect2(680, 368, 552, 300),
	}
	for key: String in cards:
		var card := page.get_node(key) as Panel
		var rect: Rect2 = cards[key]
		card.position = rect.position
		card.size = rect.size
		card.add_theme_stylebox_override("panel", MoonUI.surface(card_bg, card_stroke, 12))
		# The header has its own large title; the generic card accent crossed through
		# the first glyph and looked like a stray line.
		if key == "SettingsHeader":
			for child: Node in card.get_children():
				if child is ColorRect:
					child.visible = false
		var heading := card.get_node_or_null("Heading") as Label
		if heading:
			heading.position = Vector2(20, 18)
			heading.size = Vector2(card.size.x - 40, 24)
			heading.add_theme_font_size_override("font_size", 18)
	var names := ["MasterVolume", "MusicVolume", "EffectsVolume", "VoiceVolume"]
	var labels := ["主音量", "音乐", "音效", "语音"]
	for index in range(4):
		_place(page, names[index], Rect2(182, 148 + index * 40, 286, 26))
		_label(page, labels[index], Rect2(72, 143 + index * 40, 98, 32))
	_label(page, "设置与操作", Rect2(72, 22, 700, 32), 28)
	_label(page, "调整你的月蚀路线 · 所有说明收纳于此", Rect2(72, 58, 900, 20), 14)
	_label(page, "分辨率", Rect2(544, 148, 82, 36))
	_place(page, "ResolutionSelector", Rect2(630, 148, 208, 38))
	var controls := {
		"FullscreenToggle": Rect2(876, 148, 320, 38),
		"VsyncToggle": Rect2(544, 188, 294, 38),
		"DamageNumbersToggle": Rect2(876, 188, 320, 38),
		"ReducedEffectsToggle": Rect2(544, 228, 294, 38),
		"LargeTextToggle": Rect2(876, 228, 320, 38),
		"HighContrastToggle": Rect2(544, 268, 294, 34),
		"ColorBlindToggle": Rect2(876, 268, 320, 34),
		"HUDScaleLabel": Rect2(544, 304, 82, 34),
		"HUDScaleSelector": Rect2(630, 304, 208, 34),
		"ControllerStatus": Rect2(876, 304, 320, 34),
		"DisplayStatus": Rect2(544, 334, 652, 20),
		"OperationGuide": Rect2(700, 412, 250, 256),
		"OperationGuideCombat": Rect2(976, 412, 236, 256),
		"ResetBindings": Rect2(48, 672, 252, 40),
		"CloseSettings": Rect2(992, 672, 240, 40),
		"SettingsAbout": Rect2(350, 676, 580, 22),
	}
	for key: String in controls:
		_place(page, key, controls[key])
	for key: String in ["OperationGuide", "OperationGuideCombat"]:
		var guide_column := page.get_node(key) as RichTextLabel
		guide_column.add_theme_constant_override("line_separation", 2)
	for key in ["ControllerStatus", "DisplayStatus", "SettingsAbout"]:
		var label := page.get_node(key) as Label
		label.add_theme_font_size_override("font_size", 13)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.tooltip_text = label.text
	var bindings := {
		"build_overview": "构筑总览", "move_left": "向左", "move_right": "向右",
		"jump": "跳跃", "attack": "攻击", "aim_up": "上劈方向", "aim_down": "下劈方向",
		"dash": "闪避冲刺", "skill": "主动技能", "interact": "互动",
		"cycle_weapon": "切换武器", "restart": "重开本局", "pause": "暂停菜单",
	}
	var index := 0
	for action: String in bindings:
		var origin := Vector2(68 + (index / 7) * 302, 406 + (index % 7) * 34)
		_label(page, bindings[action], Rect2(origin, Vector2(86, 36)))
		_place(page, "Bind_" + action, Rect2(origin + Vector2(90, 0), Vector2(194, 36)))
		index += 1


static func _place(page: Control, key: String, rect: Rect2) -> void:
	var control := page.get_node(key) as Control
	control.position = rect.position
	control.size = rect.size


static func _label(page: Control, text: String, rect: Rect2, size: int = 16) -> void:
	for child: Node in page.get_children():
		if child is Label and child.text == text:
			child.position = rect.position
			child.size = rect.size
			child.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
			child.add_theme_font_size_override("font_size", size)


static func _style_text(node: Node, font: Font) -> void:
	if node is Label or node is BaseButton:
		node.add_theme_font_override("font", font)
		node.add_theme_font_size_override("font_size", 16)
		node.add_theme_constant_override("outline_size", 0)
		node.add_theme_color_override("font_color", MoonUI.TEXT_PRIMARY)
	if node is RichTextLabel:
		for key in ["normal_font", "bold_font", "italics_font", "mono_font"]:
			node.add_theme_font_override(key, font)
		node.add_theme_font_size_override("normal_font_size", 16)
		node.add_theme_font_size_override("bold_font_size", 16)
		node.add_theme_constant_override("line_separation", 4)
		node.scroll_active = false
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child: Node in node.get_children():
		_style_text(child, font)
