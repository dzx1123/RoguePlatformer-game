extends Node2D

class_name RoomEntryBeam

const FRAME_COUNT := 12
const FRAME_TIME := 0.1
const DISPLAY_SCALE := 0.5
var _elapsed := 0.0
var _frames: Array[Texture2D] = []

func _ready() -> void:
	for index in range(FRAME_COUNT):
		_frames.append(load("res://assets/effects/entry_beam/frame_%03d.png" % index))
	# The supplied animation has a black matte. Additive compositing keeps
	# the original blue light and frame artwork without a black rectangle.
	var blend := CanvasItemMaterial.new()
	blend.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = blend
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR

func play(_scale_multiplier: float = 1.0) -> void:
	_elapsed = 0.0
	queue_redraw()

func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= FRAME_COUNT * FRAME_TIME:
		queue_free()
	queue_redraw()

func _draw() -> void:
	if _frames.is_empty():
		return
	var index := mini(FRAME_COUNT - 1, int(_elapsed / FRAME_TIME))
	var size := _frames[index].get_size() * DISPLAY_SCALE
	draw_texture_rect(_frames[index], Rect2(Vector2(-size.x * 0.5, 48.0 - size.y), size), false)
