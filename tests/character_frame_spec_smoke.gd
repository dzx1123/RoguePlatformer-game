extends SceneTree

const FRAME_DIRECTORY := "res://assets/characters/frames_polished/"
const CANONICAL_SIZE := Vector2i(640, 416)
const ALPHA_THRESHOLD := 0.01
const EDGE_MARGIN := 4
const MAX_EDGE_ALPHA_PIXELS := 96
const MAX_RUN_BASELINE_SPREAD := 2

const CANONICAL_FRAMES: Array[String] = [
	"hero_idle.png",
	"hero_recovery.png",
	"hero_windup.png",
	"hero_walk_1.png",
	"hero_walk_2.png",
	"hero_walk_3.png",
	"hero_jump_takeoff.png",
	"hero_jump_tuck.png",
	"hero_jump_fall.png",
	"hero_land.png",
	"hero_slash.png",
	"hero_slash_followthrough.png",
	"hero_slash_up_windup.png",
	"hero_slash_up.png",
	"hero_slash_up_followthrough.png",
	"hero_slash_down_windup.png",
	"hero_slash_down.png",
	"hero_slash_down_followthrough.png",
	"hero_run_0.png",
	"hero_run_1.png",
	"hero_run_2.png",
	"hero_run_3.png",
	"hero_run_4.png",
	"hero_run_5.png",
	"hero_run_6.png",
	"hero_run_7.png",
]


func _initialize() -> void:
	call_deferred(&"_run_test")


func _run_test() -> void:
	var run_baselines: Array[int] = []
	for frame_name: String in CANONICAL_FRAMES:
		var image: Image = _load_frame_image(frame_name)
		if image == null or image.is_empty():
			_fail("Could not load canonical character frame: %s" % frame_name)
			return
		if image.get_size() != CANONICAL_SIZE:
			_fail(
				"%s uses %s instead of the canonical %s canvas"
				% [frame_name, image.get_size(), CANONICAL_SIZE]
			)
			return
		var alpha_metrics: Dictionary = _measure_alpha(image)
		if int(alpha_metrics.get("visible_pixels", 0)) <= 0:
			_fail("%s contains no visible character pixels" % frame_name)
			return
		if int(alpha_metrics.get("edge_pixels", 0)) > MAX_EDGE_ALPHA_PIXELS:
			_fail("%s touches too much of the canvas edge; check clipping or a matte" % frame_name)
			return
		if frame_name.begins_with("hero_run_"):
			run_baselines.append(int(alpha_metrics.get("bottom", -1)))

	if run_baselines.size() != 8:
		_fail("The canonical locomotion set does not contain eight run frames")
		return
	var baseline_min: int = run_baselines.min()
	var baseline_max: int = run_baselines.max()
	if baseline_max - baseline_min > MAX_RUN_BASELINE_SPREAD:
		_fail(
			"Run-frame source baselines drift by %d px"
			% (baseline_max - baseline_min)
		)
		return

	if not _check_special_asset("hero_near_arm.png", Vector2i(84, 168)):
		return
	if not _check_special_asset("hero_waist_cover.png", Vector2i(67, 72)):
		return
	if not _check_special_asset("hero_skill_fullmoon_sheet_v2.png", Vector2i(1536, 1024)):
		return

	print(
		"character_frame_spec_smoke: PASS (run baseline %d..%d)"
		% [baseline_min, baseline_max]
	)
	quit(0)


func _measure_alpha(image: Image) -> Dictionary:
	var size: Vector2i = image.get_size()
	var visible_pixels := 0
	var edge_pixels := 0
	var bottom := -1
	for y in range(size.y):
		for x in range(size.x):
			if image.get_pixel(x, y).a <= ALPHA_THRESHOLD:
				continue
			visible_pixels += 1
			bottom = maxi(bottom, y)
			if (
				x < EDGE_MARGIN
				or y < EDGE_MARGIN
				or x >= size.x - EDGE_MARGIN
				or y >= size.y - EDGE_MARGIN
			):
				edge_pixels += 1
	return {
		"visible_pixels": visible_pixels,
		"edge_pixels": edge_pixels,
		"bottom": bottom,
	}


func _check_special_asset(frame_name: String, expected_size: Vector2i) -> bool:
	var image: Image = _load_frame_image(frame_name)
	if image == null or image.is_empty():
		_fail("Could not load layered character asset: %s" % frame_name)
		return false
	if image.get_size() != expected_size:
		_fail("%s no longer matches its documented layer size" % frame_name)
		return false
	return true


func _load_frame_image(frame_name: String) -> Image:
	var texture := load(FRAME_DIRECTORY + frame_name) as Texture2D
	if texture == null:
		return null
	return texture.get_image()


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
