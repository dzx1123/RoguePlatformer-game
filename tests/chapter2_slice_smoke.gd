extends SceneTree

func _initialize() -> void:
	call_deferred("run_test")

func clear_room(scene: Node) -> void:
	for enemy in scene.living_enemies():
		enemy.receive_player_attack(enemy.position, 1.0, 9999)
		assert(enemy.get_current_health() == 0)
		enemy._physics_process(2.0)
	await process_frame
	assert(scene.living_enemies().is_empty())

func exit_room(scene: Node) -> void:
	scene.player.position = scene.EXIT_POSITION
	assert(scene.try_exit())
	scene.player.set_physics_process(false)

func run_test() -> void:
	var catalog = load("res://scripts/chapter2_slice_catalog.gd")
	assert(catalog.validate(catalog.rooms()).is_empty())
	var bad: Array[Dictionary] = catalog.rooms()
	bad[1].id = bad[0].id
	bad[1].layout = &"missing"
	bad[0].enemies = [{"kind": &"ember_caster"}]
	assert(catalog.validate(bad).size() == 3)
	var scene = load("res://scenes/Chapter2Slice.tscn").instantiate()
	root.add_child(scene)
	scene.set_physics_process(false)
	scene.player.set_physics_process(false)
	assert(scene.room_index == 0 and scene.living_enemies().is_empty())
	assert(not scene.try_exit(), "Cannot exit from spawn")
	scene.player.position = Vector2(640, 590)
	scene.elapsed = 2.5
	var initial_health: int = scene.player.get_current_health()
	scene._physics_process(0.01)
	assert(scene.heat_is_active() and scene.player.get_current_health() == initial_health, "Entrance demo must be harmless")
	exit_room(scene)
	assert(scene.room_index == 1 and scene.living_enemies().size() == 2)
	scene.player.position = scene.EXIT_POSITION
	assert(not scene.try_exit(), "Combat blocks exit")
	await clear_room(scene)
	var reward: int = scene.room_gold
	exit_room(scene)
	assert(scene.gold == reward and scene.room_index == 2)
	assert(is_instance_valid(scene.caster) and scene.living_enemies().size() == 1)
	scene._spawn_ember()
	assert(scene.embers.get_child_count() == 0, "Caster cannot target spawn")
	scene.player.position = Vector2(750, 580)
	scene._spawn_ember()
	assert(scene.embers.get_child_count() == 1)
	scene.paused = true
	var elapsed_before: float = scene.elapsed
	scene._physics_process(2)
	assert(scene.elapsed == elapsed_before)
	scene.paused = false
	await clear_room(scene)
	scene.player.apply_event_cost(45)
	var damaged_health: int = scene.player.get_current_health()
	exit_room(scene)
	assert(scene.room_index == 3 and scene.player.get_current_health() == damaged_health)
	assert(scene.living_enemies().is_empty() and scene.heat_zones.is_empty())
	exit_room(scene)
	assert(scene.ritual_open)
	assert(scene.ritual_panel.visible and scene.ritual_panel.get_child(0).get_child_count() == 3)
	scene.paused = true
	assert(not scene.choose_ritual(false))
	scene.paused = false
	assert(scene.choose_ritual(false))
	assert(scene.player.get_current_health() == damaged_health + 25)
	assert(scene.room_index == 4 and not scene.heat_disabled)
	assert(not scene.choose_ritual(true))
	assert(scene.living_enemies().size() == 3)
	await clear_room(scene)
	exit_room(scene)
	assert(scene.ritual_open and not scene.route_complete)
	var damage: int = scene.player.get_attack_damage()
	assert(scene.choose_upgrade(&"tempered_edge"))
	assert(scene.route_complete and scene.player.get_attack_damage() == damage + 8)
	assert(not scene.choose_upgrade(&"vitality_rune"))
	assert(not scene.try_exit())
	scene.restart_slice()
	assert(scene.gold == 0 and scene.claimed.is_empty() and scene.player.get_attack_damage() == damage)
	scene._load_layout(3)
	exit_room(scene)
	assert(scene.choose_ritual(true))
	assert(scene.heat_disabled and scene.cooling_room == 25)
	scene.player.position = Vector2(750, 580)
	scene._spawn_ember()
	assert(scene.embers.get_child_count() == 1, "Cooling does not stop enemy projectiles")
	var old_caster: int = scene.caster.get_instance_id()
	scene.player._die(Vector2.ZERO, &"test")
	scene.paused = true
	scene._physics_process(2)
	assert(scene.player.is_dead())
	scene.paused = false
	scene._physics_process(1.1)
	assert(not scene.player.is_dead() and scene.heat_disabled)
	assert(scene.caster.get_instance_id() != old_caster and scene.embers.get_child_count() == 0)
	assert(scene.living_enemies().size() == 3 and scene.cycle == 0)
	await clear_room(scene)
	exit_room(scene)
	assert(scene.choose_upgrade(&"vitality_rune"))
	assert(scene.cooling_room == -1 and not scene.heat_disabled)
	# Revisiting a settled room cannot pay it again, even after retry.
	scene.restart_slice()
	scene._load_layout(1)
	await clear_room(scene)
	exit_room(scene)
	var settled_gold: int = scene.gold
	scene._load_layout(1)
	scene.retry_room()
	await clear_room(scene)
	exit_room(scene)
	assert(scene.gold == settled_gold)
	var key := InputEventKey.new()
	key.keycode = KEY_H
	key.pressed = true
	var hints_before: bool = scene.tutorial_enabled
	scene._unhandled_key_input(key)
	assert(scene.tutorial_enabled != hints_before)
	scene.queue_free()
	await process_frame
	print("chapter2_slice_smoke: PASS")
	quit()
