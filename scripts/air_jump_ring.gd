extends Node2D

## A light foot ring that marks an air jump without covering the character.

const LIFETIME := 0.26
const START_RADIUS := 5.0
const END_RADIUS := 20.0

var _age := 0.0


func _ready() -> void:
	z_index = 0
	queue_redraw()


func _process(delta: float) -> void:
	_age += delta
	queue_redraw()
	if _age >= LIFETIME:
		queue_free()


func _draw() -> void:
	var progress: float = clampf(_age / LIFETIME, 0.0, 1.0)
	var fade: float = (1.0 - progress) * (1.0 - progress)
	var radius: float = lerpf(START_RADIUS, END_RADIUS, progress)
	var ring := Color(0.62, 0.92, 1.0, 0.28 * fade)
	var inner := Color(1.0, 1.0, 1.0, 0.12 * fade)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 28, ring, 1.4, true)
	draw_arc(Vector2.ZERO, radius * 0.62, 0.0, TAU, 20, inner, 0.8, true)
