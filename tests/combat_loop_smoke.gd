extends SceneTree


func _initialize() -> void:
	call_deferred(&"_run_test")


func _run_test() -> void:
	var main_scene: PackedScene = load("res://scenes/Main.tscn")
	var main: Node2D = main_scene.instantiate() as Node2D
	main.set("save_enabled", false)
	root.add_child(main)
	var player: RoguePlayer = main.get_node("Player") as RoguePlayer
	for _settle_frame in range(24):
		await physics_frame

	var enemies: Array = main.get("_enemies") as Array
	var melee_enemy: RogueEnemy
	var ranged_enemy: RogueEnemy
	for enemy_value in enemies:
		var enemy: RogueEnemy = enemy_value as RogueEnemy
		enemy.set_physics_process(false)
		enemy.global_position = Vector2(1450.0, 590.0)
		if enemy.is_ranged_enemy() and ranged_enemy == null:
			ranged_enemy = enemy
		elif not enemy.is_ranged_enemy() and melee_enemy == null:
			melee_enemy = enemy
	if melee_enemy == null or ranged_enemy == null:
		_fail("Initial enemy group did not contain both melee and ranged roles")
		return
	var room_surfaces: Array = main.get("platform_rects") as Array
	var test_surface: Rect2 = room_surfaces[0]
	for surface_value in room_surfaces:
		var surface: Rect2 = surface_value
		if surface.size.x > test_surface.size.x:
			test_surface = surface
	var player_x: float = test_surface.position.x + test_surface.size.x * 0.25
	var ranged_offset: float = minf(260.0, test_surface.size.x * 0.50)
	player.global_position = Vector2(player_x, test_surface.position.y - 60.0)
	player.velocity = Vector2.ZERO

	melee_enemy.global_position = player.global_position + Vector2(72.0, 0.0)
	var melee_health_before: int = melee_enemy.get_current_health()
	var first_enemy_hit: bool = melee_enemy.receive_player_attack(
		player.global_position,
		1.0,
		player.get_attack_damage()
	)
	if not first_enemy_hit:
		_fail("Melee enemy hurtbox rejected a valid player attack")
		return
	if melee_enemy.get_current_health() >= melee_health_before:
		_fail("Melee enemy health did not decrease after a valid attack")
		return
	var health_after_first_hit: int = melee_enemy.get_current_health()
	var repeated_enemy_hit: bool = melee_enemy.receive_player_attack(
		player.global_position,
		1.0,
		player.get_attack_damage()
	)
	if repeated_enemy_hit or melee_enemy.get_current_health() != health_after_first_hit:
		_fail("Enemy hurt invulnerability did not reject an immediate repeated hit")
		return

	player.set("_hurt_invulnerability_remaining", 0.0)
	var player_health_before: int = player.get_current_health()
	var player_was_hit: bool = player.receive_enemy_attack(
		player.global_position + Vector2(40.0, 0.0),
		20
	)
	if not player_was_hit or player.get_current_health() != player_health_before - 20:
		_fail("Player damage did not reduce health by the expected amount")
		return
	var player_health_after_hit: int = player.get_current_health()
	var repeated_player_hit: bool = player.receive_enemy_attack(
		player.global_position + Vector2(40.0, 0.0),
		20
	)
	if repeated_player_hit or player.get_current_health() != player_health_after_hit:
		_fail("Player invulnerability did not reject an immediate repeated hit")
		return

	player.set("_hurt_invulnerability_remaining", 0.0)
	ranged_enemy.global_position = player.global_position + Vector2(ranged_offset, 0.0)
	ranged_enemy.velocity = Vector2.ZERO
	ranged_enemy.set("_attack_remaining", 0.0)
	ranged_enemy.set("_attack_cooldown_remaining", 0.0)
	ranged_enemy.set_physics_process(true)
	var player_health_before_ranged: int = player.get_current_health()
	var maximum_projectile_count: int = 0
	var ranged_damage_observed: bool = false
	for _ranged_attack_frame in range(150):
		await physics_frame
		var active_projectiles: Array = main.get("_projectiles") as Array
		maximum_projectile_count = maxi(maximum_projectile_count, active_projectiles.size())
		if player.get_current_health() < player_health_before_ranged:
			ranged_damage_observed = true
			break
	if maximum_projectile_count <= 0:
		_fail("Ranged enemy never created a projectile")
		return
	if not ranged_damage_observed:
		_fail("Ranged projectile did not damage the player")
		return

	ranged_enemy.set_physics_process(false)
	player.set("_hurt_invulnerability_remaining", 0.0)
	var run_generation_before_death: int = int(main.get("_run_generation"))
	player.receive_enemy_attack(player.global_position + Vector2(40.0, 0.0), 999)
	if not player.is_dead() or player.get_current_health() != 0:
		_fail("Lethal damage did not enter the player death state")
		return
	for _restart_frame in range(80):
		await physics_frame
	if player.is_dead() or player.get_current_health() != player.get_max_health():
		_fail("Player did not recover full health after the run restart")
		return
	if int(main.get("_run_generation")) <= run_generation_before_death:
		_fail("Player death did not start a fresh run")
		return

	main.queue_free()
	print("combat_loop_smoke: PASS")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
