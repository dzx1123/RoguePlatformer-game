extends RefCounted

## Shared stonework used by both chapters; cap follows the collision surface.
static func draw_platform(canvas: Node2D, rect: Rect2, room_accent: Color) -> void:
	var visible_height: float = minf(rect.size.y, 720.0 - rect.position.y)
	if visible_height <= 0.0:
		return
	var facade := Rect2(rect.position, Vector2(rect.size.x, visible_height))
	var rune_color := room_accent.lerp(Color("#50d9ed"), 0.65)
	var stone_edge := Color("#07111b")
	var stone_face := Color("#132a3a")
	var gold_trim := Color("#c79b48")

	# The cap is the walkable stone lip. It shares the collider's exact top edge.
	canvas.draw_rect(facade, stone_edge)
	canvas.draw_rect(Rect2(rect.position + Vector2(2.0, 3.0), Vector2(rect.size.x - 4.0, maxf(0.0, visible_height - 3.0))), stone_face)
	canvas.draw_rect(Rect2(rect.position, Vector2(rect.size.x, minf(8.0, visible_height))), Color("#29495a"))
	canvas.draw_line(rect.position + Vector2(0.0, 1.0), rect.position + Vector2(rect.size.x, 1.0), gold_trim, 1.5)
	canvas.draw_line(rect.position + Vector2(0.0, 6.0), rect.position + Vector2(rect.size.x, 6.0), Color("#5e8290"), 1.0)

	var block_width: float = 42.0
	var block_x: float = rect.position.x + 4.0
	var row_index: int = 0
	while block_x < rect.end.x - 3.0:
		var offset: float = 0.0 if row_index % 2 == 0 else block_width * 0.5
		for row_y in range(14, int(visible_height), 15):
			var seam_x: float = block_x + offset
			if seam_x > rect.position.x + 3.0 and seam_x < rect.end.x - 3.0:
				canvas.draw_line(
					Vector2(seam_x, rect.position.y + float(row_y)),
					Vector2(seam_x, rect.position.y + minf(float(row_y + 12), visible_height - 2.0)),
					Color("#0a1a25"),
					1.0
				)
		row_index += 1
		block_x += block_width
	for row_y in range(14, int(visible_height), 15):
		canvas.draw_line(
			Vector2(rect.position.x + 3.0, rect.position.y + float(row_y)),
			Vector2(rect.end.x - 3.0, rect.position.y + float(row_y)),
			Color("#0a1a25"),
			1.0
		)

	var rune_x: float = rect.position.x + 24.0
	while rune_x < rect.end.x - 16.0:
		if visible_height >= 22.0:
			var rune_center := Vector2(rune_x, rect.position.y + 15.0)
			canvas.draw_colored_polygon(
				PackedVector2Array([
					rune_center + Vector2(0.0, -4.0), rune_center + Vector2(4.0, 0.0),
					rune_center + Vector2(0.0, 4.0), rune_center + Vector2(-4.0, 0.0),
				]),
				rune_color
			)
			canvas.draw_circle(rune_center, 1.4, Color("#d8f7ff"))
		rune_x += 96.0

