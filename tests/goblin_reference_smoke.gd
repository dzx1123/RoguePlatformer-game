extends SceneTree
var projectile_style := -1

func _initialize() -> void:
	call_deferred(&"_run")

func _run() -> void:
	var atlas := RogueEnemy.GOBLIN_REFERENCE_ATLAS.get_image()
	if atlas.get_size() != Vector2i(2448, 138):
		fail("Reference atlas dimensions changed")
		return
	var actors: Array[RogueEnemy] = []
	for kind in range(4):
		var actor := RogueEnemy.new()
		actor.setup(0, 0, -200, 200, 1 if kind == 2 else 0, 2 if kind == 3 else (1 if kind == 1 else 0), 1, 1, RogueEnemy.EnemyFamily.GOBLIN)
		root.add_child(actor)
		actor.set_physics_process(false)
		actors.append(actor)
		var sprite := actor.get_node("EnemySprite") as Sprite2D
		if sprite.texture != RogueEnemy.GOBLIN_REFERENCE_ATLAS or sprite.get_child_count() == 0:
			fail("Goblin variant does not use the reference model and horns")
			return
		var origin := sprite.position
		for facing in [-1.0, 1.0]:
			actor.set("_facing", facing)
			actor.velocity = Vector2(facing * 72, 0)
			for frame in range(6):
				actor.set("_locomotion_cycle", float(frame))
				actor.call(&"_update_sprite_animation")
				if sprite.region_rect.position.x != (11 + frame) * 144 or sprite.position != origin or sprite.flip_h != (facing < 0):
					fail("Reference walk loses frame order, registration or facing")
					return
		actor.set("_locomotion_cycle", 0.0)
		for tick in range(6):
			actor.call(&"_update_locomotion_animation", 0.1)
		if absf(float(actor.get("_locomotion_cycle"))) > 0.01:
			fail("Patrol must preserve the GIF's 600ms gait cycle")
			return
		actor.velocity = Vector2.ZERO
		actor.set("_locomotion_active", false)
		var duration := float(actor.call(&"_get_attack_duration"))
		actor.set("_attack_remaining", duration * 0.55)
		actor.call(&"_update_sprite_animation")
		if kind != 2 and sprite.region_rect.position.x != 3 * 144:
			fail("Melee impact pose is not synchronized with the strike")
			return
		actor.set("_attack_remaining", 0.0)
		actor.set("_hurt_remaining", 0.12)
		actor.call(&"_update_sprite_animation")
		if sprite.region_rect.position.x != 5 * 144:
			fail("Missing authored hurt pose")
			return
		actor.set("_hurt_remaining", 0.0)
		actor.set("_is_defeated", true)
		for frame in range(3):
			actor.set("_death_remaining", RogueEnemy.DEATH_ANIMATION_DURATION * (1.0 - (frame + 0.1) / 3.0))
			actor.call(&"_update_sprite_animation")
			if sprite.region_rect.position.x != (7 + frame) * 144:
				fail("Missing authored collapse pose")
				return
	var target := Node2D.new()
	target.position = Vector2(150, 0)
	root.add_child(target)
	actors[2].set("_is_defeated", false)
	actors[2].set_target(target)
	actors[2].projectile_requested.connect(func(_p: Vector2, _v: Vector2, _d: int, style: int): projectile_style = style)
	actors[2].call(&"_fire_projectile")
	if projectile_style != RogueEnemy.ProjectileStyle.ARROW:
		fail("Ranged goblin no longer fires an arrow")
		return
	for actor in actors:
		actor.queue_free()
	target.queue_free()
	print("goblin_reference_smoke: PASS all 4 variants, 6-frame gait, attack/hurt/death, arrows")
	quit(0)

func fail(message: String) -> void:
	push_error(message)
	quit(1)
