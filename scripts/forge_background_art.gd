extends RefCounted

static var warm: Texture2D
static var cool: Texture2D

static func draw_background(canvas: Node2D, layout: StringName) -> void:
	if warm == null:
		warm = load("res://assets/chapter2/forge_background_v1.png") as Texture2D
		cool = load("res://assets/chapter2/cooling_court_v1.png") as Texture2D
	var tint := Color(0.78, 0.78, 0.85) if layout in [&"bridge", &"chain"] else Color.WHITE
	canvas.draw_texture_rect(cool if layout == &"court" else warm, Rect2(0, 0, 1280, 720), false, tint)
	canvas.draw_rect(Rect2(0, 0, 1280, 180), Color(0.025, 0.03, 0.055, 0.72))
