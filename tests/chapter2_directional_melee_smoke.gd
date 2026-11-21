extends SceneTree


class HitCounter extends Node2D:
	var hits := 0
	var damage := 0

	func receive_enemy_attack(_origin: Vector2, amount: int, _cause: StringName) -> bool:
		hits += 1
		damage += amount
		return true


func _initialize() -> void:
	call_deferred("run_test")


func run_test() -> void:
	var room = load("res://scenes/Chapter2Journey.tscn").instantiate()
	room.persistence_enabled = false
	root.add_child(room)
	room.set_physics_process(false)

	room._load_layout(8)
	if room.living_enemies().size() != 2 or not directional_melees(room).is_empty():
		fail("Room 29 must retain its existing melee behavior")
		return

	room._load_layout(9)
	room.player.set_physics_process(false)
	var slimes := directional_melees(room)
	if room.living_enemies().size() != 2 or slimes.size() != 1:
		fail("Room 30 wave one must have one directional melee slime")
		return
	if not check_directional_melee(room, slimes[0], "Room 30 wave one"):
		return
	for enemy: RogueEnemy in room.living_enemies():
		enemy.defeat()
		enemy._physics_process(RogueEnemy.DEATH_ANIMATION_DURATION + 0.1)
	room._physics_process(1.0 / 60.0)
	if room.wave_delay != room.WAVE_WARNING_SECONDS or not room.living_enemies().is_empty():
		fail("Room 30 must announce the second wave before it spawns")
		return
	for tick in range(90):
		room._physics_process(1.0 / 60.0)
		if room.next_wave == 1:
			break
	slimes = directional_melees(room)
	if room.next_wave != 1 or room.living_enemies().size() != 2 or slimes.size() != 1:
		fail("Room 30 wave two must spawn one directional slime alongside the guard")
		return
	if not check_directional_melee(room, slimes[0], "Room 30 wave two"):
		return

	room._load_layout(15)
	slimes = directional_melees(room)
	if slimes.size() != 2:
		fail("Room 36 must enable the directional windup for both melee slimes")
		return
	for slime: RogueEnemy in slimes:
		if not check_directional_melee(room, slime, "Room 36"):
			return

	room.queue_free()
	await process_frame
	print("chapter2_directional_melee_smoke: PASS")
	quit()


func directional_melees(room: Node) -> Array[RogueEnemy]:
	var result: Array[RogueEnemy] = []
	for enemy: RogueEnemy in room.living_enemies():
		if enemy.directional_melee:
			result.append(enemy)
	return result


func check_directional_melee(room: Node, melee: RogueEnemy, encounter: String) -> bool:
	if melee.directional_melee_floor_y != room.platforms[0].position.y:
		return fail(encounter + ": the warning must use the room's base floor as its visual limit")

	var target := HitCounter.new()
	room.add_child(target)
	melee.set_target(target)
	for facing: float in [1.0, -1.0]:
		var origin := Vector2(660.0, 598.0)
		melee.global_position = origin
		for offset: Vector2 in [
			Vector2(facing * 80.0, 0.0),
			Vector2(-facing * 40.0, 0.0),
			Vector2(facing * 110.0, 0.0),
			Vector2(facing * 80.0, -70.0),
		]:
			target.global_position = origin + Vector2(facing * 70.0, 0.0)
			melee._attack_remaining = 0.0
			melee._attack_cooldown_remaining = 0.0
			melee.velocity = Vector2.ZERO
			melee._physics_process(1.0 / 60.0)
			if melee._attack_remaining <= 0.0 or melee._facing != facing:
				return fail(encounter + ": the attack must trigger and commit to the side on which it started")
			var hits_before := target.hits
			for tick in range(17):
				melee._physics_process(1.0 / 60.0)
			if target.hits != hits_before or melee._attack_action_performed:
				return fail(encounter + ": the enemy applied damage before giving the full warning")

			target.global_position = melee.global_position + offset
			var expected_hit := melee.get_directional_melee_bounds().has_point(offset)
			var expected_front_hit := offset == Vector2(facing * 80.0, 0.0)
			if expected_hit != expected_front_hit:
				return fail(encounter + ": the drawn strike bounds do not match the authored front reach")
			for tick in range(4):
				melee._physics_process(1.0 / 60.0)
			if melee._facing != facing or not melee._attack_action_performed:
				return fail(encounter + ": impact must retain the warning's facing and finish its attack tick")
			if target.hits != hits_before + int(expected_hit):
				return fail("%s: impact did not match the visible strike bounds for offset %s" % [encounter, offset])

	if target.damage != RogueEnemy.MELEE_DAMAGE * 2:
		return fail(encounter + ": both front strikes must deal ordinary melee damage")
	target.queue_free()
	return true


func fail(message: String) -> bool:
	push_error(message)
	quit(1)
	return false
