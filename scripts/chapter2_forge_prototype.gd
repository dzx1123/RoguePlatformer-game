extends Node2D

## Standalone second-chapter room prototype. It is intentionally not in Main's run route yet.
const ROOM_SIZE := Vector2(1280.0, 720.0)
const PLATFORM_RECTS := [
	Rect2(-40.0, 620.0, 420.0, 100.0),
	Rect2(470.0, 620.0, 340.0, 100.0),
	Rect2(900.0, 620.0, 420.0, 100.0),
	Rect2(210.0, 470.0, 230.0, 26.0),
	Rect2(570.0, 385.0, 210.0, 26.0),
	Rect2(930.0, 460.0, 220.0, 26.0),
]
const HEAT_RECTS := [Rect2(300.0, 580.0, 120.0, 40.0), Rect2(680.0, 580.0, 110.0, 40.0), Rect2(1010.0, 580.0, 130.0, 40.0)]
var elapsed := 0.0
var cycle := 0.0
var paused := false

func _ready() -> void:
	queue_redraw()

func _process(delta: float) -> void:
	if paused:
		return
	elapsed += delta
	cycle = fmod(elapsed, 3.0)
	queue_redraw()

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE:
			paused = not paused
			queue_redraw()
		elif event.keycode == KEY_ESCAPE:
			get_tree().quit()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, ROOM_SIZE), Color("#100d16"))
	for band in range(5):
		var y := 110.0 + band * 104.0
		draw_rect(Rect2(0.0, y, ROOM_SIZE.x, 2.0), Color(0.82, 0.34, 0.10, 0.20))
		draw_circle(Vector2(1040.0, 170.0), 92.0, Color(0.95, 0.32, 0.08, 0.10))
	for rect: Rect2 in PLATFORM_RECTS:
		draw_rect(rect, Color("#262a32"))
		draw_line(rect.position, Vector2(rect.end.x, rect.position.y), Color("#d49a5a"), 3.0)
	for heat: Rect2 in HEAT_RECTS:
		var warning := cycle > 1.95 and cycle < 2.50
		var active := cycle >= 2.50 or cycle < 0.30
		var color := Color("#ffbe62") if warning else (Color("#ff4b20") if active else Color("#8c4328"))
		draw_rect(heat, Color(color, 0.28 if active else 0.14))
		draw_line(heat.position, Vector2(heat.end.x, heat.position.y), Color(color, 0.95), 4.0)
		if warning:
			for x in range(int(heat.position.x) + 8, int(heat.end.x), 22):
				draw_line(Vector2(x, heat.end.y), Vector2(x + 8, heat.position.y), Color("#ffd78c"), 2.0)
	# Ember caster telegraph: an arc and landing marker, deliberately readable.
	var caster := Vector2(860.0, 360.0)
	var landing := Vector2(510.0, 580.0)
	draw_circle(caster, 18.0, Color("#ff9b3d"))
	for i in range(1, 7):
		var t := float(i) / 7.0
		var point := caster.lerp(landing, t) + Vector2(0.0, -120.0 * sin(t * PI))
		draw_circle(point, 4.0, Color(1.0, 0.48, 0.12, 0.65))
	var marker_color := Color("#ffd16b") if cycle > 1.95 else Color(1.0, 0.34, 0.10, 0.72)
	draw_arc(landing, 32.0, 0.0, TAU, 32, marker_color, 3.0)
	draw_string(ThemeDB.fallback_font, Vector2(34.0, 42.0), "第二章原型 · 熔炉长廊", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 24, Color("#f1c184"))
	draw_string(ThemeDB.fallback_font, Vector2(34.0, 70.0), "热区：预警后激活    熔火投掷者：落点预警", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 16, Color("#bd9b86"))
	draw_string(ThemeDB.fallback_font, Vector2(34.0, 690.0), "空格：暂停原型    Esc：退出", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14, Color("#8c8294"))
