extends RefCounted

## Hand-authored room layouts used to assemble a run in a random order.
class_name RunRoomCatalog

const ROLE_MELEE := 0
const ROLE_RANGED := 1


static func create_room_pool() -> Array[Dictionary]:
	return [
		_moon_gate(),
		_broken_stair(),
		_twin_bridge(),
		_sunken_forge(),
		_high_gallery(),
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
