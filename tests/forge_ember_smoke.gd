extends SceneTree

const CASTER := preload("res://scripts/forge_caster_prototype.gd")
const EMBER := preload("res://scripts/forge_ember.gd")

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
	var ember := EMBER.new()
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
	var miss := EMBER.new()
	miss.target = target
	root.add_child(miss)
	target.position.x = 100
	miss.advance(1.53)
	assert(target.hits == 1, "Moving out must evade locked impact")
	target.position = Vector2.ZERO
	if not await verify_cast_cancellation(target):
		quit(1)
		return
	ember.queue_free()
	miss.queue_free()
	target.queue_free()
	await process_frame
	print("forge_ember_smoke: PASS")
	quit()


func verify_cast_cancellation(target: Target) -> bool:
	var hits_before := target.hits
	for phase: String in ["windup", "windup_removed", "flight"]:
		var released := phase == "flight"
		var caster := CASTER.new()
		root.add_child(caster)
		caster.set_physics_process(false)
		var ember := EMBER.new()
		ember.caster = caster
		ember.target = target
		root.add_child(ember)
		ember.advance(EMBER.WARNING + 0.01 if released else EMBER.WARNING - 0.01)
		caster.defeat()
		if phase != "windup":
			caster.queue_free()
			await process_frame
		if not released:
			ember.advance(EMBER.FLIGHT + 0.02)
			if not ember.is_queued_for_deletion() or ember.visible or ember.impacted or target.hits != hits_before:
				push_error("A defeated caster's unreleased ember must cancel without impact")
				return false
		else:
			ember.advance(EMBER.FLIGHT)
			if not ember.impacted or target.hits != hits_before + 1:
				push_error("A released ember must finish its flight after its caster is removed")
				return false
		if is_instance_valid(caster):
			caster.queue_free()
		ember.queue_free()
		await process_frame
	return true
