extends RefCounted

## Chapter-two basalt masonry. Decoration never changes the walkable surface.
static func draw_platform(canvas: Node2D, rect: Rect2) -> void:
	var height := minf(rect.size.y, 720.0 - rect.position.y)
	if height <= 0.0:
		return
	var p := rect.position
	var width := rect.size.x
	canvas.draw_rect(Rect2(p, Vector2(width, height)), Color("#171315"))
	canvas.draw_rect(Rect2(p + Vector2(2, 7), Vector2(width - 4, maxf(0, height - 7))), Color("#332522"))
	# Broad, cooled tread reads as solid footing above the ember seams.
	canvas.draw_rect(Rect2(p, Vector2(width, minf(7, height))), Color("#625047"))
	canvas.draw_line(p + Vector2(0, 1), p + Vector2(width, 1), Color("#c69a6d"), 2)
	canvas.draw_line(p + Vector2(2, 7), p + Vector2(width - 2, 7), Color("#100f12"), 2)
	for i in range(int(ceil(width / 46.0))):
		var x := float(i) * 46.0
		var span := minf(43.0, width - x - 3.0)
		if span <= 0:
			continue
		var shade := Color("#40302a") if i % 2 == 0 else Color("#2a2223")
		canvas.draw_rect(Rect2(p + Vector2(x + 2, 10), Vector2(span, maxf(1, height - 13))), shade)
		canvas.draw_line(p + Vector2(x + 8, 3), p + Vector2(minf(width - 2, x + 30), 3), Color("#877060"), 1)
		if height >= 20 and span >= 25:
			var crack := PackedVector2Array([
				p + Vector2(x + 18, 10), p + Vector2(x + 25, 15),
				p + Vector2(x + 20, minf(height - 3, 23)),
				p + Vector2(x + 29, height - 2),
			])
			canvas.draw_polyline(crack, Color(0.85, 0.20, 0.035, 0.18), 7, true)
			canvas.draw_polyline(crack, Color("#9c3920"), 3, true)
			canvas.draw_polyline(crack, Color("#e57b35"), 1, true)
	if rect.size.y < 100:
		# Irregular cooled-rock underside replaces the blue ornamental corbels.
		for i in range(int(ceil(width / 38.0))):
			var x := float(i) * 38.0
			var right := minf(width, x + 38)
			var depth := 9.0 + float((i * 7 + int(p.x)) % 13)
			var points := PackedVector2Array([
				p + Vector2(x, height - 1), p + Vector2(right, height - 1),
				p + Vector2(lerpf(x, right, 0.72), height + depth * 0.7),
				p + Vector2(lerpf(x, right, 0.30), height + depth),
			])
			canvas.draw_colored_polygon(points, Color("#241d1e"))
			canvas.draw_line(points[0] + Vector2(5, 0), points[3], Color("#583528"), 1)
