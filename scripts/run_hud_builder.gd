class_name RunHUDBuilder
extends RefCounted

## Owns the stable combat-HUD node tree. Gameplay code only supplies state through
## RunHUDPresenter, keeping layout construction out of the run orchestrator.

const DISPLAY_SIZE := Vector2(1280.0, 840.0)
const HUD_DOCK_TOP := 720.0
const HEALTH_FILL_WIDTH := 354.0
const ABILITY_SLOT_SCRIPT := preload("res://scripts/ability_slot.gd")


static func build(hud: CanvasLayer, title_label: Label, controls_label: Label) -> void:
	if hud.has_node("BottomHUD"):
		return
	title_label.text = ""
	title_label.visible = false
	controls_label.text = ""
	controls_label.visible = false

	var bottom_hud := Panel.new()
	bottom_hud.name = "BottomHUD"
	bottom_hud.position = Vector2(0.0, HUD_DOCK_TOP)
	bottom_hud.size = Vector2(DISPLAY_SIZE.x, DISPLAY_SIZE.y - HUD_DOCK_TOP)
	bottom_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bottom_style := StyleBoxFlat.new()
	bottom_style.bg_color = Color(0.008, 0.019, 0.032, 1.0)
	bottom_style.border_color = Color(0.21, 0.58, 0.67, 0.72)
	bottom_style.border_width_top = 2
	bottom_style.shadow_color = Color(0.0, 0.0, 0.0, 0.72)
	bottom_style.shadow_size = 12
	bottom_style.shadow_offset = Vector2(0.0, -4.0)
	bottom_hud.add_theme_stylebox_override("panel", bottom_style)
	hud.add_child(bottom_hud)

	var top_rune := ColorRect.new()
	top_rune.position = Vector2(28.0, 4.0)
	top_rune.size = Vector2(1224.0, 2.0)
	top_rune.color = Color(0.31, 0.82, 0.90, 0.54)
	top_rune.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom_hud.add_child(top_rune)

	_create_hud_panel(
		hud, "VitalsPanel", Vector2(28.0, 728.0), Vector2(390.0, 104.0),
		Color(0.23, 0.58, 0.66, 0.60), Color("#46cdd9")
	)
	_create_hud_panel(
		hud, "AbilityPanel", Vector2(432.0, 722.0), Vector2(416.0, 114.0),
		Color(0.40, 0.55, 0.75, 0.72), Color("#86a8ff")
	)
	var weapon_panel := _create_hud_panel(
		hud, "WeaponPanel", Vector2(862.0, 728.0), Vector2(390.0, 104.0),
		Color(0.63, 0.47, 0.24, 0.68), Color("#e8b65c")
	)

	var health_background := ColorRect.new()
	health_background.name = "HealthBackground"
	health_background.position = Vector2(42.0, 755.0)
	health_background.size = Vector2(362.0, 28.0)
	health_background.color = Color(0.012, 0.033, 0.047, 0.98)
	health_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(health_background)

	var health_fill := ColorRect.new()
	health_fill.name = "HealthFill"
	health_fill.position = Vector2(4.0, 4.0)
	health_fill.size = Vector2(HEALTH_FILL_WIDTH, 20.0)
	health_fill.color = Color(0.18, 0.82, 0.50, 0.96)
	health_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	health_background.add_child(health_fill)

	var health_label := Label.new()
	health_label.name = "HealthLabel"
	health_label.position = Vector2(4.0, 0.0)
	health_label.size = Vector2(354.0, 28.0)
	health_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	health_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	health_label.add_theme_font_size_override("font_size", 15)
	health_label.add_theme_color_override("font_color", Color.WHITE)
	health_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.84))
	health_label.add_theme_constant_override("outline_size", 2)
	health_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	health_background.add_child(health_label)

	_create_hud_panel(
		hud, "RoomCard", Vector2(1002.0, 16.0), Vector2(246.0, 70.0),
		Color(0.26, 0.68, 0.78, 0.72), Color("#61d6e8")
	)
	_create_hud_panel(
		hud, "StatusToast", Vector2(42.0, 802.0), Vector2(362.0, 25.0),
		Color(0.78, 0.57, 0.24, 0.48), Color("#efb85d")
	)

	var status_label := Label.new()
	status_label.name = "CombatStatus"
	status_label.position = Vector2(52.0, 804.0)
	status_label.size = Vector2(340.0, 21.0)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	status_label.clip_text = true
	status_label.add_theme_font_size_override("font_size", 12)
	status_label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.50, 1.0))
	status_label.add_theme_color_override("font_outline_color", Color(0.025, 0.045, 0.07, 0.96))
	status_label.add_theme_constant_override("outline_size", 1)
	status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(status_label)

	var room_label := Label.new()
	room_label.name = "RoomProgress"
	room_label.position = Vector2(1018.0, 24.0)
	room_label.size = Vector2(214.0, 54.0)
	room_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	room_label.add_theme_font_size_override("font_size", 14)
	room_label.add_theme_color_override("font_color", Color(0.78, 0.90, 0.96, 1.0))
	room_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(room_label)

	var currency_label := Label.new()
	currency_label.name = "Currency"
	currency_label.position = Vector2(42.0, 785.0)
	currency_label.size = Vector2(362.0, 16.0)
	currency_label.clip_text = true
	currency_label.add_theme_font_size_override("font_size", 13)
	currency_label.add_theme_color_override("font_color", Color(1.0, 0.83, 0.43, 1.0))
	currency_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(currency_label)

	var equipment_label := Label.new()
	equipment_label.name = "Equipment"
	equipment_label.position = Vector2(880.0, 734.0)
	equipment_label.size = Vector2(352.0, 20.0)
	equipment_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	equipment_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	equipment_label.clip_text = true
	equipment_label.add_theme_font_size_override("font_size", 13)
	equipment_label.add_theme_color_override("font_color", Color(0.96, 0.82, 0.53, 1.0))
	equipment_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(equipment_label)

	var lives_label := Label.new()
	lives_label.name = "Lives"
	lives_label.position = Vector2(42.0, 734.0)
	lives_label.size = Vector2(362.0, 18.0)
	lives_label.add_theme_font_size_override("font_size", 13)
	lives_label.clip_text = true
	lives_label.add_theme_color_override("font_color", Color(1.0, 0.76, 0.46, 1.0))
	lives_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(lives_label)

	var boss_health_background := ColorRect.new()
	boss_health_background.name = "BossHealth"
	boss_health_background.position = Vector2(390.0, 22.0)
	boss_health_background.size = Vector2(500.0, 28.0)
	boss_health_background.color = Color(0.05, 0.02, 0.03, 0.92)
	boss_health_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(boss_health_background)

	var boss_health_fill := ColorRect.new()
	boss_health_fill.position = Vector2(4.0, 4.0)
	boss_health_fill.size = Vector2(492.0, 20.0)
	boss_health_fill.color = Color(0.88, 0.18, 0.22, 0.96)
	boss_health_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boss_health_background.add_child(boss_health_fill)

	var boss_health_label := Label.new()
	boss_health_label.position = Vector2(8.0, 1.0)
	boss_health_label.size = Vector2(484.0, 26.0)
	boss_health_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_health_label.add_theme_font_size_override("font_size", 15)
	boss_health_label.add_theme_color_override("font_color", Color.WHITE)
	boss_health_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boss_health_background.add_child(boss_health_label)
	boss_health_background.visible = false

	var ability_heading := Label.new()
	ability_heading.position = Vector2(450.0, 726.0)
	ability_heading.size = Vector2(380.0, 20.0)
	ability_heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ability_heading.text = "战技  ·  COMBAT ARTS"
	ability_heading.add_theme_font_size_override("font_size", 12)
	ability_heading.add_theme_color_override("font_color", Color(0.63, 0.78, 0.98, 0.90))
	ability_heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(ability_heading)

	_create_weapon_hud(weapon_panel)
	_create_ability_hud(hud)


static func _create_hud_panel(
	hud: CanvasLayer,
	panel_name: String,
	panel_position: Vector2,
	panel_size: Vector2,
	border_color: Color,
	accent_color: Color
) -> Panel:
	var panel := Panel.new()
	panel.name = panel_name
	panel.position = panel_position
	panel.size = panel_size
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.018, 0.042, 0.065, 0.90)
	panel_style.border_color = border_color
	panel_style.set_border_width_all(1)
	panel_style.corner_radius_top_left = 9
	panel_style.corner_radius_top_right = 9
	panel_style.corner_radius_bottom_left = 9
	panel_style.corner_radius_bottom_right = 9
	panel_style.shadow_color = Color(0.0, 0.0, 0.0, 0.36)
	panel_style.shadow_size = 7
	panel_style.shadow_offset = Vector2(0.0, 3.0)
	panel.add_theme_stylebox_override("panel", panel_style)
	hud.add_child(panel)
	var accent := ColorRect.new()
	accent.position = Vector2(0.0, 10.0)
	accent.size = Vector2(4.0, panel_size.y - 20.0)
	accent.color = accent_color
	accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(accent)
	return panel


static func _create_weapon_hud(weapon_panel: Panel) -> void:
	for weapon_index: int in range(WeaponCatalog.all_weapon_ids().size()):
		var slot := Panel.new()
		slot.name = "WeaponSlot_%d" % weapon_index
		slot.position = Vector2(18.0 + float(weapon_index) * 92.0, 31.0)
		slot.size = Vector2(84.0, 58.0)
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		weapon_panel.add_child(slot)

		var slot_label := Label.new()
		slot_label.name = "Label"
		slot_label.position = Vector2(4.0, 3.0)
		slot_label.size = Vector2(76.0, 52.0)
		slot_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		slot_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		slot_label.add_theme_font_size_override("font_size", 11)
		slot_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(slot_label)

	var switch_panel := Panel.new()
	switch_panel.name = "WeaponSwitch"
	switch_panel.position = Vector2(296.0, 31.0)
	switch_panel.size = Vector2(72.0, 58.0)
	switch_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var switch_style := StyleBoxFlat.new()
	switch_style.bg_color = Color(0.025, 0.075, 0.098, 0.96)
	switch_style.border_color = Color(0.37, 0.78, 0.85, 0.70)
	switch_style.set_border_width_all(1)
	switch_style.corner_radius_top_left = 6
	switch_style.corner_radius_top_right = 6
	switch_style.corner_radius_bottom_left = 6
	switch_style.corner_radius_bottom_right = 6
	switch_panel.add_theme_stylebox_override("panel", switch_style)
	weapon_panel.add_child(switch_panel)

	var switch_label := Label.new()
	switch_label.name = "Label"
	switch_label.position = Vector2(3.0, 3.0)
	switch_label.size = Vector2(66.0, 52.0)
	switch_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	switch_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	switch_label.text = "Q\n切换"
	switch_label.add_theme_font_size_override("font_size", 12)
	switch_label.add_theme_color_override("font_color", Color(0.65, 0.90, 0.95, 1.0))
	switch_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	switch_panel.add_child(switch_label)


static func _create_ability_hud(hud: CanvasLayer) -> void:
	var ability_bar := Control.new()
	ability_bar.name = "AbilityBar"
	ability_bar.position = Vector2(503.0, 752.0)
	ability_bar.size = Vector2(274.0, 76.0)
	ability_bar.mouse_filter = Control.MOUSE_FILTER_PASS
	hud.add_child(ability_bar)

	var attack_slot := ABILITY_SLOT_SCRIPT.new() as Control
	attack_slot.name = "AttackAbility"
	attack_slot.position = Vector2(0.0, 0.0)
	attack_slot.size = Vector2(78.0, 76.0)
	ability_bar.add_child(attack_slot)

	var dash_slot := ABILITY_SLOT_SCRIPT.new() as Control
	dash_slot.name = "DashAbility"
	dash_slot.position = Vector2(98.0, 0.0)
	dash_slot.size = Vector2(78.0, 76.0)
	ability_bar.add_child(dash_slot)

	var skill_slot := ABILITY_SLOT_SCRIPT.new() as Control
	skill_slot.name = "SkillAbility"
	skill_slot.position = Vector2(196.0, 0.0)
	skill_slot.size = Vector2(78.0, 76.0)
	ability_bar.add_child(skill_slot)
