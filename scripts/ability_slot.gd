extends Control

## Compact bottom-HUD ability icon with hover help and a cooldown mask.

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
	_icon_type = icon_type
	_title = title
	_hotkey = hotkey
	_description = description
	_accent = accent
	_refresh()


func set_cooldown(remaining: float, duration: float) -> void:
	_cooldown_remaining = maxf(0.0, remaining)
	_cooldown_duration = maxf(0.01, duration)
	_refresh()


func _create_labels() -> void:
	_title_label = Label.new()
	_title_label.position = Vector2(2.0, 50.0)
	_title_label.size = Vector2(74.0, 16.0)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 11)
	_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_title_label)

	_key_label = Label.new()
	_key_label.position = Vector2(5.0, 4.0)
	_key_label.size = Vector2(20.0, 18.0)
	_key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_key_label.add_theme_font_size_override("font_size", 12)
	_key_label.add_theme_color_override("font_color", Color(0.84, 0.94, 1.0, 1.0))
	_key_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_key_label)

	_countdown_label = Label.new()
	_countdown_label.position = Vector2(18.0, 20.0)
	_countdown_label.size = Vector2(42.0, 27.0)
	_countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_countdown_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_countdown_label.add_theme_font_size_override("font_size", 18)
	_countdown_label.add_theme_color_override("font_color", Color.WHITE)
	_countdown_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_countdown_label)


func _refresh() -> void:
	tooltip_text = "%s [%s]\n%s" % [_title, _hotkey, _description]
	if is_instance_valid(_title_label):
		_title_label.text = _title
		_title_label.add_theme_color_override("font_color", _accent.lightened(0.15))
		_key_label.text = _hotkey
		_countdown_label.text = "" if _cooldown_remaining <= 0.0 else "%.1f" % _cooldown_remaining
	queue_redraw()


func _on_mouse_entered() -> void:
	_is_hovered = true
	queue_redraw()


func _on_mouse_exited() -> void:
	_is_hovered = false
	queue_redraw()


func _draw() -> void:
	var slot_rect := Rect2(Vector2.ZERO, size)
	var glow_alpha: float = 0.30 if _is_hovered else 0.14
	draw_rect(slot_rect.grow(3.0), Color(_accent, glow_alpha), false, 2.0)
	draw_rect(slot_rect, Color(0.018, 0.046, 0.070, 0.98), true)
	draw_rect(Rect2(3.0, 3.0, size.x - 6.0, 3.0), Color(_accent, 0.32), true)
	draw_rect(Rect2(3.0, size.y - 23.0, size.x - 6.0, 20.0), Color(0.006, 0.018, 0.030, 0.78), true)
	draw_rect(slot_rect, Color(_accent, 0.70), false, 2.0)
	draw_rect(Rect2(5.0, 4.0, 20.0, 18.0), Color(0.01, 0.025, 0.04, 0.94), true)
	draw_rect(Rect2(5.0, 4.0, 20.0, 18.0), Color(_accent, 0.54), false, 1.0)
	_draw_icon()
	var icon_height: float = size.y - 21.0
	if _cooldown_remaining > 0.0:
		var fill_ratio: float = clampf(_cooldown_remaining / _cooldown_duration, 0.0, 1.0)
		draw_rect(Rect2(3.0, 3.0, size.x - 6.0, icon_height * fill_ratio), Color(0.01, 0.02, 0.04, 0.74), true)
	else:
		draw_arc(Vector2(size.x * 0.5, icon_height * 0.5 + 3.0), 20.0, -PI * 0.5, TAU - PI * 0.5, 20, Color(_accent, 0.72), 1.5, true)


func _draw_icon() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(size.x / 100.0, 0.75))
	var center := Vector2(50.0, 35.0)
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
