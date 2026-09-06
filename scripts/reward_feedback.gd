extends Control

class_name RewardFeedback

## Non-blocking reward confirmation shared by relics, shops, events and chests.
## Main keeps flow ownership; this layer only provides a short visual bridge while
## the next room is prepared behind it.

const DISPLAY_SIZE := Vector2(1280.0, 720.0)
const UI := preload("res://scripts/ui_theme.gd")
const HUD_LAYOUT := preload("res://scripts/run_hud_builder.gd")
const PANEL_SIZE := Vector2(520.0, 56.0)
const PANEL_POSITION := Vector2(380.0, HUD_LAYOUT.HUD_DOCK_TOP - 8.0 - PANEL_SIZE.y)

var _panel: Panel
var _accent_rule: ColorRect
var _kicker: Label
var _title: Label
var _detail: Label
var _tween: Tween
var _generation: int = 0
var _kind: StringName = &""
var _accent: Color = UI.ACCENT_MOON
var _reduced_motion: bool = false


func _ready() -> void:
	name = "RewardFeedback"
	position = Vector2.ZERO
	size = DISPLAY_SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	z_index = 95
	_build_interface()
	visible = false


func set_reduced_motion(enabled: bool) -> void:
	_reduced_motion = enabled


func present(
	kind: StringName,
	kicker_text: String,
	title_text: String,
	detail_text: String,
	accent_color: Color,
	hold_seconds: float = 0.72
) -> void:
	_generation += 1
	var presentation_generation: int = _generation
	_kind = kind
	_accent = accent_color
	if _tween != null and _tween.is_valid():
		_tween.kill()
	visible = true
	_kicker.text = kicker_text
	_title.text = title_text
	_detail.text = detail_text
	_accent_rule.color = Color(_accent, 0.94)
	_panel.add_theme_stylebox_override("panel", _make_panel_style(_accent))
	_panel.position = PANEL_POSITION + Vector2(0.0, 8.0 if not _reduced_motion else 0.0)
	_panel.scale = Vector2.ONE
	modulate = Color(1.0, 1.0, 1.0, 0.0)
	queue_redraw()

	var enter_duration: float = 0.10 if _reduced_motion else 0.20
	var exit_duration: float = 0.10 if _reduced_motion else 0.22
	# Reduced motion changes movement, not the time available to read the result.
	var hold_duration: float = maxf(hold_seconds, 0.0)
	var exit_delay: float = enter_duration + hold_duration
	_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_parallel(true)
	_tween.tween_property(self, "modulate:a", 1.0, enter_duration)
	_tween.tween_property(_panel, "position", PANEL_POSITION, enter_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "modulate:a", 0.0, exit_duration).set_delay(exit_delay)
	if not _reduced_motion:
		_tween.tween_property(
			_panel,
			"position",
			PANEL_POSITION + Vector2(0.0, -8.0),
			exit_duration
		).set_delay(exit_delay)
	_tween.tween_callback(
		_finish_presentation.bind(presentation_generation)
	).set_delay(exit_delay + exit_duration)


func hide_feedback() -> void:
	_generation += 1
	if _tween != null and _tween.is_valid():
		_tween.kill()
	visible = false
	modulate = Color.WHITE


func get_snapshot() -> Dictionary:
	return {
		"visible": visible,
		"kind": _kind,
		"kicker": _kicker.text if is_instance_valid(_kicker) else "",
		"title": _title.text if is_instance_valid(_title) else "",
		"detail": _detail.text if is_instance_valid(_detail) else "",
		"accent": _accent,
		"reduced_motion": _reduced_motion,
	}


func _finish_presentation(presentation_generation: int) -> void:
	if presentation_generation != _generation:
		return
	visible = false
	modulate = Color.WHITE


func _build_interface() -> void:
	_panel = Panel.new()
	_panel.name = "RewardToast"
	_panel.position = PANEL_POSITION
	_panel.size = PANEL_SIZE
	_panel.pivot_offset = PANEL_SIZE * 0.5
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)

	_accent_rule = ColorRect.new()
	_accent_rule.name = "AccentRule"
	_accent_rule.position = Vector2(0.0, 8.0)
	_accent_rule.size = Vector2(4.0, 40.0)
	_accent_rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_accent_rule)

	_kicker = Label.new()
	_kicker.name = "Kicker"
	# Keep presentation metadata for callers; the rail has only two visible lines.
	_kicker.visible = false
	_kicker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_kicker)

	_title = Label.new()
	_title.name = "Title"
	_title.position = Vector2(20.0, 4.0)
	_title.size = Vector2(480.0, 26.0)
	_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_title.clip_text = true
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 18)
	_title.add_theme_color_override("font_color", UI.TEXT_PRIMARY)
	_title.add_theme_constant_override("outline_size", 0)
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_title)

	_detail = Label.new()
	_detail.name = "Detail"
	_detail.position = Vector2(20.0, 30.0)
	_detail.size = Vector2(480.0, 22.0)
	_detail.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_detail.clip_text = true
	_detail.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_detail.add_theme_font_size_override("font_size", 15)
	_detail.add_theme_color_override("font_color", UI.TEXT_SECONDARY)
	_detail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_detail)


func _make_panel_style(accent_color: Color) -> StyleBoxFlat:
	return UI.surface(UI.BG_PANEL, Color(accent_color, 0.22), UI.CHIP_RADIUS, 1, 6)
