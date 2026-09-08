extends SceneTree

const PREVIEW_SIZE := Vector2i(1180, 420)
const SAMPLE_LABELS: Array[String] = [
	"FLAP UP",
	"FLAP MID",
	"FLAP DOWN",
	"TUCK / WARN",
	"DIVE ATTACK",
	"RECOVER",
]


func _initialize() -> void:
	call_deferred(&"_capture_preview")


func _capture_preview() -> void:
	root.content_scale_size = PREVIEW_SIZE
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_IGNORE
	root.size = PREVIEW_SIZE
	RenderingServer.set_default_clear_color(Color("#080d19"))

	var backdrop_layer := CanvasLayer.new()
	backdrop_layer.layer = -1
	root.add_child(backdrop_layer)
	var backdrop := ColorRect.new()
	backdrop.size = Vector2(PREVIEW_SIZE)
	backdrop.color = Color("#080d19")
	backdrop_layer.add_child(backdrop)
	var moon_glow := ColorRect.new()
	moon_glow.position = Vector2(0.0, 308.0)
	moon_glow.size = Vector2(float(PREVIEW_SIZE.x), 112.0)
	moon_glow.color = Color("#111f33")
	backdrop_layer.add_child(moon_glow)
	var title := Label.new()
	title.text = "NIGHT BAT / HOVER LOOP + TELEGRAPHED DIVE"
	title.position = Vector2(28.0, 24.0)
	title.size = Vector2(float(PREVIEW_SIZE.x) - 56.0, 34.0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color("#d9e8ff"))
	backdrop_layer.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "3-frame flight cycle  →  tucked warning  →  locked dive  →  climb recovery"
	subtitle.position = Vector2(28.0, 60.0)
	subtitle.size = Vector2(float(PREVIEW_SIZE.x) - 56.0, 26.0)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 14)
	subtitle.add_theme_color_override("font_color", Color("#829abd"))
	backdrop_layer.add_child(subtitle)

	for sample_index in range(SAMPLE_LABELS.size()):
		var sample_x: float = 100.0 + float(sample_index) * 196.0
		var divider := ColorRect.new()
		divider.position = Vector2(sample_x - 98.0, 104.0)
		divider.size = Vector2(1.0, 204.0)
		divider.color = Color(0.33, 0.46, 0.66, 0.22)
		backdrop_layer.add_child(divider)
		var label := Label.new()
		label.text = SAMPLE_LABELS[sample_index]
		label.position = Vector2(sample_x - 82.0, 112.0)
		label.size = Vector2(164.0, 24.0)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 13)
		label.add_theme_color_override(
			"font_color",
			Color("#ffb45d") if sample_index == 4 else Color("#cbb9ff")
		)
		backdrop_layer.add_child(label)

		var bat := RogueEnemy.new()
		bat.position = Vector2(sample_x, 224.0 if sample_index != 4 else 238.0)
		bat.setup(
			0,
			0.0,
			sample_x - 80.0,
			sample_x + 80.0,
			RogueEnemy.EnemyRole.MELEE,
			RogueEnemy.EnemyRank.NORMAL,
			1.0,
			1.0,
			RogueEnemy.EnemyFamily.NIGHT_BAT
		)
		root.add_child(bat)
		bat.set_physics_process(false)
		if sample_index < 3:
			bat.set(
				"_elapsed",
				(float(sample_index) + 0.02) / RogueEnemy.NIGHT_BAT_FLAP_FPS
			)
		else:
			var attack_progress: float = [0.12, 0.46, 0.84][sample_index - 3]
			var attack_duration: float = float(bat.call(&"_get_attack_duration"))
			bat.set("_attack_remaining", attack_duration * (1.0 - attack_progress))
			bat.set("_night_bat_dive_target", bat.position + Vector2(92.0, 118.0))
			bat.set("_night_bat_dive_direction", Vector2(0.62, 0.78).normalized())
			bat.set("_night_bat_dive_committed", sample_index >= 4)
			bat.set("_facing", 1.0)
			bat.velocity = (
				Vector2(335.0, 420.0)
				if sample_index == 4
				else Vector2(110.0, -285.0)
			)
		bat.call(&"_update_sprite_animation", 1.0 / 60.0)
		bat.queue_redraw()

	await process_frame
	await process_frame
	var output_path := "user://night_bat_preview.png"
	var user_arguments := OS.get_cmdline_user_args()
	if not user_arguments.is_empty():
		output_path = user_arguments[0]
	var viewport_texture: Texture2D = root.get_texture()
	if viewport_texture == null:
		push_error("Night bat preview requires a rendered compatibility window")
		quit(1)
		return
	var image: Image = viewport_texture.get_image()
	var save_error: Error = image.save_png(output_path)
	if save_error != OK:
		push_error("Could not save night bat preview: %s" % error_string(save_error))
		quit(1)
		return
	print("capture_night_bat_preview: PASS %s" % output_path)
	quit(0)
