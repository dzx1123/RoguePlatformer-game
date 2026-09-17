extends "res://scripts/chapter2_full_slice.gd"

const CHECKPOINT := preload("res://scripts/chapter2_continue_store.gd")
var save_path := CHECKPOINT.CHAPTER2_PATH
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
var campaign_pause: PanelContainer
var last_campaign_status := ""

func _ready() -> void:
	# The title/victory UI pauses the shared SceneTree; scene replacement does not
	# reset it. Resume here so every entry route runs arrival animation and input.
	get_tree().paused = false
	if get_tree().has_meta(&"chapter2_save_path"):
		save_path = str(get_tree().get_meta(&"chapter2_save_path"))
		get_tree().remove_meta(&"chapter2_save_path")
	if get_tree().has_meta(&"campaign_runtime"):
		campaign_runtime = get_tree().get_meta(&"campaign_runtime")
		get_tree().remove_meta(&"campaign_runtime")
		persistence_enabled = bool(campaign_runtime.save_enabled)
	checkpoint_store = CHECKPOINT.new(save_path, persistence_enabled)
	checkpoint_store.load_snapshot()
	if get_tree().has_meta(&"chapter2_initial"):
		checkpoint_store.save_snapshot(get_tree().get_meta(&"chapter2_initial"))
		get_tree().remove_meta(&"chapter2_initial")
	if checkpoint_store.can_resume():
		campaign = checkpoint_store.get_snapshot().get("campaign", {}).duplicate(true)
	if not campaign.is_empty() and campaign_runtime.is_empty():
		var progression := ProgressionStore.new()
		progression.load_progress()
		var telemetry := RunTelemetry.new()
		telemetry.load_data()
		campaign_runtime = {"progression": progression, "telemetry": telemetry, "save_enabled": persistence_enabled}
	super._ready()
	if checkpoint_store.can_resume():
		restore_checkpoint(checkpoint_store.get_snapshot())
	else:
		checkpoint = CHECKPOINT.from_player(player, gold)
		restoring = false
	journey_ready = true
	_create_return_ui()
	_save_checkpoint()
	if not campaign.is_empty():
		player.damage_received.connect(_campaign_damage)
		_create_campaign_hud()
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
	if not checkpoint_store._is_valid_snapshot(data) or bool(data.completed):
		return false
	restoring = true
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
	if journey_ready and not campaign.is_empty():
		campaign_runtime.telemetry.complete_room(&"advanced")
	super._load_layout(index, carry_health)
	_save_checkpoint()
	if journey_ready:
		_begin_campaign_room()

func _advance_room() -> void:
	super._advance_room()
	_save_checkpoint()
	if route_complete and not campaign.is_empty() and save_error == OK:
		_resolve_campaign(true)

func choose_final_option(index: int) -> bool:
	var was_branch := choice_kind == &"branch"
	var selected := super.choose_final_option(index)
	if selected and was_branch:
		_save_checkpoint()
	return selected

func try_exit() -> bool:
	var had_chest := claimed.has(&"chain_chest")
	var result := super.try_exit()
	if result and not had_chest and claimed.has(&"chain_chest"):
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
	if not campaign.is_empty() and event.is_action_pressed(&"pause") and not event.is_echo():
		_toggle_pause()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		return_to_menu()
		return
	super._unhandled_key_input(event)

func _unhandled_input(event: InputEvent) -> void:
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
	return input_settings.get_action_prompt(&"restart", using_controller) + " 重试检查点 · " + (input_settings.get_action_prompt(&"pause", true) if using_controller else "P") + " 暂停 · Esc / 右上按钮 返回菜单"

func _objective_text() -> String:
	if not campaign.is_empty() and not route_complete:
		return super._objective_text()
	if route_complete:
		return "第二章试玩已完成 · 返回主菜单可开始新的第二章旅程"
	return super._objective_text()

func _begin_campaign_room() -> void:
	if campaign.is_empty():
		return
	campaign_runtime.telemetry.begin_room(21 + room_index, rooms[room_index].id, rooms[room_index].title, "余烬铸庭")

func _campaign_damage(amount: int, cause: StringName) -> void:
	campaign_runtime.telemetry.record_damage(amount, cause)

func _physics_process(delta: float) -> void:
	if not campaign.is_empty() and not paused and not ritual_open and not resolving_campaign:
		campaign_runtime.telemetry.tick(delta)
	super._physics_process(delta)

func _spawn_enemy(spec: Dictionary) -> void:
	super._spawn_enemy(spec)
	if campaign.is_empty():
		return
	var enemy: RogueEnemy = encounter.back()
	var profile := CombatBudget.create_profile(int(campaign.difficulty), 19, CombatBudget.NORMAL)
	enemy._max_health = maxi(1, roundi(enemy.get_max_health() * float(profile.health_multiplier)))
	enemy._current_health = enemy._max_health
	enemy._difficulty_damage_multiplier = float(profile.damage_multiplier)
	enemy.defeated.connect(_campaign_enemy_defeated.bind(enemy))

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
	get_tree().change_scene_to_file("res://scenes/Main.tscn")

func _choice_title(kind: StringName) -> String:
	if kind == &"trial":
		return "熔流试炼 · 可拒绝；失败后可从本房检查点重试"
	return super._choice_title(kind)

func _draw_hud() -> void:
	if not campaign.is_empty():
		return
	super._draw_hud()
	draw_rect(Rect2(0, 672, 1280, 48), Color("#19212b"))
	draw_string(ThemeDB.fallback_font, Vector2(34, 688), _gameplay_prompt(), HORIZONTAL_ALIGNMENT_LEFT, -1, 15)
	draw_string(ThemeDB.fallback_font, Vector2(34, 712), _journey_prompt() + " · 武器：" + WeaponCatalog.get_weapon_name(player.get_weapon_id()), HORIZONTAL_ALIGNMENT_LEFT, -1, 14)
	if player != null and player.is_dead():
		draw_string(ThemeDB.fallback_font, Vector2(340, 210), "挑战失败 · " + input_settings.get_action_prompt(&"restart", using_controller) + " 恢复检查点，或返回菜单", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("#ffd085"))

func _completion_text() -> String:
	return "第二章抢先试玩完成 · 第三章待开放 · Esc 返回菜单"

func _draw() -> void:
	super._draw()
	if route_complete:
		draw_rect(Rect2(300, 355, 680, 75), Color("#19212b"))
		var status := "完成状态已保存" if save_error == OK else "完成状态保存失败，请重试返回菜单"
		draw_string(ThemeDB.fallback_font, Vector2(330, 390), status + " · 正式章节奖励待接入", HORIZONTAL_ALIGNMENT_LEFT, -1, 18)

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
	campaign_hud.get_node("WeaponPanel/WeaponSwitch").hide()
	var ui := preload("res://scripts/ui_theme.gd")
	campaign_pause = PanelContainer.new()
	campaign_pause.position = Vector2(390, 210)
	campaign_pause.custom_minimum_size = Vector2(500, 280)
	campaign_pause.add_theme_stylebox_override("panel", ui.surface(ui.BG_PANEL, ui.ACCENT_MOON, 16, 2, 18))
	campaign_hud.add_child(campaign_pause)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 22)
	campaign_pause.add_child(column)
	var label := Label.new()
	label.text = "旅程暂停 · 余烬铸庭"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", ui.TITLE)
	column.add_child(label)
	for caption in ["继续旅程", "返回主菜单（保留进度）"]:
		var button := Button.new()
		button.text = caption
		button.custom_minimum_size.y = 68
		button.add_theme_stylebox_override("normal", ui.card(ui.ACCENT_MOON))
		button.add_theme_stylebox_override("focus", ui.card(ui.ACCENT_GOLD, true))
		column.add_child(button)
		button.pressed.connect(_toggle_pause if caption == "继续旅程" else return_to_menu)
	campaign_pause.hide()
	return_panel.hide()

func _toggle_pause() -> void:
	super._toggle_pause()
	if is_instance_valid(campaign_pause):
		campaign_pause.visible = paused
		if paused:
			campaign_pause.get_child(0).get_child(1).grab_focus()

func _process(_delta: float) -> void:
	if campaign_presenter == null:
		return
	campaign_presenter.update_health(player.get_current_health(), player.get_max_health())
	campaign_presenter.update_lives(int(campaign.lives), 3, ["简单", "普通", "困难"][int(campaign.difficulty)])
	campaign_presenter.update_economy(gold, campaign_runtime.progression.get_meta_shards(), int(campaign.run_shards))
	campaign_presenter.update_room(true, route_complete, int(campaign.run_number), int(campaign.seed), 21 + room_index, 40, "第二章", "余烬铸庭", rooms[room_index].title)
	campaign_presenter.update_equipment(player, campaign_runtime.progression)
	campaign_presenter.set_boss_visible(is_instance_valid(overseer) and overseer.get_current_health() > 0)
	if is_instance_valid(overseer):
		campaign_presenter.update_boss(overseer.get_current_health(), overseer.get_max_health(), "铸庭监炉者", overseer.phase)
	campaign_presenter.update_abilities(player, {&"attack": input_settings.get_action_prompt(&"attack", using_controller), &"dash": input_settings.get_action_prompt(&"dash", using_controller), &"skill": input_settings.get_action_prompt(&"skill", using_controller)})
	var status := last_reward if not last_reward.is_empty() else str(rooms[room_index].title) + " · " + _objective_text()
	if status != last_campaign_status:
		campaign_presenter.set_status(status)
		last_campaign_status = status
	campaign_presenter.set_obscured(paused or ritual_open)

func _open_choice(kind: StringName) -> void:
	super._open_choice(kind)
	var ui := preload("res://scripts/ui_theme.gd")
	ritual_panel.add_theme_stylebox_override("panel", ui.surface(ui.BG_PANEL, ui.ACCENT_MOON, ui.PANEL_RADIUS, 1, 18))
	for child in ritual_panel.get_child(0).get_children():
		if child is Button:
			child.add_theme_stylebox_override("normal", ui.card(ui.ACCENT_MOON))
			child.add_theme_stylebox_override("hover", ui.card(ui.ACCENT_MOON, true))
			child.add_theme_stylebox_override("focus", ui.card(ui.ACCENT_GOLD, true))
			child.add_theme_color_override("font_color", ui.TEXT_PRIMARY)
			child.add_theme_font_size_override("font_size", ui.BODY)
