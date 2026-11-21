extends Node2D

const WARNING := 0.72
const FLIGHT := 0.80
const BLAST_RADIUS := 44.0
var origin := Vector2.ZERO
var landing := Vector2.ZERO
var target: Node2D
var caster: Node2D:
	set(value):
		caster = value
		_has_caster = value != null
var age := 0.0
var impacted := false
var damage := 12
var _has_caster := false

func advance(delta: float) -> void:
	if is_queued_for_deletion():
		return
	# The warning belongs to its caster. After release, the ember keeps its flight.
	# Boss embers have no attached caster and are cleared by the boss's phase logic.
	if age < WARNING and _has_caster:
		if not is_instance_valid(caster) or caster.is_queued_for_deletion() or caster._is_defeated or caster.get_current_health() <= 0:
			hide()
			queue_free()
			return
		if caster.get_hitstop_remaining() > 0.0:
			return
		if age + delta >= WARNING:
			origin = caster.get_ember_release_point()
			caster.sound_requested.emit(&"spit", caster.is_boss())
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
