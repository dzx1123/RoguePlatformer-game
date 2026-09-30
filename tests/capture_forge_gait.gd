extends SceneTree

class MotionSheet extends Node2D:
	const ART := preload("res://scripts/forge_character_art.gd")
	func _draw() -> void:
		draw_rect(Rect2(0, 0, 1280, 720), Color("#121b28"))
		for row in range(4):
			for column in range(6):
				draw_set_transform(Vector2(110 + column * 210, 130 + row * 175))
				draw_line(Vector2(-95, 24), Vector2(95, 24), Color("#4b6475"), 1)
				draw_set_transform(Vector2.ZERO)

class ActorSample extends Node2D:
	const ART := preload("res://scripts/forge_character_art.gd")
	var row := 0
	var cycle := 0.0
	var facing := 1.0
	func _draw() -> void:
		ART.draw_actor(self, row, 0, facing, 115 if row != 2 else 65, false, 1, Vector2.ONE, cycle, 1)

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1280, 720)
	var sheet := MotionSheet.new()
	root.add_child(sheet)
	for row in range(4):
		for column in range(6):
			var sample := ActorSample.new()
			sample.row = row
			sample.cycle = column * TAU / 6.0
			sample.facing = -1 if column >= 3 else 1
			sample.position = Vector2(110 + column * 210, 130 + row * 175)
			sheet.add_child(sample)
	await process_frame
	await RenderingServer.frame_post_draw
	var result := root.get_texture().get_image().save_png("D:/Godot/RoguePlatformer-game/test_output/forge_gait_sheet.png")
	if result != OK: quit(1); return
	print("capture_forge_gait: PASS")
	sheet.queue_free()
	await process_frame
	quit()
