extends SceneTree

const EXPECTED := {
	"res://assets/characters/weapon_sets/twin_blades/hero_idle.png": Vector2i(640, 416),
	"res://assets/characters/weapon_sets/greatsword/hero_idle.png": Vector2i(768, 416),
}
const EXPECTED_BOTTOM := 404
const MIN_MARGIN := 4


func _init() -> void:
	var failures: Array[String] = []
	for path: String in EXPECTED:
		var image := Image.load_from_file(ProjectSettings.globalize_path(path))
		if image == null or image.is_empty():
			failures.append("missing or empty: %s" % path)
			continue
		if image.get_size() != EXPECTED[path]:
			failures.append("wrong size %s: %s" % [path, image.get_size()])
		if image.get_format() not in [Image.FORMAT_RGBA8, Image.FORMAT_RGBAF, Image.FORMAT_RGBAH]:
			failures.append("not RGBA: %s" % path)
		var bounds := image.get_used_rect()
		if bounds.position.x < MIN_MARGIN or bounds.end.x > image.get_width() - MIN_MARGIN:
			failures.append("horizontal safety margin failed %s: %s" % [path, bounds])
		if bounds.end.y != EXPECTED_BOTTOM:
			failures.append("foot baseline failed %s: %s" % [path, bounds])
	if failures.is_empty():
		print("weapon_pose_base_smoke: PASS")
		quit(0)
	else:
		for failure: String in failures:
			print("weapon_pose_base_smoke: FAIL: ", failure)
		quit(1)
