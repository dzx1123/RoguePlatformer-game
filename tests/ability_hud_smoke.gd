extends SceneTree


func _initialize() -> void:
	call_deferred(&"_run_test")


func _run_test() -> void:
	var main_scene: PackedScene = load("res://scenes/Main.tscn")
	var main: Node2D = main_scene.instantiate() as Node2D
	main.set("save_enabled", false)
	root.add_child(main)
	for _settle_frame in range(12):
		await physics_frame

	var dash_slot: Control = main.get_node("HUD/AbilityBar/DashAbility") as Control
	var skill_slot: Control = main.get_node("HUD/AbilityBar/SkillAbility") as Control
	if dash_slot == null or skill_slot == null:
		_fail("The bottom ability HUD did not create both ability icons")
		return
	if not dash_slot.tooltip_text.contains("2.0") or not skill_slot.tooltip_text.contains("L"):
		_fail("Ability icons did not expose their hover descriptions")
		return

	var player: RoguePlayer = main.get_node("Player") as RoguePlayer
	player.call(&"_start_dash")
	if player.get_dash_cooldown_remaining() < 1.8:
		_fail("Dash did not start its two-second cooldown")
		return

	player.set("_dash_remaining", 0.0)
	player.call(&"_start_skill")
	if player.get_skill_cooldown_remaining() <= 0.0:
		_fail("Active skill did not start its cooldown")
		return

	main.queue_free()
	print("ability_hud_smoke: PASS")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
