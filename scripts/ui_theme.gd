class_name MoonUI
extends RefCounted

## Shared visual tokens from docs/UI_DESIGN_REFRESH.md. No gameplay state here.
const BG_DEEP := Color("#050B14")
const BG_PANEL := Color("#0A1624")
const BG_PANEL_ELEV := Color("#102033")
const BG_VEIL := Color(0.0196, 0.0431, 0.0784, 0.72)
const STROKE_QUIET := Color("#2A4A5C")
const ACCENT_MOON := Color("#5ED7F2")
const ACCENT_GOLD := Color("#E8B45A")
const ACCENT_OMEN := Color("#B985FF")
const ACCENT_SEAL := Color("#6FE0B0")
const ACCENT_RISK := Color("#FF6B7A")
const TEXT_PRIMARY := Color("#EAF6FF")
const TEXT_SECONDARY := Color("#8FB0C4")
const TEXT_DISABLED := Color("#5A7384")
const RARITY_COMMON := TEXT_SECONDARY
const RARITY_RARE := ACCENT_MOON
const RARITY_LEGEND := ACCENT_GOLD
const DISPLAY := 52
const TITLE := 30
const HEADLINE := 22
const BODY := 16
const CAPTION := 13
const MICRO := 10
const PANEL_RADIUS := 16
const CARD_RADIUS := 12
const CHIP_RADIUS := 10

static func surface(
	background: Color, stroke: Color = STROKE_QUIET,
	radius: int = CARD_RADIUS, width: int = 1, shadow: int = 0
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = stroke
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	if shadow > 0:
		style.shadow_color = Color(0.0, 0.0, 0.0, 0.55)
		style.shadow_size = shadow
		style.shadow_offset = Vector2(0.0, 10.0 if shadow >= 18 else 4.0)
	return style

static func card(accent: Color, focused: bool = false) -> StyleBoxFlat:
	var style := surface(BG_PANEL_ELEV if focused else BG_PANEL,
		accent if focused else STROKE_QUIET, CARD_RADIUS, 1, 14 if focused else 6)
	style.border_width_top = 3
	if focused:
		style.shadow_color = Color(accent, 0.35)
		style.shadow_offset = Vector2.ZERO
	return style

## Small procedural emblems reuse the project's palette without new raster art.
static func draw_reward_emblem(canvas: CanvasItem, accent: Color, identity: String) -> void:
	var center := Vector2(56, 40)
	canvas.draw_circle(center, 35, Color(accent, 0.07))
	canvas.draw_arc(center, 35, -0.3, TAU - 0.6, 64, Color(accent, 0.45), 1, true)
	canvas.draw_arc(center, 29, 0.5, 4.8, 48, Color(accent, 0.22), 1, true)
	for angle in [0.0, PI * 0.5, PI, PI * 1.5]:
		var point: Vector2 = center + Vector2.from_angle(angle) * 38
		canvas.draw_colored_polygon(PackedVector2Array([point + Vector2(0, -2), point + Vector2(2, 0), point + Vector2(0, 2), point + Vector2(-2, 0)]), accent)
	if identity.contains("vitality") or identity.contains("wind") or identity.contains("rest"):
		var heart := PackedVector2Array([Vector2(-21, -8), Vector2(-17, -17), Vector2(-7, -18), Vector2(0, -11), Vector2(7, -18), Vector2(17, -17), Vector2(21, -8), Vector2(17, 3), Vector2(0, 20), Vector2(-17, 3)])
		for index in range(heart.size()):
			heart[index] += center
		canvas.draw_colored_polygon(heart, Color(accent, 0.85))
		canvas.draw_line(center + Vector2(-8, -1), center + Vector2(8, -1), TEXT_PRIMARY, 3, true)
		canvas.draw_line(center + Vector2(0, -9), center + Vector2(0, 7), TEXT_PRIMARY, 3, true)
	elif identity.contains("gold"):
		for index in range(3):
			var coin := center + Vector2(-10 + index * 9, 9 - index * 9)
			canvas.draw_circle(coin, 13, BG_PANEL)
			canvas.draw_circle(coin, 13, accent, false, 2, true)
			canvas.draw_line(coin + Vector2(0, -6), coin + Vector2(0, 6), accent, 2, true)
	elif identity.contains("shards") or identity.contains("star") or identity.contains("fault"):
		canvas.draw_colored_polygon(PackedVector2Array([center + Vector2(0, -25), center + Vector2(17, -5), center + Vector2(0, 25), center + Vector2(-17, -5)]), Color(accent, 0.7))
		canvas.draw_line(center + Vector2(0, -25), center + Vector2(0, 25), TEXT_PRIMARY, 2, true)
		canvas.draw_line(center + Vector2(-17, -5), center + Vector2(17, -5), accent, 2, true)
	elif identity.contains("step") or identity.contains("dash") or identity.contains("momentum"):
		canvas.draw_colored_polygon(PackedVector2Array([center + Vector2(16, -25), center + Vector2(-20, 3), center + Vector2(-3, 3), center + Vector2(-14, 25), center + Vector2(22, -6), center + Vector2(5, -6)]), accent)
		canvas.draw_line(center + Vector2(-28, 10), center + Vector2(-12, 10), Color(accent, 0.4), 2, true)
	elif identity.contains("moon") or identity.contains("lunar") or identity.contains("eclipse") or identity.contains("focus"):
		var crescent := PackedVector2Array()
		for index in range(33):
			var angle: float = lerpf(-PI * 0.5, PI * 0.5, float(index) / 32)
			crescent.append(center + Vector2.from_angle(angle) * 25)
		for index in range(33):
			var angle: float = lerpf(PI * 0.5, -PI * 0.5, float(index) / 32)
			crescent.append(center + Vector2(10 * cos(angle), 25 * sin(angle)))
		canvas.draw_colored_polygon(crescent, accent)
		canvas.draw_circle(center + Vector2(-12, -8), 3, TEXT_PRIMARY)
	else:
		var blade := PackedVector2Array([Vector2(-9, 7), Vector2(12, -22), Vector2(24, -27), Vector2(21, -14), Vector2(-3, 13)])
		for index in range(blade.size()):
			blade[index] += center
		canvas.draw_colored_polygon(blade, accent)
		canvas.draw_line(center + Vector2(-6, 10), center + Vector2(20, -23), TEXT_PRIMARY, 1, true)
		canvas.draw_line(center + Vector2(-15, 2), center + Vector2(2, 19), ACCENT_GOLD, 3, true)
		canvas.draw_line(center + Vector2(-7, 11), center + Vector2(-17, 23), accent, 4, true)
