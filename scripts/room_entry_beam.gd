extends Node2D

class_name RoomEntryBeam

const DURATION := 1.2
const LIGHT := Color("#91dfff")
const GLOW := Color("#3b89db")

var _elapsed := 0.0
var _reduced_motion := false


func play(scale_multiplier: float = 1.0, reduced_motion: bool = false) -> void:
	_elapsed = 0.0
	scale = Vector2.ONE * scale_multiplier
	_reduced_motion = reduced_motion
	queue_redraw()


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= DURATION:
		queue_free()
	queue_redraw()


func _draw() -> void:
	var wake := smoothstep(0.0, 0.16, _elapsed)
	var dispersal := smoothstep(0.52, DURATION, _elapsed)
	var opacity := wake * (1.0 - dispersal)
	var origin := Vector2(0, 27)
	var spread := lerpf(0.7, 1.3, dispersal)
	draw_set_transform(origin, 0.0, Vector2(spread, 0.26 * spread))
	draw_circle(Vector2.ZERO, 42.0, Color(GLOW, opacity * 0.08))
	draw_arc(Vector2.ZERO, 42.0, 0, TAU, 48, Color(LIGHT, opacity * 0.55), 1.5, true)
	draw_arc(Vector2.ZERO, 32.0, PI * 0.1, PI * 1.45, 32, Color(LIGHT, opacity * 0.27), 1.5, true)
	draw_set_transform(Vector2.ZERO)

	var height := lerpf(154.0, 96.0, dispersal)
	for index in range(3):
		var x := float(index - 1) * 14.0
		var top := Vector2(x * 0.60, origin.y - height + absf(x) * 2.0)
		var bottom := Vector2(x, origin.y)
		_draw_ray(top, bottom, 18.0, Color(GLOW, opacity * 0.10))
		_draw_ray(top, bottom, 2.5, Color(LIGHT, opacity * 0.52))

	if _reduced_motion:
		return
	for index in range(12):
		var age := _elapsed - float(index % 5) * 0.07
		var life := clampf(age / 0.84, 0.0, 1.0)
		var alpha := sin(life * PI) * opacity
		var x := sin(float(index) * 2.39996) * (15.0 + life * 32.0)
		var y := origin.y - life * (42.0 + float(index % 4) * 21.0)
		var point := Vector2(x, y)
		draw_circle(point, 3.0, Color(GLOW, alpha * 0.22))
		draw_line(point - Vector2(0, 2), point + Vector2(0, 2), Color(LIGHT, alpha), 1.5, true)


func _draw_ray(top: Vector2, bottom: Vector2, width: float, color: Color) -> void:
	var half := Vector2(width * 0.5, 0.0)
	draw_polygon(
		PackedVector2Array([top, bottom - half, bottom + half]),
		PackedColorArray([Color(color, 0.0), color, color])
	)
