extends SceneTree

const DESIGN_SIZE := Vector2(1280.0, 840.0)
const TEST_SIZES: Array[Vector2i] = [
	Vector2i(1280, 840),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
]


func _initialize() -> void:
	call_deferred(&"_run_test")


func _run_test() -> void:
	if not _verify_scale_contract():
		return
	var scene: PackedScene = load("res://scenes/Main.tscn")
	var main: Node2D = scene.instantiate() as Node2D
	main.set("save_enabled", false)
	root.add_child(main)
	for _frame_index: int in range(8):
		await process_frame
	var hud: CanvasLayer = main.get_node("HUD") as CanvasLayer
	var required_paths: Array[String] = [
		"BottomHUD",
		"VitalsPanel",
		"AbilityPanel",
		"WeaponPanel",
		"RoomCard",
		"StatusToast",
		"HealthBackground",
		"AbilityBar",
		"EntryFlow",
		"PauseMenu",
		"SettingsMenu",
	]
	for path: String in required_paths:
		var control: Control = hud.get_node_or_null(path) as Control
		if control == null:
			_fail("Missing responsive HUD control: %s" % path)
			return
		if not _inside_design_rect(control.get_global_rect()):
			_fail("HUD control leaves the design viewport: %s %s" % [path, control.get_global_rect()])
			return
	var bottom_hud: Control = hud.get_node("BottomHUD") as Control
	if bottom_hud.position != Vector2(0.0, 720.0) or bottom_hud.size != Vector2(1280.0, 120.0):
		_fail("Bottom HUD no longer owns the reserved 120-pixel dock")
		return
	var vitals: Control = hud.get_node("VitalsPanel") as Control
	var abilities: Control = hud.get_node("AbilityPanel") as Control
	var weapons: Control = hud.get_node("WeaponPanel") as Control
	if vitals.get_global_rect().intersects(abilities.get_global_rect()):
		_fail("Vitals and ability panels overlap")
		return
	if abilities.get_global_rect().intersects(weapons.get_global_rect()):
		_fail("Ability and weapon panels overlap")
		return
	main.queue_free()
	print("resolution_matrix_smoke: PASS sizes=%d" % TEST_SIZES.size())
	quit(0)


func _inside_design_rect(rect: Rect2) -> bool:
	return (
		rect.position.x >= -0.1
		and rect.position.y >= -0.1
		and rect.end.x <= DESIGN_SIZE.x + 0.1
		and rect.end.y <= DESIGN_SIZE.y + 0.1
	)


func _verify_scale_contract() -> bool:
	if (
		int(ProjectSettings.get_setting("display/window/size/viewport_width", 0)) != int(DESIGN_SIZE.x)
		or int(ProjectSettings.get_setting("display/window/size/viewport_height", 0)) != int(DESIGN_SIZE.y)
		or String(ProjectSettings.get_setting("display/window/stretch/aspect", "")) != "keep"
	):
		_fail("Project stretch contract changed")
		return false
	for window_size: Vector2i in TEST_SIZES:
		var scale: float = minf(
			float(window_size.x) / DESIGN_SIZE.x,
			float(window_size.y) / DESIGN_SIZE.y
		)
		var content_size: Vector2 = DESIGN_SIZE * scale
		var letterbox: Vector2 = (Vector2(window_size) - content_size) * 0.5
		if scale <= 0.0 or letterbox.x < -0.1 or letterbox.y < -0.1:
			_fail("Invalid keep-aspect projection for %s" % window_size)
			return false
		if content_size.x > float(window_size.x) + 0.1 or content_size.y > float(window_size.y) + 0.1:
			_fail("Projected content exceeds window size %s" % window_size)
			return false
	return true


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
