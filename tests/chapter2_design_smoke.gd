extends SceneTree

const CATALOG := preload("res://scripts/chapter2_catalog.gd")

func _init() -> void:
	var rooms := CATALOG.room_prototypes()
	if rooms.size() != 2:
		push_error("Chapter 2 must start with exactly two room prototypes")
		quit(1)
		return
	var enemy := CATALOG.enemy_prototype()
	if String(enemy.get("id", "")) != "ember_caster" or float(enemy.get("telegraph_seconds", 0.0)) < 0.60:
		push_error("Ember caster prototype lacks a readable telegraph")
		quit(1)
		return
	if CATALOG.enemy_roster().size() != 3:
		push_error("Chapter 2 enemy roster is incomplete")
		quit(1)
		return
	if CATALOG.event_prototypes().size() != 3:
		push_error("Chapter 2 event draft is incomplete")
		quit(1)
		return
	print("chapter2_design_smoke: PASS")
	quit(0)
