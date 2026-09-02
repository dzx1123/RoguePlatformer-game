class_name RunHUDPresenter
extends RefCounted

const HEALTH_FILL_WIDTH := 354.0

var health_label: Label
var health_fill: ColorRect
var lives_label: Label
var status_label: Label
var room_label: Label
var currency_label: Label
var equipment_label: Label
var boss_health_background: ColorRect
var boss_health_fill: ColorRect
var boss_health_label: Label
var attack_slot: Control
var dash_slot: Control
var skill_slot: Control
var weapon_slot_panels: Array[Panel] = []
var weapon_slot_labels: Array[Label] = []
var weapon_switch_label: Label
var _weapon_state_key: String = ""


func bind(hud: CanvasLayer) -> bool:
	health_label = hud.get_node_or_null("HealthBackground/HealthLabel") as Label
	health_fill = hud.get_node_or_null("HealthBackground/HealthFill") as ColorRect
	lives_label = hud.get_node_or_null("Lives") as Label
	status_label = hud.get_node_or_null("CombatStatus") as Label
	room_label = hud.get_node_or_null("RoomProgress") as Label
	currency_label = hud.get_node_or_null("Currency") as Label
	equipment_label = hud.get_node_or_null("Equipment") as Label
	boss_health_background = hud.get_node_or_null("BossHealth") as ColorRect
	if boss_health_background != null:
		boss_health_fill = boss_health_background.get_child(0) as ColorRect
		boss_health_label = boss_health_background.get_child(1) as Label
	attack_slot = hud.get_node_or_null("AbilityBar/AttackAbility") as Control
	dash_slot = hud.get_node_or_null("AbilityBar/DashAbility") as Control
	skill_slot = hud.get_node_or_null("AbilityBar/SkillAbility") as Control
	weapon_switch_label = hud.get_node_or_null("WeaponPanel/WeaponSwitch/Label") as Label
	weapon_slot_panels.clear()
	weapon_slot_labels.clear()
	for weapon_index: int in range(WeaponCatalog.all_weapon_ids().size()):
		var slot: Panel = hud.get_node_or_null(
			"WeaponPanel/WeaponSlot_%d" % weapon_index
		) as Panel
		if slot == null:
			continue
		weapon_slot_panels.append(slot)
		weapon_slot_labels.append(slot.get_node("Label") as Label)
	return is_bound()


func is_bound() -> bool:
	return (
		health_label != null
		and health_fill != null
		and lives_label != null
		and status_label != null
		and room_label != null
		and currency_label != null
		and equipment_label != null
		and boss_health_background != null
		and attack_slot != null
		and dash_slot != null
		and skill_slot != null
		and weapon_switch_label != null
		and weapon_slot_panels.size() == WeaponCatalog.all_weapon_ids().size()
	)


func update_health(current_health: int, maximum_health: int) -> void:
	if health_label == null or health_fill == null:
		return
	var health_ratio: float = clampf(
		float(current_health) / float(maxi(maximum_health, 1)),
		0.0,
		1.0
	)
	health_fill.size.x = HEALTH_FILL_WIDTH * health_ratio
	health_fill.color = (
		Color(0.90, 0.24, 0.22, 0.96)
		if health_ratio <= 0.30
		else Color(0.18, 0.82, 0.50, 0.96)
	)
	health_label.text = "生命  %d / %d" % [current_health, maximum_health]


func update_lives(lives_remaining: int, maximum_lives: int, difficulty_name: String) -> void:
	if lives_label == null:
		return
	var marks := ""
	for life_index: int in range(maximum_lives):
		marks += "●" if life_index < lives_remaining else "○"
	lives_label.text = "命数  %s   难度：%s" % [marks, difficulty_name]


func update_room(
	has_room: bool,
	run_complete: bool,
	run_number: int,
	run_seed: int,
	room_number: int,
	room_total: int,
	encounter_name: String,
	chapter_name: String,
	room_title: String
) -> void:
	if room_label == null:
		return
	if not has_room:
		room_label.text = ""
	elif run_complete:
		room_label.text = "轮次完成 · RUN %02d · S%06d\n月蚀回廊已净化" % [
			run_number,
			run_seed,
		]
	else:
		room_label.text = "房间 %02d/%02d · %s · S%06d\n%s · %s" % [
			room_number,
			room_total,
			encounter_name,
			run_seed,
			chapter_name,
			room_title,
		]


func update_economy(gold: int, meta_shards: int, run_shards: int) -> void:
	if currency_label == null:
		return
	currency_label.text = "金币 %d    局外星屑 %d（本局待结算 %d）" % [
		gold,
		meta_shards,
		run_shards,
	]


func update_equipment(player: RoguePlayer, progression: ProgressionStore) -> void:
	if equipment_label == null or progression == null:
		return
	equipment_label.text = "武器库  ·  当前：%s" % player.get_weapon_name()
	update_weapon_slots(player, progression)


func update_weapon_slots(player: RoguePlayer, progression: ProgressionStore) -> void:
	if progression == null:
		return
	var weapon_ids: Array[StringName] = WeaponCatalog.all_weapon_ids()
	if weapon_slot_panels.size() != weapon_ids.size():
		return
	var unlocked: Array[StringName] = progression.get_unlocked_weapons()
	var active_weapon: StringName = player.get_weapon_id()
	var state_parts: Array[String] = [String(active_weapon)]
	for weapon_id: StringName in weapon_ids:
		state_parts.append("1" if unlocked.has(weapon_id) else "0")
	var state_key: String = "|".join(state_parts)
	if state_key == _weapon_state_key:
		return
	_weapon_state_key = state_key

	for weapon_index: int in range(weapon_ids.size()):
		var weapon_id: StringName = weapon_ids[weapon_index]
		var weapon_data: Dictionary = WeaponCatalog.get_weapon(weapon_id)
		var accent: Color = weapon_data.get("accent", Color("#78d9ef"))
		var is_unlocked: bool = unlocked.has(weapon_id)
		var is_active: bool = weapon_id == active_weapon
		var slot: Panel = weapon_slot_panels[weapon_index]
		var slot_style := StyleBoxFlat.new()
		slot_style.bg_color = (
			Color(accent, 0.20)
			if is_active
			else Color(0.026, 0.054, 0.070, 0.98) if is_unlocked
			else Color(0.018, 0.027, 0.036, 0.96)
		)
		slot_style.border_color = (
			Color(accent, 0.96)
			if is_active
			else Color(0.37, 0.55, 0.62, 0.58) if is_unlocked
			else Color(0.22, 0.27, 0.31, 0.60)
		)
		slot_style.set_border_width_all(2 if is_active else 1)
		slot_style.corner_radius_top_left = 6
		slot_style.corner_radius_top_right = 6
		slot_style.corner_radius_bottom_left = 6
		slot_style.corner_radius_bottom_right = 6
		if is_active:
			slot_style.shadow_color = Color(accent, 0.35)
			slot_style.shadow_size = 5
		slot.add_theme_stylebox_override("panel", slot_style)

		var slot_label: Label = weapon_slot_labels[weapon_index]
		var slot_state := "未解锁"
		if is_active:
			slot_state = "装备中"
		elif is_unlocked:
			slot_state = "可切换"
		var weapon_name: String = WeaponCatalog.get_weapon_name(weapon_id)
		slot_label.text = "%s\n%s" % [weapon_name, slot_state]
		slot_label.add_theme_color_override(
			"font_color",
			accent.lightened(0.18)
			if is_active
			else Color(0.67, 0.76, 0.79, 1.0)
			if is_unlocked
			else Color(0.34, 0.39, 0.42, 1.0)
		)
		slot.tooltip_text = "%s · %s" % [weapon_name, slot_state]


func update_abilities(player: RoguePlayer, prompts: Dictionary = {}) -> void:
	if attack_slot == null or dash_slot == null or skill_slot == null:
		return
	var attack_prompt: String = String(prompts.get("attack", "J"))
	var dash_prompt: String = String(prompts.get("dash", "K"))
	var skill_prompt: String = String(prompts.get("skill", "L"))
	var up_prompt: String = String(prompts.get("aim_up", "W"))
	var down_prompt: String = String(prompts.get("aim_down", "S"))
	var cycle_weapon_prompt: String = String(prompts.get("cycle_weapon", "Q"))
	if weapon_switch_label != null:
		weapon_switch_label.text = "%s\n切换" % cycle_weapon_prompt
	var weapon_data: Dictionary = WeaponCatalog.get_weapon(player.get_weapon_id())
	var weapon_accent: Color = weapon_data.get("accent", Color("#78d9ef"))
	attack_slot.call(
		&"configure",
		0,
		"普通攻击",
		attack_prompt,
		"使用%s发动普通攻击，可配合 %s / %s 改变挥砍方向。" % [
			player.get_weapon_name(), up_prompt, down_prompt,
		],
		weapon_accent
	)
	attack_slot.call(
		&"set_cooldown",
		player.get_attack_cooldown_remaining(),
		player.get_attack_cooldown_duration()
	)
	dash_slot.call(
		&"configure",
		1,
		"闪避冲刺",
		dash_prompt,
		"向当前朝向高速闪避。冷却：2.0 秒。",
		Color("#65dcff")
	)
	dash_slot.call(
		&"set_cooldown",
		player.get_dash_cooldown_remaining(),
		player.get_dash_cooldown_duration()
	)
	skill_slot.call(
		&"configure",
		2,
		player.get_skill_name(),
		skill_prompt,
		"向前突进并释放多重月弧，造成高额范围伤害。",
		weapon_accent.lightened(0.12)
	)
	skill_slot.call(
		&"set_cooldown",
		player.get_skill_cooldown_remaining(),
		player.get_skill_cooldown_duration()
	)


func update_boss(
	current_health: int,
	maximum_health: int,
	boss_name: String,
	boss_phase: int
) -> void:
	if boss_health_background == null or boss_health_fill == null or boss_health_label == null:
		return
	var health_ratio: float = clampf(
		float(current_health) / float(maxi(1, maximum_health)),
		0.0,
		1.0
	)
	boss_health_fill.size.x = 492.0 * health_ratio
	boss_health_label.text = "%s  阶段 %d  ·  %d / %d" % [
		boss_name,
		boss_phase,
		current_health,
		maximum_health,
	]


func set_boss_visible(visible: bool) -> void:
	if boss_health_background != null:
		boss_health_background.visible = visible


func set_status(message: String) -> void:
	if status_label != null:
		status_label.text = message
