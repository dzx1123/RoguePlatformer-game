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
var _beam_texture: ImageTexture


func setup(prompt_text: String = "E 进入下一房") -> void:
	set_prompt_text(prompt_text)


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_beam_texture = _create_beam_texture()
	_create_prompt_bubble()


func _create_beam_texture() -> ImageTexture:
	var image := Image.create(128, 256, false, Image.FORMAT_RGBA8)
	for y in range(image.get_height()):
		var vertical: float = float(y) / float(image.get_height() - 1)
		# Almost invisible at the top, increasingly luminous toward the floor.
		var height_fade: float = smoothstep(0.0, 1.0, vertical)
		for x in range(image.get_width()):
			var normalized_x: float = absf(float(x) / 127.0 * 2.0 - 1.0)
			var edge_fade: float = 1.0 - smoothstep(0.38, 1.0, normalized_x)
			var core: float = 1.0 - smoothstep(0.0, 0.30, normalized_x)
			var alpha: float = height_fade * edge_fade * (0.24 + core * 0.52)
			var color := Color(
				lerpf(0.25, 0.40, height_fade),
				lerpf(0.78, 0.94, height_fade),
				1.0,
				alpha
			)
			image.set_pixel(x, y, color)
	return ImageTexture.create_from_image(image)


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
	badge.text = "下一房"
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
	var pulse := 0.5 + 0.5 * sin(_visual_time * 3.2)
	var strength := 1.5 if _activating else 1.0
	# Unequal blue-white streams rise from a bright ground pool.
	for ray in range(17):
		var phase := float(ray) * 2.399
		var x := sin(phase) * 43.0
		var height := (65.0 + 120.0 * (0.5 + 0.5 * sin(_visual_time * 1.7 + phase))) * strength
		var width := 3.0 + float(ray % 3) * 2.0
		if is_instance_valid(_beam_texture):
			draw_texture_rect(_beam_texture, Rect2(x - width, 20.0 - height, width * 2.0, height), false, Color(0.18,0.52,1.0,0.95 * strength))
		var rise := fposmod(_visual_time * (0.35 + float(ray % 4) * 0.08) + float(ray) * 0.13, 1.0)
		var pos := Vector2(x, 18.0 - rise * height)
		draw_line(pos, pos + Vector2(0, 5.0), Color(0.30,0.68,1.0, sin(rise * PI) * 0.95), 1.2, true)
	draw_set_transform(Vector2(0,22), 0, Vector2(1,0.18))
	for layer in range(10,0,-1):
		draw_circle(Vector2.ZERO, float(layer) * 6.0, Color(0.04,0.35,1.0,0.09 * strength))
	draw_circle(Vector2.ZERO, 31.0 + pulse * 3.0, Color(0.28,0.62,1.0,0.85))
	draw_set_transform(Vector2.ZERO,0,Vector2.ONE)