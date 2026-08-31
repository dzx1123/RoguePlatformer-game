extends RefCounted

## Hand-authored room layouts used to assemble a run in a random order.
class_name RunRoomCatalog

const ROLE_MELEE := 0
const ROLE_RANGED := 1
const WORLD_WIDTH := 1280.0


static func create_room_pool() -> Array[Dictionary]:
	return [
		_moon_gate(),
		_broken_stair(),
		_twin_bridge(),
		_sunken_forge(),
		_high_gallery(),
		_crescent_spires(),
		_shattered_crossing(),
		_hanging_gardens(),
		_eclipse_well(),
		_fang_gauntlet(),
		_mirrored_ramparts(),
		_abyssal_steps(),
	]


static func build_room_sequence(
	pool_size: int,
	room_count: int,
	rng: RandomNumberGenerator
) -> Array[int]:
	var sequence: Array[int] = []
	if pool_size <= 0 or room_count <= 0:
		return sequence

	var available: Array[int] = []
	for room_index in range(pool_size):
		available.append(room_index)
	_shuffle_indices(available, rng)

	while sequence.size() < room_count:
		if available.is_empty():
			for room_index in range(pool_size):
				if sequence.is_empty() or room_index != sequence.back():
					available.append(room_index)
			_shuffle_indices(available, rng)
		sequence.append(available.pop_back())
	return sequence


static func build_room_variant(
	room_template: Dictionary,
	rng: RandomNumberGenerator,
	room_number: int
) -> Dictionary:
	var variant: Dictionary = room_template.duplicate(true)
	var source_platforms: Array = variant.get("platforms", []) as Array
	var varied_platforms: Array[Rect2] = []
	var mirrored: bool = rng.randf() < 0.5
	var room_progress: float = clampf((float(maxi(room_number, 1)) - 1.0) / 19.0, 0.0, 1.0)
	var variation_strength: float = lerpf(0.42, 1.0, room_progress)

	for platform_value: Variant in source_platforms:
		var platform: Rect2 = platform_value
		if mirrored:
			platform.position.x = WORLD_WIDTH - platform.end.x
		if platform.size.y < 100.0:
			var varied_width: float = clampf(
				platform.size.x + rng.randf_range(-28.0, 28.0) * variation_strength,
				140.0,
				310.0
			)
			var varied_x: float = clampf(
				platform.get_center().x - varied_width * 0.5
					+ rng.randf_range(-34.0, 34.0) * variation_strength,
				42.0,
				WORLD_WIDTH - varied_width - 42.0
			)
			var varied_y: float = clampf(
				platform.position.y + rng.randf_range(-20.0, 20.0) * variation_strength,
				280.0,
				558.0
			)
			platform = Rect2(varied_x, varied_y, varied_width, platform.size.y)
		varied_platforms.append(platform)

	var source_enemies: Array = variant.get("enemies", []) as Array
	var varied_enemies: Array[Dictionary] = []
	for enemy_value: Variant in source_enemies:
		var descriptor: Dictionary = (enemy_value as Dictionary).duplicate(true)
		var horizontal_ratio: float = float(descriptor.get("ratio", 0.5))
		if mirrored:
			horizontal_ratio = 1.0 - horizontal_ratio
		horizontal_ratio = clampf(
			horizontal_ratio + rng.randf_range(-0.12, 0.12) * variation_strength,
			0.16,
			0.84
		)
		descriptor["ratio"] = horizontal_ratio
		var role_swap_chance: float = lerpf(0.08, 0.18, room_progress)
		if rng.randf() < role_swap_chance:
			var current_role: int = int(descriptor.get("role", ROLE_MELEE))
			descriptor["role"] = ROLE_RANGED if current_role == ROLE_MELEE else ROLE_MELEE
		varied_enemies.append(descriptor)

	variant["platforms"] = varied_platforms
	variant["enemies"] = varied_enemies
	variant["mirrored"] = mirrored
	return variant


static func _shuffle_indices(values: Array[int], rng: RandomNumberGenerator) -> void:
	for value_index in range(values.size() - 1, 0, -1):
		var swap_index: int = rng.randi_range(0, value_index)
		var held_value: int = values[value_index]
		values[value_index] = values[swap_index]
		values[swap_index] = held_value


static func _moon_gate() -> Dictionary:
	var platforms: Array[Rect2] = [
		Rect2(-80.0, 640.0, 1440.0, 160.0),
		Rect2(250.0, 520.0, 230.0, 28.0),
		Rect2(570.0, 430.0, 190.0, 28.0),
		Rect2(860.0, 515.0, 250.0, 28.0),
		Rect2(1060.0, 380.0, 150.0, 28.0),
	]
	var enemies: Array[Dictionary] = [
		_enemy(0, 0.43, ROLE_MELEE),
		_enemy(1, 0.48, ROLE_MELEE),
		_enemy(2, 0.52, ROLE_RANGED),
		_enemy(3, 0.38, ROLE_MELEE),
	]
	return _room(&"moon_gate", "月影门廊", platforms, enemies, Color("#78bdc3"))


static func _broken_stair() -> Dictionary:
	var platforms: Array[Rect2] = [
		Rect2(-80.0, 640.0, 1440.0, 160.0),
		Rect2(190.0, 545.0, 170.0, 28.0),
		Rect2(410.0, 470.0, 180.0, 28.0),
		Rect2(650.0, 390.0, 180.0, 28.0),
		Rect2(890.0, 480.0, 190.0, 28.0),
		Rect2(1090.0, 350.0, 150.0, 28.0),
	]
	var enemies: Array[Dictionary] = [
		_enemy(0, 0.68, ROLE_MELEE),
		_enemy(1, 0.50, ROLE_MELEE),
		_enemy(3, 0.50, ROLE_RANGED),
		_enemy(4, 0.52, ROLE_MELEE),
		_enemy(5, 0.48, ROLE_RANGED),
	]
	return _room(&"broken_stair", "断阶回廊", platforms, enemies, Color("#d3a25d"))


static func _twin_bridge() -> Dictionary:
	var platforms: Array[Rect2] = [
		Rect2(-80.0, 640.0, 1440.0, 160.0),
		Rect2(160.0, 485.0, 280.0, 28.0),
		Rect2(500.0, 365.0, 240.0, 28.0),
		Rect2(800.0, 485.0, 280.0, 28.0),
		Rect2(1030.0, 325.0, 170.0, 28.0),
	]
	var enemies: Array[Dictionary] = [
		_enemy(0, 0.52, ROLE_MELEE),
		_enemy(1, 0.32, ROLE_MELEE),
		_enemy(1, 0.76, ROLE_RANGED),
		_enemy(2, 0.50, ROLE_RANGED),
		_enemy(3, 0.50, ROLE_MELEE),
	]
	return _room(&"twin_bridge", "双桥中庭", platforms, enemies, Color("#85a7e8"))


static func _sunken_forge() -> Dictionary:
	var platforms: Array[Rect2] = [
		Rect2(-80.0, 640.0, 430.0, 160.0),
		Rect2(455.0, 640.0, 360.0, 160.0),
		Rect2(925.0, 640.0, 435.0, 160.0),
		Rect2(300.0, 515.0, 220.0, 28.0),
		Rect2(700.0, 470.0, 210.0, 28.0),
		Rect2(1010.0, 390.0, 180.0, 28.0),
	]
	var enemies: Array[Dictionary] = [
		_enemy(0, 0.70, ROLE_MELEE),
		_enemy(1, 0.45, ROLE_MELEE),
		_enemy(2, 0.35, ROLE_MELEE),
		_enemy(3, 0.52, ROLE_RANGED),
		_enemy(4, 0.50, ROLE_RANGED),
	]
	return _room(&"sunken_forge", "沉没锻炉", platforms, enemies, Color("#e17655"))


static func _high_gallery() -> Dictionary:
	var platforms: Array[Rect2] = [
		Rect2(-80.0, 640.0, 1440.0, 160.0),
		Rect2(210.0, 430.0, 210.0, 28.0),
		Rect2(500.0, 535.0, 210.0, 28.0),
		Rect2(790.0, 405.0, 210.0, 28.0),
		Rect2(1050.0, 520.0, 170.0, 28.0),
		Rect2(515.0, 295.0, 200.0, 28.0),
	]
	var enemies: Array[Dictionary] = [
		_enemy(0, 0.76, ROLE_MELEE),
		_enemy(1, 0.50, ROLE_RANGED),
		_enemy(2, 0.42, ROLE_MELEE),
		_enemy(3, 0.52, ROLE_RANGED),
		_enemy(4, 0.50, ROLE_MELEE),
		_enemy(5, 0.50, ROLE_RANGED),
	]
	return _room(&"high_gallery", "高塔画廊", platforms, enemies, Color("#9c7bd8"))


static func _crescent_spires() -> Dictionary:
	var platforms: Array[Rect2] = [
		Rect2(-80.0, 640.0, 1440.0, 160.0),
		Rect2(120.0, 520.0, 190.0, 28.0),
		Rect2(365.0, 400.0, 175.0, 28.0),
		Rect2(610.0, 510.0, 180.0, 28.0),
		Rect2(850.0, 380.0, 190.0, 28.0),
		Rect2(1065.0, 495.0, 155.0, 28.0),
		Rect2(575.0, 285.0, 150.0, 28.0),
	]
	var enemies: Array[Dictionary] = [
		_enemy(0, 0.42, ROLE_MELEE),
		_enemy(1, 0.50, ROLE_MELEE),
		_enemy(2, 0.52, ROLE_RANGED),
		_enemy(3, 0.46, ROLE_MELEE),
		_enemy(4, 0.54, ROLE_RANGED),
		_enemy(5, 0.48, ROLE_MELEE),
		_enemy(6, 0.50, ROLE_RANGED),
	]
	return _room(&"crescent_spires", "新月双塔", platforms, enemies, Color("#6dcbd2"))


static func _shattered_crossing() -> Dictionary:
	var platforms: Array[Rect2] = [
		Rect2(-80.0, 640.0, 410.0, 160.0),
		Rect2(420.0, 640.0, 330.0, 160.0),
		Rect2(845.0, 640.0, 515.0, 160.0),
		Rect2(235.0, 505.0, 205.0, 28.0),
		Rect2(515.0, 410.0, 210.0, 28.0),
		Rect2(790.0, 505.0, 205.0, 28.0),
		Rect2(1015.0, 370.0, 180.0, 28.0),
	]
	var enemies: Array[Dictionary] = [
		_enemy(0, 0.62, ROLE_MELEE),
		_enemy(1, 0.52, ROLE_MELEE),
		_enemy(2, 0.46, ROLE_RANGED),
		_enemy(3, 0.50, ROLE_MELEE),
		_enemy(4, 0.48, ROLE_RANGED),
		_enemy(5, 0.52, ROLE_MELEE),
		_enemy(6, 0.50, ROLE_RANGED),
	]
	return _room(&"shattered_crossing", "碎裂渡口", platforms, enemies, Color("#d4935c"))


static func _hanging_gardens() -> Dictionary:
	var platforms: Array[Rect2] = [
		Rect2(-80.0, 640.0, 1440.0, 160.0),
		Rect2(105.0, 455.0, 225.0, 28.0),
		Rect2(390.0, 545.0, 185.0, 28.0),
		Rect2(635.0, 430.0, 225.0, 28.0),
		Rect2(920.0, 535.0, 205.0, 28.0),
		Rect2(1015.0, 340.0, 185.0, 28.0),
		Rect2(520.0, 300.0, 180.0, 28.0),
	]
	var enemies: Array[Dictionary] = [
		_enemy(0, 0.46, ROLE_MELEE),
		_enemy(1, 0.48, ROLE_RANGED),
		_enemy(2, 0.52, ROLE_MELEE),
		_enemy(3, 0.44, ROLE_MELEE),
		_enemy(4, 0.56, ROLE_RANGED),
		_enemy(5, 0.50, ROLE_MELEE),
		_enemy(6, 0.50, ROLE_RANGED),
	]
	return _room(&"hanging_gardens", "悬空庭园", platforms, enemies, Color("#72b98a"))


static func _eclipse_well() -> Dictionary:
	var platforms: Array[Rect2] = [
		Rect2(-80.0, 640.0, 470.0, 160.0),
		Rect2(495.0, 640.0, 285.0, 160.0),
		Rect2(885.0, 640.0, 475.0, 160.0),
		Rect2(165.0, 510.0, 190.0, 28.0),
		Rect2(430.0, 385.0, 180.0, 28.0),
		Rect2(680.0, 500.0, 180.0, 28.0),
		Rect2(930.0, 380.0, 190.0, 28.0),
		Rect2(545.0, 280.0, 190.0, 28.0),
	]
	var enemies: Array[Dictionary] = [
		_enemy(0, 0.58, ROLE_MELEE),
		_enemy(1, 0.50, ROLE_MELEE),
		_enemy(2, 0.42, ROLE_MELEE),
		_enemy(3, 0.50, ROLE_RANGED),
		_enemy(4, 0.48, ROLE_MELEE),
		_enemy(5, 0.52, ROLE_RANGED),
		_enemy(6, 0.50, ROLE_MELEE),
		_enemy(7, 0.50, ROLE_RANGED),
	]
	return _room(&"eclipse_well", "蚀月深井", platforms, enemies, Color("#6f7fe0"))


static func _fang_gauntlet() -> Dictionary:
	var platforms: Array[Rect2] = [
		Rect2(-80.0, 640.0, 1440.0, 160.0),
		Rect2(155.0, 545.0, 155.0, 28.0),
		Rect2(355.0, 455.0, 165.0, 28.0),
		Rect2(565.0, 350.0, 175.0, 28.0),
		Rect2(790.0, 455.0, 165.0, 28.0),
		Rect2(1000.0, 545.0, 155.0, 28.0),
		Rect2(1010.0, 325.0, 170.0, 28.0),
	]
	var enemies: Array[Dictionary] = [
		_enemy(0, 0.48, ROLE_MELEE),
		_enemy(1, 0.50, ROLE_MELEE),
		_enemy(2, 0.50, ROLE_RANGED),
		_enemy(3, 0.50, ROLE_MELEE),
		_enemy(4, 0.50, ROLE_RANGED),
		_enemy(5, 0.50, ROLE_MELEE),
		_enemy(6, 0.50, ROLE_RANGED),
	]
	return _room(&"fang_gauntlet", "獠牙试炼场", platforms, enemies, Color("#cf5c67"))


static func _mirrored_ramparts() -> Dictionary:
	var platforms: Array[Rect2] = [
		Rect2(-80.0, 640.0, 1440.0, 160.0),
		Rect2(95.0, 505.0, 235.0, 28.0),
		Rect2(390.0, 390.0, 210.0, 28.0),
		Rect2(680.0, 390.0, 210.0, 28.0),
		Rect2(950.0, 505.0, 235.0, 28.0),
		Rect2(535.0, 525.0, 210.0, 28.0),
		Rect2(535.0, 275.0, 210.0, 28.0),
	]
	var enemies: Array[Dictionary] = [
		_enemy(0, 0.40, ROLE_MELEE),
		_enemy(1, 0.50, ROLE_RANGED),
		_enemy(2, 0.50, ROLE_MELEE),
		_enemy(3, 0.50, ROLE_RANGED),
		_enemy(4, 0.50, ROLE_MELEE),
		_enemy(5, 0.50, ROLE_MELEE),
		_enemy(6, 0.50, ROLE_RANGED),
	]
	return _room(&"mirrored_ramparts", "镜像壁垒", platforms, enemies, Color("#9b79cf"))


static func _abyssal_steps() -> Dictionary:
	var platforms: Array[Rect2] = [
		Rect2(-80.0, 640.0, 360.0, 160.0),
		Rect2(385.0, 640.0, 250.0, 160.0),
		Rect2(740.0, 640.0, 250.0, 160.0),
		Rect2(1095.0, 640.0, 265.0, 160.0),
		Rect2(215.0, 500.0, 175.0, 28.0),
		Rect2(500.0, 405.0, 175.0, 28.0),
		Rect2(785.0, 500.0, 175.0, 28.0),
		Rect2(1035.0, 370.0, 170.0, 28.0),
	]
	var enemies: Array[Dictionary] = [
		_enemy(0, 0.58, ROLE_MELEE),
		_enemy(1, 0.50, ROLE_MELEE),
		_enemy(2, 0.50, ROLE_RANGED),
		_enemy(3, 0.48, ROLE_MELEE),
		_enemy(4, 0.50, ROLE_RANGED),
		_enemy(5, 0.50, ROLE_MELEE),
		_enemy(6, 0.50, ROLE_RANGED),
		_enemy(7, 0.50, ROLE_MELEE),
	]
	return _room(&"abyssal_steps", "深渊断阶", platforms, enemies, Color("#4b9aae"))


static func _enemy(surface_index: int, horizontal_ratio: float, role: int) -> Dictionary:
	return {
		"surface": surface_index,
		"ratio": clampf(horizontal_ratio, 0.0, 1.0),
		"role": role,
	}


static func _room(
	id: StringName,
	title: String,
	platforms: Array[Rect2],
	enemies: Array[Dictionary],
	accent: Color
) -> Dictionary:
	return {
		"id": id,
		"title": title,
		"platforms": platforms,
		"enemies": enemies,
		"accent": accent,
	}
