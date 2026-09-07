class_name RunHUDPresenter
extends RefCounted

const HEALTH_FILL_WIDTH := 316.0
const UI := preload("res://scripts/ui_theme.gd")
const HUD_SCALE_ANCHORS := {
	"VitalsPanel": Vector2(32.0, 716.0),
	"HealthBackground": Vector2(32.0, 716.0),
	"Lives": Vector2(32.0, 716.0),
	"Currency": Vector2(32.0, 716.0),
	"AbilityPanel": Vector2(640.0, 716.0),
	"AbilityBar": Vector2(640.0, 716.0),
	"WeaponPanel": Vector2(1248.0, 716.0),
	"Equipment": Vector2(1248.0, 716.0),
	"RoomCard": Vector2(40.0, 28.0),
	"RoomProgress": Vector2(40.0, 28.0),
	"StatusToast": Vector2(640.0, 620.0),
	"CombatStatus": Vector2(640.0, 620.0),
	"BossHealth": Vector2(640.0, 44.0),
}
const HUD_SCALE_COLUMNS: Array[Array] = [
	["VitalsPanel", "HealthBackground", "Lives", "Currency"],
	["AbilityPanel", "AbilityBar"],
	["WeaponPanel", "Equipment"],
]
const HUD_CANVAS := Vector2(1280.0, 720.0)
const HUD_SCALE_MARGIN := 8.0
const HUD_SCALE_GAP := 8.0
const HUD_DOCK_TOP := 640.0
var _hud: CanvasLayer
var _status_tween: Tween
var _health_tween: Tween
var _last_health: int = -1
var _status_panel: Panel
var _obscured: bool = false
var _reward_visible: bool = false
var _color_blind_enabled: bool = false

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
	_hud = hud
	_status_panel = hud.get_node("StatusToast") as Panel
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


func apply_accessibility(
	large_text: bool,
	high_contrast: bool,
	color_blind_enabled: bool = false,
	hud_scale: float = 1.0
) -> void:
	## Absolute sizes from flags — never compound on repeated calls.
	_color_blind_enabled = color_blind_enabled
	_apply_hud_scale(clampf(hud_scale, 0.90, 1.10))
	var caption_size: int = UI.CAPTION + (2 if large_text else 0)
	var body_size: int = UI.BODY + (2 if large_text else 0)
	var micro_size: int = 12 + (2 if large_text else 0)
	if room_label != null:
		room_label.add_theme_font_size_override("font_size", caption_size)
		room_label.add_theme_color_override(
			"font_color",
			UI.TEXT_PRIMARY if high_contrast else UI.TEXT_SECONDARY
		)
	if status_label != null:
		status_label.add_theme_font_size_override("font_size", caption_size)
		var status_outline: int = 1 + (1 if high_contrast else 0)
		status_label.add_theme_constant_override("outline_size", mini(status_outline, 3))
	if health_label != null:
		health_label.add_theme_font_size_override("font_size", body_size)
		var health_outline: int = 2 + (1 if high_contrast else 0)
		health_label.add_theme_constant_override("outline_size", mini(health_outline, 3))
	if lives_label != null:
		lives_label.add_theme_font_size_override("font_size", micro_size)
		lives_label.add_theme_color_override(
			"font_color",
			Color("#a8e8ff") if color_blind_enabled else Color(0.94, 0.78, 0.49, 1.0)
		)
	if currency_label != null:
		currency_label.add_theme_font_size_override("font_size", micro_size)
		currency_label.add_theme_color_override(
			"font_color",
			Color("#ffd166") if color_blind_enabled else Color(1.0, 0.83, 0.47, 1.0)
		)
	if equipment_label != null:
		equipment_label.add_theme_font_size_override("font_size", micro_size)
	if health_fill != null:
		health_fill.color = _health_color(health_fill.size.x / HEALTH_FILL_WIDTH)
	if boss_health_fill != null:
		boss_health_fill.color = (
			Color("#ff9f43") if color_blind_enabled else Color(0.88, 0.18, 0.22, 0.96)
		)
	if _hud != null and _hud.has_node("BottomHUD"):
		var bottom_hud := _hud.get_node("BottomHUD") as Panel
		if bottom_hud != null:
			var bottom_style := StyleBoxFlat.new()
			bottom_style.bg_color = Color(UI.BG_PANEL, 0.92)
			bottom_style.border_color = (
				UI.TEXT_PRIMARY
				if high_contrast
				else Color("#4cc9ff") if color_blind_enabled else UI.ACCENT_MOON
			)
			bottom_style.border_width_top = 2
			bottom_style.shadow_color = Color(0.0, 0.0, 0.0, 0.66)
			bottom_style.shadow_size = 14
			bottom_style.shadow_offset = Vector2(0.0, -4.0)
			bottom_hud.add_theme_stylebox_override("panel", bottom_style)


func _apply_hud_scale(scale_factor: float) -> void:
	if _hud == null:
		return
	var requested_scale: float = clampf(scale_factor, 0.90, 1.10)
	var applied_scale: float = _fitted_bottom_hud_scale(requested_scale)
	for path_value: Variant in HUD_SCALE_ANCHORS:
		var path := String(path_value)
		var control := _hud.get_node_or_null(path) as Control
		if control == null:
			continue
		if not control.has_meta(&"hud_scale_base_position"):
			control.set_meta(&"hud_scale_base_position", control.position)
			control.set_meta(&"hud_scale_base_scale", control.scale)
		var base_position: Vector2 = control.get_meta(&"hud_scale_base_position")
		var base_scale: Vector2 = control.get_meta(&"hud_scale_base_scale")
		var anchor: Vector2 = HUD_SCALE_ANCHORS[path]
		control.position = anchor + (base_position - anchor) * applied_scale
		control.scale = base_scale * applied_scale
	if applied_scale > 1.0:
		_pack_bottom_hud_columns()
	_sync_bottom_dock_to_scaled_hud()


func _fitted_bottom_hud_scale(requested_scale: float) -> float:
	if requested_scale <= 1.0:
		return requested_scale
	var native_width: float = 0.0
	for column: Array in HUD_SCALE_COLUMNS:
		var panel := _hud.get_node_or_null(String(column[0])) as Control
		if panel == null:
			return requested_scale
		native_width += panel.size.x
	if native_width <= 0.0:
		return requested_scale
	var inner_width: float = (
		HUD_CANVAS.x
		- HUD_SCALE_MARGIN * 2.0
		- HUD_SCALE_GAP * float(HUD_SCALE_COLUMNS.size() - 1)
	)
	return minf(requested_scale, inner_width / native_width)


func _pack_bottom_hud_columns() -> void:
	var cursor_x: float = HUD_SCALE_MARGIN
	for column: Array in HUD_SCALE_COLUMNS:
		var panel := _hud.get_node_or_null(String(column[0])) as Control
		if panel == null:
			return
		var delta_x: float = cursor_x - panel.position.x
		for path_value: Variant in column:
			var control := _hud.get_node_or_null(String(path_value)) as Control
			if control != null:
				control.position.x += delta_x
		cursor_x += panel.size.x * panel.scale.x + HUD_SCALE_GAP


func _sync_bottom_dock_to_scaled_hud() -> void:
	var dock := _hud.get_node_or_null("BottomHUD") as Control
	if dock == null:
		return
	var dock_top: float = HUD_DOCK_TOP
	var vitals := _hud.get_node_or_null("VitalsPanel") as Control
	if vitals != null:
		dock_top = minf(dock_top, vitals.position.y)
	dock.position = Vector2(0.0, dock_top)
	dock.size = Vector2(HUD_CANVAS.x, HUD_CANVAS.y - dock_top)


func _health_color(health_ratio: float) -> Color:
	if health_ratio <= 0.30:
		return Color("#ff9f43") if _color_blind_enabled else UI.ACCENT_RISK
	return Color("#4cc9ff") if _color_blind_enabled else UI.ACCENT_MOON

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


func update_health(current_health: int, maximum_health: int, reduced: bool = false) -> void:
	if health_label == null or health_fill == null:
		return
	var health_ratio: float = clampf(
		float(current_health) / float(maxi(maximum_health, 1)),
		0.0,
		1.0
	)
	health_fill.size.x = HEALTH_FILL_WIDTH * health_ratio
	health_fill.color = _health_color(health_ratio)
	health_label.text = "%d / %d" % [current_health, maximum_health]
	if _health_tween != null and _health_tween.is_valid():
		_health_tween.kill()
	if _last_health >= 0 and current_health < _last_health:
		var resting_color: Color = health_fill.color
		health_fill.color = UI.ACCENT_RISK
		_health_tween = health_fill.create_tween()
		_health_tween.tween_interval(0.016 if reduced else 0.12)
		_health_tween.tween_property(health_fill, "color", resting_color, 0.0)
	_last_health = current_health


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
	room_label.tooltip_text = "%s · %s · %s" % [chapter_name, encounter_name, room_title]
	if not has_room:
		room_label.text = ""
	elif run_complete:
		room_label.text = "第 %d 轮完成 · S%d" % [run_number, run_seed]
	else:
		room_label.text = "第 %d/%d 房 · S%d" % [room_number, room_total, run_seed]


func update_economy(gold: int, meta_shards: int, run_shards: int) -> void:
	if currency_label == null:
		return
	currency_label.text = "金币 %d   星屑 %d   本局 +%d" % [
		gold,
		meta_shards,
		run_shards,
	]


func update_equipment(player: RoguePlayer, progression: ProgressionStore) -> void:
	if equipment_label == null or progression == null:
		return
	equipment_label.text = "%s" % player.get_weapon_name()
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
			Color(accent, 0.22)
			if is_active
			else Color(0.024, 0.064, 0.088, 0.32) if is_unlocked
			else Color(0.012, 0.025, 0.040, 0.30)
		)
		slot_style.border_color = (
			Color(accent, 0.88)
			if is_active
			else Color(0.47, 0.72, 0.80, 0.26) if is_unlocked
			else Color(0.30, 0.38, 0.45, 0.22)
		)
		slot_style.set_border_width_all(1)
		slot_style.corner_radius_top_left = 8
		slot_style.corner_radius_top_right = 8
		slot_style.corner_radius_bottom_left = 8
		slot_style.corner_radius_bottom_right = 8
		if is_active:
			slot_style.shadow_color = Color(accent, 0.26)
			slot_style.shadow_size = 4
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
	if status_label == null:
		return
	status_label.tooltip_text = message
	status_label.text = message if message.length() <= 28 else message.left(27) + "…"
	if _status_tween != null and _status_tween.is_valid():
		_status_tween.kill()
	status_label.modulate.a = 1.0
	_status_panel.modulate.a = 1.0
	_status_tween = status_label.create_tween().set_parallel(true)
	_status_tween.tween_property(status_label, "modulate:a", 0.0, 0.35).set_delay(2.65)
	_status_tween.tween_property(_status_panel, "modulate:a", 0.0, 0.35).set_delay(2.65)
	_refresh_status_visibility()


func set_obscured(obscured: bool, reward_visible: bool = false) -> void:
	_obscured = obscured
	_reward_visible = reward_visible
	var chrome_paths := [
		"BottomHUD", "VitalsPanel", "AbilityPanel", "WeaponPanel", "HealthBackground",
		"Lives", "Currency", "Equipment", "AbilityBar", "RoomCard", "RoomProgress",
	]
	var dim_paths := [
		"BottomHUD", "VitalsPanel", "AbilityPanel", "WeaponPanel", "HealthBackground",
		"Lives", "Currency", "Equipment", "AbilityBar",
	]
	for path in chrome_paths:
		var item := _hud.get_node(path) as CanvasItem
		item.visible = not obscured
	# Soft deprioritize under reward toast without hiding room caption.
	var dim_alpha: float = 0.38 if (reward_visible and not obscured) else 1.0
	for path in dim_paths:
		(_hud.get_node(path) as CanvasItem).modulate.a = dim_alpha
	# Boss visibility remains owned by combat; opacity only suppresses the overlay.
	boss_health_background.modulate.a = 0.0 if obscured else 1.0
	_refresh_status_visibility()


func set_modal_suppressed(suppressed: bool) -> void:
	## Prefer hard-hide for full-screen modals; soft-dim is via set_obscured(_, reward_visible).
	set_obscured(suppressed, false)

func _refresh_status_visibility() -> void:
	var show: bool = not _obscured and not _reward_visible
	status_label.visible = show
	_status_panel.visible = show
