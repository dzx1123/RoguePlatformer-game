extends RefCounted

## Both chapters retain the same controls and bindings across settings sections.
enum Section { AUDIO, DISPLAY, CONTROLS }

const TAB_NAMES := ["AudioTab", "DisplayTab", "ControlsTab"]
const TAB_TEXT := ["音频", "显示与辅助", "操作"]
const TAB_FIRST_CONTROL := ["MasterVolume", "ResolutionSelector", "Bind_build_overview"]
const SECTION_META := &"settings_section"
const PANEL := Color("#101d2b")
const EDGE := Color("#30465a")


static func apply(page: Control) -> void:
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei", "Noto Sans CJK SC", "sans-serif"])
	font.font_weight = 400
	_style_text(page, font)
	for node in page.get_children():
		if node is ColorRect and node.size.x >= 1280:
			node.color = Color("#060d17")

	_place(page.get_node("SettingsHeader"), Rect2(72, 20, 1136, 70))
	page.get_node("SettingsHeader").hide()
	_label(page, "设置与操作", Rect2(72, 28, 700, 56), 36)
	var subtitle := _find_label(page, "调整你的月蚀路线 · 所有说明收纳于此")
	if subtitle != null:
		subtitle.hide()
	_card(page, "SettingsAudioCard", Rect2(72, 167, 1136, 450), Section.AUDIO)
	_card(page, "SettingsSystemCard", Rect2(72, 167, 1136, 450), Section.DISPLAY)
	_card(page, "SettingsBindingsCard", Rect2(72, 167, 578, 450), Section.CONTROLS)
	_card(page, "SettingsGuideCard", Rect2(674, 167, 534, 450), Section.CONTROLS)
	_place(page.get_node("SettingsGuideCard/Heading"), Rect2(24, 14, 292, 38))

	var sliders := ["MasterVolume", "MusicVolume", "EffectsVolume", "VoiceVolume"]
	var slider_labels := ["主音量", "音乐", "音效", "语音"]
	for index in sliders.size():
		var y: float = 246.0 + float(index) * 78.0
		_place(page.get_node(sliders[index]), Rect2(368, y, 668, 30), Section.AUDIO)
		_label(page, slider_labels[index], Rect2(108, y - 5, 224, 40), 20, Section.AUDIO)

	_label(page, "分辨率", Rect2(108, 235, 110, 44), 18, Section.DISPLAY)
	var display_layout := {
		"ResolutionSelector": Rect2(242, 235, 304, 44),
		"FullscreenToggle": Rect2(664, 235, 496, 44),
		"VsyncToggle": Rect2(108, 294, 438, 44),
		"DamageNumbersToggle": Rect2(664, 294, 496, 44),
		"ReducedEffectsToggle": Rect2(108, 353, 438, 44),
		"LargeTextToggle": Rect2(664, 353, 496, 44),
		"HighContrastToggle": Rect2(108, 412, 438, 44),
		"ColorBlindToggle": Rect2(664, 412, 496, 44),
		"HUDScaleLabel": Rect2(108, 475, 118, 44),
		"HUDScaleSelector": Rect2(242, 475, 304, 44),
		"DisplayStatus": Rect2(108, 552, 1052, 36),
	}
	for name: String in display_layout:
		_place(page.get_node(name), display_layout[name], Section.DISPLAY)

	var actions := {
		"build_overview": "构筑总览", "move_left": "向左", "move_right": "向右",
		"jump": "跳跃", "attack": "攻击", "aim_up": "上劈方向", "aim_down": "下劈方向",
		"dash": "闪避冲刺", "skill": "主动技能", "interact": "互动",
		"cycle_weapon": "切换武器", "restart": "重开本局", "pause": "暂停菜单",
	}
	var index := 0
	for action: String in actions:
		var origin := Vector2(96.0 + floorf(float(index) / 7.0) * 272.0, 235.0 + float(index % 7) * 48.0)
		_label(page, actions[action], Rect2(origin, Vector2(94, 38)), 16, Section.CONTROLS)
		_place(page.get_node("Bind_" + action), Rect2(origin + Vector2(95, 0), Vector2(153, 38)), Section.CONTROLS)
		index += 1
	_place(page.get_node("OperationGuide"), Rect2(698, 239, 232, 337), Section.CONTROLS)
	_place(page.get_node("OperationGuideCombat"), Rect2(949, 239, 235, 337), Section.CONTROLS)
	_place(page.get_node("TutorialToggle"), Rect2(1038, 180, 146, 40), Section.CONTROLS)
	_place(page.get_node("ControllerStatus"), Rect2(96, 575, 528, 28), Section.CONTROLS)
	_place(page.get_node("ResetBindings"), Rect2(72, 648, 258, 44), Section.CONTROLS)
	_place(page.get_node("CloseSettings"), Rect2(1004, 648, 204, 44))
	_place(page.get_node("SettingsAbout"), Rect2(350, 658, 580, 24))
	for name in ["ControllerStatus", "DisplayStatus", "SettingsAbout"]:
		var label := page.get_node(name) as Label
		label.add_theme_font_size_override("font_size", 14)
		label.add_theme_color_override("font_color", MoonUI.TEXT_SECONDARY)
	_create_tab_bar(page, font)
	select_section(page, Section.AUDIO)


static func select_section(page: Control, section: int) -> void:
	page.set_meta(SECTION_META, section)
	for node in page.get_children():
		if node is Control and node.has_meta(SECTION_META):
			node.visible = int(node.get_meta(SECTION_META)) == section
	for index in TAB_NAMES.size():
		(page.get_node(TAB_NAMES[index]) as Button).set_pressed_no_signal(index == section)


static func focus_active_tab(page: Control) -> void:
	(page.get_node(TAB_NAMES[int(page.get_meta(SECTION_META, Section.AUDIO))]) as Button).grab_focus()


static func _create_tab_bar(page: Control, font: Font) -> void:
	var tabs: Array[Button] = []
	var group := ButtonGroup.new()
	for index in TAB_NAMES.size():
		var tab := Button.new()
		tab.name = TAB_NAMES[index]
		tab.text = TAB_TEXT[index]
		tab.toggle_mode = true
		tab.button_group = group
		tab.position = Vector2(72 + index * 180, 103)
		tab.size = Vector2(164, 44)
		tab.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		tab.add_theme_font_override("font", font)
		tab.add_theme_font_size_override("font_size", 17)
		tab.add_theme_color_override("font_color", MoonUI.TEXT_SECONDARY)
		tab.add_theme_color_override("font_pressed_color", MoonUI.TEXT_PRIMARY)
		tab.add_theme_stylebox_override("normal", MoonUI.surface(PANEL, EDGE, 8))
		tab.add_theme_stylebox_override("pressed", MoonUI.surface(Color("#1a3145"), MoonUI.ACCENT_MOON, 8))
		tab.add_theme_stylebox_override("hover", MoonUI.surface(Color("#1a3145"), EDGE, 8))
		var focus := MoonUI.surface(Color.TRANSPARENT, MoonUI.TEXT_PRIMARY, 8, 2)
		focus.draw_center = false
		tab.add_theme_stylebox_override("focus", focus)
		tab.pressed.connect(select_section.bind(page, index))
		page.add_child(tab)
		tabs.append(tab)
	for index in tabs.size():
		var tab := tabs[index]
		tab.focus_neighbor_left = tab.get_path_to(tabs[posmod(index - 1, tabs.size())])
		tab.focus_neighbor_right = tab.get_path_to(tabs[(index + 1) % tabs.size()])
		tab.focus_neighbor_bottom = tab.get_path_to(page.get_node(TAB_FIRST_CONTROL[index]))


static func _card(page: Control, name: String, rect: Rect2, section: int) -> void:
	var card := page.get_node(name) as Panel
	_place(card, rect, section)
	card.add_theme_stylebox_override("panel", MoonUI.surface(PANEL, EDGE, 14))
	for node in card.get_children():
		if node is ColorRect:
			node.hide()
	var heading := card.get_node("Heading") as Label
	_place(heading, Rect2(24, 14, card.size.x - 48, 38))
	heading.add_theme_font_size_override("font_size", 20)


static func _place(control: Control, rect: Rect2, section: int = -1) -> void:
	control.position = rect.position
	control.size = rect.size
	if section >= 0:
		control.set_meta(SECTION_META, section)


static func _label(page: Control, value: String, rect: Rect2, font_size: int, section: int = -1) -> void:
	var label := _find_label(page, value)
	if label == null:
		return
	_place(label, rect, section)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.add_theme_font_size_override("font_size", font_size)


static func _find_label(page: Control, value: String) -> Label:
	for child in page.get_children():
		if child is Label and child.text == value:
			return child
	return null


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
		node.add_theme_constant_override("line_separation", 5)
		node.scroll_active = false
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_style_text(child, font)
