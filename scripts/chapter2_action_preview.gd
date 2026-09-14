extends Node2D

## Review-only atlas viewer. Gray backgrounds are intentionally retained.
const SHEETS := [
	"res://docs/chapter2_actions/forge_sentinel_actions_v1.png",
	"res://docs/chapter2_actions/ember_beetle_actions_v1.png",
	"res://docs/chapter2_actions/ember_caster_actions_v2.png",
]
const NAMES := ["铸炉守卫", "余烬甲虫", "熔火投掷者"]
const POSES := ["待机", "移动", "蓄力预警", "攻击", "受击 / 失衡", "死亡"]
var textures: Array[Texture2D] = []
var pose: int = 0
var playing: bool = true
var mirrored: bool = false
var elapsed: float = 0.0
var caption: Label

func _ready() -> void:
	for path: String in SHEETS:
		# Read source PNGs directly so this review tool needs no editor import.
		var source := Image.load_from_file(path)
		if source == null:
			push_error("Missing chapter 2 action sheet: " + path)
			return
		textures.append(ImageTexture.create_from_image(source))
	var heading := Label.new()
	heading.position = Vector2(28, 18)
	heading.text = "第二章 · 动作预览（概念帧，非战斗场景）"
	heading.add_theme_font_size_override("font_size", 26)
	add_child(heading)
	caption = Label.new()
	caption.position = Vector2(28, 62)
	add_child(caption)
	for i in range(3):
		var label := Label.new()
		label.position = Vector2(36 + i * 418, 112)
		label.text = NAMES[i]
		label.add_theme_font_size_override("font_size", 22)
		add_child(label)
	var controls := Label.new()
	controls.position = Vector2(28, 600)
	controls.text = "空格：播放 / 暂停    ← →：单步    F：镜像    Esc：退出\n浅灰背景为原图内容；尚未抠图、校准锚点或补齐动画中间帧。"
	add_child(controls)
	_refresh()

func _process(delta: float) -> void:
	if not playing:
		return
	elapsed += delta
	if elapsed >= 1.0:
		elapsed = 0.0
		pose = (pose + 1) % 6
		_refresh()

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_SPACE: playing = not playing
		KEY_LEFT, KEY_RIGHT:
			playing = false
			pose = posmod(pose + (1 if event.keycode == KEY_RIGHT else -1), 6)
		KEY_F: mirrored = not mirrored
		KEY_ESCAPE: get_tree().quit()
	_refresh()

func _refresh() -> void:
	if is_instance_valid(caption):
		caption.text = "%02d / 06 · %s · %s" % [pose + 1, POSES[pose], "播放中" if playing else "已暂停"]
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color("#101722"))
	for i in range(textures.size()):
		var texture: Texture2D = textures[i]
		var cell: Vector2 = texture.get_size() / Vector2(3, 2)
		var region := Rect2(Vector2(pose % 3, floori(pose / 3.0)) * cell, cell)
		var dest := Rect2(28 + i * 418, 154, 396, 396)
		if mirrored:
			dest.position.x += dest.size.x
			dest.size.x = -dest.size.x
		draw_texture_rect_region(texture, dest, region)
