extends Control

class_name OpeningIntro

## First-launch veil over the title screen. 5.6s of moon-eclipse then corridor
## reveal, using the existing sanctum art and UI palette. Any confirm skips.

signal finished
signal slash_struck

const UI := preload("res://scripts/ui_theme.gd")
const SANCTUM := preload("res://assets/backgrounds/menu_moonlit_sanctum_v1.png")

const DURATION := 5.60
const REDUCED_DURATION := 0.72
const SLASH_TIME := 1.42

var _elapsed: float = 0.0
var _playing: bool = false
var _reduced: bool = false
var _slash_emitted: bool = false
var _sanctum: TextureRect
var _veil: ColorRect
var _kicker: Label
var _title: Label
var _subtitle: Label
var _skip: Label
var _stage: Control


class Stage extends Control:
	func _draw() -> void:
		var intro := get_parent() as OpeningIntro
		if intro == null:
			return
		intro.draw_stage(self)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_fit_children()


func _ready() -> void:
	name = "OpeningIntro"
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	visible = false
	z_index = 20
	set_process(false)
	size = Vector2(1280.0, 720.0)

	_sanctum = TextureRect.new()
	_sanctum.name = "Sanctum"
	_sanctum.texture = SANCTUM
	_sanctum.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_sanctum.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_sanctum.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sanctum.size = size
	add_child(_sanctum)

	_veil = ColorRect.new()
	_veil.name = "Veil"
	_veil.color = UI.BG_DEEP
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_veil.size = size
	add_child(_veil)

	_stage = Stage.new()
	_stage.name = "Stage"
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.size = size
	add_child(_stage)

	_kicker = _make_label(
		"Kicker",
		"踏入月夜 · 循回不息",
		Vector2(300.0, 132.0),
		Vector2(680.0, 24.0),
		UI.CAPTION,
		UI.ACCENT_MOON
	)
	_title = _make_label(
		"Title",
		"月蚀回廊",
		Vector2(250.0, 170.0),
		Vector2(780.0, 76.0),
		UI.DISPLAY,
		UI.TEXT_PRIMARY
	)
	_subtitle = _make_label(
		"Subtitle",
		"二十房月桥 · 肉鸽动作",
		Vector2(270.0, 254.0),
		Vector2(740.0, 44.0),
		UI.CAPTION,
		UI.TEXT_SECONDARY
	)
	_skip = _make_label(
		"SkipHint",
		"按任意键跳过",
		Vector2(440.0, 656.0),
		Vector2(400.0, 24.0),
		UI.CAPTION,
		UI.TEXT_DISABLED
	)
	_fit_children()


func _fit_children() -> void:
	for child in [_sanctum, _veil, _stage]:
		if child == null:
			continue
		child.position = Vector2.ZERO
		child.size = size


func play(reduced_effects: bool = false) -> void:
	_reduced = reduced_effects
	_elapsed = 0.0
	_playing = true
	_slash_emitted = false
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	modulate = Color.WHITE
	if is_inside_tree():
		grab_focus()
	set_process(true)
	_apply_visuals()
	queue_redraw()
	if is_instance_valid(_stage):
		_stage.queue_redraw()


func is_playing() -> bool:
	return _playing


func skip() -> void:
	if not _playing:
		return
	_finish()


func get_duration() -> float:
	return REDUCED_DURATION if _reduced else DURATION


func _process(delta: float) -> void:
	if not _playing:
		return
	if _wants_skip():
		_finish()
		return
	_elapsed = minf(_elapsed + delta, get_duration())
	if not _reduced and not _slash_emitted and _elapsed >= SLASH_TIME:
		_slash_emitted = true
		slash_struck.emit()
	_apply_visuals()
	if is_instance_valid(_stage):
		_stage.queue_redraw()
	if _elapsed >= get_duration():
		_finish()


func _gui_input(event: InputEvent) -> void:
	if not _playing:
		return
	if event.is_pressed() and not event.is_echo():
		if (
			event is InputEventKey
			or event is InputEventMouseButton
			or event is InputEventJoypadButton
		):
			accept_event()
			_finish()


func _wants_skip() -> bool:
	for action_name: StringName in [&"attack", &"jump", &"interact", &"ui_accept", &"ui_cancel", &"pause"]:
		if InputMap.has_action(action_name) and Input.is_action_just_pressed(action_name):
			return true
	return false


func _finish() -> void:
	if not _playing:
		return
	_playing = false
	_elapsed = get_duration()
	set_process(false)
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	finished.emit()


func _apply_visuals() -> void:
	var duration: float = get_duration()
	var progress: float = clampf(_elapsed / maxf(duration, 0.001), 0.0, 1.0)
	if _reduced:
		_sanctum.modulate = Color(1.0, 1.0, 1.0, smoothstep(0.0, 1.0, progress))
		_veil.color = Color(UI.BG_DEEP, 1.0 - progress)
		_kicker.modulate.a = progress
		_title.modulate.a = progress
		_subtitle.modulate.a = progress
		_skip.modulate.a = 0.0
		return

	var sanctum_alpha: float = smoothstep(0.0, 1.0, clampf((_elapsed - 2.05) / 1.45, 0.0, 1.0))
	_sanctum.modulate = Color(1.0, 1.0, 1.0, sanctum_alpha)
	var zoom: float = lerpf(1.045, 1.0, sanctum_alpha)
	_sanctum.pivot_offset = size * 0.5
	_sanctum.scale = Vector2(zoom, zoom)

	var veil_alpha: float = 1.0
	if _elapsed < 2.10:
		veil_alpha = 1.0
	elif _elapsed < 4.40:
		veil_alpha = lerpf(1.0, 0.22, clampf((_elapsed - 2.10) / 2.30, 0.0, 1.0))
	else:
		veil_alpha = lerpf(0.22, 0.0, clampf((_elapsed - 4.40) / 1.20, 0.0, 1.0))
	_veil.color = Color(UI.BG_DEEP, veil_alpha)

	_kicker.modulate.a = smoothstep(0.0, 1.0, clampf((_elapsed - 3.35) / 0.45, 0.0, 1.0))
	_title.modulate.a = smoothstep(0.0, 1.0, clampf((_elapsed - 3.55) / 0.50, 0.0, 1.0))
	_subtitle.modulate.a = smoothstep(0.0, 1.0, clampf((_elapsed - 3.85) / 0.45, 0.0, 1.0))
	var skip_in: float = smoothstep(0.0, 1.0, clampf((_elapsed - 0.35) / 0.40, 0.0, 1.0))
	var skip_out: float = 1.0 - smoothstep(0.0, 1.0, clampf((_elapsed - 5.05) / 0.35, 0.0, 1.0))
	_skip.modulate.a = skip_in * skip_out * 0.85


func draw_stage(canvas: Control) -> void:
	if not _playing:
		return
	if _reduced:
		return
	_draw_stars(canvas)
	_draw_moon(canvas)
	_draw_slash(canvas)


func _draw_stars(canvas: Control) -> void:
	var appear: float = smoothstep(0.0, 1.0, clampf(_elapsed / 0.80, 0.0, 1.0))
	var fade: float = 1.0 - smoothstep(0.0, 1.0, clampf((_elapsed - 3.20) / 1.40, 0.0, 1.0))
	var alpha: float = appear * fade
	if alpha <= 0.01:
		return
	var seeds: Array[Vector2] = [
		Vector2(160.0, 70.0), Vector2(980.0, 86.0), Vector2(1120.0, 190.0),
		Vector2(90.0, 210.0), Vector2(430.0, 48.0), Vector2(860.0, 40.0),
		Vector2(1188.0, 62.0), Vector2(240.0, 140.0),
	]
	for index in range(seeds.size()):
		var twinkle: float = 0.55 + 0.45 * sin(_elapsed * (2.4 + float(index) * 0.35) + float(index))
		canvas.draw_circle(seeds[index], 1.6 + float(index % 3) * 0.5, Color(UI.ACCENT_MOON, alpha * 0.55 * twinkle))


func _draw_moon(canvas: Control) -> void:
	var appear: float = smoothstep(0.0, 1.0, clampf((_elapsed - 0.08) / 0.70, 0.0, 1.0))
	var fade: float = 1.0 - smoothstep(0.0, 1.0, clampf((_elapsed - 3.00) / 1.50, 0.0, 1.0))
	var alpha: float = appear * fade
	if alpha <= 0.01:
		return
	var center := Vector2(640.0, 236.0)
	var radius := 96.0
	canvas.draw_circle(center, radius + 36.0, Color(Color("#ffd06e"), 0.10 * alpha))
	canvas.draw_circle(center, radius + 16.0, Color(Color("#fff4bd"), 0.10 * alpha))
	canvas.draw_circle(center, radius, Color(Color("#ffe08a"), alpha))
	canvas.draw_circle(center + Vector2(-18.0, -16.0), radius * 0.38, Color(Color("#fff6d0"), 0.35 * alpha))
	var eclipse: float = smoothstep(0.0, 1.0, clampf((_elapsed - 0.82) / 1.15, 0.0, 1.0))
	var occluder := center + Vector2(lerpf(118.0, 30.0, eclipse), lerpf(-8.0, -28.0, eclipse))
	canvas.draw_circle(occluder, radius * 0.98, Color(UI.BG_DEEP, alpha))
	if eclipse > 0.18:
		var rim_alpha: float = alpha * clampf(eclipse * 1.2, 0.0, 1.0) * fade
		canvas.draw_arc(
			center,
			radius + 2.0,
			2.35,
			4.55,
			28,
			Color(UI.ACCENT_MOON, rim_alpha * 0.90),
			3.0,
			true
		)
		canvas.draw_arc(
			center,
			radius - 6.0,
			2.50,
			4.40,
			24,
			Color(Color("#eaf6ff"), rim_alpha * 0.55),
			1.5,
			true
		)


func _draw_slash(canvas: Control) -> void:
	var phase: float = clampf((_elapsed - 1.18) / 0.72, 0.0, 1.0)
	if phase <= 0.0 or phase >= 1.0:
		return
	var alpha: float = pow(sin(phase * PI), 0.62)
	var start := Vector2(168.0, 428.0)
	var control := Vector2(620.0, 188.0)
	var finish := Vector2(1124.0, 132.0)
	var points := PackedVector2Array()
	for point_index in range(22):
		var weight: float = float(point_index) / 21.0
		var inverse: float = 1.0 - weight
		points.append(
			start * inverse * inverse
			+ control * 2.0 * inverse * weight
			+ finish * weight * weight
		)
	var visible_count: int = clampi(roundi(phase * float(points.size())), 2, points.size())
	var live := PackedVector2Array()
	for point_index in range(visible_count):
		live.append(points[point_index])
	if live.size() >= 2:
		canvas.draw_polyline(live, Color(0.04, 0.10, 0.18, alpha * 0.55), 18.0, true)
		canvas.draw_polyline(live, Color(UI.ACCENT_MOON, alpha * 0.92), 8.0, true)
		canvas.draw_polyline(live, Color(Color("#eaf6ff"), alpha), 2.4, true)
	var tip: Vector2 = live[live.size() - 1]
	canvas.draw_circle(tip, 5.0 + phase * 4.0, Color(Color("#fff6d0"), alpha * 0.80))


func _make_label(
	node_name: String,
	text: String,
	pos: Vector2,
	extent: Vector2,
	font_size: int,
	color: Color
) -> Label:
	var label := Label.new()
	label.name = node_name
	label.text = text
	label.position = pos
	label.size = extent
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.modulate.a = 0.0
	add_child(label)
	return label
