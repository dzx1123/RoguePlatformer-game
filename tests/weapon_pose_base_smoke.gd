extends SceneTree

const EXPECTED := {
	"res://assets/characters/weapon_sets/twin_blades/hero_idle.png": Vector2i(640, 512),
	"res://assets/characters/weapon_sets/greatsword/hero_idle.png": Vector2i(768, 512),
}
const EXPECTED_BOOT_OFFSET := 190.0
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
		if absf(_boot_offset(image) - EXPECTED_BOOT_OFFSET) > 3.0:
			failures.append("boot baseline failed %s: %s" % [path, _boot_offset(image)])
	if failures.is_empty():
		print("weapon_pose_base_smoke: PASS")
		quit(0)
	else:
		for failure: String in failures:
			print("weapon_pose_base_smoke: FAIL: ", failure)
		quit(1)


func _boot_offset(image: Image) -> float:
	for y in range(image.get_height() - 1, image.get_height() / 2, -1):
		var warm_pixels := 0
		for x in range(image.get_width() / 2 - 100, image.get_width() / 2 + 116):
			var color := image.get_pixel(x, y)
			if color.a >= 0.5 and color.r > 24.0 / 255.0 and color.r < 175.0 / 255.0 and color.r > color.g * 1.1 and color.g > color.b * 1.1:
				warm_pixels += 1
		if warm_pixels >= 3:
			return float(y + 1) - float(image.get_height()) * 0.5
	return -INF