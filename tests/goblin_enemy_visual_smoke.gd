extends SceneTree

var _projectile_style: int = -1


func _initialize() -> void:
	call_deferred(&"_run_test")


func _run_test() -> void:
	var asset_paths: Array[String] = [
		"res://assets/enemies/red_fang_goblin_club_sheet.png",
		"res://assets/enemies/red_fang_goblin_elite_sheet.png",
		"res://assets/enemies/red_fang_goblin_archer_sheet.png",
	]
	for asset_path in asset_paths:
		var texture := load(asset_path) as Texture2D
		if texture == null or texture.get_width() % 4 != 0 or texture.get_height() % 4 != 0:
			_fail("Goblin sheet is not divisible into a 4x4 grid: %s" % asset_path)
			return
		var png_bytes: PackedByteArray = FileAccess.get_file_as_bytes(asset_path)
		var image := Image.new()
		var load_error: Error = image.load_png_from_buffer(png_bytes)
		if load_error != OK or image.is_empty() or image.get_pixel(0, 0).a > 0.01:
			_fail("Goblin sheet is missing real alpha transparency: %s" % asset_path)
			return
		if not _validate_clean_registered_sheet(image, asset_path):
			return

	var run_asset_paths: Array[String] = [
		"res://assets/enemies/red_fang_goblin_club_run_sheet_v2.png",
		"res://assets/enemies/red_fang_goblin_elite_run_sheet_v2.png",
		"res://assets/enemies/red_fang_goblin_archer_run_sheet_v2.png",
	]
	for asset_path in run_asset_paths:
		var texture := load(asset_path) as Texture2D
		if texture == null or texture.get_width() % 4 != 0 or texture.get_height() % 2 != 0:
			_fail("Goblin run sheet is not divisible into a 4x2 grid: %s" % asset_path)
			return
		var png_bytes: PackedByteArray = FileAccess.get_file_as_bytes(asset_path)
		var image := Image.new()
		if image.load_png_from_buffer(png_bytes) != OK or image.get_pixel(0, 0).a > 0.01:
			_fail("Goblin run sheet is missing real alpha transparency: %s" % asset_path)
			return

	var club := _make_goblin(RogueEnemy.EnemyRole.MELEE, RogueEnemy.EnemyRank.NORMAL)
	var elite := _make_goblin(RogueEnemy.EnemyRole.MELEE, RogueEnemy.EnemyRank.ELITE)
	var archer := _make_goblin(RogueEnemy.EnemyRole.RANGED, RogueEnemy.EnemyRank.NORMAL)
	root.add_child(club)
	root.add_child(elite)
	root.add_child(archer)
	await physics_frame

	var club_sprite := club.get_node("EnemySprite") as Sprite2D
	var elite_sprite := elite.get_node("EnemySprite") as Sprite2D
	var archer_sprite := archer.get_node("EnemySprite") as Sprite2D
	if not club_sprite.texture.resource_path.ends_with("red_fang_goblin_club_sheet.png"):
		_fail("Ordinary goblin did not use the club soldier sheet")
		return
	if not elite_sprite.texture.resource_path.ends_with("red_fang_goblin_elite_sheet.png"):
		_fail("Elite goblin did not use the armored brute sheet")
		return
	if not archer_sprite.texture.resource_path.ends_with("red_fang_goblin_archer_sheet.png"):
		_fail("Ranged goblin did not use the archer sheet")
		return
	if elite_sprite.scale.x <= club_sprite.scale.x:
		_fail("Elite goblin was not visually larger than the ordinary soldier")
		return

	club.velocity.x = 100.0
	var run_frames_seen: Dictionary = {}
	for frame_index in range(8):
		club.set("_elapsed", (float(frame_index) + 0.01) / 11.0)
		club.call(&"_update_sprite_animation")
		if not club_sprite.texture.resource_path.ends_with("red_fang_goblin_club_run_sheet_v2.png"):
			_fail("Ordinary goblin did not switch to its authored run sheet")
			return
		var run_cell_width: float = float(club_sprite.texture.get_width()) / 4.0
		var run_cell_height: float = float(club_sprite.texture.get_height()) / 2.0
		var run_column: int = int(round(club_sprite.region_rect.position.x / run_cell_width))
		var run_row: int = int(round(club_sprite.region_rect.position.y / run_cell_height))
		var resolved_frame: int = run_row * 4 + run_column
		if resolved_frame != frame_index:
			_fail("Goblin run cycle selected frame %d instead of %d" % [resolved_frame, frame_index])
			return
		run_frames_seen[club_sprite.region_rect.position] = true
	if run_frames_seen.size() != 8:
		_fail("Goblin run did not expose all eight authored poses")
		return

	elite.velocity.x = 100.0
	elite.call(&"_update_sprite_animation")
	if not elite_sprite.texture.resource_path.ends_with("red_fang_goblin_elite_run_sheet_v2.png"):
		_fail("Elite goblin did not switch to its authored run sheet")
		return
	archer.velocity.x = 100.0
	archer.call(&"_update_sprite_animation")
	if not archer_sprite.texture.resource_path.ends_with("red_fang_goblin_archer_run_sheet_v2.png"):
		_fail("Archer goblin did not switch to its authored run sheet")
		return

	club.velocity.x = 0.0
	club.call(&"_update_sprite_animation")
	var cell_width: float = float(club_sprite.texture.get_width()) / 4.0
	var cell_height: float = float(club_sprite.texture.get_height()) / 4.0
	var expected_idle_columns: Array[int] = [0, 1, 2, 1]
	for frame_index in range(expected_idle_columns.size()):
		club.set("_elapsed", (float(frame_index) + 0.01) / 4.5)
		club.call(&"_update_sprite_animation")
		var idle_column: int = int(round(club_sprite.region_rect.position.x / cell_width))
		if idle_column != expected_idle_columns[frame_index]:
			_fail(
				"Goblin idle frame %d selected column %d instead of %d"
				% [frame_index, idle_column, expected_idle_columns[frame_index]]
			)
			return

	club.call(&"_start_attack")
	club.call(&"_update_sprite_animation")
	if not is_equal_approx(club_sprite.region_rect.position.y, cell_height * 2.0):
		_fail("Goblin attack did not select the attack row")
		return
	var attack_duration: float = float(club.call(&"_get_attack_duration"))
	club.set("_attack_remaining", attack_duration * 0.55)
	club.call(&"_update_sprite_animation")
	var impact_column: int = int(round(club_sprite.region_rect.position.x / cell_width))
	if impact_column != 2:
		_fail("Goblin attack did not reach its impact pose at the hit timing")
		return
	club.set("_attack_remaining", 0.0)
	club.set("_hurt_remaining", 0.12)
	club.call(&"_update_sprite_animation")
	if not is_equal_approx(club_sprite.region_rect.position.y, cell_height * 3.0):
		_fail("Goblin hurt did not select the reaction row")
		return

	var target := Node2D.new()
	target.position = Vector2(-180.0, 0.0)
	root.add_child(target)
	archer.set_target(target)
	archer.projectile_requested.connect(_on_projectile_requested)
	archer.call(&"_fire_projectile")
	if _projectile_style != RogueEnemy.ProjectileStyle.ARROW:
		_fail("Goblin archer did not request an arrow projectile")
		return

	club.queue_free()
	elite.queue_free()
	archer.queue_free()
	target.queue_free()
	print("goblin_enemy_visual_smoke: PASS")
	quit(0)


func _make_goblin(role: int, rank: int) -> RogueEnemy:
	var enemy := RogueEnemy.new()
	enemy.setup(
		0,
		0.0,
		-100.0,
		100.0,
		role,
		rank,
		1.0,
		1.0,
		RogueEnemy.EnemyFamily.GOBLIN
	)
	return enemy


func _on_projectile_requested(
	_origin: Vector2,
	_velocity: Vector2,
	_damage: int,
	style: int
) -> void:
	_projectile_style = style


func _validate_clean_registered_sheet(image: Image, asset_path: String) -> bool:
	image.convert(Image.FORMAT_RGBA8)
	var width: int = image.get_width()
	var height: int = image.get_height()
	var cell_width: int = width / 4
	var cell_height: int = height / 4
	var pixels: PackedByteArray = image.get_data()
	var transparent_white_pixels: int = 0
	var pale_boundary_pixels: int = 0

	for row in range(4):
		for column in range(4):
			var origin_x: int = column * cell_width
			var origin_y: int = row * cell_height
			for local_y in range(cell_height):
				var y: int = origin_y + local_y
				for local_x in range(cell_width):
					var x: int = origin_x + local_x
					var pixel_index: int = (y * width + x) * 4
					var red: int = pixels[pixel_index]
					var green: int = pixels[pixel_index + 1]
					var blue: int = pixels[pixel_index + 2]
					var alpha: int = pixels[pixel_index + 3]
					if alpha == 0:
						if red >= 245 and green >= 245 and blue >= 245:
							transparent_white_pixels += 1
						continue
					if not _pixel_touches_frame_transparency(
						pixels,
						width,
						origin_x,
						origin_y,
						cell_width,
						cell_height,
						local_x,
						local_y
					):
						continue
					var brightest: int = maxi(red, maxi(green, blue))
					var darkest: int = mini(red, mini(green, blue))
					var luminance: int = (
						red * 54 + green * 183 + blue * 19
					) >> 8
					if luminance >= 80 and brightest - darkest <= 90:
						pale_boundary_pixels += 1

	if transparent_white_pixels > 2000:
		_fail("Goblin sheet still contains white RGB below transparency: %s" % asset_path)
		return false
	if pale_boundary_pixels > 2500:
		_fail("Goblin sheet still contains a baked pale border: %s" % asset_path)
		return false

	var minimum_bottom: int = cell_height
	var maximum_bottom: int = -1
	var minimum_idle_anchor: int = cell_width
	var maximum_idle_anchor: int = -1
	for row in range(4):
		for column in range(4):
			var frame_bottom: int = _find_frame_bottom(
				pixels,
				width,
				cell_width,
				cell_height,
				column,
				row
			)
			if frame_bottom < 0:
				_fail("Goblin sheet contains an empty frame: %s" % asset_path)
				return false
			minimum_bottom = mini(minimum_bottom, frame_bottom)
			maximum_bottom = maxi(maximum_bottom, frame_bottom)
			if row == 0:
				var torso_anchor: int = _find_red_torso_anchor(
					pixels,
					width,
					cell_width,
					cell_height,
					column
				)
				minimum_idle_anchor = mini(minimum_idle_anchor, torso_anchor)
				maximum_idle_anchor = maxi(maximum_idle_anchor, torso_anchor)

	if maximum_bottom - minimum_bottom > 1:
		_fail("Goblin frames do not share one floor anchor: %s" % asset_path)
		return false
	if maximum_idle_anchor - minimum_idle_anchor > 4:
		_fail("Goblin idle frames do not share one torso anchor: %s" % asset_path)
		return false
	return true


func _pixel_touches_frame_transparency(
	pixels: PackedByteArray,
	image_width: int,
	origin_x: int,
	origin_y: int,
	cell_width: int,
	cell_height: int,
	local_x: int,
	local_y: int
) -> bool:
	for offset_y in range(-1, 2):
		for offset_x in range(-1, 2):
			if offset_x == 0 and offset_y == 0:
				continue
			var neighbour_x: int = local_x + offset_x
			var neighbour_y: int = local_y + offset_y
			if (
				neighbour_x < 0
				or neighbour_x >= cell_width
				or neighbour_y < 0
				or neighbour_y >= cell_height
			):
				return true
			var pixel_index: int = (
				(origin_y + neighbour_y) * image_width + origin_x + neighbour_x
			) * 4
			if pixels[pixel_index + 3] == 0:
				return true
	return false


func _find_frame_bottom(
	pixels: PackedByteArray,
	image_width: int,
	cell_width: int,
	cell_height: int,
	column: int,
	row: int
) -> int:
	var origin_x: int = column * cell_width
	var origin_y: int = row * cell_height
	for local_y in range(cell_height - 1, -1, -1):
		var y: int = origin_y + local_y
		for local_x in range(cell_width):
			var pixel_index: int = (y * image_width + origin_x + local_x) * 4
			if pixels[pixel_index + 3] > 0:
				return local_y
	return -1


func _find_red_torso_anchor(
	pixels: PackedByteArray,
	image_width: int,
	cell_width: int,
	cell_height: int,
	column: int
) -> int:
	var histogram := PackedInt32Array()
	histogram.resize(cell_width)
	var red_pixel_count: int = 0
	var origin_x: int = column * cell_width
	for local_y in range(cell_height):
		for local_x in range(cell_width):
			var pixel_index: int = (local_y * image_width + origin_x + local_x) * 4
			var red: int = pixels[pixel_index]
			var green: int = pixels[pixel_index + 1]
			var blue: int = pixels[pixel_index + 2]
			if (
				pixels[pixel_index + 3] > 0
				and red >= 72
				and red * 4 >= green * 5
				and red * 5 >= blue * 6
				and red - green >= 18
			):
				histogram[local_x] += 1
				red_pixel_count += 1
	if red_pixel_count == 0:
		return cell_width / 2
	var midpoint: int = red_pixel_count / 2
	var accumulated: int = 0
	for local_x in range(cell_width):
		accumulated += histogram[local_x]
		if accumulated >= midpoint:
			return local_x
	return cell_width / 2


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
