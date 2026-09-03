class_name RunBuildOverview
extends Control

## A paused, player-facing readout of the current run build. It deliberately
## derives every displayed value from RoguePlayer and UpgradeCatalog, so the
## panel cannot drift away from the actual combat rules.

signal close_requested

const DISPLAY_SIZE := Vector2(1280.0, 840.0)
const UPGRADE_CATALOG := preload("res://scripts/upgrade_catalog.gd")

var _weapon_name_label: Label
var _weapon_detail_label: RichTextLabel
var _stats_label: RichTextLabel
var _upgrades_label: RichTextLabel
var _synergy_label: RichTextLabel
var _total_label: Label
var _close_button: Button


func _ready() -> void:
	position = Vector2.ZERO
	size = DISPLAY_SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_interface()
	visible = false


func refresh(player: RoguePlayer, overview_prompt: String) -> void:
	if not is_instance_valid(player):
		return
	var stats: Dictionary = player.get_run_stats()
	var weapon_id: StringName = player.get_weapon_id()
	var weapon: Dictionary = WeaponCatalog.get_weapon(weapon_id)
	var upgrade_counts: Dictionary = player.get_run_upgrade_counts()
	var total_upgrades: int = player.get_total_run_upgrade_count()

	_weapon_name_label.text = "%s\n%s" % [
		player.get_weapon_name(),
		player.get_skill_name(),
	]
	_weapon_detail_label.text = _get_weapon_flow_text(weapon_id, weapon)
	_stats_label.text = _format_stats(stats, player)
	_upgrades_label.text = _format_upgrades(upgrade_counts, weapon_id)
	_synergy_label.text = _format_synergies(upgrade_counts, weapon_id)
	_total_label.text = "本局强化  %d 层 · 当前武器流派已同步" % total_upgrades
	_close_button.text = "关闭  %s" % overview_prompt


func focus_close_button() -> void:
	if is_instance_valid(_close_button):
		_close_button.grab_focus()


func get_snapshot() -> Dictionary:
	return {
		"visible": visible,
		"weapon_text": _weapon_name_label.text if is_instance_valid(_weapon_name_label) else "",
		"stats_text": _stats_label.text if is_instance_valid(_stats_label) else "",
		"upgrades_text": _upgrades_label.text if is_instance_valid(_upgrades_label) else "",
		"synergy_text": _synergy_label.text if is_instance_valid(_synergy_label) else "",
		"total_text": _total_label.text if is_instance_valid(_total_label) else "",
	}


func _build_interface() -> void:
	var dimmer := ColorRect.new()
	dimmer.name = "Dimmer"
	dimmer.size = DISPLAY_SIZE
	dimmer.color = Color(0.006, 0.014, 0.028, 0.86)
	dimmer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dimmer)

	var sheet := Panel.new()
	sheet.name = "BuildSheet"
	sheet.position = Vector2(58.0, 42.0)
	sheet.size = Vector2(1164.0, 756.0)
	sheet.mouse_filter = Control.MOUSE_FILTER_STOP
	sheet.add_theme_stylebox_override("panel", _make_sheet_style())
	add_child(sheet)

	var top_rule := ColorRect.new()
	top_rule.position = Vector2(28.0, 94.0)
	top_rule.size = Vector2(1108.0, 2.0)
	top_rule.color = Color(0.37, 0.84, 0.94, 0.70)
	top_rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sheet.add_child(top_rule)

	var title := _make_label(
		"Title",
		Vector2(30.0, 22.0),
		Vector2(700.0, 34.0),
		"构筑总览",
		27,
		Color(0.82, 0.95, 1.0, 1.0)
	)
	sheet.add_child(title)

	_total_label = _make_label(
		"Total",
		Vector2(32.0, 60.0),
		Vector2(760.0, 24.0),
		"",
		14,
		Color(0.56, 0.77, 0.84, 1.0)
	)
	sheet.add_child(_total_label)

	_close_button = Button.new()
	_close_button.name = "CloseButton"
	_close_button.position = Vector2(976.0, 29.0)
	_close_button.size = Vector2(158.0, 42.0)
	_close_button.add_theme_font_size_override("font_size", 15)
	_close_button.pressed.connect(_on_close_pressed)
	sheet.add_child(_close_button)

	var weapon_card := _create_card(
		sheet,
		"WeaponCard",
		Vector2(28.0, 118.0),
		Vector2(300.0, 430.0),
		"当前武器 · 流派",
		Color("#72d9ed")
	)
	_weapon_name_label = _make_label(
		"WeaponName",
		Vector2(20.0, 58.0),
		Vector2(260.0, 72.0),
		"",
		23,
		Color(0.91, 0.98, 1.0, 1.0)
	)
	_weapon_name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	weapon_card.add_child(_weapon_name_label)
	_weapon_detail_label = _make_rich_label(
		"WeaponDetail",
		Vector2(20.0, 144.0),
		Vector2(260.0, 266.0),
		15,
		Color(0.74, 0.87, 0.92, 1.0)
	)
	weapon_card.add_child(_weapon_detail_label)

	var stats_card := _create_card(
		sheet,
		"StatsCard",
		Vector2(343.0, 118.0),
		Vector2(350.0, 430.0),
		"关键属性 · 实际生效",
		Color("#8daeff")
	)
	_stats_label = _make_rich_label(
		"Stats",
		Vector2(20.0, 58.0),
		Vector2(310.0, 350.0),
		16,
		Color(0.83, 0.90, 1.0, 1.0)
	)
	stats_card.add_child(_stats_label)

	var upgrades_card := _create_card(
		sheet,
		"UpgradesCard",
		Vector2(708.0, 118.0),
		Vector2(428.0, 430.0),
		"已选强化 · 层数 / 上限",
		Color("#efbd68")
	)
	_upgrades_label = _make_rich_label(
		"Upgrades",
		Vector2(20.0, 58.0),
		Vector2(388.0, 350.0),
		15,
		Color(0.92, 0.88, 0.76, 1.0)
	)
	_upgrades_label.scroll_active = true
	upgrades_card.add_child(_upgrades_label)

	var synergy_card := _create_card(
		sheet,
		"SynergyCard",
		Vector2(28.0, 568.0),
		Vector2(1108.0, 142.0),
		"联动关系 · 下一次强化方向",
		Color("#c392ff")
	)
	_synergy_label = _make_rich_label(
		"Synergies",
		Vector2(20.0, 51.0),
		Vector2(1068.0, 80.0),
		15,
		Color(0.90, 0.82, 1.0, 1.0)
	)
	synergy_card.add_child(_synergy_label)

	var hint := _make_label(
		"Hint",
		Vector2(30.0, 721.0),
		Vector2(1100.0, 20.0),
		"数值会在选牌或切换武器后立即更新；武器专属强化只会在对应武器装备时生效。",
		13,
		Color(0.49, 0.68, 0.75, 0.95)
	)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sheet.add_child(hint)


func _create_card(
	parent: Control,
	node_name: String,
	card_position: Vector2,
	card_size: Vector2,
	heading: String,
	accent: Color
) -> Panel:
	var card := Panel.new()
	card.name = node_name
	card.position = card_position
	card.size = card_size
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_theme_stylebox_override("panel", _make_card_style(accent))
	parent.add_child(card)

	var accent_rule := ColorRect.new()
	accent_rule.position = Vector2(0.0, 0.0)
	accent_rule.size = Vector2(card_size.x, 3.0)
	accent_rule.color = Color(accent, 0.92)
	accent_rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(accent_rule)

	var title := _make_label(
		"Heading",
		Vector2(20.0, 19.0),
		Vector2(card_size.x - 40.0, 26.0),
		heading,
		16,
		accent.lightened(0.18)
	)
	card.add_child(title)
	return card


func _make_label(
	node_name: String,
	label_position: Vector2,
	label_size: Vector2,
	label_text: String,
	font_size: int,
	font_color: Color
) -> Label:
	var label := Label.new()
	label.name = node_name
	label.position = label_position
	label.size = label_size
	label.text = label_text
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", font_color)
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.02, 0.04, 0.78))
	label.add_theme_constant_override("outline_size", 1)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _make_rich_label(
	node_name: String,
	label_position: Vector2,
	label_size: Vector2,
	font_size: int,
	font_color: Color
) -> RichTextLabel:
	var label := RichTextLabel.new()
	label.name = node_name
	label.position = label_position
	label.size = label_size
	label.bbcode_enabled = true
	label.fit_content = false
	label.scroll_active = false
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("normal_font_size", font_size)
	label.add_theme_color_override("default_color", font_color)
	return label


func _make_sheet_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.018, 0.042, 0.069, 0.985)
	style.border_color = Color(0.36, 0.83, 0.93, 0.82)
	style.set_border_width_all(2)
	style.corner_radius_top_left = 14
	style.corner_radius_top_right = 14
	style.corner_radius_bottom_left = 14
	style.corner_radius_bottom_right = 14
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.62)
	style.shadow_size = 18
	style.shadow_offset = Vector2(0.0, 8.0)
	return style


func _make_card_style(accent: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.063, 0.096, 0.96)
	style.border_color = Color(accent, 0.58)
	style.set_border_width_all(1)
	style.corner_radius_top_left = 9
	style.corner_radius_top_right = 9
	style.corner_radius_bottom_left = 9
	style.corner_radius_bottom_right = 9
	return style


func _format_stats(stats: Dictionary, player: RoguePlayer) -> String:
	var attack_cooldown: float = float(stats.get("attack_cooldown", 0.0))
	var skill_cooldown: float = float(stats.get("skill_cooldown", 0.0))
	return (
		"[color=#81dcff]生命上限[/color]  %d\n"
		+ "[color=#81dcff]普通伤害[/color]  %d    [color=#81dcff]攻击频率[/color]  %.2f 次/秒\n"
		+ "[color=#81dcff]普通范围[/color]  ×%.2f    [color=#81dcff]移动速度[/color]  %.0f\n"
		+ "[color=#81dcff]冲刺速度[/color]  %.0f\n\n"
		+ "[color=#caa1ff]技能倍率[/color]  ×%.2f    [color=#caa1ff]技能范围[/color]  ×%.2f\n"
		+ "[color=#caa1ff]技能冷却[/color]  %.2f 秒    [color=#caa1ff]命中段数[/color]  %d\n\n"
		+ "[color=#6e9cad]说明[/color]\n所有数值均已计入当前武器与已选强化。"
	) % [
		int(stats.get("max_health", 0)),
		int(stats.get("attack_damage", 0)),
		1.0 / maxf(attack_cooldown, 0.01),
		float(stats.get("attack_reach", 1.0)),
		float(stats.get("run_speed", 0.0)),
		float(stats.get("dash_speed", 0.0)),
		float(stats.get("skill_damage_multiplier", 1.0)),
		float(stats.get("skill_reach", 1.0)),
		skill_cooldown,
		player.get_skill_hit_count(),
	]


func _format_upgrades(upgrade_counts: Dictionary, active_weapon: StringName) -> String:
	var rows: Array[String] = []
	for upgrade: Dictionary in UPGRADE_CATALOG.all_upgrades():
		var upgrade_id: StringName = upgrade.get("id", &"")
		var stacks: int = int(upgrade_counts.get(upgrade_id, 0))
		if stacks <= 0:
			continue
		var required_weapon: StringName = StringName(String(upgrade.get("weapon", "")))
		var is_active: bool = required_weapon.is_empty() or required_weapon == active_weapon
		var state_text: String = "生效中" if is_active else "切换该武器后生效"
		var state_color: String = "#8ff0bb" if is_active else "#8ca5b0"
		rows.append(
			"[color=%s]%s[/color]  [color=#f7d887]%d/%d[/color]  [color=%s]%s[/color]\n"
			% [
				_rarity_color(int(upgrade.get("rarity", 0))),
				String(upgrade.get("name", "未知强化")),
				stacks,
				int(upgrade.get("max_stacks", 1)),
				state_color,
				state_text,
			]
			+ "[color=#9db4bf]%s[/color]" % String(upgrade.get("description", ""))
		)
	if rows.is_empty():
		return (
			"[color=#88a9b7]本局尚未选择强化。完成当前房间后，可从三张强化中"
			+ "围绕武器流派做取舍。[/color]"
		)
	return "\n\n".join(rows)


func _format_synergies(upgrade_counts: Dictionary, weapon_id: StringName) -> String:
	var rows: Array[String] = []
	rows.append("[color=#d8c3ff]当前流派[/color]  %s" % _get_build_direction(weapon_id, upgrade_counts))

	if _count(upgrade_counts, &"tempered_edge") >= 2 and _count(upgrade_counts, &"battle_rhythm") >= 2:
		rows.append("[color=#8ff0bb]高频锋刃[/color]：攻击伤害与攻速同时成型，适合贴身持续压制。")
	if _count(upgrade_counts, &"swift_step") >= 1 and _count(upgrade_counts, &"dash_core") >= 1:
		rows.append("[color=#8fdfff]机动压迫[/color]：移动与冲刺速度协同，适合绕侧、追击和脱离危险区。")
	if _count(upgrade_counts, &"vitality_rune") >= 1 and _count(upgrade_counts, &"second_wind") >= 1:
		rows.append("[color=#ffd28a]韧性续航[/color]：更高生命上限配合即时恢复，容错更强。")

	match weapon_id:
		WeaponCatalog.SWORD:
			if _count(upgrade_counts, &"moon_expansion") >= 1 and _count(upgrade_counts, &"moon_rupture") >= 1:
				rows.append("[color=#90edff]月轮爆发[/color]：范围与伤害同步提升，优先维持中距离扇面输出。")
			if _count(upgrade_counts, &"lunar_cycle") >= 1:
				rows.append("[color=#90edff]月相循环[/color]：技能冷却进一步缩短，可更主动处理成群敌人。")
		WeaponCatalog.TWIN_BLADES:
			if _count(upgrade_counts, &"woven_momentum") >= 1 and _count(upgrade_counts, &"threaded_edge") >= 1:
				rows.append("[color=#c59cff]织影连斩[/color]：突进距离与多段伤害相互放大，适合穿过敌群。")
			if _count(upgrade_counts, &"quicksilver") >= 1:
				rows.append("[color=#c59cff]流银回路[/color]：缩短连斩循环，持续保持高频位移。")
		WeaponCatalog.GREATSWORD:
			if _count(upgrade_counts, &"fault_line") >= 1 and _count(upgrade_counts, &"starfall_core") >= 1:
				rows.append("[color=#ffb079]坠星破阵[/color]：范围与单次爆发兼备，适合精英与首领窗口。")
			if _count(upgrade_counts, &"meteor_rhythm") >= 1:
				rows.append("[color=#ffb079]陨星节律[/color]：缩短重击循环，在安全窗口连续压血。")

	if rows.size() == 1:
		rows.append("[color=#93aeb9]尚未形成双强化联动；优先围绕当前武器的专属强化或补齐基础生存。[/color]")
	return "\n".join(rows)


func _get_weapon_flow_text(weapon_id: StringName, weapon: Dictionary) -> String:
	var base_damage: int = int(weapon.get("damage", 0))
	var base_cooldown: float = float(weapon.get("attack_cooldown", 0.0))
	match weapon_id:
		WeaponCatalog.TWIN_BLADES:
			return (
				"[color=#c69eff]高频突进流[/color]\n"
				+ "三段技能命中，依靠位移切入与脱离。优先选择连斩伤害、突进与冷却，"
				+ "以连续穿插敌阵。\n\n"
				+ "[color=#809eaa]基础：%d 伤害 · %.2f 秒普攻[/color]" % [base_damage, base_cooldown]
			)
		WeaponCatalog.GREATSWORD:
			return (
				"[color=#ffb27a]重击破阵流[/color]\n"
				+ "单次伤害、范围和击退都更强。围绕坠星范围、爆发与冷却强化，"
				+ "在敌人出招间隙收割。\n\n"
				+ "[color=#809eaa]基础：%d 伤害 · %.2f 秒普攻[/color]" % [base_damage, base_cooldown]
			)
		_:
			return (
				"[color=#8cecff]均衡月轮流[/color]\n"
				+ "稳定中距离输出与月轮斩控场兼顾。围绕月轮伤害、范围和冷却强化，"
				+ "可安全覆盖密集敌群。\n\n"
				+ "[color=#809eaa]基础：%d 伤害 · %.2f 秒普攻[/color]" % [base_damage, base_cooldown]
			)


func _get_build_direction(weapon_id: StringName, upgrade_counts: Dictionary) -> String:
	var total_weapon_stacks: int = 0
	for upgrade: Dictionary in UPGRADE_CATALOG.all_upgrades():
		var required_weapon: StringName = StringName(String(upgrade.get("weapon", "")))
		if required_weapon == weapon_id:
			total_weapon_stacks += _count(upgrade_counts, upgrade.get("id", &""))
	match weapon_id:
		WeaponCatalog.TWIN_BLADES:
			return "影织双刃 · 高频突进（专属强化 %d 层）" % total_weapon_stacks
		WeaponCatalog.GREATSWORD:
			return "坠星巨刃 · 重击破阵（专属强化 %d 层）" % total_weapon_stacks
		_:
			return "月弧长剑 · 均衡月轮（专属强化 %d 层）" % total_weapon_stacks


func _count(upgrade_counts: Dictionary, upgrade_id: StringName) -> int:
	return maxi(0, int(upgrade_counts.get(upgrade_id, 0)))


func _rarity_color(rarity: int) -> String:
	match rarity:
		UpgradeCatalog.Rarity.RARE:
			return "#7eb5ff"
		UpgradeCatalog.Rarity.LEGENDARY:
			return "#ffbe74"
		_:
			return "#d7e7ef"


func _on_close_pressed() -> void:
	close_requested.emit()
