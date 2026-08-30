extends SceneTree

var _projectile_style: int = -1


func _initialize() -> void:
	call_deferred(&"_run_test")


func _run_test() -> void:
	var asset_paths: Array[String] = [
		"res://assets/enemies/red_fang_goblin_club_sheet.png",
		"res://assets/enemies/red_fang_goblin_elite_sheet.png",
		"res://assets/enemies/red_fang_goblin_archer_sheet.png",
	]
	for asset_path in asset_paths:
		var texture := load(asset_path) as Texture2D
		if texture == null or texture.get_width() % 4 != 0 or texture.get_height() % 4 != 0:
			_fail("Goblin sheet is not divisible into a 4x4 grid: %s" % asset_path)
			return
		var image := texture.get_image()
		if image.is_empty() or image.get_pixel(0, 0).a > 0.01:
			_fail("Goblin sheet is missing real alpha transparency: %s" % asset_path)
			return

	var club := _make_goblin(RogueEnemy.EnemyRole.MELEE, RogueEnemy.EnemyRank.NORMAL)
	var elite := _make_goblin(RogueEnemy.EnemyRole.MELEE, RogueEnemy.EnemyRank.ELITE)
	var archer := _make_goblin(RogueEnemy.EnemyRole.RANGED, RogueEnemy.EnemyRank.NORMAL)
	root.add_child(club)
	root.add_child(elite)
	root.add_child(archer)
	await physics_frame

	var club_sprite := club.get_node("EnemySprite") as Sprite2D
	var elite_sprite := elite.get_node("EnemySprite") as Sprite2D
	var archer_sprite := archer.get_node("EnemySprite") as Sprite2D
	if not club_sprite.texture.resource_path.ends_with("red_fang_goblin_club_sheet.png"):
		_fail("Ordinary goblin did not use the club soldier sheet")
		return
	if not elite_sprite.texture.resource_path.ends_with("red_fang_goblin_elite_sheet.png"):
		_fail("Elite goblin did not use the armored brute sheet")
		return
	if not archer_sprite.texture.resource_path.ends_with("red_fang_goblin_archer_sheet.png"):
		_fail("Ranged goblin did not use the archer sheet")
		return
	if elite_sprite.scale.x <= club_sprite.scale.x:
		_fail("Elite goblin was not visually larger than the ordinary soldier")
		return

	club.velocity.x = 100.0
	club.call(&"_update_sprite_animation")
	var cell_height: float = float(club_sprite.texture.get_height()) / 4.0
	if not is_equal_approx(club_sprite.region_rect.position.y, cell_height):
		_fail("Goblin run did not select the movement row")
		return
	club.call(&"_start_attack")
	club.call(&"_update_sprite_animation")
	if not is_equal_approx(club_sprite.region_rect.position.y, cell_height * 2.0):
		_fail("Goblin attack did not select the attack row")
		return
	club.set("_attack_remaining", 0.0)
	club.set("_hurt_remaining", 0.12)
	club.call(&"_update_sprite_animation")
	if not is_equal_approx(club_sprite.region_rect.position.y, cell_height * 3.0):
		_fail("Goblin hurt did not select the reaction row")
		return

	var target := Node2D.new()
	target.position = Vector2(-180.0, 0.0)
	root.add_child(target)
	archer.set_target(target)
	archer.projectile_requested.connect(_on_projectile_requested)
	archer.call(&"_fire_projectile")
	if _projectile_style != RogueEnemy.ProjectileStyle.ARROW:
		_fail("Goblin archer did not request an arrow projectile")
		return

	club.queue_free()
	elite.queue_free()
	archer.queue_free()
	target.queue_free()
	print("goblin_enemy_visual_smoke: PASS")
	quit(0)


func _make_goblin(role: int, rank: int) -> RogueEnemy:
	var enemy := RogueEnemy.new()
	enemy.setup(
		0,
		0.0,
		-100.0,
		100.0,
		role,
		rank,
		1.0,
		1.0,
		RogueEnemy.EnemyFamily.GOBLIN
	)
	return enemy


func _on_projectile_requested(
	_origin: Vector2,
	_velocity: Vector2,
	_damage: int,
	style: int
) -> void:
	_projectile_style = style


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
