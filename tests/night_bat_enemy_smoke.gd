extends SceneTree

const BAT_ASSET_PATHS: Array[String] = [
	"res://assets/enemies/night_bat_flap_mid.png",
	"res://assets/enemies/night_bat_flap_down.png",
	"res://assets/enemies/night_bat_flap_up.png",
	"res://assets/enemies/night_bat_tuck.png",
	"res://assets/enemies/night_bat_dive.png",
	"res://assets/enemies/night_bat_hang.png",
]


class DamageTarget extends Node2D:
	var hit_count: int = 0
	var last_damage: int = 0
	var last_cause: StringName = &""

	func is_dead() -> bool:
		return false

	func receive_enemy_attack(_origin: Vector2, damage: int, cause: StringName) -> void:
		hit_count += 1
		last_damage = damage
		last_cause = cause


func _initialize() -> void:
	call_deferred(&"_run_test")


func _run_test() -> void:
	for asset_path: String in BAT_ASSET_PATHS:
		var texture := load(asset_path) as Texture2D
		if texture == null or texture.get_width() <= 0 or texture.get_height() <= 0:
			_fail("Night bat frame could not be loaded: %s" % asset_path)
			return
		var png_bytes: PackedByteArray = FileAccess.get_file_as_bytes(asset_path)
		var image := Image.new()
		if image.load_png_from_buffer(png_bytes) != OK or image.is_empty():
			_fail("Night bat frame is not a readable PNG: %s" % asset_path)
			return
		if image.get_pixel(0, 0).a > 0.01:
			_fail("Night bat frame lost transparent padding: %s" % asset_path)
			return

	var bat := RogueEnemy.new()
	bat.position = Vector2(260.0, 170.0)
	bat.setup(
		0,
		0.0,
		120.0,
		520.0,
		RogueEnemy.EnemyRole.RANGED,
		RogueEnemy.EnemyRank.NORMAL,
		1.0,
		1.0,
		RogueEnemy.EnemyFamily.NIGHT_BAT,
		1.0,
		1.0,
		{},
		RogueEnemy.EnemyArchetype.STANDARD,
		true
	)
	root.add_child(bat)
	bat.set_physics_process(false)
	if (
		not bat.is_night_bat()
		or not bat.is_flying_enemy()
		or bat.get_archetype() != RogueEnemy.EnemyArchetype.FLYER
		or bat.collision_mask != 0
	):
		_fail("Night bat did not retain its forced melee-flight identity")
		return

	var sprite := bat.get_node("EnemySprite") as Sprite2D
	if sprite == null or sprite.region_enabled:
		_fail("Night bat did not use individual unfiltered animation frames")
		return
	if not bat.is_night_bat_hanging() or not sprite.texture.resource_path.ends_with("night_bat_hang.png"):
		_fail("Night bat did not begin in its fixed upside-down roost pose")
		return
	var hang_position: Vector2 = bat.global_position
	for frame_index in range(3):
		bat.set("_elapsed", 3.0 + float(frame_index))
		bat.call(&"_update_sprite_animation")
		if not sprite.texture.resource_path.ends_with("night_bat_hang.png"):
			_fail("Night bat incorrectly looped flap frames while no target was present")
			return
	if bat.global_position != hang_position:
		_fail("Night bat drifted away from its roost while idle")
		return

	var target := DamageTarget.new()
	target.position = Vector2(340.0, 355.0)
	root.add_child(target)
	bat.set_target(target)
	bat.call(&"_update_night_bat_awareness", 0.0)
	bat.call(&"_update_night_bat_awareness", RogueEnemy.NIGHT_BAT_TAKEOFF_DURATION + 0.02)
	if bat.is_night_bat_hanging():
		_fail("Night bat did not wake when a player entered detection range")
		return

	var flap_paths: Dictionary = {}
	for frame_index in range(4):
		bat.set("_elapsed", (float(frame_index) + 0.02) / RogueEnemy.NIGHT_BAT_FLAP_FPS)
		bat.call(&"_update_sprite_animation")
		var flight_path: String = sprite.texture.resource_path
		if (
			flight_path.ends_with("night_bat_hang.png")
			or flight_path.ends_with("night_bat_flap_down.png")
		):
			_fail("Night bat displayed an upside-down frame while flying")
			return
		flap_paths[flight_path] = true
	if flap_paths.size() != 2:
		_fail("Night bat hover loop was not restricted to its two flight poses")
		return

	var attack_duration: float = float(bat.call(&"_get_attack_duration"))
	bat.set("_attack_remaining", attack_duration * 0.90)
	bat.call(&"_update_sprite_animation")
	if not sprite.texture.resource_path.ends_with("night_bat_tuck.png"):
		_fail("Night bat windup did not select the tucked-wing pose")
		return
	bat.set("_attack_remaining", attack_duration * 0.55)
	bat.velocity = Vector2(320.0, 380.0)
	bat.call(&"_update_sprite_animation")
	if not sprite.texture.resource_path.ends_with("night_bat_dive.png"):
		_fail("Night bat dive did not select the authored attack pose")
		return

	bat.position = Vector2(260.0, 170.0)
	bat.velocity = Vector2.ZERO
	bat.set("_attack_remaining", 0.0)
	bat.set_target(target)
	if not bool(bat.call(&"_target_in_attack_range")):
		_fail("Night bat could not acquire a player below its hover position")
		return
	bat.call(&"_start_attack")
	bat.set_physics_process(true)
	var start_y: float = bat.global_position.y
	var minimum_y: float = start_y
	var maximum_y: float = start_y
	var dive_frame_seen: bool = false
	for _frame_index in range(86):
		await physics_frame
		if not is_instance_valid(bat):
			_fail("Night bat left the world during its dive sequence")
			return
		minimum_y = minf(minimum_y, bat.global_position.y)
		maximum_y = maxf(maximum_y, bat.global_position.y)
		dive_frame_seen = (
			dive_frame_seen
			or sprite.texture.resource_path.ends_with("night_bat_dive.png")
		)

	if minimum_y >= start_y - 4.0:
		_fail("Night bat dive skipped the readable upward windup")
		return
	if maximum_y <= start_y + 85.0:
		_fail("Night bat attack never descended toward the target")
		return
	if not dive_frame_seen:
		_fail("Night bat runtime sequence never displayed the dive frame")
		return
	if (
		target.hit_count != 1
		or target.last_damage <= 0
		or target.last_cause != &"night_bat_dive"
	):
		_fail(
			"Night bat dive damage was invalid (hits %d, damage %d, cause %s)"
			% [target.hit_count, target.last_damage, target.last_cause]
		)
		return

	target.position = Vector2(3200.0, 2400.0)
	for _frame_index in range(300):
		await physics_frame
		if not is_instance_valid(bat):
			_fail("Night bat left the world while returning to its roost")
			return
		if bat.is_night_bat_hanging():
			break
	if not bat.is_night_bat_hanging():
		_fail("Night bat did not return to its fixed upside-down roost after losing the player")
		return
	if bat.global_position.distance_to(hang_position) > 0.1:
		_fail("Night bat re-hung at a different position from its authored roost")
		return
	if not sprite.texture.resource_path.ends_with("night_bat_hang.png"):
		_fail("Night bat did not restore the upside-down pose after returning")
		return

	var main_script := load("res://scripts/main.gd") as Script
	var main := main_script.new() as Node2D
	var spawned_family: int = int(main.call(&"_get_enemy_family_for_spawn", 10, 2))
	var spawned_archetype: int = int(main.call(
		&"_get_enemy_archetype_for_spawn",
		10,
		2,
		0,
		0,
		spawned_family
	))
	main.queue_free()
	if spawned_family != RogueEnemy.EnemyFamily.NIGHT_BAT:
		_fail("Mixed chapters did not schedule the deterministic night bat slot")
		return
	if spawned_archetype != RogueEnemy.EnemyArchetype.FLYER:
		_fail("Night bat spawn did not receive flight movement")
		return

	bat.queue_free()
	target.queue_free()
	print("night_bat_enemy_smoke: PASS")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
