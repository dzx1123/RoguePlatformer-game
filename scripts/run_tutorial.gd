extends Control

## First-room, non-blocking prompts. Dismissed as the player performs each action.
class_name RunTutorial

const DISPLAY_SIZE := Vector2(1280.0, 840.0)

var _banner: Panel
var _label: Label
var _move_done: bool = false
var _jump_done: bool = false
var _attack_done: bool = false
var _move_prompt: String = "A / D"
var _jump_prompt: String = "空格"
var _attack_prompt: String = "J"


func _ready() -> void:
	name = "RunTutorial"
	position = Vector2.ZERO
	size = DISPLAY_SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_build_interface()


func begin_lesson(
	move_prompt: String,
	jump_prompt: String,
	attack_prompt: String
) -> void:
	_move_prompt = move_prompt
	_jump_prompt = jump_prompt
	_attack_prompt = attack_prompt
	_move_done = false
	_jump_done = false
	_attack_done = false
	visible = true
	_refresh_text()


func notify_action(action: StringName) -> void:
	if not visible:
		return
	match action:
		&"move":
			_move_done = true
		&"jump", &"land":
			_jump_done = true
		&"attack":
			_attack_done = true
		_:
			return
	_refresh_text()
	if _move_done and _jump_done and _attack_done:
		hide_lesson()


func hide_lesson() -> void:
	visible = false


func is_active() -> bool:
	return visible


func get_snapshot() -> Dictionary:
	return {
		"visible": visible,
		"move_done": _move_done,
		"jump_done": _jump_done,
		"attack_done": _attack_done,
		"text": _label.text if is_instance_valid(_label) else "",
	}


func _refresh_text() -> void:
	var steps: Array[String] = []
	steps.append(_step_text("移动", _move_prompt, _move_done))
	steps.append(_step_text("跳跃", _jump_prompt, _jump_done))
	steps.append(_step_text("攻击", _attack_prompt, _attack_done))
	_label.text = "第一房  ·  %s" % "    ".join(steps)


func _step_text(label_text: String, prompt: String, done: bool) -> String:
	if done:
		return "%s 已完成" % label_text
	return "%s %s" % [label_text, prompt]


func _build_interface() -> void:
	_banner = Panel.new()
	_banner.name = "Banner"
	_banner.position = Vector2(250.0, 86.0)
	_banner.size = Vector2(780.0, 48.0)
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.010, 0.036, 0.070, 0.82)
	style.border_color = Color(0.42, 0.86, 0.96, 0.70)
	style.set_border_width_all(1)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	_banner.add_theme_stylebox_override("panel", style)
	add_child(_banner)

	_label = Label.new()
	_label.name = "Lesson"
	_label.position = Vector2(18.0, 6.0)
	_label.size = Vector2(744.0, 36.0)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 16)
	_label.add_theme_color_override("font_color", Color(0.86, 0.96, 1.0, 1.0))
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.add_child(_label)
