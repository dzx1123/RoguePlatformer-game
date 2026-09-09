extends SceneTree

const WEAPON_DIRS := {
	WeaponCatalog.TWIN_BLADES: "res://assets/characters/weapon_sets/twin_blades",
	WeaponCatalog.GREATSWORD: "res://assets/characters/weapon_sets/greatsword",
}
const STRIKE_POSES := [
	"hero_attack_forward_strike.png",
	"hero_attack_up_strike.png",
	"hero_attack_down_strike.png",
]

var _failures: Array[String] = []


func _init() -> void:
	_run_test()


func _run_test() -> void:
	for action_name: StringName in [&"restart", &"move_left", &"move_right", &"jump", &"dash", &"attack", &"skill"]:
		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name)

	var player_scene: PackedScene = load("res://scenes/Player.tscn")
	var player: RoguePlayer = player_scene.instantiate() as RoguePlayer
	root.add_child(player)
	await process_frame
	player.set_physics_process(false)
	var weapon_effect: WeaponSkillEffect = player.get_node("WeaponSkillEffect") as WeaponSkillEffect

	for weapon_id: StringName in [WeaponCatalog.TWIN_BLADES, WeaponCatalog.GREATSWORD]:
		_validate_baked_frames(weapon_id)
		if not player.configure_weapon(weapon_id):
			_failures.append("configure_weapon failed: %s" % weapon_id)
			continue
		var duration: float = 0.27 if weapon_id == WeaponCatalog.TWIN_BLADES else 0.52
		for attack_type in range(3):
			player.set("_attack_type", attack_type)
			player.set("_attack_remaining", duration * 0.57)
			player.call(&"_update_skill_effect")
			weapon_effect.queue_redraw()
			await process_frame
			if weapon_effect.is_attack_effect_active():
				_failures.append(
					"%s attack %d activated the removed procedural effect"
					% [weapon_id, attack_type]
				)
		player.set("_attack_remaining", 0.0)
		player.call(&"_update_skill_effect")

	player.queue_free()
	if _failures.is_empty():
		print("weapon_attack_qi_render_smoke: PASS baked=6 procedural=off")
		quit(0)
	else:
		for failure: String in _failures:
			print("weapon_attack_qi_render_smoke: FAIL: ", failure)
		quit(1)


func _validate_baked_frames(weapon_id: StringName) -> void:
	var directory: String = WEAPON_DIRS[weapon_id]
	for pose_name: String in STRIKE_POSES:
		var path := "%s/%s" % [directory, pose_name]
		var image := Image.load_from_file(ProjectSettings.globalize_path(path))
		if image == null or image.is_empty():
			_failures.append("missing baked strike: %s" % path)
			continue
		var themed_pixels := 0
		var glow_pixels := 0
		for y in range(image.get_height()):
			for x in range(image.get_width()):
				var color := image.get_pixel(x, y)
				if color.a <= 0.0:
					continue
				if color.a < 0.96 and maxf(color.r, maxf(color.g, color.b)) > 0.70:
					glow_pixels += 1
				if weapon_id == WeaponCatalog.TWIN_BLADES:
					if color.b > 0.72 and color.g > 0.42 and color.b - color.r > 0.12:
						themed_pixels += 1
				elif color.r > 0.72 and color.g > 0.28 and color.r - color.b > 0.18:
					themed_pixels += 1
		if themed_pixels < 900 or glow_pixels < 300:
			_failures.append(
				"weak baked crescent %s themed=%d glow=%d"
				% [path, themed_pixels, glow_pixels]
			)
