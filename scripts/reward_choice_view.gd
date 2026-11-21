extends Control
class_name RewardChoiceView
signal selected(index: int)
signal shop_exit_requested
const UI = preload("res://scripts/ui_theme.gd")
const DISPLAY_SIZE = Vector2(1280, 720)
const CARD_SIZE := Vector2(300.0, 316.0)
const CARD_GAP := 28.0
const CARD_TOP := 176.0
var hud: Node
var _settings
var _soundscape
var _flow_state = RunFlowState.new()
var _upgrade_overlay: Control
var _upgrade_dimmer: ColorRect
var _upgrade_panel: Panel
var _upgrade_rule: ColorRect
var _upgrade_kicker: Label
var _upgrade_title: Label
var _upgrade_hint: Label
var _upgrade_buttons: Array[Button] = []
var shop_exit_button: Button
var _upgrade_tween: Tween
var _upgrade_victory_summary: Control
func build(settings, soundscape = null) -> void:
	hud = self
	_settings = settings
	_soundscape = soundscape
	_create_upgrade_ui()
func _on_upgrade_button_pressed(index: int) -> void:
	selected.emit(index)
func _hide_upgrade_overlay() -> void:
	if _upgrade_tween != null and _upgrade_tween.is_valid():
		_upgrade_tween.kill()
	shop_exit_button.hide()
	_upgrade_overlay.hide()
func _create_surface_style(fill: Color, stroke: Color, radius: int, border: int, padding: int) -> StyleBoxFlat:
	return UI.surface(fill, stroke, radius, border, padding)

func _create_upgrade_ui() -> void:
	_upgrade_overlay = Control.new()
	_upgrade_overlay.name = "UpgradeChoice"
	_upgrade_overlay.position = Vector2.ZERO
	_upgrade_overlay.size = DISPLAY_SIZE
	_upgrade_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	hud.add_child(_upgrade_overlay)

	_upgrade_dimmer = ColorRect.new()
	_upgrade_dimmer.name = "UpgradeDimmer"
	_upgrade_dimmer.size = DISPLAY_SIZE
	_upgrade_dimmer.color = Color(0.006, 0.014, 0.035, 0.82)
	_upgrade_dimmer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_upgrade_overlay.add_child(_upgrade_dimmer)

	_upgrade_panel = Panel.new()
	_upgrade_panel.name = "UpgradePanel"
	_upgrade_panel.size = Vector2(1120.0, 590.0)
	_upgrade_panel.position = Vector2(
		(DISPLAY_SIZE.x - _upgrade_panel.size.x) * 0.5,
		(DISPLAY_SIZE.y - _upgrade_panel.size.y) * 0.5
	)
	_upgrade_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_upgrade_panel.add_theme_stylebox_override(
		"panel",
		_create_surface_style(
			Color(0.018, 0.055, 0.095, 0.975),
			Color(0.30, 0.86, 1.0, 0.82),
			18,
			2,
			18
		)
	)
	_upgrade_overlay.add_child(_upgrade_panel)

	_upgrade_rule = ColorRect.new()
	_upgrade_rule.name = "RewardRule"
	_upgrade_rule.position = Vector2(42.0, 22.0)
	_upgrade_rule.size = Vector2(1036.0, 2.0)
	_upgrade_rule.color = Color(0.42, 0.91, 1.0, 0.72)
	_upgrade_rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_upgrade_panel.add_child(_upgrade_rule)

	_upgrade_kicker = Label.new()
	_upgrade_kicker.name = "UpgradeKicker"
	_upgrade_kicker.position = Vector2(0.0, 38.0)
	_upgrade_kicker.size = Vector2(1120.0, 28.0)
	_upgrade_kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_upgrade_kicker.text = "月弧遗物 · 三选一"
	_upgrade_kicker.add_theme_font_size_override("font_size", UI.CAPTION)
	_upgrade_kicker.add_theme_color_override("font_color", Color(0.42, 0.85, 1.0, 0.92))
	_upgrade_kicker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_upgrade_panel.add_child(_upgrade_kicker)

	_upgrade_title = Label.new()
	_upgrade_title.position = Vector2(55.0, 70.0)
	_upgrade_title.size = Vector2(1010.0, 52.0)
	_upgrade_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_upgrade_title.add_theme_font_size_override("font_size", UI.TITLE)
	_upgrade_title.add_theme_color_override("font_color", UI.TEXT_PRIMARY)
	_upgrade_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_upgrade_panel.add_child(_upgrade_title)

	_upgrade_hint = Label.new()
	_upgrade_hint.position = Vector2(70.0, 122.0)
	_upgrade_hint.size = Vector2(980.0, 34.0)
	_upgrade_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_upgrade_hint.add_theme_font_size_override("font_size", UI.CAPTION)
	_upgrade_hint.add_theme_color_override("font_color", UI.TEXT_SECONDARY)
	_upgrade_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_upgrade_panel.add_child(_upgrade_hint)

	for choice_index in range(3):
		var button := Button.new()
		button.name = "Upgrade_%d" % (choice_index + 1)
		button.size = CARD_SIZE
		button.pivot_offset = button.size * 0.5
		button.add_theme_font_size_override("font_size", 19)
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.pressed.connect(_on_upgrade_button_pressed.bind(choice_index))
		_create_upgrade_card_content(button)
		_style_upgrade_card(button, {})
		_upgrade_panel.add_child(button)
		_upgrade_buttons.append(button)
	shop_exit_button = Button.new()
	shop_exit_button.name = "ShopExit"
	shop_exit_button.position = Vector2(420, 516)
	shop_exit_button.size = Vector2(280, 48)
	shop_exit_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	shop_exit_button.add_theme_stylebox_override("normal", UI.surface(UI.BG_DEEP, UI.STROKE_QUIET))
	var focused_exit := UI.surface(UI.BG_PANEL_ELEV, UI.ACCENT_GOLD, UI.CHIP_RADIUS, 2)
	shop_exit_button.add_theme_stylebox_override("hover", focused_exit)
	shop_exit_button.add_theme_stylebox_override("focus", focused_exit)
	shop_exit_button.add_theme_stylebox_override("pressed", focused_exit)
	shop_exit_button.pressed.connect(func(): shop_exit_requested.emit())
	_upgrade_panel.add_child(shop_exit_button)
	_hide_upgrade_overlay()


func set_shop_exit_prompt(shortcut: String) -> void:
	shop_exit_button.text = "离开商店  [%s]" % shortcut
	shop_exit_button.add_theme_font_size_override("font_size", UI.BODY + (2 if _settings != null and _settings.get_large_text_enabled() else 0))


func is_choice_action(control: Control) -> bool:
	return control != null and (control in _upgrade_buttons or control == shop_exit_button)


func focus_choice(preferred: Control = null) -> bool:
	if _can_focus_choice(preferred):
		preferred.grab_focus()
		return true
	for button in _upgrade_buttons:
		if _can_focus_choice(button):
			button.grab_focus()
			return true
	if _can_focus_choice(shop_exit_button):
		shop_exit_button.grab_focus()
		return true
	return false


func _can_focus_choice(control: Control) -> bool:
	return is_choice_action(control) and control.is_visible_in_tree() and not (control as Button).disabled and control.focus_mode != Control.FOCUS_NONE


func _style_upgrade_card(button: Button, choice: Dictionary) -> void:
	var rarity_name: String = String(choice.get("rarity_name", "普通"))
	if _flow_state.event_active:
		rarity_name = "事件"
	var accent: Color = UI.RARITY_COMMON
	match rarity_name:
		"稀有": accent = UI.RARITY_RARE
		"传说": accent = UI.RARITY_LEGEND
		"事件": accent = UI.ACCENT_OMEN
	if _flow_state.shopping:
		accent = UI.ACCENT_GOLD
	button.add_theme_stylebox_override("normal", UI.surface(UI.BG_PANEL, UI.STROKE_QUIET, 12, 1, 6))
	var focused := UI.surface(UI.BG_PANEL_ELEV, accent, 12, 2)
	button.add_theme_stylebox_override("hover", focused)
	button.add_theme_stylebox_override("focus", focused)
	button.add_theme_stylebox_override("pressed", focused)
	button.add_theme_stylebox_override("disabled", UI.surface(UI.BG_DEEP, UI.STROKE_QUIET))
	button.add_theme_color_override("font_color", UI.TEXT_PRIMARY)
	button.add_theme_color_override("font_hover_color", UI.TEXT_PRIMARY)
	button.add_theme_color_override("font_pressed_color", UI.TEXT_PRIMARY)
	button.add_theme_color_override("font_disabled_color", UI.TEXT_DISABLED)
	if button.disabled:
		accent = UI.TEXT_DISABLED
	var emblem: Control = button.get_node_or_null("CardEmblem") as Control
	if emblem != null:
		emblem.set_meta(&"accent", accent)
		emblem.set_meta(&"identity", String(choice.get("id", "")))
		emblem.queue_redraw()
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
		title_label.add_theme_color_override("font_color", UI.TEXT_DISABLED if button.disabled else UI.TEXT_PRIMARY)
	if footer_label != null:
		footer_label.add_theme_color_override("font_color", Color(accent, 0.84))
	var description_label: Label = button.get_node_or_null("CardDescription") as Label
	if description_label != null:
		description_label.add_theme_color_override("font_color", UI.TEXT_DISABLED if button.disabled else UI.TEXT_SECONDARY)
	var sigil_label: Label = button.get_node_or_null("CardSigil") as Label
	if sigil_label != null:
		sigil_label.add_theme_color_override("font_color", Color(accent, 0.84))



func _create_upgrade_card_content(button: Button) -> void:
	var accent_bar := ColorRect.new()
	accent_bar.name = "CardAccent"
	accent_bar.position = Vector2(12.0, 0.0)
	accent_bar.size = Vector2(276.0, 3.0)
	accent_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(accent_bar)

	var rarity_label := Label.new()
	rarity_label.name = "CardRarity"
	rarity_label.position = Vector2(23.0, 20.0)
	rarity_label.size = Vector2(254.0, 22.0)
	rarity_label.add_theme_font_size_override("font_size", 14)
	rarity_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(rarity_label)

	var separator := ColorRect.new()
	separator.name = "CardSeparator"
	separator.position = Vector2(24.0, 139.0)
	separator.size = Vector2(252.0, 1.0)
	separator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(separator)

	var title_label := Label.new()
	title_label.name = "CardTitle"
	title_label.position = Vector2(23.0, 84.0)
	title_label.size = Vector2(254.0, 48.0)
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_label.add_theme_font_size_override("font_size", UI.HEADLINE)
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(title_label)

	var sigil_label := Label.new()
	sigil_label.name = "CardSigil"
	sigil_label.position = Vector2(0.0, 63.0)
	sigil_label.size = Vector2(300.0, 64.0)
	sigil_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sigil_label.text = "◇"
	sigil_label.visible = false
	sigil_label.add_theme_font_size_override("font_size", UI.DISPLAY)
	sigil_label.add_theme_color_override("font_color", Color(0.60, 0.90, 1.0, 0.82))
	sigil_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(sigil_label)
	var emblem := Control.new()
	emblem.name = "CardEmblem"
	emblem.position = Vector2(218, 13)
	emblem.size = Vector2(112, 80)
	emblem.scale = Vector2(0.55, 0.55)
	emblem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	emblem.draw.connect(func(): UI.draw_reward_emblem(emblem, emblem.get_meta(&"accent", UI.ACCENT_MOON), String(emblem.get_meta(&"identity", ""))))
	button.add_child(emblem)

	var description_label := Label.new()
	description_label.name = "CardDescription"
	description_label.position = Vector2(23.0, 156.0)
	description_label.size = Vector2(254.0, 70.0)
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description_label.add_theme_font_size_override("font_size", UI.BODY)
	description_label.add_theme_color_override("font_color", UI.TEXT_SECONDARY)
	description_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(description_label)

	var cost_label := Label.new()
	cost_label.name = "CardCost"
	cost_label.position = Vector2(23, 232)
	cost_label.size = Vector2(254, 36)
	cost_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cost_label.add_theme_font_size_override("font_size", UI.CAPTION)
	cost_label.add_theme_color_override("font_color", UI.ACCENT_RISK)
	cost_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(cost_label)

	var badge := Panel.new()
	badge.name = "CardBadge"
	badge.position = Vector2(18, 270)
	badge.size = Vector2(264, 34)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(badge)

	var footer_label := Label.new()
	footer_label.name = "CardFooter"
	footer_label.position = Vector2(23.0, 270.0)
	footer_label.size = Vector2(254.0, 34.0)
	footer_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
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
	var cost := (button.get_node("CardCost") as Label).text
	var tooltip_lines := [card_name, description, cost].filter(func(line: String) -> bool: return not line.is_empty())
	button.tooltip_text = "\n".join(PackedStringArray(tooltip_lines))
	(button.get_node("CardRarity") as Label).text = "[%s]  %s" % [shortcut, rarity_name]
	(button.get_node("CardTitle") as Label).text = card_name
	var effect := button.get_node("CardDescription") as Label
	effect.text = description
	effect.add_theme_font_size_override("font_size", UI.BODY + (2 if _settings != null and _settings.get_large_text_enabled() else 0))
	(button.get_node("CardFooter") as Label).text = footer_text



func _play_upgrade_overlay_intro() -> void:
	if not is_instance_valid(_upgrade_overlay) or not _upgrade_overlay.visible:
		return
	if _upgrade_tween != null and _upgrade_tween.is_valid():
		_upgrade_tween.kill()
	var dimmer: ColorRect = _upgrade_overlay.get_node("UpgradeDimmer") as ColorRect
	var panel: Panel = _upgrade_overlay.get_node("UpgradePanel") as Panel
	if dimmer == null or panel == null:
		return
	panel.position = Vector2(
		(DISPLAY_SIZE.x - panel.size.x) * 0.5,
		(DISPLAY_SIZE.y - panel.size.y) * 0.5
	)
	var reduced: bool = _settings != null and _settings.get_reduced_effects_enabled()
	var enter_offset: float = 0.0 if reduced else 8.0
	dimmer.modulate = Color(1.0, 1.0, 1.0, 0.0)
	panel.pivot_offset = panel.size * 0.5
	panel.modulate = Color(1.0, 1.0, 1.0, 0.0)
	panel.scale = Vector2.ONE
	_upgrade_title.modulate = Color(1.0, 1.0, 1.0, 0.0)
	_upgrade_hint.modulate = Color(1.0, 1.0, 1.0, 0.0)
	if is_instance_valid(_upgrade_victory_summary) and _upgrade_victory_summary.visible:
		_upgrade_victory_summary.position = Vector2(50.0, 180.0 + enter_offset)
		_upgrade_victory_summary.modulate = Color(1.0, 1.0, 1.0, 0.0)
	var visible_cards := _upgrade_buttons.filter(func(button: Button) -> bool: return button.visible)
	shop_exit_button.visible = _flow_state.shopping
	shop_exit_button.disabled = false
	_configure_choice_navigation(visible_cards.filter(func(button: Button) -> bool: return not button.disabled))
	var row_width := float(visible_cards.size()) * (CARD_SIZE.x + CARD_GAP) - CARD_GAP
	var row_start := (panel.size.x - row_width) * 0.5
	for choice_index in range(visible_cards.size()):
		var button: Button = visible_cards[choice_index]
		var resting_position := Vector2(row_start + float(choice_index) * (CARD_SIZE.x + CARD_GAP), CARD_TOP)
		button.position = resting_position + Vector2(0.0, enter_offset)
		button.scale = Vector2.ONE
		button.modulate = Color(1.0, 1.0, 1.0, 0.0)
	_upgrade_tween = create_tween().set_parallel(true)
	if is_instance_valid(_soundscape):
		_soundscape.play_card()
	_upgrade_tween.tween_property(dimmer, "modulate:a", 1.0, 0.22)
	_upgrade_tween.tween_property(panel, "modulate:a", 1.0, 0.20)
	_upgrade_tween.tween_property(_upgrade_title, "modulate:a", 1.0, 0.24).set_delay(0.06)
	_upgrade_tween.tween_property(_upgrade_hint, "modulate:a", 1.0, 0.20).set_delay(0.16)
	if is_instance_valid(_upgrade_victory_summary) and _upgrade_victory_summary.visible:
		_upgrade_tween.tween_property(
			_upgrade_victory_summary, "modulate:a", 1.0, 0.26
		).set_delay(0.12)
		_upgrade_tween.tween_property(
			_upgrade_victory_summary, "position", Vector2(50.0, 180.0), 0.34
		).set_delay(0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	for choice_index in range(visible_cards.size()):
		var button: Button = visible_cards[choice_index]
		var resting_position := Vector2(row_start + float(choice_index) * (CARD_SIZE.x + CARD_GAP), CARD_TOP)
		var delay: float = 0.08 + float(choice_index) * 0.04
		_upgrade_tween.tween_property(button, "modulate:a", 1.0, 0.20).set_delay(delay)
		_upgrade_tween.tween_property(button, "position", resting_position, 0.30).set_delay(delay)



func _configure_choice_navigation(buttons: Array[Button]) -> void:
	for button: Button in _upgrade_buttons:
		button.focus_neighbor_left = NodePath()
		button.focus_neighbor_right = NodePath()
		button.focus_neighbor_top = NodePath()
		button.focus_neighbor_bottom = NodePath()
		button.focus_next = NodePath()
		button.focus_previous = NodePath()
	for button_index in range(buttons.size()):
		var button := buttons[button_index]
		var previous := buttons[posmod(button_index - 1, buttons.size())]
		var next := buttons[(button_index + 1) % buttons.size()]
		button.focus_neighbor_left = button.get_path_to(previous)
		button.focus_neighbor_right = button.get_path_to(next)
		if shop_exit_button.visible:
			button.focus_neighbor_bottom = button.get_path_to(shop_exit_button)
			button.focus_next = button.get_path_to(shop_exit_button if button_index == buttons.size() - 1 else next)
			button.focus_previous = button.get_path_to(shop_exit_button if button_index == 0 else previous)
	if shop_exit_button.visible:
		var first := buttons[0] if not buttons.is_empty() else shop_exit_button
		var last := buttons.back() as Button if not buttons.is_empty() else shop_exit_button
		shop_exit_button.focus_neighbor_top = shop_exit_button.get_path_to(first)
		shop_exit_button.focus_next = shop_exit_button.get_path_to(first)
		shop_exit_button.focus_previous = shop_exit_button.get_path_to(last)


