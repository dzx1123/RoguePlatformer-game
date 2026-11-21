class_name RunHUDPresenter
extends RefCounted

const BUILDER := preload("res://scripts/run_hud_builder.gd")
const UI := preload("res://scripts/ui_theme.gd")

var _dock: Control
var _vitals_panel: Panel
var _weapon_panel: Panel
var _room_card: Panel
var _status_panel: Panel
var _status_tween: Tween
var _health_tween: Tween
var _last_health: int = -1
var _last_maximum_health: int = -1
var _obscured: bool = false
var _reward_visible: bool = false
var _color_blind_enabled: bool = false
var _high_contrast: bool = false

var health_label: Label
var health_fill: ColorRect
var lives_label: Label
var status_label: Label
var room_label: Label
var room_name_label: Label
var currency_label: Label
var active_weapon_label: Label
var boss_health_background: Panel
var boss_health_fill: ColorRect
var boss_health_label: Label
var attack_slot: Control
var dash_slot: Control
var skill_slot: Control
var weapon_switch_label: Label
var _weapon_switch: Panel
var _weapon_slots: Array[ColorRect] = []
var _weapon_state_key: String = ""


func bind(hud: CanvasLayer) -> bool:
	_dock = hud.get_node_or_null("BottomHUD") as Control
	if _dock == null:
		return false
	_vitals_panel = _dock.get_node("VitalsPanel") as Panel
	_weapon_panel = _dock.get_node("WeaponPanel") as Panel
	_room_card = hud.get_node("RoomCard") as Panel
	_status_panel = hud.get_node("StatusToast") as Panel
	health_label = _vitals_panel.get_node("HealthBackground/HealthLabel") as Label
	health_fill = _vitals_panel.get_node("HealthBackground/HealthFill") as ColorRect
	lives_label = _vitals_panel.get_node("Lives") as Label
	currency_label = _vitals_panel.get_node("Currency") as Label
	status_label = _status_panel.get_node("CombatStatus") as Label
	room_label = _room_card.get_node("RoomProgress") as Label
	room_name_label = _room_card.get_node("RoomName") as Label
	active_weapon_label = _weapon_panel.get_node("ActiveWeapon") as Label
	boss_health_background = hud.get_node("BossHealth") as Panel
	boss_health_fill = boss_health_background.get_node("BossFill") as ColorRect
	boss_health_label = boss_health_background.get_node("BossLabel") as Label
	attack_slot = _dock.get_node("AbilityBar/AttackAbility") as Control
	dash_slot = _dock.get_node("AbilityBar/DashAbility") as Control
	skill_slot = _dock.get_node("AbilityBar/SkillAbility") as Control
	_weapon_switch = _weapon_panel.get_node("WeaponSwitch") as Panel
	weapon_switch_label = _weapon_switch.get_node("Label") as Label
	_weapon_slots.clear()
	_weapon_state_key = ""
	for weapon_index: int in range(WeaponCatalog.all_weapon_ids().size()):
		_weapon_slots.append(_weapon_panel.get_node("WeaponSlot_%d" % weapon_index) as ColorRect)
	return is_bound()


func is_bound() -> bool:
	return is_instance_valid(_dock)


func apply_accessibility(
	large_text: bool,
	high_contrast: bool,
	color_blind_enabled: bool = false,
	hud_scale: float = 1.0
) -> void:
	_color_blind_enabled = color_blind_enabled
	if _high_contrast != high_contrast:
		_high_contrast = high_contrast
		_weapon_state_key = ""
	var scale := Vector2.ONE * clampf(hud_scale, 0.90, 1.10)
	for item: Control in [_dock, _room_card, _status_panel, boss_health_background]:
		item.scale = scale
	var caption_size := UI.CAPTION + (2 if large_text else 0)
	var body_size := UI.BODY + (2 if large_text else 0)
	for caption: Label in [room_label, status_label, lives_label, currency_label, weapon_switch_label, boss_health_label]:
		caption.add_theme_font_size_override("font_size", caption_size)
	for body: Label in [health_label, room_name_label, active_weapon_label]:
		body.add_theme_font_size_override("font_size", body_size)
	room_label.add_theme_color_override("font_color", UI.TEXT_PRIMARY if high_contrast else UI.TEXT_SECONDARY)
	lives_label.add_theme_color_override("font_color", Color("#a8e8ff") if color_blind_enabled else UI.TEXT_PRIMARY)
	currency_label.add_theme_color_override("font_color", Color("#ffd166") if color_blind_enabled else UI.ACCENT_GOLD)
	weapon_switch_label.add_theme_color_override("font_color", UI.TEXT_PRIMARY if high_contrast else UI.TEXT_SECONDARY)
	health_fill.color = _health_color(health_fill.size.x / BUILDER.HEALTH_FILL_WIDTH)
	boss_health_fill.color = Color("#ff9f43") if color_blind_enabled else UI.ACCENT_RISK
	_vitals_panel.add_theme_stylebox_override("panel", BUILDER.panel_style(UI.ACCENT_MOON, high_contrast))
	_room_card.add_theme_stylebox_override("panel", BUILDER.panel_style(UI.ACCENT_MOON, high_contrast))
	_status_panel.add_theme_stylebox_override("panel", BUILDER.panel_style(UI.ACCENT_GOLD, high_contrast))
	boss_health_background.add_theme_stylebox_override("panel", BUILDER.panel_style(UI.ACCENT_RISK, high_contrast))
	_weapon_switch.add_theme_stylebox_override("panel", BUILDER.panel_style(UI.ACCENT_GOLD, high_contrast))
	for slot: Control in [attack_slot, dash_slot, skill_slot]:
		slot.call(&"apply_accessibility", large_text, high_contrast)


func _health_color(health_ratio: float) -> Color:
	if health_ratio <= 0.30:
		return Color("#ff9f43") if _color_blind_enabled else UI.ACCENT_RISK
	return Color("#4cc9ff") if _color_blind_enabled else UI.ACCENT_MOON


func update_health(current_health: int, maximum_health: int, reduced: bool = false) -> void:
	if current_health == _last_health and maximum_health == _last_maximum_health:
		return
	var health_ratio := clampf(float(current_health) / float(maxi(maximum_health, 1)), 0.0, 1.0)
	health_fill.size.x = BUILDER.HEALTH_FILL_WIDTH * health_ratio
	health_fill.color = _health_color(health_ratio)
	health_label.text = "%d / %d" % [current_health, maximum_health]
	if _health_tween != null and _health_tween.is_valid():
		_health_tween.kill()
	if _last_health >= 0 and current_health < _last_health:
		var resting_color := health_fill.color
		health_fill.color = UI.ACCENT_RISK
		_health_tween = health_fill.create_tween()
		_health_tween.tween_interval(0.016 if reduced else 0.12)
		_health_tween.tween_property(health_fill, "color", resting_color, 0.0)
	_last_health = current_health
	_last_maximum_health = maximum_health


func update_lives(lives_remaining: int, maximum_lives: int, difficulty_name: String) -> void:
	var marks := ""
	for life_index: int in range(maximum_lives):
		marks += "●" if life_index < lives_remaining else "○"
	lives_label.text = "命数 %s   %s" % [marks, difficulty_name]


func update_room(
	has_room: bool,
	run_complete: bool,
	run_number: int,
	room_number: int,
	room_total: int,
	encounter_name: String,
	chapter_name: String,
	room_title: String
) -> void:
	_room_card.tooltip_text = encounter_name
	if not has_room:
		room_label.text = ""
		room_name_label.text = ""
	elif run_complete:
		room_label.text = chapter_name
		room_name_label.text = "第 %d 轮完成" % run_number
	else:
		room_label.text = "%s  ·  %d/%d 房" % [chapter_name, room_number, room_total]
		room_name_label.text = room_title
	_room_card.visible = has_room and not _obscured


func update_economy(gold: int) -> void:
	currency_label.text = "金币 %d" % gold


func update_equipment(player: RoguePlayer, progression: ProgressionStore) -> void:
	var weapon_ids := WeaponCatalog.all_weapon_ids()
	var unlocked := progression.get_unlocked_weapons()
	var active_weapon := player.get_weapon_id()
	var state_parts: Array[String] = [String(active_weapon)]
	for weapon_id: StringName in weapon_ids:
		state_parts.append("1" if unlocked.has(weapon_id) else "0")
	var state_key := "|".join(state_parts)
	if state_key == _weapon_state_key:
		return
	_weapon_state_key = state_key

	var weapon_data := WeaponCatalog.get_weapon(active_weapon)
	var accent: Color = weapon_data.get("accent", UI.ACCENT_GOLD)
	active_weapon_label.text = player.get_weapon_name()
	_weapon_panel.add_theme_stylebox_override("panel", BUILDER.panel_style(accent, _high_contrast))
	_weapon_switch.modulate.a = 1.0 if unlocked.size() > 1 or _high_contrast else 0.66
	for index: int in range(weapon_ids.size()):
		var weapon_id := weapon_ids[index]
		var active := weapon_id == active_weapon
		var available := unlocked.has(weapon_id)
		var slot := _weapon_slots[index]
		slot.color = accent if active else UI.TEXT_SECONDARY if available else UI.STROKE_QUIET
		var state := "装备中" if active else "可切换" if available else "未解锁"
		slot.tooltip_text = "%s · %s" % [WeaponCatalog.get_weapon_name(weapon_id), state]


func update_abilities(player: RoguePlayer, prompts: Dictionary = {}) -> void:
	var attack_prompt := String(prompts.get("attack", "J"))
	var dash_prompt := String(prompts.get("dash", "K"))
	var skill_prompt := String(prompts.get("skill", "L"))
	var up_prompt := String(prompts.get("aim_up", "W"))
	var down_prompt := String(prompts.get("aim_down", "S"))
	var cycle_weapon_prompt := String(prompts.get("cycle_weapon", "Q"))
	weapon_switch_label.text = "切换 %s" % cycle_weapon_prompt
	var weapon_data := WeaponCatalog.get_weapon(player.get_weapon_id())
	var weapon_accent: Color = weapon_data.get("accent", UI.ACCENT_MOON)
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
		"向当前朝向高速闪避，期间免疫敌人攻击。冷却：2.0 秒。",
		Color("#65dcff")
	)
	dash_slot.call(
		&"set_cooldown",
		player.get_dash_cooldown_remaining(),
		player.get_dash_cooldown_duration()
	)
	var skill_description := "向上挥出完整月轮，在满月斩击时造成范围伤害。"
	match player.get_weapon_id():
		WeaponCatalog.TWIN_BLADES:
			skill_description = "向前突进，连续发动三段快速斩击。"
		WeaponCatalog.GREATSWORD:
			skill_description = "蓄势重砸地面，造成大范围裂地伤害。"
	skill_slot.call(
		&"configure",
		2,
		player.get_skill_name(),
		skill_prompt,
		skill_description,
		weapon_accent.lightened(0.12)
	)
	skill_slot.call(
		&"set_cooldown",
		player.get_skill_cooldown_remaining(),
		player.get_skill_cooldown_duration()
	)


func update_boss(current_health: int, maximum_health: int, boss_name: String, boss_phase: int) -> void:
	var health_ratio := clampf(float(current_health) / float(maxi(1, maximum_health)), 0.0, 1.0)
	boss_health_fill.size.x = BUILDER.BOSS_FILL_WIDTH * health_ratio
	boss_health_label.text = "%s  ·  阶段 %d  ·  %d / %d" % [
		boss_name, boss_phase, current_health, maximum_health,
	]


func set_boss_visible(visible: bool) -> void:
	boss_health_background.visible = visible


func set_status(message: String) -> void:
	status_label.text = message if message.length() <= 28 else message.left(27) + "…"
	_status_panel.tooltip_text = message
	if _status_tween != null and _status_tween.is_valid():
		_status_tween.kill()
	_status_panel.modulate.a = 1.0
	if not message.is_empty():
		_status_tween = _status_panel.create_tween()
		_status_tween.tween_property(_status_panel, "modulate:a", 0.0, 0.35).set_delay(2.65)
	_refresh_status_visibility()


func set_obscured(obscured: bool, reward_visible: bool = false) -> void:
	_obscured = obscured
	_reward_visible = reward_visible
	_dock.visible = not obscured
	_dock.modulate.a = 0.42 if reward_visible else 1.0
	_room_card.visible = not obscured and not room_label.text.is_empty()
	# Keep the boss's own visibility state when a modal temporarily suppresses the HUD.
	boss_health_background.modulate.a = 0.0 if obscured else 1.0
	_refresh_status_visibility()


func set_modal_suppressed(suppressed: bool) -> void:
	set_obscured(suppressed)


func _refresh_status_visibility() -> void:
	_status_panel.visible = not _obscured and not _reward_visible and not status_label.text.is_empty()
