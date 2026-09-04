extends Node2D

class_name RewardChest

signal opened(gold_reward: int, heal_reward: int)

const INTERACTION_RANGE := 92.0

var _gold_reward: int = 24
var _heal_reward: int = 24
var _is_open: bool = false
var _is_risk: bool = false
var _reward_resolved: bool = false
var _visual_time: float = 0.0
var _opener_in_range: bool = false
var _reward_bubble_remaining: float = 0.0
var _prompt_root: Control
var _prompt_panel: Panel
var _prompt_pointer: Polygon2D
var _prompt_key_label: Label
var _prompt_text_label: Label
var _prompt_style: StyleBoxFlat
var _prompt_key_style: StyleBoxFlat


func setup(
	gold_reward: int,
	heal_reward: int,
	interaction_key: String = "E",
	is_risk: bool = false
) -> void:
	_gold_reward = maxi(0, gold_reward)
	_heal_reward = maxi(0, heal_reward)
	_is_risk = is_risk
	set_interaction_prompt(interaction_key)


func set_interaction_prompt(interaction_prompt: String) -> void:
	set_meta(&"interaction_key", interaction_prompt)
	if is_instance_valid(_prompt_key_label):
		_prompt_key_label.text = interaction_prompt


func _ready() -> void:
	_create_prompt_bubble()


func _create_prompt_bubble() -> void:
	_prompt_root = Control.new()
	_prompt_root.name = "PromptBubble"
	_prompt_root.position = Vector2(-98.0, -96.0)
	_prompt_root.size = Vector2(196.0, 50.0)
	_prompt_root.pivot_offset = Vector2(98.0, 42.0)
	_prompt_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt_root.z_index = 20
	add_child(_prompt_root)

	_prompt_panel = Panel.new()
	_prompt_panel.position = Vector2.ZERO
	_prompt_panel.size = Vector2(196.0, 42.0)
	_prompt_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt_style = StyleBoxFlat.new()
	_prompt_style.bg_color = Color(0.025, 0.055, 0.075, 0.96)
	_prompt_style.border_color = (
		Color(0.96, 0.30, 0.44, 0.92)
		if _is_risk
		else Color(0.96, 0.70, 0.28, 0.88)
	)
	_prompt_style.set_border_width_all(2)
	_prompt_style.corner_radius_top_left = 9
	_prompt_style.corner_radius_top_right = 9
	_prompt_style.corner_radius_bottom_left = 9
	_prompt_style.corner_radius_bottom_right = 9
	_prompt_style.shadow_color = Color(0.0, 0.0, 0.0, 0.52)
	_prompt_style.shadow_size = 8
	_prompt_style.shadow_offset = Vector2(0.0, 4.0)
	_prompt_panel.add_theme_stylebox_override("panel", _prompt_style)
	_prompt_root.add_child(_prompt_panel)

	_prompt_pointer = Polygon2D.new()
	_prompt_pointer.name = "Pointer"
	_prompt_pointer.position = Vector2(98.0, 40.0)
	_prompt_pointer.polygon = PackedVector2Array([
		Vector2(-9.0, 0.0),
		Vector2(9.0, 0.0),
		Vector2(0.0, 10.0),
	])
	_prompt_pointer.color = (
		Color(0.96, 0.30, 0.44, 0.92)
		if _is_risk
		else Color(0.96, 0.70, 0.28, 0.92)
	)
	_prompt_root.add_child(_prompt_pointer)

	var key_panel := Panel.new()
	key_panel.name = "PromptKey"
	key_panel.position = Vector2(8.0, 6.0)
	key_panel.size = Vector2(48.0, 30.0)
	key_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt_key_style = StyleBoxFlat.new()
	_prompt_key_style.bg_color = Color(0.09, 0.17, 0.20, 1.0)
	_prompt_key_style.border_color = (
		Color(1.0, 0.38, 0.50, 0.96)
		if _is_risk
		else Color(0.98, 0.78, 0.38, 0.94)
	)
	_prompt_key_style.set_border_width_all(1)
	_prompt_key_style.corner_radius_top_left = 6
	_prompt_key_style.corner_radius_top_right = 6
	_prompt_key_style.corner_radius_bottom_left = 6
	_prompt_key_style.corner_radius_bottom_right = 6
	key_panel.add_theme_stylebox_override("panel", _prompt_key_style)
	_prompt_root.add_child(key_panel)

	_prompt_key_label = Label.new()
	_prompt_key_label.name = "KeyText"
	_prompt_key_label.position = Vector2.ZERO
	_prompt_key_label.size = key_panel.size
	_prompt_key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_key_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_prompt_key_label.text = String(get_meta(&"interaction_key", "E"))
	_prompt_key_label.add_theme_font_size_override("font_size", 14)
	_prompt_key_label.add_theme_color_override("font_color", Color(1.0, 0.91, 0.68, 1.0))
	_prompt_key_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	key_panel.add_child(_prompt_key_label)

	_prompt_text_label = Label.new()
	_prompt_text_label.name = "PromptText"
	_prompt_text_label.position = Vector2(63.0, 5.0)
	_prompt_text_label.size = Vector2(124.0, 32.0)
	_prompt_text_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_prompt_text_label.text = "开启风险宝箱" if _is_risk else "开启宝箱"
	_prompt_text_label.add_theme_font_size_override("font_size", 16)
	_prompt_text_label.add_theme_color_override("font_color", Color(1.0, 0.87, 0.55, 1.0))
	_prompt_text_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt_root.add_child(_prompt_text_label)


func _process(delta: float) -> void:
	_visual_time += delta
	_update_prompt_bubble(delta)
	queue_redraw()


func set_opener_position(opener_position: Vector2) -> void:
	if _is_open:
		return
	var in_range: bool = global_position.distance_to(opener_position) <= INTERACTION_RANGE
	if in_range == _opener_in_range:
		return
	_opener_in_range = in_range
	if is_instance_valid(_prompt_text_label):
		_prompt_text_label.text = (
			("触发挑战" if in_range else "开启风险宝箱")
			if _is_risk
			else ("现在开启" if in_range else "开启宝箱")
		)
	if _prompt_style != null:
		_prompt_style.border_color = (
			(Color(1.0, 0.34, 0.48, 1.0) if _is_risk else Color(1.0, 0.88, 0.45, 1.0))
			if in_range
			else (Color(0.96, 0.30, 0.44, 0.92) if _is_risk else Color(0.96, 0.70, 0.28, 0.88))
		)


func _update_prompt_bubble(delta: float) -> void:
	if not is_instance_valid(_prompt_root):
		return
	if _is_open:
		_reward_bubble_remaining = maxf(0.0, _reward_bubble_remaining - delta)
		var reward_progress: float = 1.0 - _reward_bubble_remaining / 1.45
		_prompt_root.visible = _reward_bubble_remaining > 0.0
		_prompt_root.position = Vector2(-98.0, -96.0 - reward_progress * 18.0)
		_prompt_root.scale = Vector2.ONE * (1.04 + sin(reward_progress * PI) * 0.04)
		_prompt_root.modulate.a = clampf(_reward_bubble_remaining / 0.34, 0.0, 1.0)
		return

	_prompt_root.visible = true
	var pulse_speed: float = 5.4 if _opener_in_range else 3.2
	var pulse: float = 0.5 + 0.5 * sin(_visual_time * pulse_speed)
	var emphasis: float = 1.0 if _opener_in_range else 0.0
	_prompt_root.position = Vector2(-98.0, -96.0 - sin(_visual_time * 3.0) * (2.4 + emphasis))
	_prompt_root.scale = Vector2.ONE * (1.0 + pulse * (0.018 + emphasis * 0.018))
	_prompt_root.modulate.a = 0.90 + pulse * 0.10


func try_open(opener_position: Vector2) -> bool:
	if global_position.distance_to(opener_position) > INTERACTION_RANGE:
		return false
	return force_open()


func force_open() -> bool:
	if _is_open:
		return false
	_is_open = true
	_reward_bubble_remaining = 1.45
	if is_instance_valid(_prompt_key_label):
		_prompt_key_label.text = "+"
	if is_instance_valid(_prompt_text_label):
		_prompt_text_label.text = (
			"伏兵来袭！胜利后领取奖励"
			if _is_risk
			else "奖励结算中…"
		)
		_prompt_text_label.add_theme_font_size_override("font_size", 13)
	if _prompt_style != null:
		_prompt_style.bg_color = Color(0.12, 0.035, 0.055, 0.98) if _is_risk else Color(0.055, 0.12, 0.10, 0.98)
		_prompt_style.border_color = Color(1.0, 0.36, 0.48, 1.0) if _is_risk else Color(0.52, 0.96, 0.60, 1.0)
	if _prompt_key_style != null:
		_prompt_key_style.border_color = Color(1.0, 0.36, 0.48, 1.0) if _is_risk else Color(0.52, 0.96, 0.60, 1.0)
	opened.emit(_gold_reward, _heal_reward)
	queue_redraw()
	return true


func set_resolved_reward(gold_reward: int, restored_health: int) -> void:
	if not _is_open or not is_instance_valid(_prompt_text_label):
		return
	_reward_resolved = true
	_reward_bubble_remaining = 1.45
	_prompt_root.visible = true
	_prompt_root.modulate.a = 1.0
	_prompt_key_label.text = "+"
	_prompt_text_label.text = "金币 +%d  生命恢复 %d" % [
		maxi(0, gold_reward),
		maxi(0, restored_health),
	]
	_prompt_text_label.add_theme_color_override("font_color", Color(0.86, 1.0, 0.82, 1.0))
	_prompt_style.bg_color = Color(0.040, 0.120, 0.085, 0.98)
	_prompt_style.border_color = Color(0.52, 0.96, 0.60, 1.0)
	_prompt_key_style.border_color = Color(0.52, 0.96, 0.60, 1.0)
	if is_instance_valid(_prompt_pointer):
		_prompt_pointer.color = Color(0.52, 0.96, 0.60, 0.96)
	queue_redraw()


func get_prompt_snapshot() -> Dictionary:
	return {
		"visible": _prompt_root.visible if is_instance_valid(_prompt_root) else false,
		"text": _prompt_text_label.text if is_instance_valid(_prompt_text_label) else "",
		"resolved": _reward_resolved,
		"remaining": _reward_bubble_remaining,
	}


func is_open() -> bool:
	return _is_open


func is_risk_chest() -> bool:
	return _is_risk


func _draw() -> void:
	var pulse: float = 0.5 + 0.5 * sin(_visual_time * 3.2)
	var glow_color := Color(1.0, 0.18, 0.35, 0.12) if _is_risk else Color(1.0, 0.70, 0.20, 0.08)
	var metal_color := Color("#c54a67") if _is_risk else Color("#d08a38")
	var light_color := Color("#ff7790") if _is_risk else Color("#ffe08a")
	draw_circle(Vector2(0.0, 18.0), 30.0 + pulse * 4.0, glow_color)
	draw_ellipse_shadow()
	if _is_open:
		draw_rect(Rect2(-26.0, -2.0, 52.0, 27.0), Color("#7a4327"))
		draw_rect(Rect2(-23.0, 1.0, 46.0, 20.0), metal_color)
		draw_colored_polygon(
			PackedVector2Array([
				Vector2(-26.0, -5.0), Vector2(-18.0, -27.0),
				Vector2(18.0, -27.0), Vector2(26.0, -5.0),
			]),
			metal_color.lightened(0.16)
		)
		draw_circle(Vector2.ZERO, 8.0, Color(1.0, 0.90, 0.45, 0.65))
	else:
		draw_rect(Rect2(-27.0, -20.0, 54.0, 43.0), Color("#6c3825"))
		draw_rect(Rect2(-23.0, -16.0, 46.0, 35.0), metal_color)
		draw_line(Vector2(-22.0, -2.0), Vector2(22.0, -2.0), light_color, 4.0)
		draw_rect(Rect2(-6.0, -7.0, 12.0, 16.0), light_color)


func draw_ellipse_shadow() -> void:
	draw_set_transform(Vector2(0.0, 24.0), 0.0, Vector2(1.0, 0.35))
	draw_circle(Vector2.ZERO, 31.0, Color(0.01, 0.03, 0.05, 0.45))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
