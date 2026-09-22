extends RefCounted

## Shared by both chapters; weapon cadence and accessibility stay identical.
static func apply(player: RoguePlayer, enemy: RogueEnemy, enemies: Array, is_skill_hit: bool) -> void:
	if not is_instance_valid(player) or not is_instance_valid(enemy):
		return
	var duration := player.get_hitstop_duration(is_skill_hit)
	player.apply_hitstop(duration, enemy.is_boss())
	var enemy_duration := duration
	if enemy.is_boss():
		enemy_duration += RoguePlayer.HITSTOP_BOSS_BONUS
	if player.get_reduced_effects_enabled():
		enemy_duration *= 0.35
	enemy.apply_hitstop(enemy_duration)
	for other: RogueEnemy in enemies:
		if is_instance_valid(other) and other != enemy:
			other.apply_hitstop(enemy_duration * 0.62)
