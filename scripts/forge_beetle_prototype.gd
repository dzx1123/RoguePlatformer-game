extends "res://scripts/forge_caster_prototype.gd"

enum State { WAIT, WARN, POUNCE, BURN, REST }
var state := State.WAIT
var remaining := 1.0
var direction := 1.0
var burn_spent := false
const LEFT := 500.0
const RIGHT := 780.0
var lane_left := LEFT
var lane_right := RIGHT
const LANDING_WARNING := 0.30
const BURN_DURATION := 0.60
const BURN_RADIUS := 48.0

func _ready() -> void:
	super._ready()
	_max_health = 36
	_current_health = 36

func _physics_process(delta: float) -> void:
	if _is_defeated:
		super._physics_process(delta)
		return
	_hurt_remaining = maxf(0, _hurt_remaining - delta)
	_hurt_invulnerability_remaining = maxf(0, _hurt_invulnerability_remaining - delta)
	remaining -= delta
	velocity.x = 0
	velocity.y += 1800 * delta
	if not is_instance_valid(_target) or _target.is_dead():
		state = State.WAIT
		remaining = 1.0
	else:
		match state:
			State.WAIT:
				if remaining <= 0 and is_on_floor() and absf(_target.position.y - position.y) < 80 and absf(_target.position.x - position.x) < 240:
					direction = 1.0 if _target.position.x >= position.x else -1.0
					state = State.WARN
					remaining = 0.45
			State.WARN:
				if _hurt_remaining > 0:
					state = State.REST
					remaining = 0.9
				elif remaining <= 0:
					state = State.POUNCE
					remaining = 0.45
					velocity.y = -240
			State.POUNCE:
				velocity.x = direction * 340
				if remaining <= 0 and is_on_floor():
					state = State.BURN
					velocity.x = 0
					remaining = LANDING_WARNING + BURN_DURATION
					burn_spent = false
			State.BURN:
				if remaining <= 0:
					state = State.REST
					remaining = 1.0
				else:
					_try_burn()
			State.REST:
				if remaining <= 0:
					state = State.WAIT
	velocity.x = clampf(velocity.x, (lane_left - position.x) / maxf(delta, 0.001), (lane_right - position.x) / maxf(delta, 0.001))
	move_and_slide()
	queue_redraw()

func _try_burn() -> void:
	if state != State.BURN or remaining > BURN_DURATION or remaining <= 0 or _is_defeated or burn_spent or not is_instance_valid(_target) or _target.is_dead():
		return
	if _target.position.distance_to(position) < BURN_RADIUS:
		burn_spent = true
		_target.receive_enemy_attack(position, _get_scaled_damage(8), &"ember_beetle_burn")

func _draw() -> void:
	var color := Color("#a35730")
	if state == State.WARN:
		color = Color("#ffdf85")
	if _hurt_remaining > 0:
		color = Color.WHITE
	if _is_defeated:
		color.a = clampf(_death_remaining / DEATH_ANIMATION_DURATION, 0, 1)
	var pose := 3 if _is_defeated else (1 if state == State.WARN else (2 if state in [State.POUNCE, State.BURN] else 0))
	ART.draw_actor(self, 2, pose, direction, 48, _hurt_remaining > 0, _art_alpha(), _pose_motion(pose, clampf(1.0 - remaining / 0.45, 0, 1)))
	if state == State.BURN and not _is_defeated:
		var warning := remaining > BURN_DURATION
		var ring_color := Color("#ffdf85") if warning else Color("#ff743c")
		draw_arc(Vector2.ZERO, BURN_RADIUS, 0, TAU, 32, ring_color, 3)
		if not warning:
			draw_circle(Vector2.ZERO, BURN_RADIUS, Color(1, 0.25, 0.1, 0.15))
		else:
			draw_string(ThemeDB.fallback_font, Vector2(-30, -58), "即将灼烧", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, ring_color)
	draw_rect(Rect2(-22, -23, 44 * clampf(float(_current_health) / maxf(_max_health, 1), 0, 1), 3), color)

func get_impact_height() -> float:
	return 48.0
