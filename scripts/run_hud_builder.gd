class_name RunHUDBuilder
extends RefCounted

## A compact set of player, action, and equipment readouts shared by both chapters.

const HEALTH_FILL_WIDTH := 230.0
const BOSS_FILL_WIDTH := 472.0
const HUD_DOCK_TOP := 640.0
const ABILITY_SLOT_SCRIPT := preload("res://scripts/ability_slot.gd")
const UI := preload("res://scripts/ui_theme.gd")


static func build(hud: CanvasLayer, title_label: Label, controls_label: Label) -> void:
	if hud.has_node("BottomHUD"):
		return
	title_label.hide()
	controls_label.hide()

	var dock := Control.new()
	dock.name = "BottomHUD"
	dock.position = Vector2(104, 650)
	dock.size = Vector2(1072, 58)
	dock.pivot_offset = Vector2(dock.size.x * 0.5, dock.size.y)
	dock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(dock)
	_create_vitals(dock)
	_create_abilities(dock)
	_create_weapon_hud(dock)

	var room := _panel(hud, "RoomCard", Rect2(24, 22, 298, 55), UI.ACCENT_MOON)
	_label(room, "RoomProgress", Rect2(12, 4, 274, 21), UI.CAPTION, UI.TEXT_SECONDARY)
	_label(room, "RoomName", Rect2(12, 25, 274, 25), UI.BODY, UI.TEXT_PRIMARY)

	var status := _panel(hud, "StatusToast", Rect2(402, 72, 476, 34), UI.ACCENT_GOLD)
	status.pivot_offset.x = status.size.x * 0.5
	status.z_index = 90
	var status_label := _label(status, "CombatStatus", Rect2(12, 2, 452, 30), UI.CAPTION, UI.ACCENT_GOLD)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.hide()

	var boss := _panel(hud, "BossHealth", Rect2(396, 22, 488, 34), UI.ACCENT_RISK)
	boss.pivot_offset.x = boss.size.x * 0.5
	var boss_label := _label(boss, "BossLabel", Rect2(8, 1, 472, 23), UI.CAPTION, UI.TEXT_PRIMARY)
	boss_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_meter(boss, "BossFill", Rect2(8, 24, BOSS_FILL_WIDTH, 4), UI.ACCENT_RISK)
	boss.hide()


static func _create_vitals(parent: Control) -> void:
	var panel := _panel(parent, "VitalsPanel", Rect2(0, 0, 260, 58), UI.ACCENT_MOON)
	_label(panel, "Lives", Rect2(12, 4, 156, 23), UI.CAPTION, UI.TEXT_PRIMARY)
	var currency := _label(panel, "Currency", Rect2(169, 4, 79, 23), UI.CAPTION, UI.ACCENT_GOLD)
	currency.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	var track := _meter(panel, "HealthBackground", Rect2(12, 27, 236, 25), Color(UI.BG_DEEP, 0.92))
	_meter(track, "HealthFill", Rect2(3, 20, HEALTH_FILL_WIDTH, 4), UI.ACCENT_MOON)
	var health := _label(track, "HealthLabel", Rect2(3, -1, HEALTH_FILL_WIDTH, 21), UI.BODY, UI.TEXT_PRIMARY)
	health.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	health.add_theme_color_override("font_outline_color", UI.BG_DEEP)
	health.add_theme_constant_override("outline_size", 3)


static func _create_abilities(parent: Control) -> void:
	var bar := Control.new()
	bar.name = "AbilityBar"
	bar.position = Vector2(388, 0)
	bar.size = Vector2(296, 58)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(bar)

	var slot_names := ["AttackAbility", "DashAbility", "SkillAbility"]
	for index: int in range(slot_names.size()):
		var slot := ABILITY_SLOT_SCRIPT.new() as Control
		slot.name = slot_names[index]
		slot.position = Vector2(index * 100.0, 0)
		slot.size = Vector2(96, 58)
		bar.add_child(slot)


static func _create_weapon_hud(parent: Control) -> void:
	var panel := _panel(parent, "WeaponPanel", Rect2(812, 0, 260, 58), UI.ACCENT_GOLD)
	_label(panel, "ActiveWeapon", Rect2(12, 5, 143, 24), UI.BODY, UI.TEXT_PRIMARY)

	var switch_box := _panel(panel, "WeaponSwitch", Rect2(160, 12, 90, 34), UI.ACCENT_GOLD)
	var switch_prompt := _label(switch_box, "Label", Rect2(5, 1, 80, 32), UI.CAPTION, UI.TEXT_SECONDARY)
	switch_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	for index: int in range(WeaponCatalog.all_weapon_ids().size()):
		var marker := _meter(panel, "WeaponSlot_%d" % index, Rect2(12 + index * 34.0, 38, 26, 5), UI.STROKE_QUIET)
		marker.mouse_filter = Control.MOUSE_FILTER_PASS


static func panel_style(accent: Color, high_contrast: bool = false) -> StyleBoxFlat:
	var fill := UI.BG_DEEP if high_contrast else Color(UI.BG_PANEL, 0.91)
	var edge := Color(UI.TEXT_PRIMARY, 0.72) if high_contrast else Color(accent, 0.36)
	return UI.surface(fill, edge, 7, 1)


static func _panel(parent: Node, node_name: String, bounds: Rect2, accent: Color) -> Panel:
	var panel := Panel.new()
	panel.name = node_name
	panel.position = bounds.position
	panel.size = bounds.size
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", panel_style(accent))
	parent.add_child(panel)
	return panel


static func _meter(parent: Control, node_name: String, bounds: Rect2, color: Color) -> ColorRect:
	var meter := ColorRect.new()
	meter.name = node_name
	meter.position = bounds.position
	meter.size = bounds.size
	meter.color = color
	meter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(meter)
	return meter


static func _label(parent: Control, node_name: String, bounds: Rect2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.name = node_name
	label.position = bounds.position
	label.size = bounds.size
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label
