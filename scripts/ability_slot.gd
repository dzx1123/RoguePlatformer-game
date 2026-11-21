extends Control

## Action icon, input prompt, and readable remaining cooldown.

const UI := preload("res://scripts/ui_theme.gd")
const KEY_BOUNDS := Rect2(54, 5, 37, 20)

enum IconType {
	ATTACK,
	DASH,
	SKILL,
}

var _icon_type: int = IconType.ATTACK
var _title: String = "技能"
var _hotkey: String = "K"
var _description: String = ""
var _accent := Color("#65dcff")
var _cooldown_remaining: float = 0.0
var _cooldown_duration: float = 1.0
var _is_hovered: bool = false
var _high_contrast: bool = false
var _panel_style: StyleBoxFlat
var _title_label: Label
var _key_label: Label
var _countdown_label: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	_create_labels()
	_refresh()


func configure(icon_type: int, title: String, hotkey: String, description: String, accent: Color) -> void:
	if icon_type == _icon_type and title == _title and hotkey == _hotkey and description == _description and accent == _accent:
		return
	var accent_changed := accent != _accent
	_icon_type = icon_type
	_title = title
	_hotkey = hotkey
	_description = description
	_accent = accent
	if accent_changed:
		_update_panel_style()
	_refresh()


func set_cooldown(remaining: float, duration: float) -> void:
	var clamped_remaining := maxf(0.0, remaining)
	var clamped_duration := maxf(0.01, duration)
	if clamped_remaining == _cooldown_remaining and clamped_duration == _cooldown_duration:
		return
	_cooldown_remaining = clamped_remaining
	_cooldown_duration = clamped_duration
	_countdown_label.text = "" if _cooldown_remaining <= 0.0 else "%.1f" % _cooldown_remaining
	queue_redraw()


func apply_accessibility(large_text: bool, high_contrast: bool) -> void:
	_high_contrast = high_contrast
	_title_label.add_theme_font_size_override("font_size", UI.CAPTION + (2 if large_text else 0))
	_key_label.add_theme_font_size_override("font_size", 11 + (2 if large_text else 0))
	_countdown_label.add_theme_font_size_override("font_size", UI.BODY + (2 if large_text else 0))
	_update_panel_style()
	_refresh()


func _create_labels() -> void:
	_title_label = Label.new()
	_title_label.position = Vector2(4, 32)
	_title_label.size = Vector2(88, 20)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title_label.clip_text = true
	_title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_title_label.add_theme_font_size_override("font_size", UI.CAPTION)
	_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_title_label)

	_key_label = Label.new()
	_key_label.position = KEY_BOUNDS.position
	_key_label.size = KEY_BOUNDS.size
	_key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_key_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_key_label.clip_text = true
	_key_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_key_label.add_theme_font_size_override("font_size", 11)
	_key_label.add_theme_color_override("font_color", Color(0.88, 0.97, 1.0, 1.0))
	_key_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_key_label)

	_countdown_label = Label.new()
	_countdown_label.position = Vector2(6, 3)
	_countdown_label.size = Vector2(43, 28)
	_countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_countdown_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_countdown_label.add_theme_font_size_override("font_size", UI.BODY)
	_countdown_label.add_theme_color_override("font_color", Color.WHITE)
	_countdown_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_countdown_label)


func _refresh() -> void:
	tooltip_text = "%s [%s]\n%s" % [_title, _hotkey, _description]
	if is_instance_valid(_title_label):
		_title_label.text = _title
		_title_label.add_theme_color_override("font_color", UI.TEXT_PRIMARY if _high_contrast else _accent.lightened(0.24))
		_key_label.text = _hotkey
		_countdown_label.text = "" if _cooldown_remaining <= 0.0 else "%.1f" % _cooldown_remaining
	queue_redraw()


func _update_panel_style() -> void:
	var fill := UI.BG_DEEP if _high_contrast else Color(UI.BG_PANEL, 0.91)
	var edge := Color(UI.TEXT_PRIMARY, 0.72) if _high_contrast else Color(_accent, 0.38)
	_panel_style = UI.surface(fill, edge, 7, 1)


func _on_mouse_entered() -> void:
	_is_hovered = true
	queue_redraw()


func _on_mouse_exited() -> void:
	_is_hovered = false
	queue_redraw()


func _draw() -> void:
	if _panel_style == null:
		_update_panel_style()
	draw_style_box(_panel_style, Rect2(Vector2.ZERO, size))
	draw_rect(KEY_BOUNDS, Color(UI.BG_DEEP, 0.90))
	draw_rect(KEY_BOUNDS, Color(_accent, 0.72 if _is_hovered else 0.4), false, 1.0)
	if _cooldown_remaining <= 0.0:
		_draw_icon()
	var bar_width := size.x - 16.0
	var ready_ratio := 1.0 - clampf(_cooldown_remaining / _cooldown_duration, 0.0, 1.0)
	draw_rect(Rect2(8, 53, bar_width, 2), Color(_accent, 0.16))
	draw_rect(Rect2(8, 53, bar_width * ready_ratio, 2), Color(_accent, 0.85))


func _draw_icon() -> void:
	draw_set_transform(Vector2(2, 1), 0.0, Vector2(0.50, 0.49))
	var center := Vector2(50.0, 34.0)
	if _icon_type == IconType.ATTACK:
		var blade := PackedVector2Array([
			Vector2(66.0, 14.0),
			Vector2(61.0, 35.0),
			Vector2(43.0, 48.0),
			Vector2(39.0, 44.0),
			Vector2(53.0, 27.0),
		])
		draw_colored_polygon(blade, Color(0.87, 0.97, 1.0, 0.94))
		draw_polyline(PackedVector2Array([Vector2(66.0, 14.0), Vector2(61.0, 35.0), Vector2(43.0, 48.0)]), _accent, 2.0, true)
		draw_line(Vector2(34.0, 39.0), Vector2(47.0, 52.0), Color(0.95, 0.75, 0.32, 1.0), 4.0, true)
		draw_line(Vector2(39.0, 48.0), Vector2(30.0, 57.0), Color(_accent, 0.92), 5.0, true)
		draw_circle(Vector2(29.0, 58.0), 3.0, Color(0.95, 0.75, 0.32, 1.0))
	elif _icon_type == IconType.DASH:
		for trail_index in range(3):
			var offset := float(trail_index) * 10.0
			draw_line(Vector2(19.0 - offset * 0.35, 40.0 - offset * 0.20), Vector2(61.0 - offset * 0.15, 40.0 - offset * 0.20), Color(_accent, 0.22 + float(trail_index) * 0.15), 3.0, true)
		draw_colored_polygon(PackedVector2Array([Vector2(28.0, 39.0), Vector2(56.0, 20.0), Vector2(49.0, 34.0), Vector2(73.0, 34.0), Vector2(42.0, 51.0), Vector2(49.0, 39.0)]), _accent)
	else:
		for arc_index in range(3):
			var radius := 16.0 + float(arc_index) * 7.0
			draw_arc(center, radius, -1.45, 0.75, 14, Color(_accent, 0.34 + float(arc_index) * 0.20), 2.5, true)
		draw_circle(center, 7.0, Color(1.0, 1.0, 1.0, 0.80))
		draw_circle(center, 4.0, _accent)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
