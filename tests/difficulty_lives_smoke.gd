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

	var lives_label: Label = main.get_node("HUD/Lives") as Label
	var ability_bar: Control = main.get_node("HUD/AbilityBar") as Control
	var status_label: Label = main.get_node("HUD/CombatStatus") as Label
	var room_card: Panel = main.get_node("HUD/RoomCard") as Panel
	var status_card: Panel = main.get_node("HUD/StatusToast") as Panel
	var bottom_hud: Panel = main.get_node("HUD/BottomHUD") as Panel
	var vitals_panel: Panel = main.get_node("HUD/VitalsPanel") as Panel
	var ability_panel: Panel = main.get_node("HUD/AbilityPanel") as Panel
	var weapon_panel: Panel = main.get_node("HUD/WeaponPanel") as Panel
	var viewport_size: Vector2 = main.get_viewport_rect().size
	if (
		viewport_size != Vector2(1280.0, 840.0)
		or bottom_hud.position.y < 720.0
		or bottom_hud.position.y + bottom_hud.size.y > viewport_size.y
		or lives_label.position.y < 720.0
		or lives_label.position.y + lives_label.size.y > viewport_size.y
		or ability_bar.position.y < 720.0
		or room_card.position.x < 980.0
		or status_label.position.x > 100.0
		or status_label.position.y < 790.0
		or status_card.size.x > 380.0
		or vitals_panel.position.x >= ability_panel.position.x
		or ability_panel.position.x >= weapon_panel.position.x
	):
		_fail("Dedicated 1280x840 combat dock or its three-column layout was not aligned")
		return

	main.set("_selected_difficulty", 0)
	main.set("_current_room_index", 0)
	main.set("_current_encounter", 0)
	var easy_first_health: float = float(main.call(&"_get_difficulty_health_multiplier"))
	var easy_first_damage: float = float(main.call(&"_get_difficulty_damage_multiplier"))
	var easy_first_speed: float = float(main.call(&"_get_difficulty_speed_multiplier"))
	var easy_first_aggression: float = float(main.call(&"_get_difficulty_aggression_multiplier"))
	var easy_first_profile: Dictionary = main.call(&"get_current_combat_profile") as Dictionary
	main.set("_current_room_index", 19)
	var easy_final_health: float = float(main.call(&"_get_difficulty_health_multiplier"))
	var easy_final_damage: float = float(main.call(&"_get_difficulty_damage_multiplier"))
	var easy_final_speed: float = float(main.call(&"_get_difficulty_speed_multiplier"))
	var easy_final_aggression: float = float(main.call(&"_get_difficulty_aggression_multiplier"))
	main.set("_selected_difficulty", 2)
	var hard_final_health: float = float(main.call(&"_get_difficulty_health_multiplier"))
	var hard_final_damage: float = float(main.call(&"_get_difficulty_damage_multiplier"))
	var hard_final_speed: float = float(main.call(&"_get_difficulty_speed_multiplier"))
	var hard_final_aggression: float = float(main.call(&"_get_difficulty_aggression_multiplier"))
	var hard_final_profile: Dictionary = main.call(&"get_current_combat_profile") as Dictionary
	if (
		easy_first_health >= 1.0
		or easy_first_damage > 0.70
		or easy_first_speed > 0.90
		or easy_first_aggression > 0.65
		or easy_final_health <= easy_first_health
		or easy_final_damage <= easy_first_damage
		or easy_final_speed <= easy_first_speed
		or easy_final_aggression <= easy_first_aggression
		or hard_final_health <= easy_final_health
		or hard_final_damage <= easy_final_damage
		or hard_final_speed <= easy_final_speed
		or hard_final_aggression <= easy_final_aggression
		or hard_final_health > 1.45
		or hard_final_damage > 1.35
		or hard_final_speed > 1.15
	):
		_fail("Bounded difficulty scaling did not progress across twenty rooms")
		return
	var easy_behavior: Dictionary = easy_first_profile.get("behavior", {}) as Dictionary
	var hard_behavior: Dictionary = hard_final_profile.get("behavior", {}) as Dictionary
	if (
		int(easy_behavior.get("tier", -1)) != 0
		or int(easy_behavior.get("pursuit_level", -1)) != 0
		or int(easy_behavior.get("ranged_volley_count", 0)) != 1
		or float(easy_behavior.get("melee_combo_chance", 1.0)) > 0.0
		or int(hard_behavior.get("tier", -1)) != 5
		or int(hard_behavior.get("pursuit_level", 0)) != 2
		or int(hard_behavior.get("ranged_volley_count", 0)) != 3
		or float(hard_behavior.get("melee_combo_chance", 0.0)) <= 0.0
	):
		_fail("Difficulty did not unlock behavior tiers instead of relying on raw stats")
		return

	var easy_enemy := RogueEnemy.new()
	easy_enemy.setup(
		0,
		0.0,
		-100.0,
		100.0,
		RogueEnemy.EnemyRole.MELEE,
		RogueEnemy.EnemyRank.NORMAL,
		easy_first_health,
		easy_first_damage,
		RogueEnemy.EnemyFamily.GOBLIN,
		easy_first_speed,
		easy_first_aggression,
		easy_behavior
	)
	if (
		float(easy_enemy.call(&"_get_attack_cooldown")) < 2.0
		or float(easy_enemy.get("_attack_cooldown_remaining")) < 1.20
	):
		_fail("Easy mode behavior profile still attacks immediately or too frequently")
		return
	easy_enemy.queue_free()

	var enemy_count_before: int = (main.get("_enemies") as Array).size()
	main.call(
		&"_spawn_enemy",
		Vector2(420.0, 600.0),
		300.0,
		560.0,
		0,
		0,
		0
	)
	var scaled_enemies: Array = main.get("_enemies") as Array
	if scaled_enemies.size() != enemy_count_before + 1:
		_fail("Late-room enemy could not be spawned for scaling verification")
		return
	var scaled_enemy: RogueEnemy = scaled_enemies.back() as RogueEnemy
	var scaled_behavior: Dictionary = scaled_enemy.get_behavior_profile()
	if (
		scaled_enemy.get_max_health() <= 72
		or scaled_enemy.get_speed_multiplier() < hard_final_speed - 0.001
		or scaled_enemy.get_aggression_multiplier() < hard_final_aggression - 0.001
		or float(scaled_enemy.call(&"_get_attack_cooldown")) >= 0.95
		or int(scaled_enemy.call(&"_get_scaled_damage", 22)) <= 22
		or int(scaled_behavior.get("tier", -1)) != 5
		or int(scaled_behavior.get("pursuit_level", 0)) != 2
	):
		_fail("Main did not pass the bounded stats and late behavior tier into enemy AI")
		return

	main.set("_current_room_index", 0)
	var all_enemies: Array = main.get("_enemies") as Array
	for enemy_value in all_enemies:
		var enemy: RogueEnemy = enemy_value as RogueEnemy
		enemy.set_physics_process(false)
	for life_index in range(3):
		main.call(&"_on_player_died")
		await create_timer(1.15).timeout
		if life_index < 2 and int(main.get("_lives_remaining")) != 2 - life_index:
			_fail("A death did not consume exactly one life")
			return

	var entry_flow: Control = main.get_node("HUD/EntryFlow") as Control
	if int(main.get("_lives_remaining")) != 0 or not entry_flow.visible:
		_fail("Exhausting three lives did not return to difficulty selection")
		return

	main.queue_free()
	print("difficulty_lives_smoke: PASS")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
