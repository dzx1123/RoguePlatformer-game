extends "res://scripts/forge_caster_prototype.gd"

enum ChargeState { WAIT, WINDUP, CHARGE, RECOVER }
var charge_state := ChargeState.WAIT
var state_time := 0.8
var charge_facing := 1.0
var hit_this_charge := false
var lane_left := 490.0
var lane_right := 630.0
const CHARGE_SPEED := 300.0
const CHARGE_DURATION := 0.4

func get_charge_warning_rect() -> Rect2:
	var endpoint := clampf(position.x + charge_facing * CHARGE_SPEED * CHARGE_DURATION, lane_left, lane_right)
	# Include the contact reach beyond the body's travel, in local draw coordinates.
	var start := minf(position.x, endpoint) - position.x - 40.0
	return Rect2(start, -22, absf(endpoint - position.x) + 80, 44)

func _physics_process(delta: float) -> void:
	if _is_defeated:
		super._physics_process(delta)
		return
	_hurt_remaining = maxf(0, _hurt_remaining - delta)
	_hurt_invulnerability_remaining = maxf(0, _hurt_invulnerability_remaining - delta)
	velocity.y += 1800 * delta
	velocity.x = 0
	if not is_instance_valid(_target) or _target.is_dead():
		charge_state = ChargeState.WAIT
		state_time = 0.8
	else:
		state_time -= delta
		match charge_state:
			ChargeState.WAIT:
				if state_time <= 0 and absf(_target.position.y - position.y) < 90 and absf(_target.position.x - position.x) < 240:
					charge_facing = 1.0 if _target.position.x >= position.x else -1.0
					charge_state = ChargeState.WINDUP
					state_time = 0.8
			ChargeState.WINDUP:
				if _hurt_remaining > 0:
					_begin_recovery()
				elif state_time <= 0:
					charge_state = ChargeState.CHARGE
					state_time = CHARGE_DURATION
					hit_this_charge = false
			ChargeState.CHARGE:
				velocity.x = charge_facing * CHARGE_SPEED
				if state_time <= 0 or (charge_facing < 0 and position.x <= lane_left) or (charge_facing > 0 and position.x >= lane_right):
					_begin_recovery()
			ChargeState.RECOVER:
				if state_time <= 0:
					charge_state = ChargeState.WAIT
					state_time = 0.8
	velocity.x = clampf(velocity.x, (lane_left - position.x) / maxf(delta, 0.001), (lane_right - position.x) / maxf(delta, 0.001))
	move_and_slide()
	if charge_state == ChargeState.CHARGE and not hit_this_charge and is_instance_valid(_target):
		if absf(_target.position.x - position.x) < 40 and absf(_target.position.y - position.y) < 44:
			hit_this_charge = true
			_target.receive_enemy_attack(position, _get_scaled_damage(16), &"forge_guard_charge")
	queue_redraw()

func _begin_recovery() -> void:
	charge_state = ChargeState.RECOVER
	state_time = 1.1
	velocity.x = 0

func _draw() -> void:
	var color := Color("#94664f")
	if charge_state == ChargeState.WINDUP:
		color = Color("#ffd16b")
	elif charge_state == ChargeState.RECOVER:
		color = Color("#8ddbcc")
	if _hurt_remaining > 0:
		color = Color.WHITE
	if _is_defeated:
		color.a = clampf(_death_remaining / DEATH_ANIMATION_DURATION, 0, 1)
	var pose := 3 if _is_defeated else (1 if charge_state == ChargeState.WINDUP else (2 if charge_state == ChargeState.CHARGE else 0))
	ART.draw_actor(self, 1, pose, charge_facing if charge_state in [ChargeState.CHARGE, ChargeState.WINDUP] else _art_facing(), 106, _hurt_remaining > 0, _art_alpha(), _pose_motion(pose, clampf(1.0 - state_time / 0.8, 0, 1)))
	draw_rect(Rect2(-28, -43, 56 * float(_current_health) / maxf(_max_health, 1), 4), color)
	if charge_state == ChargeState.WINDUP and not _is_defeated:
		var warning := get_charge_warning_rect()
		draw_rect(warning, Color(1.0, 0.75, 0.25, 0.13))
		draw_line(Vector2(warning.position.x, 22), Vector2(warning.end.x, 22), Color("#ffd16b"), 3)
		var tip := Vector2(warning.end.x if charge_facing > 0 else warning.position.x, 22)
		draw_line(tip, tip + Vector2(-charge_facing * 10, -10), Color("#ffd16b"), 3)
	if charge_state == ChargeState.RECOVER and not _is_defeated:
		draw_string(ThemeDB.fallback_font, Vector2(-30, -75), "反击窗口", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, color)

func get_impact_height() -> float:
	return 106.0
