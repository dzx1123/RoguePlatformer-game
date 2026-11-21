extends RefCounted

enum Clip {
	IDLE, CAST_LIFT, CAST_RELEASE, CAST_RETURN, SHIELD_LIFT, SHIELD_DRIVE,
	SHIELD_BRAKE, BEETLE_CROUCH, BEETLE_POUNCE, BEETLE_LAND, HAMMER_LIFT,
	HAMMER_DROP, HAMMER_RETURN, CORE_PULSE, OVERLOAD,
}

# Keyframes move the active limb, shift the torso, and load the leading leg.
# The source atlas supplies the held, extended, and fallen silhouettes.
const KEYS := {
	Clip.CAST_LIFT: [Vector4(0.12, 0.18, 0.04, 0.0), Vector4(0.09, 0.08, -0.04, 0.02), Vector4(0.0, 0.0, -0.06, 0.04)],
	Clip.CAST_RELEASE: [Vector4(-0.03, 0.01, 0.04, 0.03), Vector4(0.03, -0.02, 0.07, 0.0), Vector4(0.00, 0.01, 0.04, 0.0)],
	Clip.CAST_RETURN: [Vector4(0.09, -0.12, 0.06, 0.0), Vector4(0.03, -0.04, 0.02, 0.03), Vector4.ZERO],
	Clip.SHIELD_LIFT: [Vector4(0.0, 0.06, 0.0, 0.0), Vector4(-0.06, -0.03, -0.04, 0.04), Vector4(-0.08, -0.04, -0.06, 0.02)],
	Clip.SHIELD_DRIVE: [Vector4(-0.06, 0.03, 0.02, 0.06), Vector4(0.09, -0.02, 0.1, -0.03), Vector4(0.06, 0.01, 0.08, 0.04)],
	Clip.SHIELD_BRAKE: [Vector4(0.04, 0.04, 0.07, -0.02), Vector4(-0.03, 0.08, 0.02, 0.01), Vector4.ZERO],
	Clip.BEETLE_CROUCH: [Vector4.ZERO, Vector4(-0.06, 0.04, -0.02, -0.04), Vector4(-0.1, 0.06, -0.05, -0.10)],
	Clip.BEETLE_POUNCE: [Vector4(-0.02, -0.03, 0.05, 0.02), Vector4(0.11, -0.08, 0.09, 0.14), Vector4(0.06, 0.05, 0.06, 0.01)],
	Clip.BEETLE_LAND: [Vector4(0.07, 0.04, 0.08, -0.02), Vector4(0.13, 0.05, 0.03, -0.07), Vector4.ZERO],
	Clip.HAMMER_LIFT: [Vector4(0.12, 0.21, 0.0, 0.0), Vector4(0.05, 0.09, -0.06, 0.03), Vector4(-0.01, -0.01, -0.09, 0.0)],
	Clip.HAMMER_DROP: [Vector4(0.02, -0.05, 0.07, 0.03), Vector4(0.03, 0.13, 0.11, -0.01), Vector4(0.01, 0.09, 0.08, 0.0)],
	Clip.HAMMER_RETURN: [Vector4(0.07, -0.12, 0.06, 0.0), Vector4(0.02, -0.04, 0.03, 0.04), Vector4.ZERO],
	Clip.CORE_PULSE: [Vector4(-0.02, 0.06, -0.03, 0.0), Vector4(0.05, -0.16, 0.04, 0.0), Vector4.ZERO],
	Clip.OVERLOAD: [Vector4(0.03, 0.09, 0.0, 0.0), Vector4(-0.08, 0.05, -0.04, -0.05), Vector4(0.07, -0.14, 0.0, 0.04), Vector4.ZERO],
}

## Visual gait is measured in travelled pixels rather than wall-clock time.
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

static func _step(cycle: float) -> Vector2:
	const STANCE := 0.56
	var progress := fposmod(cycle / TAU, 1.0)
	if progress < STANCE:
		return Vector2(lerpf(0.5, -0.5, progress / STANCE), 0.0)
	var swing := (progress - STANCE) / (1.0 - STANCE)
	return Vector2(lerpf(-0.5, 0.5, smoothstep(0.0, 1.0, swing)), -sin(swing * PI))

static func gait_offset(uv: Vector2, cycle: float, amount: float, height: float, row: int) -> Vector2:
	var insect := row == 2
	var lower := smoothstep(0.47 if insect else 0.56, 1.0, uv.y)
	var side := smoothstep(0.38, 0.62, uv.x)
	var step := _step(cycle).lerp(_step(cycle + PI), side)
	var stride := height * (0.24 if insect else 0.22)
	var lift := height * (0.14 if insect else 0.09)
	var body := Vector2(sin(cycle) * 0.018, -absf(sin(cycle)) * 0.025) * (1.0 - lower) * height
	var feet := step * Vector2(stride, lift) * lower
	if row == 1:
		# The shield is a rigid prop, even where it overlaps the moving boots.
		var shield := smoothstep(0.66, 0.78, uv.x) * smoothstep(0.17, 0.28, uv.y)
		feet = feet.lerp(Vector2(sin(cycle) * height * 0.025, 0.0), shield)
	return (feet + body) * amount

static func sample_clip(clip: Clip, progress: float) -> Vector4:
	if clip == Clip.IDLE:
		return Vector4.ZERO
	var keys: Array = KEYS[clip]
	var cursor := clampf(progress, 0.0, 1.0) * (keys.size() - 1)
	var index := mini(int(cursor), keys.size() - 2)
	var first: Vector4 = keys[index]
	return first.lerp(keys[index + 1], smoothstep(0.0, 1.0, cursor - index))

static func action_offset(uv: Vector2, joint: Vector2, keys: Vector4, height: float, insect: bool) -> Vector2:
	# The wrist moves farther than the elbow. Bottom vertices stay on or above
	# the sole line, including during the insect's landing compression.
	var joint_weight := 1.0 - smoothstep(0.07, 0.53, uv.distance_to(joint))
	var lower := smoothstep(0.48 if insect else 0.56, 1.0, uv.y)
	var front := smoothstep(0.39, 0.69, uv.x)
	var arm := Vector2(keys.x, keys.y) * joint_weight * (1.0 - lower)
	var lean := Vector2(keys.z, absf(keys.z) * 0.24) * (1.0 - lower)
	var leg := Vector2(keys.z * 0.55 * (front * 2.0 - 1.0), -maxf(0.0, keys.w * (front * 2.0 - 1.0))) * lower
	return (arm + lean + leg) * height
