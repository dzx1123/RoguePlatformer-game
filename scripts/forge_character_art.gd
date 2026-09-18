extends RefCounted

## Runtime atlas regions keep original generated alpha; drawing never changes hit geometry.
const ATLAS_PATH := "res://assets/chapter2/forge_characters_v1.png"
static var atlas: Texture2D
static var regions: Array[Rect2] = []

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

static func draw_actor(canvas: Node2D, row: int, pose: int, facing: float, height: float, hurt: bool, death_alpha: float = 1.0, motion: Vector2 = Vector2.ONE) -> void:
	_load()
	var source := regions[row * 4 + clampi(pose, 0, 3)]
	# Constant row scale avoids enlarging the collapsed pose.
	var reference_height := regions[row * 4].size.y
	var scale := height / reference_height
	var size := source.size * scale * motion
	var destination := Rect2(Vector2(-size.x / 2, 24 - size.y), size)
	if facing < 0:
		canvas.draw_set_transform(Vector2.ZERO, 0, Vector2(-1, 1))
	canvas.draw_texture_rect_region(atlas, destination, source, Color(1.6, 1.6, 1.6, death_alpha) if hurt else Color(1, 1, 1, death_alpha))
	canvas.draw_set_transform(Vector2.ZERO)
