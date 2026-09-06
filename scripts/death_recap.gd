extends Control

## Readable death result with explicit actions; gameplay owns life accounting.
class_name DeathRecap
signal retry_requested
signal title_requested
const DISPLAY_SIZE := Vector2(1280.0, 720.0)
const UI := preload("res://scripts/ui_theme.gd")
var _title: Label
var _body: RichTextLabel
var _hint: Label
var _values: Array[Label] = []
var _details: Array[Label] = []
var _retry: Button
var _return: Button

func _ready() -> void:
	name = "DeathRecap"
	size = DISPLAY_SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_interface()
	visible = false

func present(summary: Dictionary, continue_prompt: String) -> void:
	_title.text = "陨落"
	_body.text = "[center]死因 · %s[/center]" % _cause_label(String(summary.get("reason", "unknown")))
	_hint.text = continue_prompt
	_values[0].text = "第 %d / 20 房" % int(summary.get("room_number", 1))
	_details[0].text = "%s · %s" % [summary.get("room_title", ""), summary.get("encounter", "")]
	var sources: Dictionary = summary.get("damage_sources", {}) as Dictionary
	var keys: Array = sources.keys()
	keys.sort_custom(func(left: Variant, right: Variant) -> bool: return int(sources[left]) > int(sources[right]))
	_values[1].text = _cause_label(String(keys[0])) if not keys.is_empty() else _cause_label(String(summary.get("reason", "unknown")))
	_details[1].text = "本房承伤 %d · 本局承伤 %d" % [summary.get("room_damage", 0), summary.get("run_damage", 0)]
	_values[1].tooltip_text = _format_sources(sources)
	var lives: int = int(summary.get("lives_remaining", 0))
	_values[2].text = "%d / 3" % lives
	_details[2].text = "用剩余命数开启新路线" if lives > 0 else "再次挑战将重新选择难度"
	_retry.text = "再次挑战"
	visible = true
	_retry.grab_focus()

func hide_recap() -> void:
	visible = false

func ensure_focus() -> void:
	var owner: Control = get_viewport().gui_get_focus_owner()
	if visible and (owner == null or not is_ancestor_of(owner)):
		_retry.grab_focus()

func get_snapshot() -> Dictionary:
	return {"visible": visible, "title": _title.text, "body": _body.text,
		"hint": _hint.text, "retry_visible": _retry.visible and visible}

func _build_interface() -> void:
	var dimmer := ColorRect.new()
	dimmer.name = "Dimmer"
	dimmer.size = DISPLAY_SIZE
	dimmer.color = UI.BG_VEIL
	dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dimmer)
	var sheet := Panel.new()
	sheet.name = "Sheet"
	sheet.position = Vector2(80, 138)
	sheet.size = Vector2(1120, 564)
	sheet.mouse_filter = Control.MOUSE_FILTER_STOP
	sheet.add_theme_stylebox_override("panel", UI.surface(UI.BG_PANEL, UI.STROKE_QUIET, 16, 1, 18))
	add_child(sheet)
	var rule := ColorRect.new()
	rule.position = Vector2(16, 0)
	rule.size = Vector2(1088, 3)
	rule.color = UI.ACCENT_RISK
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sheet.add_child(rule)
	_title = _label(sheet, "Title", "", Vector2(40, 35), Vector2(1040, 48), UI.TITLE, UI.TEXT_PRIMARY)
	_body = RichTextLabel.new()
	_body.name = "Body"
	_body.position = Vector2(40, 92)
	_body.size = Vector2(1040, 40)
	_body.bbcode_enabled = true
	_body.scroll_active = false
	_body.add_theme_font_size_override("normal_font_size", UI.BODY)
	_body.add_theme_color_override("default_color", UI.ACCENT_RISK)
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sheet.add_child(_body)
	var headings := ["终止房间", "主要承伤来源", "剩余命数"]
	for index in range(3):
		var card := Panel.new()
		card.name = "DeathStat_%d" % index
		card.position = Vector2(50 + index * 340, 152)
		card.size = Vector2(320, 172)
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_theme_stylebox_override("panel", UI.surface(UI.BG_DEEP, Color(UI.ACCENT_RISK, 0.40), 12, 1))
		sheet.add_child(card)
		_label(card, "Heading", headings[index], Vector2(16, 20), Vector2(288, 24), UI.CAPTION, UI.TEXT_SECONDARY)
		_values.append(_label(card, "Value", "", Vector2(16, 58), Vector2(288, 44), UI.HEADLINE, UI.TEXT_PRIMARY))
		var detail := _label(card, "Detail", "", Vector2(16, 120), Vector2(288, 38), UI.CAPTION, UI.TEXT_SECONDARY)
		detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_details.append(detail)
	_retry = _button(sheet, "Retry", "再次挑战", Vector2(260, 374), UI.ACCENT_RISK)
	_return = _button(sheet, "ReturnTitle", "返回标题", Vector2(580, 374), UI.TEXT_SECONDARY)
	_retry.pressed.connect(func(): retry_requested.emit())
	_return.pressed.connect(func(): title_requested.emit())
	_retry.focus_neighbor_right = _retry.get_path_to(_return)
	_retry.focus_neighbor_left = _retry.get_path_to(_return)
	_retry.focus_next = _retry.get_path_to(_return)
	_return.focus_neighbor_left = _return.get_path_to(_retry)
	_return.focus_neighbor_right = _return.get_path_to(_retry)
	_return.focus_next = _return.get_path_to(_retry)
	_hint = _label(sheet, "Hint", "", Vector2(40, 448), Vector2(1040, 58), UI.CAPTION, UI.TEXT_SECONDARY)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func _label(parent: Control, node_name: String, value: String, pos: Vector2, extent: Vector2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.name = node_name
	label.text = value
	label.position = pos
	label.size = extent
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func _button(parent: Control, node_name: String, value: String, pos: Vector2, accent: Color) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = value
	button.position = pos
	button.size = Vector2(280, 54)
	button.add_theme_font_size_override("font_size", UI.HEADLINE)
	button.add_theme_stylebox_override("normal", UI.surface(UI.BG_PANEL_ELEV, Color(accent, 0.5), 12, 1))
	var focused := UI.card(accent, true)
	button.add_theme_stylebox_override("focus", focused)
	button.add_theme_stylebox_override("hover", focused)
	button.add_theme_stylebox_override("pressed", UI.surface(UI.BG_DEEP, accent))
	button.add_theme_color_override("font_color", UI.TEXT_PRIMARY)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	parent.add_child(button)
	return button


func _format_sources(sources: Dictionary) -> String:
	if sources.is_empty():
		return "[color=#8aa0ab]这一房没有记下具体来源。[/color]"
	var rows: Array[String] = []
	var keys: Array = sources.keys()
	keys.sort_custom(func(left: Variant, right: Variant) -> bool:
		return int(sources.get(left, 0)) > int(sources.get(right, 0))
	)
	for key_value: Variant in keys:
		var key := String(key_value)
		rows.append(
			"%s  %d" % [_cause_label(key), int(sources.get(key, 0))]
		)
		if rows.size() >= 4:
			break
	return "[color=#d7e4ea]%s[/color]" % "\n".join(rows)


func _cause_label(cause: String) -> String:
	match cause:
		"fall":
			return "坠落"
		"enemy_attack", "enemy_melee":
			return "近战打击"
		"enemy_projectile":
			return "远程弹幕"
		"war_chief_charge":
			return "战酋冲锋"
		"crystal_king_lunge":
			return "晶王突袭"
		"crystal_king_slam":
			return "晶王震地"
		"war_chief_slam":
			return "战酋重砸"
		"goblin_arrow":
			return "哥布林箭矢"
		"slime_projectile":
			return "晶黏弹幕"
		"boss_volley":
			return "首领弹幕"
		"boss_slam":
			return "首领震地"
		"arcane_trap":
			return "地面陷阱"
		"event_cost":
			return "奇遇代价"
		"interrupted":
			return "中途中断"
		"unknown":
			return "未记录的伤害"
		_:
			return "未分类伤害"
