extends SceneTree

const MOTION := preload("res://scripts/forge_actor_motion.gd")
const C := MOTION.Clip
const ACTION_POSES := [
	[[0, C.IDLE, 0.0], [1, C.CAST_LIFT, 0.0], [1, C.CAST_LIFT, 0.67], [1, C.CAST_LIFT, 1.0], [2, C.CAST_RELEASE, 0.0], [0, C.CAST_RETURN, 0.5]],
	[[0, C.IDLE, 0.0], [1, C.SHIELD_LIFT, 0.0], [1, C.SHIELD_LIFT, 1.0], [2, C.SHIELD_DRIVE, 0.5], [2, C.SHIELD_BRAKE, 0.1], [0, C.SHIELD_BRAKE, 0.65]],
	[[0, C.IDLE, 0.0], [1, C.BEETLE_CROUCH, 0.4], [1, C.BEETLE_CROUCH, 1.0], [2, C.BEETLE_POUNCE, 0.5], [2, C.BEETLE_LAND, 0.25], [0, C.IDLE, 0.0]],
	[[1, C.HAMMER_LIFT, 0.0], [1, C.HAMMER_LIFT, 1.0], [2, C.HAMMER_DROP, 0.5], [0, C.HAMMER_RETURN, 0.65], [1, C.OVERLOAD, 0.35], [1, C.OVERLOAD, 0.65]],
]

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
	var pose := 0
	var cycle := 0.0
	var facing := 1.0
	var gait := 1.0
	var clip := C.IDLE
	var progress := 0.0
	func _draw() -> void:
		ART.draw_actor(self, row, pose, facing, 115 if row != 2 else 65, false, 1, Vector2.ONE, cycle, gait, clip, progress)

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1280, 720)
	var sheet := MotionSheet.new()
	root.add_child(sheet)
	var show_actions := "actions" in OS.get_cmdline_user_args()
	for row in range(4):
		for column in range(6):
			var sample := ActorSample.new()
			sample.row = row
			sample.cycle = column * TAU / 6.0
			if show_actions:
				var key: Array = ACTION_POSES[row][column]
				sample.pose = key[0]
				sample.clip = key[1]
				sample.progress = key[2]
				sample.gait = 0
			else:
				sample.facing = -1 if column >= 3 else 1
			sample.position = Vector2(110 + column * 210, 130 + row * 175)
			sheet.add_child(sample)
	await process_frame
	await RenderingServer.frame_post_draw
	var filename := "forge_action_sheet.png" if show_actions else "forge_gait_sheet.png"
	var result := root.get_texture().get_image().save_png("res://test_output/" + filename)
	if result != OK: quit(1); return
	print("capture_forge_gait: PASS")
	sheet.queue_free()
	await process_frame
	quit()
