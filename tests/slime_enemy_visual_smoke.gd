extends SceneTree

var _death_signal_seen: bool = false


func _initialize() -> void:
	call_deferred(&"_run_test")


func _run_test() -> void:
	var asset_paths: Array[String] = [
		"res://assets/enemies/red_crystal_slime_melee_sheet.png",
		"res://assets/enemies/red_crystal_slime_ranged_sheet.png",
		"res://assets/enemies/red_crystal_slime_boss_sheet.png",
	]
	for asset_path in asset_paths:
		var texture := load(asset_path) as Texture2D
		var image := texture.get_image() if texture != null else Image.new()
		if image.is_empty() or image.get_pixel(0, 0).a > 0.01:
			_fail("Enemy sprite sheet is missing real alpha transparency: %s" % asset_path)
			return

	var melee := RogueEnemy.new()
	melee.setup(0, 0.0, -100.0, 100.0, RogueEnemy.EnemyRole.MELEE)
	root.add_child(melee)
	await physics_frame
	var melee_sprite := melee.get_node("EnemySprite") as Sprite2D
	if not melee_sprite.texture.resource_path.ends_with("red_crystal_slime_melee_sheet.png"):
		_fail("Melee slime did not use the melee sprite sheet")
		return
	if not is_equal_approx(melee_sprite.position.y, -15.0):
		_fail("Melee slime sprite baseline was not aligned to its platform collider")
		return
	var cell_height: float = float(melee_sprite.texture.get_height()) / 4.0

	melee.velocity.x = 120.0
	melee.call(&"_update_sprite_animation")
	if not is_equal_approx(melee_sprite.region_rect.position.y, cell_height):
		_fail("Melee slime movement did not select the movement row")
		return
	melee.call(&"_start_attack")
	melee.call(&"_update_sprite_animation")
	if not is_equal_approx(melee_sprite.region_rect.position.y, cell_height * 2.0):
		_fail("Melee slime attack did not select the bite row")
		return
	melee.set("_attack_remaining", 0.0)
	melee.set("_hurt_remaining", 0.12)
	melee.call(&"_update_sprite_animation")
	if not is_equal_approx(melee_sprite.region_rect.position.y, cell_height * 3.0):
		_fail("Melee slime hurt state did not select the reaction row")
		return

	var ranged := RogueEnemy.new()
	ranged.setup(1, 0.0, -100.0, 100.0, RogueEnemy.EnemyRole.RANGED)
	root.add_child(ranged)
	await physics_frame
	var ranged_sprite := ranged.get_node("EnemySprite") as Sprite2D
	if not ranged_sprite.texture.resource_path.ends_with("red_crystal_slime_ranged_sheet.png"):
		_fail("Ranged slime did not use the ranged sprite sheet")
		return
	if not is_equal_approx(ranged_sprite.position.y, -17.0):
		_fail("Ranged slime sprite baseline was not aligned to its platform collider")
		return

	var boss := RogueEnemy.new()
	boss.setup(
		0,
		0.0,
		-100.0,
		100.0,
		RogueEnemy.EnemyRole.MELEE,
		RogueEnemy.EnemyRank.BOSS
	)
	root.add_child(boss)
	await physics_frame
	var boss_sprite := boss.get_node("EnemySprite") as Sprite2D
	if not boss_sprite.texture.resource_path.ends_with("red_crystal_slime_boss_sheet.png"):
		_fail("Slime boss did not use the boss sprite sheet")
		return
	if boss_sprite.scale.x < 0.58 or boss_sprite.scale.x < melee_sprite.scale.x * 1.8:
		_fail("Slime boss was not enlarged enough to read as a room boss")
		return
	if boss.get_hurtbox_rect().size.x < 140.0:
		_fail("Enlarged slime boss did not receive a matching hurtbox")
		return
	if not is_equal_approx(boss_sprite.position.y, -30.0):
		_fail("Slime boss sprite baseline was not aligned to its platform collider")
		return

	melee.defeated.connect(_on_death_signal)
	melee.defeat()
	melee.call(&"_update_sprite_animation")
	if not is_equal_approx(melee_sprite.region_rect.position.y, cell_height * 3.0):
		_fail("Slime death did not select the dissolve row")
		return
	for _frame in range(34):
		await physics_frame
	if not _death_signal_seen:
		_fail("Slime death animation did not finish")
		return

	ranged.queue_free()
	boss.queue_free()
	print("slime_enemy_visual_smoke: PASS")
	quit(0)


func _on_death_signal() -> void:
	_death_signal_seen = true


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
