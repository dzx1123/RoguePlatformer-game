extends "res://scripts/forge_caster_prototype.gd"

## Greybox boss with explicit warnings and damage windows; artwork remains provisional.
signal ember_requested(origin: Vector2, target_position: Vector2)
signal hazards_cleared
signal overheat_started

enum State { IDLE, HAMMER_WARNING, HAMMER_HIT, BARRAGE, CHARGE_WARNING, CHARGE, RECOVER, SHIFT }
var state := State.IDLE
var remaining := 1.2
var phase := 1
var engaged := false
var attack_index := 0
var locked_facing := -1.0
var hammer_rect := Rect2()
var hit_spent := false
var second_ember := false
const LEFT := 180.0
const RIGHT := 1100.0

func _ready() -> void:
	super._ready()
	_max_health = 520
	_current_health = 520

func is_boss() -> bool:
	return true

func _update_boss_phase() -> void:
	# This boss owns its two phases, not the chapter-one 70%/35% phase machine.
	pass

func get_hurtbox_rect() -> Rect2:
	return Rect2(global_position - Vector2(35, 60), Vector2(70, 88))

func defeat() -> void:
	if not _is_defeated:
		hazards_cleared.emit()
	super.defeat()

func _physics_process(delta: float) -> void:
	if _is_defeated:
		super._physics_process(delta)
		return
	_hurt_remaining = maxf(0, _hurt_remaining - delta)
	_hurt_invulnerability_remaining = maxf(0, _hurt_invulnerability_remaining - delta)
	velocity.x = 0
	velocity.y += 1800 * delta
	if not is_instance_valid(_target) or _target.is_dead():
		move_and_slide()
		return
	if phase == 1 and _current_health <= _max_health / 2:
		phase = 2
		state = State.SHIFT
		remaining = 1.2
		hazards_cleared.emit()
		queue_redraw()
		return
	if not engaged:
		engaged = absf(_target.position.x - position.x) < 600
		if not engaged:
			move_and_slide()
			return
	remaining -= delta
	match state:
		State.IDLE:
			if remaining <= 0:
				_begin_attack(attack_index % 3)
				attack_index += 1
		State.HAMMER_WARNING:
			if remaining <= 0:
				state = State.HAMMER_HIT
				remaining = 0.15
				hit_spent = true
				if hammer_rect.intersects(Rect2(_target.position - Vector2(18, 28), Vector2(36, 56))):
					_target.receive_enemy_attack(hammer_rect.get_center(), _get_scaled_damage(20), &"forge_boss_hammer")
		State.HAMMER_HIT:
			if remaining <= 0:
				_recover()
		State.BARRAGE:
			if not second_ember and remaining <= 1.75:
				second_ember = true
				ember_requested.emit(position, _target.position)
			if remaining <= 0:
				_recover()
		State.CHARGE_WARNING:
			if remaining <= 0:
				state = State.CHARGE
				remaining = 0.65
		State.CHARGE:
			velocity.x = locked_facing * 420
			if remaining <= 0 or (locked_facing < 0 and position.x <= LEFT) or (locked_facing > 0 and position.x >= RIGHT):
				_recover()
		State.RECOVER:
			if remaining <= 0:
				state = State.IDLE
				remaining = 0.45
		State.SHIFT:
			if remaining <= 0:
				overheat_started.emit()
				_recover()
	velocity.x = clampf(velocity.x, (LEFT - position.x) / maxf(delta, 0.001), (RIGHT - position.x) / maxf(delta, 0.001))
	move_and_slide()
	if state == State.CHARGE and not hit_spent and absf(_target.position.x - position.x) < 58 and absf(_target.position.y - position.y) < 52:
		hit_spent = true
		_target.receive_enemy_attack(position, _get_scaled_damage(18), &"forge_boss_charge")
	queue_redraw()

func _begin_attack(kind: int) -> void:
	locked_facing = 1.0 if _target.position.x >= position.x else -1.0
	hit_spent = false
	match kind:
		0:
			state = State.HAMMER_WARNING
			remaining = 0.9
			var x := clampf(_target.position.x, position.x - 200, position.x + 200)
			hammer_rect = Rect2(clampf(x - 80, 120, 1000), 545, 160, 75)
		1:
			state = State.BARRAGE
			remaining = 2.2
			second_ember = false
			ember_requested.emit(position, _target.position)
		2:
			state = State.CHARGE_WARNING
			remaining = 0.8

func _recover() -> void:
	state = State.RECOVER
	remaining = 1.1
	velocity.x = 0

func _draw() -> void:
	var tint := Color("#a67a65")
	if state == State.RECOVER:
		tint = Color("#83d9d3")
	elif state in [State.HAMMER_WARNING, State.CHARGE_WARNING, State.SHIFT]:
		tint = Color("#ffcb76")
	if _hurt_remaining > 0:
		tint = Color.WHITE
	if _is_defeated:
		tint.a = clampf(_death_remaining / DEATH_ANIMATION_DURATION, 0, 1)
	var pose := 3 if _is_defeated else (1 if state in [State.HAMMER_WARNING, State.CHARGE_WARNING, State.SHIFT] else (2 if state in [State.HAMMER_HIT, State.CHARGE, State.BARRAGE] else 0))
	ART.draw_actor(self, 3, pose, locked_facing, 140, _hurt_remaining > 0, _art_alpha())
	draw_string(ThemeDB.fallback_font, Vector2(-90, -146), "铸庭监炉者", HORIZONTAL_ALIGNMENT_LEFT, -1, 16)
	draw_rect(Rect2(-85, -132, 170, 7), Color("#3a2930"))
	draw_rect(Rect2(-85, -132, 170 * float(_current_health) / 520, 7), Color("#ffb970"))
	if _is_defeated:
		return
	if state in [State.HAMMER_WARNING, State.HAMMER_HIT]:
		var area := Rect2(hammer_rect.position - position, hammer_rect.size)
		draw_rect(area, Color(1, 0.5, 0.2, 0.23))
		draw_rect(area, Color("#ffd085"), false, 3)
		for x in range(0, 160, 20):
			draw_line(area.position + Vector2(x, 75), area.position + Vector2(x + 16, 0), Color("#ffd085"), 2)
	if state == State.CHARGE_WARNING:
		draw_line(Vector2(0, 22), Vector2(locked_facing * 160, 22), Color("#ffd085"), 5)
		draw_line(Vector2(locked_facing * 160, 22), Vector2(locked_facing * 140, 4), Color("#ffd085"), 4)
	if state in [State.SHIFT, State.RECOVER]:
		draw_string(ThemeDB.fallback_font, Vector2(-60, -112), "核心过载 · 换位" if state == State.SHIFT else "反击窗口", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, tint)
