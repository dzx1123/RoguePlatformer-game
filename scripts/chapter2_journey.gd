extends "res://scripts/chapter2_full_slice.gd"

const CHECKPOINT := preload("res://scripts/chapter2_continue_store.gd")
const ROUTE_HINT_FIRST_ROOM := 27
const ROUTE_HINT_DURATION := 7.0
const REWARD_PORTAL_CONTEXT := {
	&"ritual": ["选择冷却仪式", "仪式"],
	&"toll": ["查看铸火代价", "交易"],
	&"upgrade": ["选择强化", "奖励"],
	&"shop": ["查看旅商商品", "商店"],
	&"supply": ["选择战前补给", "补给"],
}
var save_path := ""
var title_continue_path := RunContinueStore.DEFAULT_SAVE_PATH
var persistence_enabled := true
var checkpoint_store: RefCounted
var checkpoint: Dictionary = {}
var restoring := true
var journey_ready := false
var save_error := OK
var return_panel: PanelContainer
var campaign: Dictionary = {}
var campaign_runtime: Dictionary = {}
var resolving_campaign := false
var campaign_hud: CanvasLayer
var campaign_presenter: RunHUDPresenter
var campaign_pause: Control
var chapter_menu: Node
var last_campaign_status := ""
var route_hint_panel: Panel
var route_hint_label: Label
var _route_hint_remaining := 0.0
var room_portal: RoomExitPortal
var entry_beam: RoomEntryBeam
var portal_delay := -1.0
var portal_sound: RogueSoundscape
var reward_view: RewardChoiceView
var reward_cards: Array[Dictionary] = []
var reward_feedback: RewardFeedback
var _reward_focus_before_pause: Control

func _open_choice(kind: StringName) -> void:
	ritual_open = true
	choice_kind = kind
	player.clear_action_buffer()
	player.set_physics_process(false)
	for enemy in living_enemies():
		enemy.set_physics_process(false)
	if reward_view == null:
		reward_view = RewardChoiceView.new()
		campaign_hud.add_child(reward_view)
		reward_view.build(input_settings, portal_sound)
		reward_view.selected.connect(_select_reward_card)
		reward_view.shop_exit_requested.connect(_leave_shop)
		reward_feedback = RewardFeedback.new()
		campaign_hud.add_child(reward_feedback)
	var rng := RandomNumberGenerator.new()
	reward_feedback.hide()
	reward_feedback.set_reduced_motion(input_settings.get_reduced_effects_enabled())
	rng.seed = int(campaign.get("seed", 1)) * 100 + room_index
	reward_cards.clear()
	if kind == &"upgrade":
		reward_cards = RunUpgradeService.pick_choices(player.get_weapon_id(), player.get_run_upgrade_counts(), rng)
	elif kind == &"rare":
		offered = _available_weapon_rares().slice(0, reward_view._upgrade_buttons.size())
		reward_cards = offered.duplicate(true)
		if offered.is_empty():
			reward_cards.append({"id": &"trial_gold", "name": "领取金币", "description": "稀有强化已满层 · 金币 +%d" % TRIAL_FALLBACK_GOLD})
	elif kind == &"shop":
		reward_cards = RunUpgradeService.create_shop_offers(player.get_weapon_id(), player.get_run_upgrade_counts(), rng)
		offered = reward_cards.duplicate(true)
	else:
		reward_cards = _event_reward_cards(kind)
	reward_view._flow_state.transition_to(RunFlowState.Phase.SHOP if kind == &"shop" else (RunFlowState.Phase.UPGRADE if kind in [&"upgrade", &"rare"] else RunFlowState.Phase.EVENT))
	reward_view._upgrade_title.text = "选择一项强化" if kind == &"upgrade" else _choice_title(kind)
	if kind == &"rare" and offered.is_empty():
		reward_view._upgrade_title.text = "熔流试炼完成 · 领取金币"
	var ui := preload("res://scripts/ui_theme.gd")
	var accent: Color = ui.ACCENT_GOLD if kind == &"shop" else (ui.ACCENT_MOON if kind in [&"upgrade", &"rare"] else ui.ACCENT_OMEN)
	reward_view._upgrade_dimmer.color = ui.BG_VEIL
	reward_view._upgrade_panel.add_theme_stylebox_override("panel", ui.surface(ui.BG_PANEL, ui.STROKE_QUIET, 16, 1, 18))
	reward_view._upgrade_rule.color = Color(accent, 0.40)
	reward_view._upgrade_kicker.add_theme_color_override("font_color", Color(accent, 0.94))
	reward_view._upgrade_kicker.text = "强化" if kind in [&"upgrade", &"rare"] else ("交易" if kind == &"shop" else "余烬铸庭")
	for index in range(3):
		var button: Button = reward_view._upgrade_buttons[index]
		button.visible = index < reward_cards.size()
		if not button.visible:
			continue
		var card := reward_cards[index]
		var unavailable_reason := _reward_card_unavailable_reason(card)
		button.disabled = not unavailable_reason.is_empty()
		var scope := "通用" if str(card.get("weapon", "")).is_empty() else WeaponCatalog.get_weapon_name(card.weapon) + "专属"
		var footer := "%s · %d/%d 层" % [scope, card.get("current_stacks", 0), card.get("max_stacks", 1)]
		if kind == &"shop":
			footer = "%d 金币" % card.cost
		elif kind not in [&"upgrade", &"rare"] or (kind == &"rare" and offered.is_empty()):
			footer = ""
		button.get_node("CardFooter").add_theme_font_size_override("font_size", ui.CAPTION)
		var cost := button.get_node("CardCost") as Label
		cost.text = unavailable_reason if button.disabled else str(card.get("cost_text", ""))
		reward_view._set_upgrade_card_content(button, str(index + 1), str(card.get("rarity_name", "事件")), str(card.name), str(card.description), footer)
		reward_view._style_upgrade_card(button, card)
		button.get_node("CardBadge").visible = kind == &"shop"
		if kind == &"shop":
			button.get_node("CardFooter").add_theme_font_size_override("font_size", ui.HEADLINE)
			button.get_node("CardBadge").add_theme_stylebox_override("panel", ui.surface(ui.BG_DEEP, ui.STROKE_QUIET if button.disabled else Color(ui.ACCENT_GOLD, 0.45), ui.CHIP_RADIUS))
	reward_view._upgrade_overlay.show()
	_refresh_reward_choice_prompts()
	reward_view._play_upgrade_overlay_intro()
	reward_view.focus_choice()


func _event_reward_cards(kind: StringName) -> Array[Dictionary]:
	var missing_health: int = player.get_max_health() - player.get_current_health()
	match kind:
		&"ritual":
			return [
				{"id": "moon_cooling", "name": "冷却炉口", "description": "关闭第 25 房的环境热区", "cost_text": "熔火弹仍会造成伤害"},
				{"id": "rest", "name": "恢复生命", "description": "当前可恢复 %d 生命" % mini(25, missing_health)},
			]
		&"supply":
			var current_health: int = player.get_current_health()
			var max_health: int = player.get_max_health()
			var recovery := _supply_recovery()
			var vitality := UpgradeCatalog.get_upgrade(&"vitality_rune")
			var can_upgrade: bool = player.get_run_upgrade_count(&"vitality_rune") < int(vitality.max_stacks)
			var heal_card := {
				"id": "rest", "name": "恢复生命",
				"description": "恢复 %d 生命\n补给后 %d/%d 生命" % [recovery, current_health + recovery, max_health] if recovery > 0 else "当前 %d/%d 生命" % [current_health, max_health],
				"unavailable_reason": "生命已满" if recovery == 0 else "",
			}
			var vitality_card := {
				"id": "vitality_rune", "name": "生命铸纹",
				"description": "生命上限 +20\n补给后 %d/%d 生命" % [current_health + 20, max_health + 20],
			}
			return [
				heal_card,
				vitality_card if can_upgrade else {"id": "gold", "name": "领取金币", "description": "生命铸纹已满层 · 金币 +15"},
			]
		&"toll":
			_choice_options(kind)
			var cards: Array[Dictionary] = []
			var health_after: int = player.get_current_health() - TOLL_COST
			var cost_text := "代价 %d 生命 · 交易后 %d/%d" % [TOLL_COST, health_after, player.get_max_health()]
			for offer in offered:
				cards.append({"id": offer.id, "name": offer.name, "description": offer.description, "cost_text": cost_text})
			var leave_text := "武器稀有强化已满层，可直接前往下一房" if offered.is_empty() else "保留当前生命并前往下一房"
			cards.append({"id": "leave", "name": "离开炉台", "description": leave_text})
			return cards
	var cards: Array[Dictionary] = []
	for option in _choice_options(kind):
		var lines := str(option).split(" · ", false, 1)
		cards.append({"id": str(cards.size()), "name": lines[0], "description": lines[1] if lines.size() > 1 else ""})
	return cards


func _reward_card_unavailable_reason(card: Dictionary) -> String:
	if choice_kind == &"shop" and gold < int(card.cost):
		return "金币不足"
	if choice_kind == &"toll" and card.has("cost_text") and player.get_current_health() <= TOLL_COST:
		return "生命不足 · 支付后需保留至少 1 生命"
	return str(card.get("unavailable_reason", ""))


func _refresh_reward_choice_prompts() -> void:
	if not ritual_open or not is_instance_valid(reward_view):
		return
	var shortcuts := PackedStringArray(["X", "Y", "B"] if using_controller else ["1", "2", "3"]).slice(0, reward_cards.size())
	var offered_shortcuts := PackedStringArray()
	for index in reward_cards.size():
		var label := reward_view._upgrade_buttons[index].get_node("CardRarity") as Label
		var rarity: String = reward_cards[index].get("rarity_name", "")
		label.text = rarity
		if _reward_card_unavailable_reason(reward_cards[index]).is_empty():
			offered_shortcuts.append(shortcuts[index])
			label.text = "[%s]" % shortcuts[index] if rarity.is_empty() else "[%s]  %s" % [shortcuts[index], rarity]
	reward_view._upgrade_hint.text = ("A 确认 · %s 直选" if using_controller else "点击卡片或按 %s 选择") % " / ".join(offered_shortcuts)
	if choice_kind == &"shop":
		reward_view.set_shop_exit_prompt(input_settings.get_action_prompt(&"interact", using_controller))
		var hint := "当前商品均无法购买" if offered_shortcuts.is_empty() else reward_view._upgrade_hint.text
		reward_view._upgrade_hint.text = "金币 %d · %s" % [gold, hint]


func _select_reward_card(index: int) -> void:
	if not ritual_open or paused or index < 0 or index >= reward_cards.size():
		return
	var card := reward_cards[index]
	if not str(card.get("unavailable_reason", "")).is_empty():
		return
	if is_instance_valid(portal_sound):
		portal_sound.play_ui()
	var ui := preload("res://scripts/ui_theme.gd")
	if choice_kind == &"rare":
		var grants_gold := offered.is_empty()
		if not choose_mid_option(index):
			return
		if grants_gold:
			reward_feedback.present(&"event", "熔流试炼", last_reward, "", ui.ACCENT_GOLD)
		else:
			reward_feedback.present(&"relic", "遗物共鸣", last_reward, str(card.description), ui.ACCENT_MOON)
	elif choice_kind == &"upgrade":
		if not _can_claim(choice_kind) or not player.apply_run_upgrade(card.id):
			return
		claimed[rooms[room_index].id] = true
		last_reward = "已获得「%s」" % card.name
		reward_feedback.present(&"relic", "遗物共鸣", last_reward, str(card.description), ui.ACCENT_MOON)
		_close_choice()
		_advance_room()
	else:
		_select_option(index)
		if not ritual_open and is_instance_valid(reward_feedback):
			reward_feedback.present(&"event", "选择完成", last_reward, "", ui.ACCENT_MOON)

func _leave_shop() -> void:
	if ritual_open and not paused and choice_kind == &"shop":
		choose_mid_option(offered.size())


func _close_choice() -> void:
	super._close_choice()
	_reward_focus_before_pause = null
	for enemy in living_enemies():
		enemy.set_physics_process(not paused)
	if is_instance_valid(reward_view):
		reward_view._hide_upgrade_overlay()

func _ready() -> void:
	# The title/victory UI pauses the shared SceneTree; scene replacement does not
	# reset it. Resume here so every entry route runs arrival animation and input.
	get_tree().paused = false
	if get_tree().has_meta(&"campaign_runtime"):
		campaign_runtime = get_tree().get_meta(&"campaign_runtime")
		get_tree().remove_meta(&"campaign_runtime")
		persistence_enabled = bool(campaign_runtime.save_enabled)
	if get_tree().has_meta(&"chapter2_entry"):
		var entry: Dictionary = get_tree().get_meta(&"chapter2_entry")
		get_tree().remove_meta(&"chapter2_entry")
		checkpoint_store = entry.store
		title_continue_path = str(entry.title_path)
		save_path = checkpoint_store.get_save_path()
		persistence_enabled = bool(entry.persistent)
	else:
		persistence_enabled = persistence_enabled and not save_path.is_empty()
		checkpoint_store = CHECKPOINT.new(save_path, persistence_enabled)
		checkpoint_store.load_snapshot()
	var saved_room: Dictionary = checkpoint_store.get_snapshot()
	var can_restore: bool = checkpoint_store.can_resume() and int(saved_room.get("chapter", 0)) == 2
	if can_restore:
		campaign = saved_room.get("campaign", {}).duplicate(true)
	if not campaign.is_empty() and campaign_runtime.is_empty():
		var progression := ProgressionStore.new()
		progression.load_progress()
		var telemetry := RunTelemetry.new()
		telemetry.load_data()
		if not telemetry.tracks_seed(int(campaign.seed)):
			telemetry.begin_run(int(campaign.seed), ["简单", "中等", "困难"][int(campaign.difficulty)], StringName(saved_room.weapon_id))
		campaign_runtime = {"progression": progression, "telemetry": telemetry, "save_enabled": persistence_enabled}
	super._ready()
	if can_restore:
		restore_checkpoint(saved_room)
	else:
		checkpoint = CHECKPOINT.from_player(player, gold)
		restoring = false
	journey_ready = true
	_create_return_ui()
	_save_checkpoint()
	if campaign_runtime.is_empty():
		var progression := ProgressionStore.new()
		progression.load_progress()
		campaign_runtime = {"progression": progression}
	_create_campaign_hud()
	_queue_route_hint()
	if not InputMap.has_action(&"cycle_weapon"):
		InputMap.add_action(&"cycle_weapon")
		var key := InputEventKey.new()
		key.physical_keycode = KEY_Q
		InputMap.action_add_event(&"cycle_weapon", key)
	input_settings.apply()
	player.weapon_changed.connect(_on_journey_weapon_changed)
	portal_sound = preload("res://scripts/soundscape.gd").new()
	add_child(portal_sound)
	player.action_started.connect(_on_shared_player_action)
	player.vocal_requested.connect(portal_sound.handle_player_vocal)
	for enemy in living_enemies():
		_connect_enemy_audio(enemy)
	_update_shared_music_state()
	if player.modulate.a > 0:
		player.enter_room(Vector2(100, 580), 0)
	_spawn_entry_beam()
	_sync_room_portal()
	if not campaign.is_empty():
		player.damage_received.connect(_campaign_damage)
		_begin_campaign_room()

func _create_return_ui() -> void:
	return_panel = PanelContainer.new()
	return_panel.position = Vector2(940, 16)
	var layer := CanvasLayer.new()
	add_child(layer)
	layer.add_child(return_panel)
	var button := Button.new()
	button.text = "返回主菜单（保留检查点）"
	button.custom_minimum_size = Vector2(300, 42)
	button.pressed.connect(return_to_menu)
	return_panel.add_child(button)

func restore_checkpoint(data: Dictionary) -> bool:
	if int(data.get("chapter", 0)) != 2 or not checkpoint_store._is_valid_snapshot(data) or bool(data.completed):
		return false
	restoring = true
	campaign = data.get("campaign", {}).duplicate(true)
	checkpoint = data.duplicate(true)
	claimed.clear()
	for key in data.claimed:
		claimed[StringName(str(key))] = data.claimed[key]
	branch_choices.clear()
	for key in data.branches:
		branch_choices[int(str(key))] = int(data.branches[key])
	cooling_room = int(data.cooling_room)
	gold = int(data.gold)
	player.configure_weapon(StringName(str(data.weapon_id)))
	var counts := {}
	for key in data.upgrade_counts:
		counts[StringName(str(key))] = int(data.upgrade_counts[key])
	player.restore_run_progression(counts, int(data.health))
	player.apply_max_health_delta(int(data.max_health) - player.get_max_health())
	player.set_current_health(int(data.health))
	paused = false
	_load_layout(int(data.room_index), true)
	restoring = false
	return true

func _snapshot() -> Dictionary:
	var data := CHECKPOINT.from_player(player, gold)
	data.room_index = room_index
	data.claimed = claimed.duplicate(true)
	data.branches = branch_choices.duplicate(true)
	data.cooling_room = cooling_room
	data.completed = route_complete
	if not campaign.is_empty():
		data.campaign = campaign.duplicate(true)
	return data

func _save_checkpoint() -> void:
	if restoring or not journey_ready or player.is_dead():
		return
	checkpoint = _snapshot()
	save_error = checkpoint_store.save_snapshot(checkpoint)
	if save_error != OK:
		last_reward = "检查点保存失败，请勿退出；错误码 %d" % save_error
	queue_redraw()

func _load_layout(index: int, carry_health: bool = false) -> void:
	portal_delay = -1
	if is_instance_valid(room_portal):
		room_portal.queue_free()
	room_portal = null
	if journey_ready and not campaign.is_empty():
		campaign_runtime.telemetry.complete_room(&"advanced")
	super._load_layout(index, carry_health)
	_save_checkpoint()
	if journey_ready:
		_begin_campaign_room()
		_spawn_entry_beam()
		_queue_route_hint()

func _advance_room() -> void:
	super._advance_room()
	_save_checkpoint()
	if route_complete and not campaign.is_empty() and save_error == OK:
		_resolve_campaign(true)

func choose_final_option(index: int) -> bool:
	if choice_kind == &"supply" and index == 0 and _supply_recovery() == 0:
		return false
	var was_branch := choice_kind == &"branch"
	var selected := super.choose_final_option(index)
	if selected and was_branch:
		_save_checkpoint()
		_queue_route_hint()
	return selected

func try_exit() -> bool:
	var had_chest := claimed.has(&"chain_chest")
	var result := super.try_exit()
	if result and not had_chest and claimed.has(&"chain_chest"):
		portal_sound.play_chest()
		_save_checkpoint()
	return result

func _on_player_died() -> void:
	super._on_player_died()
	retry_remaining = -1
	if not campaign.is_empty():
		_resolve_campaign(false)
		return
	last_reward = "挑战失败 · 从检查点重试将恢复检查点生命与构筑"

func retry_room() -> void:
	if not campaign.is_empty():
		last_reward = "连续旅程不支持免费重试；死亡后按整局规则扣除命数"
		return
	if ritual_open or route_complete or paused:
		return
	restore_checkpoint(checkpoint)

func restart_slice() -> void:
	# F2 must not erase a journey or create a free healing/reset exploit.
	retry_room()

func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause") and not event.is_echo():
		_toggle_pause()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_ESCAPE, KEY_P]:
		# Only the shared pause binding may open menus; suppress prototype shortcuts.
		return
	super._unhandled_key_input(event)

func _unhandled_input(event: InputEvent) -> void:
	if ritual_open and not paused:
		var index := -1
		if event is InputEventKey and event.pressed and not event.echo:
			index = [KEY_1, KEY_2, KEY_3].find(event.keycode)
		elif event is InputEventJoypadButton and event.pressed:
			index = [JOY_BUTTON_X, JOY_BUTTON_Y, JOY_BUTTON_B].find(event.button_index)
		if index >= 0:
			_select_reward_card(index)
			get_viewport().set_input_as_handled()
		elif choice_kind == &"shop" and event.is_action_pressed(&"interact"):
			_leave_shop()
			get_viewport().set_input_as_handled()
		return
	if event is InputEventJoypadButton and event.is_action_pressed(&"pause"):
		_toggle_pause()
		get_viewport().set_input_as_handled()

func _gameplay_prompt() -> String:
	var parts := PackedStringArray()
	for action: StringName in [&"move_left", &"move_right", &"jump", &"attack", &"dash", &"skill", &"interact"]:
		parts.append(input_settings.get_action_prompt(action, using_controller) + " " + str({&"move_left": "左移", &"move_right": "右移", &"jump": "跳跃", &"attack": "攻击", &"dash": "冲刺", &"skill": "技能", &"interact": "交互"}[action]))
	return " · ".join(parts)

func _journey_prompt() -> String:
	if not campaign.is_empty():
		return input_settings.get_action_prompt(&"pause", using_controller) + " 暂停 · 死亡扣除命数并重开整局"
	return input_settings.get_action_prompt(&"restart", using_controller) + " 重试检查点 · " + input_settings.get_action_prompt(&"pause", using_controller) + " 暂停 · 暂停菜单可返回主菜单"

func _objective_text() -> String:
	if not campaign.is_empty() and not route_complete:
		return super._objective_text()
	if route_complete:
		return "第二章试玩已完成 · 返回主菜单可开始新的第二章旅程"
	return super._objective_text()

func _begin_campaign_room() -> void:
	if campaign.is_empty():
		return
	campaign_runtime.telemetry.resume_room(21 + room_index, rooms[room_index].id, rooms[room_index].title, "余烬铸庭")

func _campaign_damage(amount: int, cause: StringName) -> void:
	campaign_runtime.telemetry.record_damage(amount, cause)

func _physics_process(delta: float) -> void:
	_sync_room_portal()
	if portal_delay >= 0:
		if not paused:
			portal_delay -= delta
			if portal_delay < 0:
				try_exit()
		return
	if not paused and not ritual_open and not player.is_dead() and Input.is_action_just_pressed(&"interact") and is_instance_valid(room_portal) and room_portal.is_in_range(player.global_position):
		room_portal.play_activation()
		player.set_physics_process(false)
		portal_delay = 0.22
		if is_instance_valid(portal_sound):
			portal_sound.play_portal()
		return
	if not campaign.is_empty() and not paused and not ritual_open and not resolving_campaign:
		campaign_runtime.telemetry.tick(delta)
	super._physics_process(delta)

func _draw_exit_marker() -> void:
	pass

func _at_exit() -> bool:
	return room_portal.is_in_range(player.global_position) if is_instance_valid(room_portal) else super._at_exit()

func _spawn_entry_beam() -> void:
	if is_instance_valid(entry_beam):
		entry_beam.queue_free()
	entry_beam = preload("res://scripts/room_entry_beam.gd").new()
	add_child(entry_beam)
	entry_beam.global_position = player.global_position + Vector2(0, -8)
	entry_beam.z_index = 12
	entry_beam.play(1.0, input_settings.get_reduced_effects_enabled())

func _sync_room_portal() -> void:
	if is_instance_valid(entry_beam):
		entry_beam.set_process(not paused)
	var ready_for_exit: bool = not route_complete and not player.is_dead() and living_enemies().is_empty()
	if room_index == 16 and not branch_choices.has(37):
		ready_for_exit = false
	if _waves_pending() and (rooms[room_index].goal != &"trial" or trial_active):
		ready_for_exit = false
	if not ready_for_exit:
		if is_instance_valid(room_portal):
			room_portal.queue_free()
		room_portal = null
		return
	if not is_instance_valid(room_portal):
		room_portal = preload("res://scripts/room_exit_portal.gd").new()
		room_portal.position = Vector2(EXIT_POSITION.x, 596)
		room_portal.prompt_offset_x = minf(-142.0, 1280.0 - EXIT_POSITION.x - 296.0)
		room_portal.z_index = 3
		add_child(room_portal)
	var room: Dictionary = rooms[room_index]
	var context := ["进入下一房", "下一房"]
	if room.reward == &"chapter":
		context = ["完成测试" if campaign.is_empty() else "完成旅程", "结算"]
	elif not claimed.has(room.id):
		if room.reward == &"rare":
			context = ["领取试炼奖励", "奖励"] if trial_active else ["选择是否挑战", "试炼"]
		elif REWARD_PORTAL_CONTEXT.has(room.reward):
			context = REWARD_PORTAL_CONTEXT[room.reward]
	var action := input_settings.get_action_prompt(&"interact", using_controller)
	room_portal.set_prompt_text(action + " " + context[0], context[1])
	room_portal.set_opener_position(player.global_position)
	room_portal.set_prompt_visible(not ritual_open and not paused)
	room_portal.set_process(not paused)
	if is_instance_valid(entry_beam):
		entry_beam.set_process(not paused)

func _spawn_enemy(spec: Dictionary) -> void:
	super._spawn_enemy(spec)
	if is_instance_valid(portal_sound):
		_connect_enemy_audio(encounter.back())
	if campaign.is_empty():
		return
	var enemy: RogueEnemy = encounter.back()
	var profile := CombatBudget.create_profile(int(campaign.difficulty), 19, CombatBudget.NORMAL)
	enemy._max_health = maxi(1, roundi(enemy.get_max_health() * float(profile.health_multiplier)))
	enemy._current_health = enemy._max_health
	enemy._difficulty_damage_multiplier = float(profile.damage_multiplier)
	enemy.defeated.connect(_campaign_enemy_defeated.bind(enemy))

func _on_shared_player_action(action: StringName) -> void:
	if not paused and not ritual_open:
		portal_sound.handle_player_action(action, player.get_weapon_id())

func _connect_enemy_audio(enemy: RogueEnemy) -> void:
	if not enemy.sound_requested.is_connected(portal_sound.handle_enemy_sound):
		enemy.sound_requested.connect(portal_sound.handle_enemy_sound)
	var callback := _on_shared_enemy_defeat.bind(enemy)
	if not enemy.defeated.is_connected(callback):
		enemy.defeated.connect(callback)

func _on_shared_enemy_defeat(enemy: RogueEnemy) -> void:
	portal_sound.play_enemy_defeat(enemy.is_boss(), enemy.get_enemy_family() == RogueEnemy.EnemyFamily.SLIME)

func _spawn_impact_slash(enemy: RogueEnemy, facing: float, strength: float) -> void:
	super._spawn_impact_slash(enemy, facing, strength)
	preload("res://scripts/combat_hit_feedback.gd").apply(player, enemy, living_enemies(), strength > 1.0)
	portal_sound.play_impact(enemy.get_enemy_family() == RogueEnemy.EnemyFamily.SLIME, enemy.is_boss(), enemy.is_night_bat())

func _spawn_ember() -> void:
	super._spawn_ember()
	_scale_campaign_embers()

func _spawn_boss_ember(origin: Vector2, target_position: Vector2) -> void:
	super._spawn_boss_ember(origin, target_position)
	_scale_campaign_embers()

func _scale_campaign_embers() -> void:
	if campaign.is_empty():
		return
	var profile := CombatBudget.create_profile(int(campaign.difficulty), 19, CombatBudget.NORMAL)
	for ember in embers.get_children():
		ember.damage = maxi(1, roundi(12 * float(profile.damage_multiplier)))

func _campaign_enemy_defeated(enemy: RogueEnemy) -> void:
	campaign.run_shards = int(campaign.run_shards) + enemy.get_essence_reward()
	if enemy.is_boss():
		campaign_runtime.telemetry.record_boss_defeat()

func _resolve_campaign(victory: bool) -> void:
	if resolving_campaign:
		return
	resolving_campaign = true
	player.set_input_enabled(false)
	# Persist a terminal checkpoint before returning to the shared run settlement.
	var data := _snapshot()
	var terminal := data.duplicate(true)
	terminal.health = maxi(1, int(terminal.health))
	terminal.completed = true
	save_error = checkpoint_store.save_snapshot(terminal)
	if save_error != OK:
		resolving_campaign = false
		last_reward = "整局状态保存失败，请重试返回菜单"
		return
	get_tree().set_meta(&"campaign_result", {"data": data, "runtime": campaign_runtime, "path": save_path, "victory": victory, "cause": str(player.get_last_death_reason())})
	get_tree().call_deferred("change_scene_to_file", "res://scenes/Main.tscn")

func return_to_menu() -> void:
	if not campaign.is_empty() and (player.is_dead() or route_complete):
		_resolve_campaign(route_complete)
		return
	# Room-entry checkpoints are intentional: mid-fight health/enemies are not saved.
	if save_error != OK:
		save_error = checkpoint_store.save_snapshot(checkpoint)
		if save_error != OK:
			last_reward = "保存失败，已保留在当前场景，请稍后重试"
			return
	get_tree().paused = false
	get_tree().set_meta(&"title_continue_path", title_continue_path)
	get_tree().change_scene_to_file("res://scenes/Main.tscn")

func _choice_title(kind: StringName) -> String:
	if kind == &"trial":
		return "熔流试炼 · 选择是否挑战"
	if kind == &"toll":
		return "铸火代价 · 当前生命 %d/%d" % [player.get_current_health(), player.get_max_health()]
	if kind == &"shop":
		return "冷却水庭旅商 · 可购买一项"
	return super._choice_title(kind)

func _draw_hud() -> void:
	# All player-facing entries use the chapter-one HUD, including developer tests.
	pass

func _branch_interaction_prompt() -> String:
	return input_settings.get_action_prompt(&"interact", using_controller) + " 选择路线"

func _completion_text() -> String:
	return "第二章测试完成 · Esc 返回标题"

func _draw() -> void:
	super._draw()
	if rooms[room_index].layout == &"ember_pass" and is_instance_valid(route_hint_panel) and route_hint_panel.visible:
		_draw_ember_pass_steps()
	if route_complete:
		draw_rect(Rect2(300, 355, 680, 75), Color("#19212b"))
		draw_string(ThemeDB.fallback_font, Vector2(330, 390), "正式旅程可从标题页继续", HORIZONTAL_ALIGNMENT_LEFT, -1, 18)

func _draw_ember_pass_steps() -> void:
	# Mark the three ascents and the final drop on the walkable platforms.
	for index in range(1, platforms.size()):
		var platform: Rect2 = platforms[index]
		var point := platform.position + Vector2(32, 16)
		var direction := -1.0 if index == platforms.size() - 1 else 1.0
		var arrow := PackedVector2Array([
			point + Vector2(-6, 3 * direction),
			point + Vector2(0, -3 * direction),
			point + Vector2(6, 3 * direction),
		])
		draw_rect(Rect2(point - Vector2(13, 8), Vector2(26, 16)), MoonUI.BG_PANEL)
		draw_polyline(arrow, MoonUI.ACCENT_MOON, 2.0, true)

func _create_campaign_hud() -> void:
	campaign_hud = CanvasLayer.new()
	add_child(campaign_hud)
	var title := Label.new()
	var controls := Label.new()
	campaign_hud.add_child(title)
	campaign_hud.add_child(controls)
	RunHUDBuilder.build(campaign_hud, title, controls)
	campaign_presenter = RunHUDPresenter.new()
	campaign_presenter.bind(campaign_hud)
	campaign_presenter.apply_accessibility(input_settings.get_large_text_enabled(), input_settings.get_high_contrast_enabled(), input_settings.get_color_blind_enabled(), input_settings.get_hud_scale_factor())
	route_hint_panel = RunHUDBuilder._panel(campaign_hud, "RouteHint", Rect2(944, 22, 310, 56), MoonUI.ACCENT_MOON)
	route_hint_panel.pivot_offset = Vector2(route_hint_panel.size.x, 0)
	route_hint_label = RunHUDBuilder._label(route_hint_panel, "Hint", Rect2(12, 3, 286, 50), MoonUI.CAPTION, MoonUI.TEXT_PRIMARY)
	route_hint_panel.hide()
	_apply_route_hint_accessibility()
	if campaign.is_empty():
		# Development availability is local to this scene, never persisted as unlocks.
		var preview_progression := ProgressionStore.new()
		preview_progression.load_progress()
		preview_progression._unlocked_weapons = WeaponCatalog.all_weapon_ids()
		campaign_runtime.progression = preview_progression
	campaign_hud.process_mode = Node.PROCESS_MODE_ALWAYS
	chapter_menu = preload("res://scripts/chapter_menu_controller.gd").new()
	add_child(chapter_menu)
	chapter_menu.setup(self)
	campaign_pause = chapter_menu._pause_overlay
	return_panel.hide()

func _apply_route_hint_accessibility() -> void:
	route_hint_panel.scale = Vector2.ONE * input_settings.get_hud_scale_factor()
	route_hint_panel.add_theme_stylebox_override("panel", RunHUDBuilder.panel_style(MoonUI.ACCENT_MOON, input_settings.get_high_contrast_enabled()))
	route_hint_label.add_theme_font_size_override("font_size", MoonUI.CAPTION + (2 if input_settings.get_large_text_enabled() else 0))

func _queue_route_hint() -> void:
	if not is_instance_valid(route_hint_panel):
		return
	var room := rooms[room_index]
	var room_number: int = room.number
	var message := String(room.hint).replace(" · ", "\n") if room_number >= ROUTE_HINT_FIRST_ROOM else ""
	if room_number == 37:
		match int(branch_choices.get(room_number, -1)):
			0:
				message = "已选上路 · 击败高台守卫\n清场后到右侧出口"
			1:
				message = "已选下路 · 击败两只甲虫\n清场后到右侧出口"
	route_hint_label.text = message
	_route_hint_remaining = ROUTE_HINT_DURATION if not message.is_empty() else 0.0
	_update_route_hint(0.0)

func _update_route_hint(delta: float) -> void:
	var can_show: bool = tutorial_enabled and not paused and not ritual_open and not route_complete and not player.is_dead()
	if can_show:
		_route_hint_remaining = maxf(0.0, _route_hint_remaining - delta)
	var show_hint := can_show and _route_hint_remaining > 0.0
	if route_hint_panel.visible != show_hint:
		route_hint_panel.visible = show_hint
		if rooms[room_index].layout == &"ember_pass":
			queue_redraw()

func _toggle_pause() -> void:
	if route_complete or player.is_dead() or resolving_campaign:
		return
	if not paused and ritual_open and is_instance_valid(reward_view):
		var focused := get_viewport().gui_get_focus_owner()
		_reward_focus_before_pause = focused if reward_view.is_choice_action(focused) else null
	super._toggle_pause()
	if is_instance_valid(portal_sound):
		portal_sound.play_ui()
	if is_instance_valid(reward_view) and ritual_open:
		for index in range(reward_cards.size()):
			reward_view._upgrade_buttons[index].disabled = paused or not _reward_card_unavailable_reason(reward_cards[index]).is_empty()
		reward_view.shop_exit_button.disabled = paused
	if portal_delay >= 0:
		player.set_physics_process(false)
	get_tree().paused = paused
	if is_instance_valid(chapter_menu):
		chapter_menu.show_pause(paused)
	if not paused and ritual_open and is_instance_valid(reward_view):
		reward_view.focus_choice(_reward_focus_before_pause)
		_reward_focus_before_pause = null
	campaign_presenter.set_obscured(paused or ritual_open)
	_update_route_hint(0.0)

func _process(delta: float) -> void:
	if campaign_presenter == null:
		return
	_update_shared_music_state()
	if Input.is_action_just_pressed(&"cycle_weapon"):
		_cycle_journey_weapon()
	campaign_presenter.update_health(player.get_current_health(), player.get_max_health(), player.get_reduced_effects_enabled())
	campaign_presenter.update_lives(int(campaign.get("lives", 3)), 3, ["简单", "普通", "困难"][int(campaign.get("difficulty", 1))])
	campaign_presenter.update_economy(gold)
	campaign_presenter.update_room(true, route_complete, int(campaign.get("run_number", 1)), 21 + room_index, 40, "第二章", "余烬铸庭", rooms[room_index].title)
	campaign_presenter.update_equipment(player, campaign_runtime.progression)
	campaign_presenter.set_boss_visible(is_instance_valid(overseer) and overseer.get_current_health() > 0)
	if is_instance_valid(overseer):
		campaign_presenter.update_boss(overseer.get_current_health(), overseer.get_max_health(), "铸庭监炉者", overseer.phase)
	campaign_presenter.update_abilities(player, {&"cycle_weapon": input_settings.get_action_prompt(&"cycle_weapon", using_controller), &"attack": input_settings.get_action_prompt(&"attack", using_controller), &"dash": input_settings.get_action_prompt(&"dash", using_controller), &"skill": input_settings.get_action_prompt(&"skill", using_controller)})
	if last_reward != last_campaign_status:
		campaign_presenter.set_status(last_reward)
		last_campaign_status = last_reward
	campaign_presenter.set_obscured(paused or ritual_open)
	_update_route_hint(delta)

func _update_shared_music_state() -> void:
	if not is_instance_valid(portal_sound):
		return
	var state := RogueSoundscape.MusicState.EXPLORE
	if is_instance_valid(overseer) and not overseer.is_queued_for_deletion() and overseer.get_current_health() > 0:
		state = RogueSoundscape.MusicState.BOSS
	elif not living_enemies().is_empty() and not ritual_open:
		state = RogueSoundscape.MusicState.COMBAT
	portal_sound.set_music_state(state)

func _cycle_journey_weapon() -> void:
	if paused or ritual_open or route_complete or resolving_campaign or portal_delay >= 0 or player.is_dead():
		return
	var available: Array[StringName] = campaign_runtime.progression.get_unlocked_weapons()
	if available.size() < 2:
		return
	var index := available.find(player.get_requested_weapon_id())
	player.request_weapon_switch(available[posmod(index + 1, available.size())])

func _on_journey_weapon_changed(weapon_id: StringName, _weapon_name: String, _skill_name: String) -> void:
	if restoring or not journey_ready:
		return
	if not campaign.is_empty():
		campaign_runtime.progression.select_weapon(weapon_id)
		if persistence_enabled:
			campaign_runtime.progression.save_progress()
	_save_checkpoint()
