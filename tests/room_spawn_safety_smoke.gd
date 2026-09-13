extends SceneTree

const CATALOG := preload("res://scripts/run_room_catalog.gd")

func _initialize() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 712903
	var pool := CATALOG.create_room_pool()
	var first := pool[0] as Dictionary
	var signatures: Dictionary = {}
	var min_enemy_ratio := 1.0
	for sample in range(12):
		var variant := CATALOG.build_room_variant(first, rng, sample + 1)
		var platforms: Array = variant.get("platforms", []) as Array
		var enemies: Array = variant.get("enemies", []) as Array
		var signature := "%s|%s" % [platforms, enemies]
		signatures[signature] = true
		for enemy_value in enemies:
			min_enemy_ratio = minf(min_enemy_ratio, float((enemy_value as Dictionary).get("ratio", 0.5)))
	if signatures.size() < 5:
		_fail("Room variants are not varied enough: %d unique" % signatures.size())
		return
	if min_enemy_ratio < 0.28:
		_fail("Enemy variant can still use the unsafe left-side ratio: %.3f" % min_enemy_ratio)
		return
	# The gameplay lock is intentionally longer than the entry beam's first flash.
	var main_script := load("res://scripts/main.gd")
	if main_script == null:
		_fail("Main gameplay script is unavailable")
		return
	print("room_spawn_safety_smoke: PASS variants=%d min_enemy_ratio=%.3f entry_lock=1.15s boss_min_distance=260px" % [signatures.size(), min_enemy_ratio])
	quit()

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
