extends "res://scripts/rogue_enemy.gd"

## Stationary combat prototype; uses existing hit geometry, not final character art.
func _ready() -> void:
	super._ready()
	_enemy_sprite.hide()
	if is_instance_valid(_reference_adornment):
		_reference_adornment.hide()

func _physics_process(delta: float) -> void:
	if _is_defeated:
		_death_remaining -= delta
		if _death_remaining <= 0:
			defeated.emit()
			queue_free()
		queue_redraw()
		return
	_hurt_remaining = maxf(0, _hurt_remaining - delta)
	_hurt_invulnerability_remaining = maxf(0, _hurt_invulnerability_remaining - delta)
	velocity.x = move_toward(velocity.x, 0, 900 * delta)
	velocity.y += 1800 * delta
	move_and_slide()
	queue_redraw()

func _draw() -> void:
	var tint := Color.WHITE if _hurt_remaining > 0 else Color("#b46943")
	if _is_defeated:
		tint.a = clampf(_death_remaining / DEATH_ANIMATION_DURATION, 0, 1)
	draw_rect(Rect2(-23, -30, 46, 52), tint)
	draw_circle(Vector2(0, -8), 12, Color("#ffb54a"))
	draw_rect(Rect2(-28, -44, 56, 4), Color("#39252b"))
	draw_rect(Rect2(-28, -44, 56 * float(_current_health) / maxf(_max_health, 1), 4), Color("#f5b562"))
	draw_string(ThemeDB.fallback_font, Vector2(-65, -55), "投掷者·占位外观", HORIZONTAL_ALIGNMENT_LEFT, -1, 13)
