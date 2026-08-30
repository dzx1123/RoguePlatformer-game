extends Sprite2D

## A real dash afterimage that remains in world space after the player moves on.

const LIFETIME := 0.22

var _remaining := LIFETIME


func setup(source_texture: Texture2D, facing: float, source_scale: Vector2) -> void:
	texture = source_texture
	flip_h = facing < 0.0
	scale = source_scale
	modulate = Color(0.26, 0.86, 1.0, 0.44)


func _process(delta: float) -> void:
	_remaining = maxf(0.0, _remaining - delta)
	var ratio: float = _remaining / LIFETIME
	modulate.a = ratio * ratio * 0.44
	scale *= 1.0 + delta * 0.65
	if _remaining <= 0.0:
		queue_free()
