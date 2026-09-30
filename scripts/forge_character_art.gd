extends RefCounted

## Runtime atlas regions keep original generated alpha; drawing never changes hit geometry.
const ATLAS_PATH := "res://assets/chapter2/forge_characters_v1.png"
static var atlas: Texture2D
static var regions: Array[Rect2] = []
const MOTION := preload("res://scripts/forge_actor_motion.gd")

static func _load() -> void:
	if atlas != null:
		return
	atlas = load(ATLAS_PATH) as Texture2D
	var image := atlas.get_image()
	if image.is_compressed():
		image.decompress()
	# Authored atlas has taller humanoids and a shorter insect row.
	var rows := [0.0, 0.264, 0.535, 0.695, 1.0]
	for row in range(4):
		for column in range(4):
			var rect := Rect2i(int(column * image.get_width() / 4.0), int(rows[row] * image.get_height()), int(image.get_width() / 4.0), int((rows[row + 1] - rows[row]) * image.get_height()))
			var used := image.get_region(rect).get_used_rect()
			regions.append(Rect2(rect.position + used.position, used.size))

static func draw_actor(canvas: Node2D, row: int, pose: int, facing: float, height: float, hurt: bool, death_alpha: float = 1.0, motion: Vector2 = Vector2.ONE, gait_phase: float = 0.0, gait_weight: float = 0.0) -> void:
	_load()
	var source := regions[row * 4 + clampi(pose, 0, 3)]
	# Constant row scale avoids enlarging the collapsed pose.
	var reference_height := regions[row * 4].size.y
	var scale := height / reference_height
	var size := source.size * scale * motion
	var destination := Rect2(Vector2(-size.x / 2, 24 - size.y), size)
	if facing < 0:
		canvas.draw_set_transform(Vector2.ZERO, 0, Vector2(-1, 1))
	var tint := Color(1.6, 1.6, 1.6, death_alpha) if hurt else Color(1, 1, 1, death_alpha)
	if gait_weight > 0.001 and pose == 0:
		_draw_gait(canvas, destination, source, tint, row == 2, height, gait_phase, gait_weight)
	else:
		canvas.draw_texture_rect_region(atlas, destination, source, tint)
	canvas.draw_set_transform(Vector2.ZERO)

static func _draw_gait(canvas: Node2D, destination: Rect2, source: Rect2, tint: Color, insect: bool, height: float, cycle: float, weight: float) -> void:
	# Six columns split left/right feet; shared edge samples prevent gaps in the body.
	for y in range(6):
		for x in range(6):
			var points := PackedVector2Array()
			var uvs := PackedVector2Array()
			for corner: Vector2 in [Vector2(x, y), Vector2(x + 1, y), Vector2(x + 1, y + 1), Vector2(x, y + 1)]:
				var uv := corner / 6.0
				points.append(destination.position + uv * destination.size + MOTION.offset(uv, cycle, weight, height, insect))
				uvs.append((source.position + uv * source.size) / atlas.get_size())
			canvas.draw_polygon(points, PackedColorArray([tint]), uvs, atlas)
