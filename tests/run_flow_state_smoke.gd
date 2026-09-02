extends SceneTree

const FLOW_STATE := preload("res://scripts/run_flow_state.gd")


func _initialize() -> void:
	call_deferred(&"_run_test")


func _run_test() -> void:
	var state: RunFlowState = FLOW_STATE.new() as RunFlowState
	var transitions: Array[int] = [
		RunFlowState.Phase.ROOM_LOADING,
		RunFlowState.Phase.COMBAT,
		RunFlowState.Phase.CHEST,
		RunFlowState.Phase.RISK_AMBUSH,
		RunFlowState.Phase.UPGRADE,
		RunFlowState.Phase.SHOP,
		RunFlowState.Phase.EVENT,
		RunFlowState.Phase.COMPLETE,
		RunFlowState.Phase.DEATH_RESTART,
		RunFlowState.Phase.IDLE,
	]
	for next_phase: int in transitions:
		state.transition_to(next_phase)
		if state.phase != next_phase or not state.has_consistent_flags():
			_fail("Flow state produced inconsistent flags for phase %d" % next_phase)
			return
	state.begin_combat()
	if not state.run_active or state.choosing_upgrade or state.awaiting_chest:
		_fail("Combat phase contract changed")
		return
	state.begin_shop()
	if not state.shopping or not state.choosing_upgrade or state.run_active:
		_fail("Shop phase contract changed")
		return
	state.begin_risk_ambush()
	if not state.risk_ambush_active or not state.run_active:
		_fail("Risk ambush phase contract changed")
		return
	print("run_flow_state_smoke: PASS")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
