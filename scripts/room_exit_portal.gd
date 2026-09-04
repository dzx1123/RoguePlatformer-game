extends Node2D

class_name RoomExitPortal

## A visual room-exit gateway. Main owns the flow transition while this node owns
## the light pillar, hovering motes, and contextual prompt bubble.

signal entered

var _visual_time: float = 0.0
var _activating: bool = false
var _prompt_root: Control
var _prompt_label: Label
var _opener_near: bool = false


func setup(prompt_text: String = "E 进入下一房") -> void:
	set_prompt_text(prompt_text)


func _ready() -> void:
	_create_prompt_bubble()


func set_prompt_text(prompt_text: String) -> void:
	set_meta(&"prompt_text", prompt_text)
	if is_instance_valid(_prompt_label):
		_refresh_prompt()


func is_in_range(opener_position: Vector2) -> bool:
	var offset: Vector2 = opener_position - global_position
	return absf(offset.x) <= 88.0 and absf(offset.y) <= 72.0


func set_opener_position(opener_position: Vector2) -> void:
	_opener_near = is_in_range(opener_position)
	_refresh_prompt()


func _refresh_prompt() -> void:
	if is_instance_valid(_prompt_label):
		_prompt_label.text = String(get_meta(&"prompt_text", "E 进入下一房")) if _opener_near else "走近光柱后互动"


func play_activation() -> void:
	if _activating:
		return
	_activating = true
	if is_instance_valid(_prompt_root):
		var tween := _prompt_root.create_tween().set_parallel(true)
		tween.tween_property(_prompt_root, "modulate:a", 0.0, 0.16)
		tween.tween_property(_prompt_root, "position:y", -252.0, 0.16)
	entered.emit()
	queue_redraw()


func is_activating() -> bool:
	return _activating


func _create_prompt_bubble() -> void:
	_prompt_root = Control.new()
	_prompt_root.name = "PromptBubble"
	_prompt_root.position = Vector2(-142.0, -224.0)
	_prompt_root.size = Vector2(284.0, 52.0)
	_prompt_root.pivot_offset = Vector2(142.0, 43.0)
	_prompt_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt_root.z_index = 20
	add_child(_prompt_root)

	var prompt_panel := Panel.new()
	prompt_panel.position = Vector2.ZERO
	prompt_panel.size = Vector2(284.0, 44.0)
	prompt_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var prompt_style := StyleBoxFlat.new()
	prompt_style.bg_color = Color(0.018, 0.045, 0.085, 0.96)
	prompt_style.border_color = Color(0.42, 0.91, 1.0, 0.92)
	prompt_style.set_border_width_all(2)
	prompt_style.corner_radius_top_left = 12
	prompt_style.corner_radius_top_right = 12
	prompt_style.corner_radius_bottom_left = 12
	prompt_style.corner_radius_bottom_right = 12
	prompt_style.shadow_color = Color(0.0, 0.02, 0.08, 0.70)
	prompt_style.shadow_size = 10
	prompt_style.shadow_offset = Vector2(0.0, 5.0)
	prompt_panel.add_theme_stylebox_override("panel", prompt_style)
	_prompt_root.add_child(prompt_panel)

	var badge := Label.new()
	badge.name = "ExitBadge"
	badge.position = Vector2(9.0, 7.0)
	badge.size = Vector2(54.0, 30.0)
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.text = "NEXT"
	badge.add_theme_font_size_override("font_size", 12)
	badge.add_theme_color_override("font_color", Color(0.76, 0.96, 1.0, 1.0))
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt_root.add_child(badge)

	_prompt_label = Label.new()
	_prompt_label.name = "PromptText"
	_prompt_label.position = Vector2(70.0, 4.0)
	_prompt_label.size = Vector2(204.0, 34.0)
	_prompt_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_label.text = "走近光柱后互动"
	_prompt_label.add_theme_font_size_override("font_size", 17)
	_prompt_label.add_theme_color_override("font_color", Color(0.88, 0.97, 1.0, 1.0))
	_prompt_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt_root.add_child(_prompt_label)

	var pointer := Polygon2D.new()
	pointer.name = "PromptPointer"
	pointer.position = Vector2(142.0, 42.0)
	pointer.polygon = PackedVector2Array([
		Vector2(-10.0, 0.0), Vector2(10.0, 0.0), Vector2(0.0, 11.0),
	])
	pointer.color = Color(0.42, 0.91, 1.0, 0.92)
	_prompt_root.add_child(pointer)


func _process(delta: float) -> void:
	_visual_time += delta
	if is_instance_valid(_prompt_root) and not _activating:
		var pulse: float = 0.5 + 0.5 * sin(_visual_time * 3.6)
		_prompt_root.position = Vector2(
			-142.0,
			-224.0 - sin(_visual_time * 2.6) * 3.0
		)
		_prompt_root.scale = Vector2.ONE * (1.0 + pulse * 0.018)
		_prompt_root.modulate.a = 0.89 + pulse * 0.11
	queue_redraw()


func _draw() -> void:
	var pulse: float = 0.5 + 0.5 * sin(_visual_time * 3.2)
	var activation: float = 1.0 if _activating else 0.0
	var beam_height: float = 158.0 + pulse * 13.0 + activation * 44.0
	var base_width: float = 44.0 + pulse * 6.0
	var top_width: float = 18.0 + pulse * 3.0
	var beam_alpha: float = 0.20 + pulse * 0.11 + activation * 0.16

	draw_set_transform(Vector2(0.0, 23.0), 0.0, Vector2(1.0, 0.26))
	draw_circle(Vector2.ZERO, 76.0 + pulse * 11.0, Color(0.10, 0.78, 1.0, 0.16))
	draw_circle(Vector2.ZERO, 51.0 + pulse * 6.0, Color(0.36, 0.94, 1.0, 0.20))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	draw_colored_polygon(
		PackedVector2Array([
			Vector2(-base_width, 22.0),
			Vector2(-top_width, 22.0 - beam_height),
			Vector2(top_width, 22.0 - beam_height),
			Vector2(base_width, 22.0),
		]),
		Color(0.25, 0.86, 1.0, beam_alpha)
	)
	draw_line(
		Vector2(-base_width * 0.56, 20.0),
		Vector2(-top_width * 0.52, 22.0 - beam_height),
		Color(0.66, 0.97, 1.0, 0.72),
		2.0
	)
	draw_line(
		Vector2(base_width * 0.56, 20.0),
		Vector2(top_width * 0.52, 22.0 - beam_height),
		Color(0.66, 0.97, 1.0, 0.72),
		2.0
	)

	for ring_index in range(4):
		var ring_ratio: float = float(ring_index) / 3.0
		var ring_y: float = 16.0 - ring_ratio * (beam_height - 18.0)
		var ring_radius: float = 28.0 - ring_ratio * 11.0 + pulse * 1.4
		draw_arc(
			Vector2(0.0, ring_y),
			ring_radius,
			-PI + sin(_visual_time * 1.8 + ring_index) * 0.15,
			sin(_visual_time * 1.8 + ring_index) * 0.15,
			18,
			Color(0.72, 0.98, 1.0, 0.58 - ring_ratio * 0.22),
			1.6
		)

	for mote_index in range(8):
		var mote_phase: float = _visual_time * (1.1 + float(mote_index % 3) * 0.18) + float(mote_index) * 1.73
		var mote_x: float = sin(mote_phase) * (12.0 + float(mote_index % 4) * 7.0)
		var mote_y: float = 18.0 - fposmod(mote_phase * 34.0, beam_height - 16.0)
		draw_circle(
			Vector2(mote_x, mote_y),
			1.6 + float(mote_index % 2) * 0.8,
			Color(0.76, 0.98, 1.0, 0.52 + pulse * 0.30)
		)

	draw_circle(Vector2(0.0, 18.0), 12.0 + pulse * 3.0, Color(0.78, 0.98, 1.0, 0.76))
	draw_circle(Vector2(0.0, 18.0), 5.0 + pulse * 1.4, Color(0.18, 0.76, 1.0, 0.96))
