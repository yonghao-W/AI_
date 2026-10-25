extends SceneTree
## 纯近战状态机回归：不实例化 Player / 场景 / HUD。

const ComboState := preload("res://scripts/melee_combo_state.gd")

var checks := 0
var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("[melee-state] " + message)


func _run() -> void:
	var state: Variant = ComboState.new()
	_check(state.active_stage() == 0 and not state.is_swinging(), "state starts idle")
	_check(state.next_stage() == 1, "idle requests stage 1")

	state.begin(0.5, 0.4, 1)
	_check(state.active_stage() == 1 and state.is_swinging(), "begin starts stage 1")
	_check(is_equal_approx(state.progress(), 0.0), "new swing starts at zero progress")
	state.tick(0.1)
	_check(not state.hit_this_tick, "no hit before contact fraction")
	state.tick(0.15)
	_check(state.hit_this_tick and state.hit_stage == 1, "contact frame emits a stage-1 hit")
	state.tick(0.01)
	_check(not state.hit_this_tick, "hit event is one-shot")

	state.tick(0.3)
	_check(state.finished_this_tick and not state.is_swinging(), "swing finishes into the combo window")
	_check(state.combo_left > 0.0 and state.next_stage() == 2, "combo window advances to stage 2")
	state.begin(0.4, 0.5, 2)
	_check(state.active_stage() == 2, "stage 2 begins with an explicit stage")

	state.tick(0.01)
	_check(not state.buffer_attack(), "too-early click is not buffered")
	state.tick(0.25)
	_check(state.buffer_attack(), "late click buffers inside the window")
	_check(state.buffered, "buffer state is visible")
	state.tick(0.5)
	_check(state.chain_requested and state.buffered == false, "buffered input requests the next stage after the swing")
	_check(state.next_stage() == 3, "buffered chain advances to stage 3")
	state.begin(0.6, 0.5, 3)
	state.tick(1.0)
	_check(state.active_stage() == 0, "finisher resets the chain")
	_check(state.hit_this_tick and state.hit_stage == 3, "finisher hit event keeps its stage before reset")

	var slow: Variant = ComboState.new()
	slow.begin(0.2, 0.5, 1)
	slow.tick(0.25)
	_check(slow.combo_left > 0.0, "slow chain still has a window")
	slow.tick(ComboState.DEFAULT_COMBO_WINDOW + 0.01)
	_check(slow.active_stage() == 0, "expired window resets the chain")
	_check(slow.next_stage() == 1, "expired chain restarts at stage 1")

	var cancelled: Variant = ComboState.new()
	cancelled.begin(0.5, 0.4, 1)
	cancelled.buffer_attack()
	cancelled.cancel()
	_check(cancelled.active_stage() == 0 and cancelled.swing_left == 0.0 and not cancelled.buffered, "cancel clears swing, window and buffer")
	_check(cancelled.hit_stage == 0 and not cancelled.hit_pending, "cancel clears pending hit state")

	var custom: Variant = ComboState.new(2, 0.2, 0.05)
	custom.begin(0.3, 0.5, 1)
	custom.tick(0.26)
	_check(custom.buffer_attack(), "custom buffer window accepts a late click")
	custom.tick(0.2)
	_check(custom.chain_requested and custom.next_stage() == 2, "custom stage count caps at two")
	custom.begin(0.3, 0.5, 2)
	custom.tick(0.4)
	_check(custom.active_stage() == 0, "custom finisher resets")

	var short: Variant = ComboState.new()
	short.begin(0.01, 0.5, 1)
	short.tick(0.02)
	_check(short.finished_this_tick and short.hit_this_tick and short.hit_stage == 1, "a single large tick still reports contact and finish")

	print("Melee combo state: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
