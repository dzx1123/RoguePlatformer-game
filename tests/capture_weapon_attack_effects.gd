extends SceneTree

const PREVIEW_SIZE := Vector2i(1200, 780)
const BACKGROUND := Color("#08111d")
const OUTPUT_PATH := "res://tests/artifacts/weapon_actions/attack_effects_v6.png"
const ATTACK_NAMES := ["FORWARD", "UP", "DOWN"]
const SWORD_TEXTURES := [
	"res://assets/characters/frames_polished/hero_slash.png",
	"res://assets/characters/frames_polished/hero_slash_up.png",
	"res://assets/characters/frames_polished/hero_slash_down.png",
]
const WEAPON_POSES := [
	"hero_attack_forward_strike.png",
	"hero_attack_up_strike.png",
	"hero_attack_down_strike.png",
]


func _init() -> void:
	_capture()


func _capture() -> void:
	root.content_scale_size = PREVIEW_SIZE
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_IGNORE
	root.size = PREVIEW_SIZE
	RenderingServer.set_default_clear_color(BACKGROUND)

	var backdrop := ColorRect.new()
	backdrop.size = Vector2(PREVIEW_SIZE)
	backdrop.color = BACKGROUND
	root.add_child(backdrop)

	var column_x := [200.0, 600.0, 1000.0]
	var row_y := [145.0, 390.0, 645.0]
	for attack_type in range(3):
		_add_label(ATTACK_NAMES[attack_type], Vector2(column_x[attack_type] - 46.0, 16.0))
		_add_sprite(SWORD_TEXTURES[attack_type], Vector2(column_x[attack_type], row_y[0]))

		_add_sprite(
			"res://assets/characters/weapon_sets/twin_blades/%s" % WEAPON_POSES[attack_type],
			Vector2(column_x[attack_type], row_y[1])
		)
		_add_effect(
			Vector2(column_x[attack_type], row_y[1]),
			WeaponCatalog.TWIN_BLADES,
			0.43,
			0.88,
			Color("#b48cff"),
			attack_type
		)

		_add_sprite(
			"res://assets/characters/weapon_sets/greatsword/%s" % WEAPON_POSES[attack_type],
			Vector2(column_x[attack_type], row_y[2])
		)
		_add_effect(
			Vector2(column_x[attack_type], row_y[2]),
			WeaponCatalog.GREATSWORD,
			0.47,
			1.28,
			Color("#ff9b62"),
			attack_type
		)

	_add_label("ONE-HAND", Vector2(18.0, row_y[0] - 104.0))
	_add_label("TWIN", Vector2(18.0, row_y[1] - 104.0))
	_add_label("GREAT", Vector2(18.0, row_y[2] - 104.0))

	await process_frame
	await process_frame
	RenderingServer.force_draw()
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var error := image.save_png(OUTPUT_PATH)
	if error != OK:
		push_error("Failed to save attack-effect preview: %s" % error_string(error))
		quit(1)
		return
	print("capture_weapon_attack_effects: PASS %s" % OUTPUT_PATH)
	quit(0)


func _add_sprite(texture_path: String, position: Vector2) -> void:
	var sprite := Sprite2D.new()
	# Match Player.tscn: the character is rendered above the procedural sweep,
	# preserving the same foreground/background read as the baked sword frames.
	sprite.z_index = 1
	sprite.texture = load(texture_path) as Texture2D
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# HeroSprite is offset by -15 px from the Player root in the real scene.
	sprite.position = position + Vector2(0.0, -15.0)
	sprite.scale = Vector2(0.22, 0.22)
	root.add_child(sprite)


func _add_effect(
	position: Vector2,
	weapon_id: StringName,
	progress: float,
	reach_scale: float,
	accent: Color,
	attack_type: int
) -> void:
	var effect := WeaponSkillEffect.new()
	effect.position = position
	root.add_child(effect)
	effect.call_deferred(
		&"set_attack_state",
		true,
		progress,
		1.0,
		weapon_id,
		reach_scale,
		accent,
		attack_type
	)


func _add_label(text: String, position: Vector2) -> void:
	var label := Label.new()
	label.text = text
	label.position = position
	label.add_theme_color_override("font_color", Color("#dce9f5"))
	label.add_theme_font_size_override("font_size", 16)
	root.add_child(label)
