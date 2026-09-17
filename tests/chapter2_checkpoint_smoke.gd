extends SceneTree

const STORE := preload("res://scripts/chapter2_continue_store.gd")
const PATH := "res://test_output/chapter2_checkpoint_test.json"

func _initialize() -> void:
	call_deferred("run_test")

func run_test() -> void:
	var store := STORE.new(PATH)
	store.clear_snapshot()
	var scene = load("res://scenes/Chapter2Journey.tscn").instantiate()
	scene.save_path = PATH
	root.add_child(scene)
	scene.set_physics_process(false)
	scene.player.set_physics_process(false)
	scene.player.configure_weapon(WeaponCatalog.TWIN_BLADES)
	scene.player.apply_run_upgrade(&"tempered_edge")
	scene.player.apply_max_health_delta(-10)
	scene.player.set_current_health(43)
	scene.gold = 52
	scene._save_checkpoint()
	assert(store.load_snapshot() and store.can_resume())
	assert(store.get_snapshot().health == 43 and store.get_snapshot().max_health == 90)
	scene.player.heal(50)
	scene.retry_room()
	assert(scene.player.get_current_health() == 43 and scene.player.get_max_health() == 90)
	assert(scene.player.get_weapon_id() == WeaponCatalog.TWIN_BLADES and scene.gold == 52)
	scene._load_layout(3, true)
	scene.player.position = scene.EXIT_POSITION
	assert(scene.try_exit() and scene.choose_ritual(true))
	assert(store.load_snapshot() and store.get_snapshot().room_index == 4 and store.get_snapshot().cooling_room == 25)
	scene.player._die(Vector2.ZERO, &"test")
	scene._physics_process(5)
	assert(scene.player.is_dead(), "Journey must await explicit retry")
	scene.retry_room()
	assert(scene.heat_disabled and scene.player.get_current_health() == 43)
	scene._load_layout(16, true)
	scene.player.position = scene.BRANCH_SIGN
	assert(scene.try_exit() and scene.choose_final_option(1))
	scene.queue_free()
	await process_frame
	# New scene simulates quitting and relaunching with actual JSON round-trip.
	scene = load("res://scenes/Chapter2Journey.tscn").instantiate()
	scene.save_path = PATH
	root.add_child(scene)
	scene.set_physics_process(false)
	scene.player.set_physics_process(false)
	assert(scene.room_index == 16 and scene.branch_choices[37] == 1)
	assert(scene.living_enemies().size() == 2 and scene.claimed.has(&"forge_24"))
	assert(scene.player.get_current_health() == 43 and scene.player.get_run_upgrade_count(&"tempered_edge") == 1)
	scene._load_layout(8, true)
	scene.player.position = scene.rooms[8].chest
	assert(scene.try_exit())
	var gold: int = scene.gold
	scene.retry_room()
	scene.player.position = scene.rooms[8].chest
	assert(not scene.try_exit() and scene.gold == gold)
	var invalid: Dictionary = scene.checkpoint.duplicate(true)
	invalid.room_index = 40
	assert(store.save_snapshot(invalid) == ERR_INVALID_DATA)
	invalid = scene.checkpoint.duplicate(true)
	invalid.version = 99
	assert(store.save_snapshot(invalid) == ERR_INVALID_DATA)
	scene._load_layout(19, true)
	scene.overseer.receive_player_attack(scene.overseer.position, 1, 9999)
	scene.overseer._physics_process(2)
	await process_frame
	scene.player.position = scene.EXIT_POSITION
	assert(scene.try_exit() and scene.route_complete)
	assert(store.load_snapshot() and not store.can_resume())
	assert(store.get_snapshot().completed)
	scene.queue_free()
	await process_frame
	store.clear_snapshot()
	print("chapter2_checkpoint_smoke: PASS")
	quit()
