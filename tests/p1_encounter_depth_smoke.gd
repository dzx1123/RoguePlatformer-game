extends SceneTree

const EVENT_NAME := "事件房"
const CHALLENGE_NAME := "挑战房"
const RISK_NAME := "风险宝箱"


func _initialize() -> void:
	call_deferred(&"_run_test")


func _run_test() -> void:
	var main_scene: PackedScene = load("res://scenes/Main.tscn")
	var main := main_scene.instantiate() as Node2D
	main.set("save_enabled", false)
	main.set("_next_run_seed", 123456)
	root.add_child(main)
	await _wait_physics_frames(8)

	var saw_event: bool = false
	var saw_challenge: bool = false
	var saw_risk: bool = false
	for room_number in range(1, 21):
		var encounter_name: String = String(main.call(&"get_current_encounter_name"))
		if encounter_name == EVENT_NAME:
			saw_event = true
			if not bool(main.call(&"is_event_active")):
				_fail("Event room did not open its non-combat choice")
				return
			var event_choices: Array = main.call(&"get_upgrade_choices") as Array
			if event_choices.size() != 3:
				_fail("Event room did not offer three distinct responses")
				return
			var gold_before_event: int = int(main.call(&"get_gold"))
			if not bool(main.call(&"choose_upgrade", 1)):
				_fail("Event response could not be selected")
				return
			await _wait_physics_frames(4)
			if int(main.call(&"get_gold")) < gold_before_event + 28:
				_fail("Event reward was not applied")
				return
			continue

		if encounter_name == RISK_NAME:
			saw_risk = true
			if not bool(main.call(&"is_awaiting_chest")):
				_fail("Risk room did not begin with an unopened chest")
				return
			var chest: RewardChest = main.get("_chest") as RewardChest
			if chest == null or not chest.is_risk_chest():
				_fail("Risk room used an ordinary reward chest")
				return
			var gold_before_risk: int = int(main.call(&"get_gold"))
			if not bool(main.call(&"open_current_chest_for_test")):
				_fail("Risk chest could not be opened")
				return
			await _wait_physics_frames(3)
			if (
				not bool(main.call(&"is_risk_ambush_active"))
				or (main.get("_enemies") as Array).size() < 4
			):
				_fail("Risk chest did not spawn its elite ambush")
				return
			_defeat_current_room(main)
			await _wait_physics_frames(36)
			if int(main.call(&"get_gold")) < gold_before_risk + 42:
				_fail("Risk reward was paid before combat or lost after victory")
				return
		else:
			if encounter_name == CHALLENGE_NAME:
				saw_challenge = true
				var challenge_enemies: Array = main.get("_enemies") as Array
				var elite_count: int = 0
				for enemy_value: Variant in challenge_enemies:
					if (enemy_value as RogueEnemy).is_elite():
						elite_count += 1
				if challenge_enemies.size() < 7 or elite_count < 1:
					_fail("Challenge room did not add reinforcements and an elite")
					return
			if String(main.call(&"get_current_objective_name")) == "holdout":
				if not bool(main.call(&"complete_room_objective_for_test")):
					_fail("Holdout room %d could not resolve its beacon objective" % room_number)
					return
			_defeat_current_room(main)
			await _wait_physics_frames(36)
			if encounter_name == "宝藏房" and bool(main.call(&"is_awaiting_chest")):
				main.call(&"open_current_chest_for_test")
				await _wait_physics_frames(4)

		if room_number < 20:
			if bool(main.call(&"is_shopping")):
				main.call(&"_leave_shop")
			else:
				if bool(main.call(&"is_awaiting_exit")) and not await _enter_room_exit(main):
					return
				if not bool(main.call(&"choose_upgrade", 0)):
					_fail("Room %d did not advance after its reward" % room_number)
					return
			await _wait_physics_frames(4)

	if not saw_event or not saw_challenge or not saw_risk:
		_fail("The run did not exercise all three new encounter archetypes")
		return
	if not bool(main.call(&"is_run_complete")):
		_fail("New encounter types prevented the twenty-room run from completing")
		return

	main.queue_free()
	print("p1_encounter_depth_smoke: PASS")
	quit(0)


func _defeat_current_room(main: Node2D) -> void:
	var enemies: Array = (main.get("_enemies") as Array).duplicate()
	for enemy_value: Variant in enemies:
		var enemy := enemy_value as RogueEnemy
		if is_instance_valid(enemy):
			enemy.defeat()


func _enter_room_exit(main: Node2D) -> bool:
	if not bool(main.call(&"_activate_room_exit")):
		_fail("Cleared room exit portal could not be activated")
		return false
	await _wait_physics_frames(20)
	return true


func _wait_physics_frames(frame_count: int) -> void:
	for _frame_index in range(frame_count):
		await physics_frame


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
