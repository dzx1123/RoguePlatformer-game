extends SceneTree

const SETTINGS_STORE := preload("res://scripts/settings_store.gd")
const SAVE_PATH := "res://tests/accessibility_settings_smoke_temp.json"


func _initialize() -> void:
	call_deferred(&"_run_test")


func _run_test() -> void:
	_cleanup()
	var settings = SETTINGS_STORE.new(SAVE_PATH)
	settings.set_reduced_effects_enabled(true)
	var main_scene: PackedScene = load("res://scenes/Main.tscn")
	var main: Node2D = main_scene.instantiate() as Node2D
	main.set("save_enabled", false)
	root.add_child(main)
	await physics_frame
	main.set("_settings", settings)
	var player: RoguePlayer = main.get_node("Player") as RoguePlayer
	player.set_reduced_effects_enabled(true)
	main.set("_camera_shake_strength", 0.0)
	main.set("_camera_shake_duration", 0.0)
	main.call(&"_trigger_camera_shake", 8.0, 0.20)
	if (
		float(main.get("_camera_shake_strength")) > 2.01
		or float(main.get("_camera_shake_duration")) > 0.141
		or not player.get_reduced_effects_enabled()
	):
		return _fail("Reduced-effects mode did not limit shake and player flashes")
	main.queue_free()
	await process_frame
	_cleanup()
	print("accessibility_settings_smoke: PASS")
	quit(0)


func _cleanup() -> void:
	for path: String in [SAVE_PATH, SAVE_PATH + ".tmp", SAVE_PATH + ".bak"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _fail(message: String) -> void:
	_cleanup()
	push_error(message)
	quit(1)
