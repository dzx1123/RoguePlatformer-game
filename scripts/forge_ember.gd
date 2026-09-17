extends Node2D

const WARNING := 0.72
const FLIGHT := 0.80
const BLAST_RADIUS := 44.0
var origin := Vector2.ZERO
var landing := Vector2.ZERO
var target: Node2D
var age := 0.0
var impacted := false
var damage := 12

func advance(delta: float) -> void:
	age += delta
	if age >= WARNING + FLIGHT and not impacted:
		impacted = true
		if is_instance_valid(target) and target.global_position.distance_to(landing) <= BLAST_RADIUS:
			target.receive_enemy_attack(landing, damage, &"ember_impact")
	if age >= WARNING + FLIGHT + 0.25:
		queue_free()
	queue_redraw()

func _draw() -> void:
	var color := Color("#ffd274") if not impacted else Color("#ff6233")
	draw_arc(landing, BLAST_RADIUS, 0, TAU, 32, color, 3)
	draw_line(landing + Vector2(-10, 0), landing + Vector2(10, 0), color, 2)
	if impacted:
		draw_circle(landing, BLAST_RADIUS, Color(1, 0.3, 0.1, 0.25))
	elif age >= WARNING:
		var t := clampf((age - WARNING) / FLIGHT, 0, 1)
		var ball := origin.lerp(landing, t) + Vector2(0, -130 * sin(PI * t))
		draw_circle(ball, 10, Color("#ff7534"))
		draw_circle(ball, 5, Color("#ffe2a0"))
