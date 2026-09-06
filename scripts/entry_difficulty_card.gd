extends Button

## Code-native moon card. The visual face lifts without moving the input target.
const UI := preload("res://scripts/ui_theme.gd")
var _face: Panel
var _bar: ColorRect
var _lift_tween: Tween
var _accent: Color = UI.ACCENT_MOON
var _reduced: bool = false
var _highlighted: bool = false

func configure(title: String, consequence: String, growth: String, accent: Color) -> void:
	_accent = accent
	text = ""
	# All consequences are already visible on the card; a duplicate native
	# tooltip covers the neighboring choice when the pointer rests here.
	tooltip_text = ""
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state in ["normal", "hover", "pressed", "focus"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	_face = Panel.new()
	_face.name = "CardFace"
	_face.size = size
	_face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_face.draw.connect(_draw_sigil)
	add_child(_face)
	_bar = ColorRect.new()
	_bar.name = "FocusRail"
	_bar.position = Vector2(12, 0)
	_bar.size = Vector2(size.x - 24, 4)
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_face.add_child(_bar)
	_add_label("Name", title, Vector2(128, 56), Vector2(180, 38), UI.HEADLINE, accent)
	_add_label("Consequence", consequence, Vector2(128, 112), Vector2(180, 108), UI.BODY, UI.TEXT_PRIMARY)
	_add_label("Growth", growth, Vector2(24, 244), Vector2(size.x - 48, 50), UI.CAPTION, UI.TEXT_SECONDARY)
	gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseMotion and event.relative.length_squared() > 0.0:
			grab_focus())
	focus_entered.connect(func(): _set_highlight(true))
	focus_exited.connect(func(): _set_highlight(false))
	_set_highlight(false)

func set_reduced_motion(enabled: bool) -> void:
	_reduced = enabled
	if _lift_tween != null and _lift_tween.is_valid():
		_lift_tween.kill()
	_face.position.y = 0.0 if enabled or not _highlighted else -6.0
	queue_redraw()

func _add_label(node_name: String, value: String, pos: Vector2, extent: Vector2, font_size: int, color: Color) -> void:
	var label := Label.new()
	label.name = node_name
	label.text = value
	label.position = pos
	label.size = extent
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_face.add_child(label)

func _set_highlight(active: bool) -> void:
	_highlighted = active
	var accent: Color = UI.ACCENT_MOON if active else _accent
	var surface := UI.surface(UI.BG_PANEL_ELEV if active else UI.BG_PANEL,
		accent if active else Color(_accent, 0.36), UI.PANEL_RADIUS, 1, 14 if active else 6)
	if active:
		surface.shadow_color = Color(UI.ACCENT_MOON, 0.35)
		surface.shadow_offset = Vector2.ZERO
	_face.add_theme_stylebox_override("panel", surface)
	_bar.color = UI.ACCENT_MOON if active else Color(_accent, 0.25)
	if _lift_tween != null and _lift_tween.is_valid():
		_lift_tween.kill()
	if is_inside_tree():
		_lift_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		_lift_tween.tween_property(_face, "position:y", -6.0 if active and not _reduced else 0.0, 0.14)
	set_process(true)
	queue_redraw()

func _process(_delta: float) -> void:
	_face.queue_redraw()
	if _lift_tween == null or not _lift_tween.is_running():
		set_process(false)

func _draw_sigil() -> void:
	var center := Vector2(72.0, 134.0)
	var ink: Color = UI.ACCENT_MOON if _highlighted else _accent
	_face.draw_arc(center, 43.0, 0, TAU, 72, Color(ink, 0.30), 1.0, true)
	_face.draw_arc(center, 49.0, 0, TAU, 72, Color(ink, 0.12), 1.0, true)
	# A real crescent polygon avoids painting a solid disc over the panel.
	var moon := PackedVector2Array()
	for step in range(41):
		var angle: float = PI * 0.35 + float(step) / 40.0 * PI * 1.30
		moon.append(center + Vector2(cos(angle), sin(angle)) * 29.0)
	var top := moon[moon.size() - 1]
	var bottom := moon[0]
	for step in range(1, 31):
		var t: float = float(step) / 30.0
		moon.append(top.lerp(bottom, t) + Vector2(-24.0 * sin(t * PI), 0))
	_face.draw_colored_polygon(moon, ink)
	_face.draw_line(center + Vector2(0, 57), center + Vector2(0, 77), Color(ink, 0.35), 1.0)
