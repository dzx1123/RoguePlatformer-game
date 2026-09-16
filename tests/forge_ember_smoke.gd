extends SceneTree
class Target extends Node2D:
	var hits := 0
	func receive_enemy_attack(_origin: Vector2, _damage: int, _cause: StringName) -> bool:
		hits += 1
		return true

func _initialize() -> void:
	call_deferred("run_test")

func run_test() -> void:
	var target := Target.new()
	root.add_child(target)
	var ember := preload("res://scripts/forge_ember.gd").new()
	ember.target = target
	root.add_child(ember)
	ember.advance(0.71)
	assert(target.hits == 0)
	ember.advance(0.80)
	assert(target.hits == 0)
	ember.advance(0.02)
	assert(target.hits == 1)
	ember.advance(0.01)
	assert(target.hits == 1, "Impact repeated")
	var miss := preload("res://scripts/forge_ember.gd").new()
	miss.target = target
	root.add_child(miss)
	target.position.x = 100
	miss.advance(1.53)
	assert(target.hits == 1, "Moving out must evade locked impact")
	ember.queue_free()
	miss.queue_free()
	target.queue_free()
	await process_frame
	print("forge_ember_smoke: PASS")
	quit()
