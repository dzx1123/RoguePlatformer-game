extends SceneTree

const CHEST_SCRIPT := preload("res://scripts/reward_chest.gd")


func _initialize() -> void:
	call_deferred(&"_run_test")


func _run_test() -> void:
	var main_scene: PackedScene = load("res://scenes/Main.tscn")
	var main: Node2D = main_scene.instantiate() as Node2D
	main.set("save_enabled", false)
	root.add_child(main)
	await physics_frame
	await process_frame

	var feedback: RewardFeedback = main.get_node_or_null("HUD/RewardFeedback") as RewardFeedback
	if feedback == null:
		return _fail("The shared reward confirmation layer was not created")

	main.call(&"_show_upgrade_choice")
	await process_frame
	if not _assert_layer_mode(main, "LUNAR RELIC", false):
		return
	var relic_choices: Array[Dictionary] = main.call(&"get_upgrade_choices") as Array[Dictionary]
	var relic_name: String = String(relic_choices[0].get("name", ""))
	if not bool(main.call(&"choose_upgrade", 0)):
		return _fail("The relic choice could not be resolved")
	await process_frame
	var feedback_snapshot: Dictionary = feedback.get_snapshot()
	if (
		StringName(feedback_snapshot.get("kind", &"")) != &"relic"
		or not String(feedback_snapshot.get("title", "")).contains(relic_name)
	):
		return _fail("Relic selection did not produce shared confirmation feedback")

	main.set("_gold", 999)
	main.call(&"_show_shop")
	await process_frame
	if not _assert_layer_mode(main, "ASTRAL MARKET", false):
		return
	var shop_choices: Array[Dictionary] = main.call(&"get_upgrade_choices") as Array[Dictionary]
	var shop_name: String = String(shop_choices[0].get("name", ""))
	if not bool(main.call(&"choose_upgrade", 0)):
		return _fail("The shop choice could not be resolved")
	await process_frame
	feedback_snapshot = feedback.get_snapshot()
	if (
		StringName(feedback_snapshot.get("kind", &"")) != &"shop"
		or not String(feedback_snapshot.get("title", "")).contains(shop_name)
	):
		return _fail("Shop purchase did not use the shared confirmation feedback")

	var player: RoguePlayer = main.get_node("Player") as RoguePlayer
	player.set_current_health(player.get_max_health())
	var gold_before_event: int = int(main.call(&"get_gold"))
	main.call(&"_show_event_choice")
	await process_frame
	if not _assert_layer_mode(main, "ECLIPSE OMEN", false):
		return
	var event_choices: Array[Dictionary] = main.call(&"get_upgrade_choices") as Array[Dictionary]
	var event_name: String = String(event_choices[0].get("name", ""))
	if not bool(main.call(&"choose_upgrade", 0)):
		return _fail("The event choice could not be resolved")
	await process_frame
	feedback_snapshot = feedback.get_snapshot()
	if (
		StringName(feedback_snapshot.get("kind", &"")) != &"event"
		or not String(feedback_snapshot.get("title", "")).contains(event_name)
		or not String(feedback_snapshot.get("detail", "")).contains("生命已满")
		or not String(feedback_snapshot.get("detail", "")).contains("金币 -8")
		or String(feedback_snapshot.get("detail", "")).contains("恢复 40")
		or int(main.call(&"get_gold")) != gold_before_event - 8
	):
		return _fail("Event resolution did not report its actual health and gold changes")

	main.call(&"_clear_enemies")
	main.call(&"_spawn_reward_chest")
	await process_frame
	if not bool(main.call(&"open_current_chest_for_test")):
		return _fail("The reward chest could not be opened")
	await process_frame
	feedback_snapshot = feedback.get_snapshot()
	if (
		StringName(feedback_snapshot.get("kind", &"")) != &"chest"
		or not String(feedback_snapshot.get("detail", "")).contains("金币 +24")
	):
		return _fail("Chest rewards did not use the shared confirmation feedback")
	feedback.hide_feedback()
	if not await _assert_feedback_lifecycle(feedback, false):
		return
	if not await _assert_feedback_lifecycle(feedback, true):
		return
	feedback.set_reduced_motion(false)

	var pending_chest: RewardChest = CHEST_SCRIPT.new() as RewardChest
	pending_chest.setup(24, 24, "E", false)
	main.add_child(pending_chest)
	await process_frame
	if not pending_chest.force_open():
		return _fail("The standalone reward chest could not be opened")
	var pending_prompt: Dictionary = pending_chest.get_prompt_snapshot()
	if (
		not String(pending_prompt.get("text", "")).contains("结算中")
		or String(pending_prompt.get("text", "")).contains("生命 +24")
	):
		return _fail("An unresolved chest exposed its promised rather than actual healing")
	pending_chest.set_resolved_reward(24, 0)
	if not String(pending_chest.get_prompt_snapshot().get("text", "")).contains("生命恢复 0"):
		return _fail("The resolved chest did not expose zero actual healing")
	pending_chest.queue_free()
	await process_frame

	feedback.hide_feedback()
	main.call(&"_clear_enemies")
	# EncounterType.RISK_CHEST is the eighth value in main.gd's stable public enum.
	main.set("_current_encounter", 7)
	main.call(&"_spawn_risk_chest")
	await process_frame
	if not bool(main.call(&"open_current_chest_for_test")):
		return _fail("The integrated risk chest could not be opened")
	await process_frame
	var active_risk_chest: RewardChest = main.get("_chest") as RewardChest
	if (
		not bool(main.call(&"is_risk_ambush_active"))
		or bool(feedback.get_snapshot().get("visible", true))
		or not String(active_risk_chest.get_prompt_snapshot().get("text", "")).contains("伏兵来袭")
	):
		return _fail("Risk-chest opening obscured or failed to announce the ambush")
	main.call(&"_clear_enemies")
	main.call(&"_clear_chest")

	var risk_chest: RewardChest = CHEST_SCRIPT.new() as RewardChest
	risk_chest.setup(42, 28, "E", true)
	main.add_child(risk_chest)
	await process_frame
	if not risk_chest.force_open():
		return _fail("The standalone risk chest could not be opened")
	risk_chest.set_resolved_reward(42, 7)
	var risk_prompt: Dictionary = risk_chest.get_prompt_snapshot()
	if (
		not bool(risk_prompt.get("resolved", false))
		or not bool(risk_prompt.get("visible", false))
		or not String(risk_prompt.get("text", "")).contains("金币 +42")
		or not String(risk_prompt.get("text", "")).contains("生命恢复 7")
	):
		return _fail("Risk chest completion did not show the resolved reward values")
	risk_chest.queue_free()
	await process_frame

	main.call(&"_complete_run")
	await process_frame
	if not _assert_layer_mode(main, "ROUTE SEALED", true):
		return
	var victory_summary: Control = main.get("_upgrade_victory_summary") as Control
	var victory_restart: Button = main.get("_victory_restart_button") as Button
	var route_value: Label = victory_summary.get_node("VictoryStat_0/Value") as Label
	var shards_value: Label = victory_summary.get_node("VictoryStat_1/Value") as Label
	var weapon_value: Label = victory_summary.get_node("VictoryStat_2/Value") as Label
	if (
		not route_value.text.contains("20 / 20")
		or not shards_value.text.begins_with("+")
		or weapon_value.text.is_empty()
		or victory_restart == null
		or not victory_restart.visible
		or victory_restart.disabled
	):
		return _fail("Victory reward summary did not expose its results and primary action")
	var victory_result: Label = victory_summary.get_node("VictoryResult") as Label
	main.call(&"_configure_victory_summary", 8, "")
	if not victory_result.text.contains("路线记录已封存"):
		return _fail("Victory summary without an unlock used the wrong fallback copy")
	main.call(&"_configure_victory_summary", 8, "解锁「影织双刃」")
	if (
		not victory_result.text.begins_with("解锁「影织双刃」")
		or victory_result.text.begins_with("；")
		or String(main.call(&"_format_unlock_suffix", "解锁「影织双刃」")) != "；解锁「影织双刃」"
	):
		return _fail("Victory unlock copy did not follow the normalized text contract")

	main.queue_free()
	await process_frame
	print("reward_layer_smoke: PASS")
	quit(0)


func _assert_layer_mode(main: Node2D, kicker_fragment: String, expect_victory: bool) -> bool:
	var overlay: Control = main.get("_upgrade_overlay") as Control
	var kicker: Label = main.get("_upgrade_kicker") as Label
	var victory_summary: Control = main.get("_upgrade_victory_summary") as Control
	if (
		not overlay.visible
		or not kicker.text.contains(kicker_fragment)
		or victory_summary.visible != expect_victory
	):
		_fail("Reward layer mode was not configured for %s" % kicker_fragment)
		return false
	return true


func _assert_feedback_lifecycle(feedback: RewardFeedback, reduced_motion: bool) -> bool:
	feedback.set_reduced_motion(reduced_motion)
	feedback.present(
		&"timing_test",
		"TIMING CHECK",
		"奖励反馈可读",
		"普通与减弱动效都应完整显示并自动关闭",
		Color("#69d9ed"),
		0.72
	)
	var readable_deadline: int = Time.get_ticks_msec() + 1500
	var became_readable: bool = false
	while Time.get_ticks_msec() < readable_deadline:
		await process_frame
		var snapshot: Dictionary = feedback.get_snapshot()
		if (
			bool(snapshot.get("visible", false))
			and bool(snapshot.get("reduced_motion", not reduced_motion)) == reduced_motion
			and feedback.modulate.a >= 0.80
		):
			became_readable = true
			break
	if not became_readable:
		_fail("Reward confirmation never reached a readable state (reduced=%s)" % reduced_motion)
		return false
	var hidden_deadline: int = Time.get_ticks_msec() + 2200
	while Time.get_ticks_msec() < hidden_deadline:
		await process_frame
		if not bool(feedback.get_snapshot().get("visible", false)):
			return true
	_fail("Reward confirmation did not close (reduced=%s)" % reduced_motion)
	return false


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
