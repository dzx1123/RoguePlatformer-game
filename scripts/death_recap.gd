extends Control

## Short post-death readout so a failed route explains what happened.
class_name DeathRecap

const DISPLAY_SIZE := Vector2(1280.0, 840.0)

var _title: Label
var _body: RichTextLabel
var _hint: Label


func _ready() -> void:
	name = "DeathRecap"
	position = Vector2.ZERO
	size = DISPLAY_SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_build_interface()


func present(summary: Dictionary, continue_prompt: String) -> void:
	_title.text = "路线中断"
	_body.text = _format_body(summary)
	_hint.text = continue_prompt
	visible = true


func hide_recap() -> void:
	visible = false


func get_snapshot() -> Dictionary:
	return {
		"visible": visible,
		"title": _title.text if is_instance_valid(_title) else "",
		"body": _body.text if is_instance_valid(_body) else "",
		"hint": _hint.text if is_instance_valid(_hint) else "",
	}


func _build_interface() -> void:
	var dimmer := ColorRect.new()
	dimmer.name = "Dimmer"
	dimmer.size = DISPLAY_SIZE
	dimmer.color = Color(0.008, 0.016, 0.036, 0.72)
	dimmer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dimmer)

	var sheet := Panel.new()
	sheet.name = "Sheet"
	sheet.position = Vector2(330.0, 176.0)
	sheet.size = Vector2(620.0, 420.0)
	sheet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.018, 0.042, 0.072, 0.96)
	style.border_color = Color(0.78, 0.42, 0.46, 0.82)
	style.set_border_width_all(2)
	style.corner_radius_top_left = 14
	style.corner_radius_top_right = 14
	style.corner_radius_bottom_left = 14
	style.corner_radius_bottom_right = 14
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.55)
	style.shadow_size = 16
	sheet.add_theme_stylebox_override("panel", style)
	add_child(sheet)

	var rule := ColorRect.new()
	rule.position = Vector2(28.0, 78.0)
	rule.size = Vector2(564.0, 2.0)
	rule.color = Color(0.86, 0.46, 0.50, 0.80)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sheet.add_child(rule)

	_title = Label.new()
	_title.name = "Title"
	_title.position = Vector2(28.0, 24.0)
	_title.size = Vector2(564.0, 44.0)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 30)
	_title.add_theme_color_override("font_color", Color(0.98, 0.86, 0.86, 1.0))
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sheet.add_child(_title)

	_body = RichTextLabel.new()
	_body.name = "Body"
	_body.position = Vector2(36.0, 96.0)
	_body.size = Vector2(548.0, 236.0)
	_body.bbcode_enabled = true
	_body.scroll_active = false
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body.add_theme_font_size_override("normal_font_size", 17)
	_body.add_theme_color_override("default_color", Color(0.86, 0.90, 0.94, 1.0))
	sheet.add_child(_body)

	_hint = Label.new()
	_hint.name = "Hint"
	_hint.position = Vector2(28.0, 348.0)
	_hint.size = Vector2(564.0, 42.0)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.add_theme_font_size_override("font_size", 15)
	_hint.add_theme_color_override("font_color", Color(0.62, 0.78, 0.86, 0.94))
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sheet.add_child(_hint)


func _format_body(summary: Dictionary) -> String:
	var reason: String = _cause_label(String(summary.get("reason", "unknown")))
	var room_title: String = String(summary.get("room_title", "未知房间"))
	var encounter: String = String(summary.get("encounter", "战斗房"))
	var room_number: int = int(summary.get("room_number", 0))
	var lives: int = int(summary.get("lives_remaining", 0))
	var room_damage: int = int(summary.get("room_damage", 0))
	var run_damage: int = int(summary.get("run_damage", 0))
	var elapsed: float = float(summary.get("elapsed_seconds", 0.0))
	var source_line: String = _format_sources(
		summary.get("damage_sources", {}) as Dictionary
	)
	return (
		"[color=#ffb4b8]死因[/color]  %s\n"
		+ "[color=#9fd7ea]房间[/color]  第 %d 房 · %s · %s\n"
		+ "[color=#9fd7ea]本房承伤[/color]  %d    [color=#9fd7ea]本局承伤[/color]  %d\n"
		+ "[color=#9fd7ea]用时[/color]  %d 秒    [color=#9fd7ea]剩余命数[/color]  %d\n\n"
		+ "[color=#c9d7de]承伤来源[/color]\n%s"
	) % [
		reason,
		room_number,
		room_title,
		encounter,
		room_damage,
		run_damage,
		roundi(elapsed),
		lives,
		source_line,
	]


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
		"enemy_attack":
			return "近战打击"
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
		_:
			return cause if not cause.is_empty() else "未知"
