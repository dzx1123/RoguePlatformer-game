extends "res://scripts/forge_caster_prototype.gd"

enum ChargeState { WAIT, WINDUP, CHARGE, RECOVER }
var charge_state := ChargeState.WAIT
var state_time := 0.8
var charge_facing := 1.0
var hit_this_charge := false
var lane_left := 490.0
var lane_right := 630.0

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
					state_time = 0.4
					hit_this_charge = false
			ChargeState.CHARGE:
				velocity.x = charge_facing * 300
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
			_target.receive_enemy_attack(position, 16, &"forge_guard_charge")
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
	draw_rect(Rect2(-24, -32, 48, 54), color)
	draw_rect(Rect2(charge_facing * 26 - 5, -30, 10, 50), color.darkened(0.3))
	draw_rect(Rect2(-28, -43, 56 * float(_current_health) / maxf(_max_health, 1), 4), color)
	draw_string(ThemeDB.fallback_font, Vector2(-75, -56), "铸炉守卫·占位外观", HORIZONTAL_ALIGNMENT_LEFT, -1, 13)
	if charge_state == ChargeState.WINDUP and not _is_defeated:
		draw_line(Vector2(0, 22), Vector2(charge_facing * 80, 22), Color("#ffd16b"), 3)
	if charge_state == ChargeState.RECOVER and not _is_defeated:
		draw_string(ThemeDB.fallback_font, Vector2(-30, -75), "反击窗口", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, color)
