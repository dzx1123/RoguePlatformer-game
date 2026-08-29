extends Node2D

class_name RewardChest

signal opened(gold_reward: int, heal_reward: int)

const INTERACTION_RANGE := 92.0

var _gold_reward: int = 24
var _heal_reward: int = 24
var _is_open: bool = false
var _visual_time: float = 0.0


func setup(gold_reward: int, heal_reward: int) -> void:
	_gold_reward = maxi(0, gold_reward)
	_heal_reward = maxi(0, heal_reward)


func _process(delta: float) -> void:
	_visual_time += delta
	queue_redraw()


func try_open(opener_position: Vector2) -> bool:
	if global_position.distance_to(opener_position) > INTERACTION_RANGE:
		return false
	return force_open()


func force_open() -> bool:
	if _is_open:
		return false
	_is_open = true
	opened.emit(_gold_reward, _heal_reward)
	queue_redraw()
	return true


func is_open() -> bool:
	return _is_open


func _draw() -> void:
	var pulse: float = 0.5 + 0.5 * sin(_visual_time * 3.2)
	draw_circle(Vector2(0.0, 18.0), 30.0 + pulse * 4.0, Color(1.0, 0.70, 0.20, 0.08))
	draw_ellipse_shadow()
	if _is_open:
		draw_rect(Rect2(-26.0, -2.0, 52.0, 27.0), Color("#7a4327"))
		draw_rect(Rect2(-23.0, 1.0, 46.0, 20.0), Color("#d08a38"))
		draw_colored_polygon(
			PackedVector2Array([
				Vector2(-26.0, -5.0), Vector2(-18.0, -27.0),
				Vector2(18.0, -27.0), Vector2(26.0, -5.0),
			]),
			Color("#e7aa4c")
		)
		draw_circle(Vector2.ZERO, 8.0, Color(1.0, 0.90, 0.45, 0.65))
	else:
		draw_rect(Rect2(-27.0, -20.0, 54.0, 43.0), Color("#6c3825"))
		draw_rect(Rect2(-23.0, -16.0, 46.0, 35.0), Color("#d08a38"))
		draw_line(Vector2(-22.0, -2.0), Vector2(22.0, -2.0), Color("#ffe08a"), 4.0)
		draw_rect(Rect2(-6.0, -7.0, 12.0, 16.0), Color("#ffe08a"))


func draw_ellipse_shadow() -> void:
	draw_set_transform(Vector2(0.0, 24.0), 0.0, Vector2(1.0, 0.35))
	draw_circle(Vector2.ZERO, 31.0, Color(0.01, 0.03, 0.05, 0.45))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
