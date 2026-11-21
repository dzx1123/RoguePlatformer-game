extends RefCounted

## Runtime atlas regions keep original generated alpha; drawing never changes hit geometry.
const ATLAS_PATH := "res://assets/chapter2/forge_characters_v1.png"
const MOTION := preload("res://scripts/forge_actor_motion.gd")
const GRID := 9
# Normalized centers of the active wrist, shield, claw, or hammer in each pose.
const JOINTS := [
	[Vector2(0.85, 0.69), Vector2(0.19, 0.21), Vector2(0.88, 0.26)],
	[Vector2(0.84, 0.45), Vector2(0.85, 0.56), Vector2(0.83, 0.49)],
	[Vector2(0.86, 0.57), Vector2(0.88, 0.57), Vector2(0.85, 0.60)],
	[Vector2(0.17, 0.70), Vector2(0.15, 0.19), Vector2(0.87, 0.35)],
]
const SOLE_CENTER := [
	[0.47, 0.45, 0.35, 0.50],
	[0.47, 0.44, 0.30, 0.50],
	[0.50, 0.49, 0.48, 0.50],
	[0.50, 0.49, 0.31, 0.50],
]
# The wide hit poses cross the atlas's nominal quarter-width cells. These
# rectangles include their complete props; adjacent silhouettes have masks below.
const CELLS := [
	[Rect2i(37, 31, 253, 304), Rect2i(315, 4, 268, 331), Rect2i(626, 56, 335, 278), Rect2i(930, 85, 311, 253)],
	[Rect2i(26, 351, 274, 313), Rect2i(318, 313, 287, 350), Rect2i(616, 397, 395, 267), Rect2i(935, 483, 312, 191)],
	[Rect2i(14, 687, 276, 185), Rect2i(317, 672, 299, 199), Rect2i(607, 699, 350, 173), Rect2i(960, 738, 285, 138)],
	[Rect2i(24, 880, 279, 351), Rect2i(318, 864, 293, 369), Rect2i(619, 934, 400, 299), Rect2i(934, 997, 316, 232)],
]
static var frames: Array[Texture2D] = []
static var mesh_indices: PackedInt32Array

static func _load() -> void:
	if not frames.is_empty():
		return
	var atlas := load(ATLAS_PATH) as Texture2D
	var image := atlas.get_image()
	if image.is_compressed():
		image.decompress()
	image.convert(Image.FORMAT_RGBA8)
	for row in range(4):
		for column in range(4):
			var frame := _extract_frame(image, row, column, CELLS[row][column])
			frames.append(ImageTexture.create_from_image(frame))
	for y in GRID:
		for x in GRID:
			var top_left := y * (GRID + 1) + x
			var bottom_left := top_left + GRID + 1
			mesh_indices.append_array([top_left, top_left + 1, bottom_left, bottom_left, top_left + 1, bottom_left + 1])

static func _extract_frame(image: Image, row: int, column: int, cell: Rect2i) -> Image:
	var frame := image.get_region(cell)
	# Clear only the overlaps where props or boots enter the neighboring frame.
	match Vector2i(row, column):
		Vector2i(0, 1):
			_clear_atlas_rect(frame, cell, Rect2i(389, 309, 105, 30))
		Vector2i(1, 1):
			_clear_atlas_rect(frame, cell, Rect2i(316, 310, 77, 28))
			_clear_atlas_rect(frame, cell, Rect2i(494, 310, 111, 28))
		Vector2i(0, 2):
			_clear_atlas_rect(frame, cell, Rect2i(926, 275, 40, 63))
		Vector2i(0, 3):
			_clear_atlas_rect(frame, cell, Rect2i(926, 50, 39, 94))
		Vector2i(1, 2):
			_clear_atlas_rect(frame, cell, Rect2i(997, 551, 18, 13))
			_clear_atlas_rect(frame, cell, Rect2i(932, 562, 83, 108))
		Vector2i(1, 3):
			_clear_atlas_rect(frame, cell, Rect2i(935, 477, 82, 77))
			_clear_atlas_rect(frame, cell, Rect2i(935, 554, 59, 14))
		Vector2i(3, 2):
			_clear_atlas_rect(frame, cell, Rect2i(928, 1082, 94, 156))
		Vector2i(3, 3):
			_clear_atlas_rect(frame, cell, Rect2i(931, 990, 87, 92))
	return frame.get_region(frame.get_used_rect())

static func _clear_atlas_rect(frame: Image, cell: Rect2i, atlas_rect: Rect2i) -> void:
	var cut := cell.intersection(atlas_rect)
	if cut.has_area():
		frame.fill_rect(Rect2i(cut.position - cell.position, cut.size), Color.TRANSPARENT)

static func _destination(row: int, pose: int, height: float, motion: Vector2) -> Rect2:
	var texture := frames[row * 4 + pose]
	# Constant row scale avoids enlarging the fallen pose.
	var size := texture.get_size() * (height / frames[row * 4].get_height()) * motion
	return Rect2(-size.x * SOLE_CENTER[row][pose], 24 - size.y, size.x, size.y)

static func caster_release_point(height: float, facing: float) -> Vector2:
	_load()
	var destination := _destination(0, 2, height, Vector2.ONE)
	var uv := Vector2(0.92, 0.13)
	var keys := MOTION.sample_clip(MOTION.Clip.CAST_RELEASE, 0.0)
	var point := destination.position + destination.size * uv + MOTION.action_offset(uv, JOINTS[0][2], keys, height, false)
	return point * Vector2(facing, 1.0)

static func draw_actor(canvas: Node2D, row: int, pose: int, facing: float, height: float, hurt: bool, death_alpha: float = 1.0, motion: Vector2 = Vector2.ONE, gait_phase: float = 0.0, gait_weight: float = 0.0, clip: MOTION.Clip = MOTION.Clip.IDLE, progress: float = 0.0) -> void:
	_load()
	pose = clampi(pose, 0, 3)
	var texture := frames[row * 4 + pose]
	var destination := _destination(row, pose, height, motion)
	if facing < 0:
		canvas.draw_set_transform(Vector2.ZERO, 0, Vector2(-1, 1))
	var tint := Color(1.6, 1.6, 1.6, death_alpha) if hurt else Color(1, 1, 1, death_alpha)
	var walking := gait_weight > 0.001 and pose == 0 and clip == MOTION.Clip.IDLE
	if walking or clip != MOTION.Clip.IDLE:
		var keys := MOTION.sample_clip(clip, progress)
		var joint: Vector2 = Vector2(0.87, 0.57) if clip == MOTION.Clip.CORE_PULSE else JOINTS[row][mini(pose, 2)]
		_draw_mesh(canvas, destination, texture, tint, row, height, joint, keys, gait_phase, gait_weight if walking else 0.0)
	else:
		canvas.draw_texture_rect(texture, destination, false, tint)
	canvas.draw_set_transform(Vector2.ZERO)

static func _draw_mesh(canvas: Node2D, destination: Rect2, texture: Texture2D, tint: Color, row: int, height: float, joint: Vector2, keys: Vector4, cycle: float, weight: float) -> void:
	var points := PackedVector2Array()
	var uvs := PackedVector2Array()
	for y in range(GRID + 1):
		for x in range(GRID + 1):
			var uv := Vector2(x, y) / GRID
			var offset := MOTION.gait_offset(uv, cycle, weight, height, row) if weight > 0.0 else MOTION.action_offset(uv, joint, keys, height, row == 2)
			points.append(destination.position + uv * destination.size + offset)
			uvs.append(uv)
	# Shared vertices keep the atlas connected across the changing silhouettes.
	RenderingServer.canvas_item_add_triangle_array(canvas.get_canvas_item(), mesh_indices, points, PackedColorArray([tint]), uvs, PackedInt32Array(), PackedFloat32Array(), texture.get_rid())
