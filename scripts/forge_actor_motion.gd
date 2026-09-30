extends RefCounted

## Visual-only gait, measured in travelled pixels rather than wall-clock time.
var phase := 0.0
var weight := 0.0
var shape := Vector2.ONE
var facing := 1.0

func advance(delta: float, horizontal_speed: float, grounded: bool, walking: bool, target_shape: Vector2, target_facing: float, stride_length: float) -> void:
	var moving := walking and grounded and absf(horizontal_speed) > 10.0
	weight = move_toward(weight, 1.0 if moving else 0.0, delta * 9.0)
	if moving:
		phase = fposmod(phase + absf(horizontal_speed) * delta * TAU / stride_length, TAU)
	shape = shape.lerp(target_shape, 1.0 - exp(-delta * 22.0))
	if absf(target_facing) > 0.1:
		facing = signf(target_facing)

static func offset(uv: Vector2, cycle: float, amount: float, height: float, insect: bool) -> Vector2:
	# A continuous mesh keeps armor/legs attached; alternating legs lift independently.
	var lower := smoothstep(0.52 if insect else 0.60, 1.0, uv.y)
	var side := smoothstep(0.35, 0.65, uv.x)
	var step := lerpf(sin(cycle), -sin(cycle), side)
	var stride := height * (0.045 if insect else 0.022)
	var lift := maxf(0.0, step) * height * 0.018
	var body := sin(cycle * 2.0) * height * 0.007 * (1.0 - lower)
	return Vector2(step * stride * lower, body - lift * lower) * amount
