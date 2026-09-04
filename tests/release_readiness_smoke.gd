extends SceneTree

const ICON := "res://assets/ui/moon_eclipse_icon.svg"


func _initialize() -> void:
	call_deferred(&"_run_test")


func _run_test() -> void:
	if String(ProjectSettings.get_setting("application/config/icon", "")) != ICON:
		_fail("Project icon is not configured")
		return
	if not ResourceLoader.exists(ICON):
		_fail("Project icon cannot be loaded")
		return
	if (
		int(ProjectSettings.get_setting("display/window/size/viewport_width", 0)) != 1280
		or int(ProjectSettings.get_setting("display/window/size/viewport_height", 0)) != 840
		or String(ProjectSettings.get_setting("display/window/stretch/mode", "")) != "canvas_items"
		or String(ProjectSettings.get_setting("display/window/stretch/aspect", "")) != "keep"
	):
		_fail("Viewport settings no longer match the HUD contract")
		return
	var preset := FileAccess.open("res://export_presets.cfg", FileAccess.READ)
	if preset == null:
		_fail("Windows export preset is missing")
		return
	var preset_text: String = preset.get_as_text()
	for required: String in [
		"Windows Desktop",
		"x86_64",
		ICON,
		"tests/*",
		"docs/*",
		"tools/*",
	]:
		if not preset_text.contains(required):
			_fail("Export preset is missing: %s" % required)
			return
	for script_path: String in [
		"res://scripts/safe_json_store.gd",
		"res://scripts/run_encounter_director.gd",
		"res://scripts/run_upgrade_service.gd",
		"res://scripts/run_flow_state.gd",
		"res://scripts/run_hud_builder.gd",
		"res://scripts/run_hud_presenter.gd",
		"res://scripts/event_catalog.gd",
		"res://scripts/run_continue_store.gd",
		"res://scripts/death_recap.gd",
		"res://scripts/run_tutorial.gd",
	]:
		if not ResourceLoader.exists(script_path):
			_fail("Release module is missing: %s" % script_path)
			return
	print("release_readiness_smoke: PASS")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
