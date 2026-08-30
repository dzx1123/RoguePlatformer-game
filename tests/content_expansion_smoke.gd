extends SceneTree

var _skill_hit_count: int = 0
var _last_skill_damage: int = 0
var _last_skill_reach: float = 0.0
var _temporary_save_path := "res://tests/progression_store_test.json"


func _initialize() -> void:
	call_deferred(&"_run_test")


func _run_test() -> void:
	_remove_temporary_save()
	var main_scene: PackedScene = load("res://scenes/Main.tscn")
	var main: Node2D = main_scene.instantiate() as Node2D
	main.set("save_enabled", false)
	root.add_child(main)
	var player: RoguePlayer = main.get_node("Player") as RoguePlayer
	player.skill_hit.connect(_on_skill_hit)
	await _wait_physics_frames(12)

	_disable_enemies(main)
	var sword_damage: int = player.get_attack_damage()
	var sword_cooldown: float = player.attack_cooldown_duration
	if not player.configure_weapon(WeaponCatalog.TWIN_BLADES):
		_fail("Twin blades could not be equipped")
		return
	if player.get_attack_damage() >= sword_damage or player.attack_cooldown_duration >= sword_cooldown:
		_fail("Twin blades did not trade damage for faster attacks")
		return
	if not player.configure_weapon(WeaponCatalog.GREATSWORD):
		_fail("Greatsword could not be equipped")
		return
	if player.get_attack_damage() <= sword_damage or player.get_attack_reach() <= 1.0:
		_fail("Greatsword did not gain damage and reach")
		return
	player.configure_weapon(WeaponCatalog.SWORD)

	Input.action_press(&"skill")
	await physics_frame
	Input.action_release(&"skill")
	await _wait_physics_frames(38)
	if _skill_hit_count != 1:
		_fail("One skill input emitted %d skill hits instead of one" % _skill_hit_count)
		return
	if _last_skill_damage <= player.get_attack_damage() or _last_skill_reach <= player.get_attack_reach():
		_fail("Active skill did not improve damage and reach over the normal attack")
		return
	if player.get_skill_cooldown_remaining() <= 0.0:
		_fail("Active skill did not enter cooldown")
		return

	if String(main.call(&"get_current_encounter_name")) != "战斗房":
		_fail("First room was not a normal combat encounter")
		return
	_defeat_current_room(main)
	await _wait_physics_frames(32)
	main.call(&"choose_upgrade", 0)
	await _wait_physics_frames(5)
	if String(main.call(&"get_current_encounter_name")) != "宝藏房":
		_fail("Second room was not a treasure encounter")
		return
	var gold_before_treasure: int = int(main.call(&"get_gold"))
	_defeat_current_room(main)
	await _wait_physics_frames(32)
	if not bool(main.call(&"is_awaiting_chest")):
		_fail("Treasure room did not spawn a reward chest")
		return
	if not bool(main.call(&"open_current_chest_for_test")):
		_fail("Reward chest could not be opened")
		return
	await _wait_physics_frames(5)
	if int(main.call(&"get_gold")) < gold_before_treasure + 24:
		_fail("Reward chest did not add its gold reward")
		return
	if not bool(main.call(&"is_choosing_upgrade")):
		_fail("Opening the chest did not continue to the room upgrade")
		return
	main.call(&"choose_upgrade", 0)
	await _wait_physics_frames(5)

	if String(main.call(&"get_current_encounter_name")) != "精英房":
		_fail("Third room was not an elite encounter")
		return
	var elite_count: int = 0
	var elite_enemies: Array = main.get("_enemies") as Array
	for enemy_value in elite_enemies:
		var enemy: RogueEnemy = enemy_value as RogueEnemy
		if enemy.is_elite():
			elite_count += 1
			if enemy.get_max_health() <= 72:
				_fail("Elite enemy did not receive increased health")
				return
	if elite_count < 2:
		_fail("Elite room spawned fewer than two elite enemies")
		return
	_defeat_current_room(main)
	await _wait_physics_frames(32)
	main.call(&"choose_upgrade", 0)
	await _wait_physics_frames(5)

	if not bool(main.call(&"is_shopping")):
		_fail("Fourth room did not open the shop")
		return
	var shop_choices: Array[Dictionary] = main.call(&"get_upgrade_choices") as Array[Dictionary]
	if shop_choices.size() != 3:
		_fail("Shop did not provide three offers")
		return
	var shop_cost: int = int(shop_choices[0].get("cost", 0))
	var gold_before_shop: int = int(main.call(&"get_gold"))
	if not bool(main.call(&"choose_upgrade", 0)):
		_fail("Affordable shop purchase was rejected")
		return
	await _wait_physics_frames(5)
	if int(main.call(&"get_gold")) != gold_before_shop - shop_cost:
		_fail("Shop purchase did not deduct the displayed price")
		return

	if String(main.call(&"get_current_encounter_name")) != "首领房":
		_fail("Fifth room was not the boss encounter")
		return
	var boss_enemies: Array = main.get("_enemies") as Array
	if boss_enemies.size() != 1:
		_fail("Boss room did not contain exactly one boss")
		return
	var boss: RogueEnemy = boss_enemies[0] as RogueEnemy
	if not boss.is_boss() or boss.get_max_health() < 400:
		_fail("Boss rank or boss health was not configured")
		return
	if boss.get_enemy_family() != RogueEnemy.EnemyFamily.SLIME:
		_fail("The first chapter boss was not the slime king")
		return
	boss.defeat()
	await _wait_physics_frames(36)
	if bool(main.call(&"is_run_complete")) or not bool(main.call(&"is_choosing_upgrade")):
		_fail("The first chapter boss incorrectly ended the ten-room run")
		return
	if not bool(main.call(&"choose_upgrade", 0)):
		_fail("The transition upgrade after the slime chapter was rejected")
		return
	await _wait_physics_frames(6)
	if int(main.call(&"get_current_room_number")) != 6:
		_fail("The second chapter did not begin in room six")
		return
	var goblin_enemies: Array = main.get("_enemies") as Array
	if goblin_enemies.is_empty():
		_fail("The goblin chapter spawned no enemies")
		return
	for enemy_value in goblin_enemies:
		var goblin := enemy_value as RogueEnemy
		if goblin.get_enemy_family() != RogueEnemy.EnemyFamily.GOBLIN:
			_fail("Room six still contained a slime enemy")
			return

	for room_number in range(6, 11):
		if room_number == 10:
			var final_enemies: Array = main.get("_enemies") as Array
			if final_enemies.size() != 1:
				_fail("Goblin chief room did not contain exactly one boss")
				return
			var goblin_chief := final_enemies[0] as RogueEnemy
			var chief_sprite := goblin_chief.get_node("EnemySprite") as Sprite2D
			if (
				not goblin_chief.is_boss()
				or goblin_chief.get_enemy_family() != RogueEnemy.EnemyFamily.GOBLIN
				or not chief_sprite.texture.resource_path.ends_with("red_fang_goblin_elite_sheet.png")
			):
				_fail("The final boss did not use the elite Red Fang design")
				return
		_defeat_current_room(main)
		await _wait_physics_frames(36)
		if bool(main.call(&"is_awaiting_chest")):
			main.call(&"open_current_chest_for_test")
			await _wait_physics_frames(5)
		if room_number < 10:
			if bool(main.call(&"is_shopping")):
				main.call(&"_leave_shop")
			elif not bool(main.call(&"choose_upgrade", 0)):
				_fail("Goblin chapter room %d did not advance" % room_number)
				return
			await _wait_physics_frames(5)

	if not bool(main.call(&"is_run_complete")):
		_fail("Defeating the goblin chief did not complete the run")
		return
	var in_memory_progress: Dictionary = main.call(&"get_progression_snapshot") as Dictionary
	if int(in_memory_progress.get("runs_completed", 0)) != 1:
		_fail("Victory did not update meta progression")
		return
	var in_memory_unlocks: Array = in_memory_progress.get("unlocked_weapons", []) as Array
	if not in_memory_unlocks.has(WeaponCatalog.TWIN_BLADES):
		_fail("Victory rewards did not unlock the twin blades")
		return

	if not _verify_save_round_trip():
		return
	_remove_temporary_save()
	main.queue_free()
	print("content_expansion_smoke: PASS")
	quit(0)


func _verify_save_round_trip() -> bool:
	var store := ProgressionStore.new(_temporary_save_path)
	var first_unlocks: Array[StringName] = store.bank_run(6, true)
	if not first_unlocks.has(WeaponCatalog.TWIN_BLADES):
		_fail("Shard threshold did not unlock twin blades")
		return false
	store.bank_run(0, true)
	if not store.select_weapon(WeaponCatalog.GREATSWORD):
		_fail("Second victory did not unlock the greatsword")
		return false
	var save_error: Error = store.save_progress()
	if save_error != OK:
		_fail("Progression save returned %s" % error_string(save_error))
		return false

	var loaded_store := ProgressionStore.new(_temporary_save_path)
	if not loaded_store.load_progress():
		_fail("Saved progression could not be loaded")
		return false
	if loaded_store.get_meta_shards() != 6 or loaded_store.get_runs_completed() != 2:
		_fail("Loaded progression values did not match saved values")
		return false
	if loaded_store.get_selected_weapon() != WeaponCatalog.GREATSWORD:
		_fail("Selected weapon was not restored from save")
		return false
	return true


func _on_skill_hit(_origin: Vector2, _facing: float, damage: int, reach: float) -> void:
	_skill_hit_count += 1
	_last_skill_damage = damage
	_last_skill_reach = reach


func _defeat_current_room(main: Node2D) -> void:
	var enemies: Array = (main.get("_enemies") as Array).duplicate()
	for enemy_value in enemies:
		var enemy: RogueEnemy = enemy_value as RogueEnemy
		if is_instance_valid(enemy):
			enemy.defeat()


func _disable_enemies(main: Node2D) -> void:
	var enemies: Array = main.get("_enemies") as Array
	for enemy_value in enemies:
		var enemy: RogueEnemy = enemy_value as RogueEnemy
		enemy.set_physics_process(false)


func _wait_physics_frames(frame_count: int) -> void:
	for _frame_index in range(frame_count):
		await physics_frame


func _remove_temporary_save() -> void:
	var absolute_path: String = ProjectSettings.globalize_path(_temporary_save_path)
	if FileAccess.file_exists(_temporary_save_path):
		DirAccess.remove_absolute(absolute_path)


func _fail(message: String) -> void:
	_remove_temporary_save()
	push_error(message)
	quit(1)
