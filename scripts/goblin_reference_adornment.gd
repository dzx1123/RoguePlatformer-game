extends Node2D

# Frame-local crown landmarks keep horns attached during windup, recoil and death.
const CROWNS := [Vector2(69, 42), Vector2(64, 53), Vector2(66, 42), Vector2(68, 47), Vector2(70, 48), Vector2(66, 48), Vector2(50, 44), Vector2(39, 77), Vector2(36, 88), Vector2(40, 101), Vector2(65, 55), Vector2(66, 43), Vector2(65, 43), Vector2(65, 47), Vector2(65, 44), Vector2(67, 42), Vector2(66, 46)]
var frame_index := 0
var facing_right := true
var elite := false
var ranged := false
var draw_progress := 0.0

func set_pose(frame: int, right: bool, large_horns: bool, archer: bool, progress: float) -> void:
	frame_index = frame
	facing_right = right
	elite = large_horns
	ranged = archer
	draw_progress = progress
	queue_redraw()

func _draw() -> void:
	var offset_y := 12 if frame_index >= 11 else (1 if frame_index >= 7 and frame_index <= 9 else 8)
	var origin := Vector2(4, offset_y) - Vector2(72, 69)
	var head: Vector2 = CROWNS[frame_index] + origin
	var sign_x := 1.0 if facing_right else -1.0
	var length := 11.0 if elite else 7.0
	for side in [-1.0, 1.0]:
		var base := head + Vector2(side * 5.0, 0.0)
		var points := PackedVector2Array([base + Vector2(-2, 2), base + Vector2(side * 3, -length), base + Vector2(2, 0)])
		for index in range(points.size()):
			points[index].x *= sign_x
		draw_colored_polygon(points, Color("#241724"))
		var light := PackedVector2Array([base, base + Vector2(side * 3, -length + 2), base + Vector2(1, 0)])
		for index in range(light.size()):
			light[index].x *= sign_x
		draw_colored_polygon(light, Color("#e4c487"))
	if ranged and frame_index < 7 or ranged and frame_index >= 10:
		# Compact quiver and bow distinguish the ranged role without changing the gait.
		var hip := Vector2(59, 79) + origin
		var quiver := PackedVector2Array([hip + Vector2(-12,-18), hip + Vector2(-7,-16), hip + Vector2(-10,-3), hip + Vector2(-15,-5)])
		for index in range(quiver.size()):
			quiver[index].x *= sign_x
		draw_colored_polygon(quiver, Color("#513022"))
		var bow_center := Vector2(80, 79) + origin
		var bow := PackedVector2Array([bow_center + Vector2(-3,-12), bow_center + Vector2(4,-6), bow_center + Vector2(6,0), bow_center + Vector2(4,6), bow_center + Vector2(-3,12)])
		for index in range(bow.size()):
			bow[index].x *= sign_x
		draw_polyline(bow, Color("#c89b54"), 2.0, false)
		var nock := bow_center + Vector2(-3.0 - sin(draw_progress * PI) * 6.0, 0)
		nock.x *= sign_x
		draw_polyline(PackedVector2Array([bow[0], nock, bow[4]]), Color("#ddd1a2"), 1.0, false)
