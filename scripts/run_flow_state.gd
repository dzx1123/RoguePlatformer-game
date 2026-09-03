class_name RunFlowState
extends RefCounted

## Single source of truth for a run's mutually-exclusive gameplay phase.
## Main keeps orchestration responsibilities while this object owns phase flags.

enum Phase {
	IDLE,
	ROOM_LOADING,
	COMBAT,
	CHEST,
	EXIT_PORTAL,
	UPGRADE,
	SHOP,
	EVENT,
	RISK_AMBUSH,
	COMPLETE,
	DEATH_RESTART,
}

var phase: int = Phase.IDLE
var run_active: bool = false
var choosing_upgrade: bool = false
var run_complete: bool = false
var death_restart_pending: bool = false
var awaiting_chest: bool = false
var awaiting_exit: bool = false
var shopping: bool = false
var event_active: bool = false
var risk_ambush_active: bool = false


func transition_to(next_phase: int) -> void:
	phase = clampi(next_phase, Phase.IDLE, Phase.DEATH_RESTART)
	run_active = phase == Phase.COMBAT or phase == Phase.RISK_AMBUSH
	choosing_upgrade = phase in [Phase.UPGRADE, Phase.SHOP, Phase.EVENT]
	run_complete = phase == Phase.COMPLETE
	death_restart_pending = phase == Phase.DEATH_RESTART
	awaiting_chest = phase == Phase.CHEST
	awaiting_exit = phase == Phase.EXIT_PORTAL
	shopping = phase == Phase.SHOP
	event_active = phase == Phase.EVENT
	risk_ambush_active = phase == Phase.RISK_AMBUSH


func reset_for_run() -> void:
	transition_to(Phase.ROOM_LOADING)


func begin_room_loading() -> void:
	transition_to(Phase.ROOM_LOADING)


func begin_combat() -> void:
	transition_to(Phase.COMBAT)


func begin_chest() -> void:
	transition_to(Phase.CHEST)


func begin_exit_portal() -> void:
	transition_to(Phase.EXIT_PORTAL)


func begin_upgrade() -> void:
	transition_to(Phase.UPGRADE)


func begin_shop() -> void:
	transition_to(Phase.SHOP)


func begin_event() -> void:
	transition_to(Phase.EVENT)


func begin_risk_ambush() -> void:
	transition_to(Phase.RISK_AMBUSH)


func complete_run() -> void:
	transition_to(Phase.COMPLETE)


func begin_death_restart() -> void:
	transition_to(Phase.DEATH_RESTART)


func snapshot() -> Dictionary:
	return {
		"phase": phase,
		"run_active": run_active,
		"choosing_upgrade": choosing_upgrade,
		"run_complete": run_complete,
		"death_restart_pending": death_restart_pending,
		"awaiting_chest": awaiting_chest,
		"awaiting_exit": awaiting_exit,
		"shopping": shopping,
		"event_active": event_active,
		"risk_ambush_active": risk_ambush_active,
	}


func has_consistent_flags() -> bool:
	var expected := RunFlowState.new()
	expected.transition_to(phase)
	return snapshot() == expected.snapshot()
