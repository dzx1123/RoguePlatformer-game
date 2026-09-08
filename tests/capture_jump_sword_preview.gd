extends SceneTree

const PREVIEW_SIZE := Vector2i(960, 280)
const OUTPUT_PATH := "res://tests/artifacts/jump_sword_filter_preview.png"


func _initialize() -> void:
	call_deferred(&"_capture")


func _capture() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Jump sword preview requires a rendering display")
		quit(1)
		return
	root.content_scale_size = PREVIEW_SIZE
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_IGNORE
	root.size = PREVIEW_SIZE
	var background := ColorRect.new()
	background.size = PREVIEW_SIZE
	background.color = Color("#0b1a28")
	root.add_child(background)
	var cases: Array[Dictionary] = [
		{"label": "起跳", "air": 0.03, "velocity": -620.0, "fall": false},
		{"label": "上升", "air": 0.20, "velocity": -420.0, "fall": false},
		{"label": "顶点", "air": 0.30, "velocity": -80.0, "fall": false},
		{"label": "下落", "air": 0.38, "velocity": 400.0, "fall": true},
	]
	var player_scene := load("res://scenes/Player.tscn") as PackedScene
	for index: int in range(cases.size()):
		var data: Dictionary = cases[index]
		var player := player_scene.instantiate() as RoguePlayer
		player.position = Vector2(120.0 + float(index) * 240.0, 154.0)
		root.add_child(player)
		player.set_physics_process(false)
		player.set_process(false)
		player.set("_airborne_time", float(data["air"]))
		player.velocity.y = float(data["velocity"])
		player.call(&"_reset_sprite_pose")
		player.call(&"_animate_jump_fall" if bool(data["fall"]) else &"_animate_jump_rise")
		var label := Label.new()
		label.position = Vector2(float(index) * 240.0, 230.0)
		label.size = Vector2(240.0, 28.0)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.text = String(data["label"])
		label.add_theme_font_size_override("font_size", 16)
		root.add_child(label)
	for _frame: int in range(4):
		await process_frame
	var save_error := root.get_texture().get_image().save_png(OUTPUT_PATH)
	if save_error != OK:
		push_error("Could not save jump sword preview: %s" % error_string(save_error))
		quit(1)
		return
	print("capture_jump_sword_preview: PASS %s" % OUTPUT_PATH)
	quit(0)
