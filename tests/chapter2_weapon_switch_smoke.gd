extends SceneTree

func _initialize() -> void:
	call_deferred("run_test")

func press_switch() -> void:
	Input.action_press(&"cycle_weapon")
	await process_frame
	await process_frame
	Input.action_release(&"cycle_weapon")
	await process_frame

func run_test() -> void:
	var scene = load("res://scenes/Chapter2Journey.tscn").instantiate()
	scene.persistence_enabled = false
	root.add_child(scene)
	await create_timer(1.8).timeout
	assert(scene.campaign_hud.get_node("WeaponPanel/WeaponSwitch").visible)
	scene.player.configure_weapon(WeaponCatalog.TWIN_BLADES)
	var seen: Array[StringName] = []
	for index in range(3):
		await press_switch()
		seen.append(scene.player.get_weapon_id())
		assert(scene.checkpoint.weapon_id == str(scene.player.get_weapon_id()))
	for weapon in WeaponCatalog.all_weapon_ids():
		assert(seen.has(weapon))
	scene._toggle_pause()
	var before: StringName = scene.player.get_weapon_id()
	await press_switch()
	assert(scene.player.get_weapon_id() == before)
	scene._toggle_pause()
	# Formal campaign availability must remain restricted to actual unlocks.
	scene.campaign = {"seed": 1, "difficulty": 1, "lives": 3, "run_shards": 0, "run_number": 1}
	scene.campaign_runtime.telemetry = RunTelemetry.new()
	var unlocked: Array[StringName] = [WeaponCatalog.SWORD]
	scene.campaign_runtime.progression._unlocked_weapons = unlocked
	scene.player.configure_weapon(WeaponCatalog.SWORD)
	await press_switch()
	assert(scene.player.get_weapon_id() == WeaponCatalog.SWORD)
	scene.queue_free()
	await process_frame
	print("chapter2_weapon_switch_smoke: PASS")
	quit()
