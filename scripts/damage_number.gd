extends Node2D

## A compact, readable number that pops above an enemy and then fades upward.
class_name DamageNumber

const DURATION := 0.72

var _remaining: float = DURATION
var _amount: int = 0
var _accent := Color("#dffcff")
var _drift: float = 0.0
var _label: Label


func setup(amount: int, accent: Color = Color("#dffcff"), drift_seed: float = 0.0) -> void:
	_amount = maxi(1, amount)
	_accent = accent
	_drift = sin(drift_seed * 1.71) * 10.0


func _ready() -> void:
	z_index = 14
	_label = Label.new()
	_label.name = "DamageLabel"
	_label.position = Vector2(-42.0, -50.0)
	_label.size = Vector2(84.0, 34.0)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.text = str(_amount)
	_label.add_theme_font_size_override("font_size", 24)
	_label.add_theme_color_override("font_color", _accent)
	_label.add_theme_color_override("font_outline_color", Color(0.02, 0.05, 0.09, 0.96))
	_label.add_theme_constant_override("outline_size", 5)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)


func _process(delta: float) -> void:
	_remaining = maxf(0.0, _remaining - delta)
	var progress: float = 1.0 - _remaining / DURATION
	var pop: float = 1.0 + sin(minf(progress, 0.32) / 0.32 * PI) * 0.22
	_label.position = Vector2(
		-42.0 + _drift * progress,
		-50.0 - 42.0 * progress - progress * progress * 14.0
	)
	_label.scale = Vector2.ONE * pop
	_label.modulate.a = 1.0 - smoothstep(0.58, 1.0, progress)
	if _remaining <= 0.0:
		queue_free()
