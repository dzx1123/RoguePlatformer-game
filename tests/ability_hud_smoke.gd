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

	var attack_slot: Control = main.get_node("HUD/AbilityBar/AttackAbility") as Control
	var dash_slot: Control = main.get_node("HUD/AbilityBar/DashAbility") as Control
	var skill_slot: Control = main.get_node("HUD/AbilityBar/SkillAbility") as Control
	if attack_slot == null or dash_slot == null or skill_slot == null:
		_fail("The center ability HUD did not create J, K, and L combat icons")
		return
	if (
		not attack_slot.tooltip_text.contains("J")
		or not dash_slot.tooltip_text.contains("2.0")
		or not skill_slot.tooltip_text.contains("L")
	):
		_fail("Ability icons did not expose their hover descriptions")
		return
	var active_weapon_label: Label = main.get_node("HUD/WeaponPanel/WeaponSlot_0/Label") as Label
	var locked_weapon_label: Label = main.get_node("HUD/WeaponPanel/WeaponSlot_1/Label") as Label
	if not active_weapon_label.text.contains("装备中") or not locked_weapon_label.text.contains("未解锁"):
		_fail("The right weapon rack did not distinguish active and locked weapons")
		return

	var player: RoguePlayer = main.get_node("Player") as RoguePlayer
	player.call(&"_start_attack")
	if player.get_attack_cooldown_remaining() <= 0.0:
		_fail("Basic attack did not feed its cooldown into the J slot")
		return
	player.set("_attack_remaining", 0.0)
	player.set("_attack_cooldown_remaining", 0.0)
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
