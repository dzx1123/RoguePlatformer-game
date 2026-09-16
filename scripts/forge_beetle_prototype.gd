extends "res://scripts/forge_caster_prototype.gd"

enum State { WAIT, WARN, POUNCE, BURN, REST }
var state := State.WAIT
var remaining := 1.0
var direction := 1.0
var burn_spent := false
const LEFT := 500.0
const RIGHT := 780.0

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
					remaining = 0.6
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
	velocity.x = clampf(velocity.x, (LEFT - position.x) / maxf(delta, 0.001), (RIGHT - position.x) / maxf(delta, 0.001))
	move_and_slide()
	queue_redraw()

func _try_burn() -> void:
	if _is_defeated or burn_spent or not is_instance_valid(_target) or _target.is_dead():
		return
	if _target.position.distance_to(position) < 48:
		burn_spent = true
		_target.receive_enemy_attack(position, 8, &"ember_beetle_burn")

func _draw() -> void:
	var color := Color("#a35730")
	if state == State.WARN:
		color = Color("#ffdf85")
	if _hurt_remaining > 0:
		color = Color.WHITE
	if _is_defeated:
		color.a = clampf(_death_remaining / DEATH_ANIMATION_DURATION, 0, 1)
	draw_circle(Vector2(0, 5), 19, color)
	for x in [-16, 0, 16]:
		draw_line(Vector2(x, 8), Vector2(x + 9, 22), color, 3)
	if state == State.BURN and not _is_defeated:
		draw_arc(Vector2.ZERO, 48, 0, TAU, 24, Color("#ff743c"), 3)
	draw_rect(Rect2(-22, -23, 44 * float(_current_health) / 36, 3), color)
	draw_string(ThemeDB.fallback_font, Vector2(-65, -35), "余烬甲虫·占位外观", HORIZONTAL_ALIGNMENT_LEFT, -1, 13)
