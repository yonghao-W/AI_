class_name MeleeComboState
extends RefCounted
## 纯近战连击时序：不依赖场景树、Player、HUD、相机或网络。

const DEFAULT_MAX_STAGES := 3
const DEFAULT_COMBO_WINDOW := 0.45
const DEFAULT_BUFFER_WINDOW := 0.2

var max_stages := DEFAULT_MAX_STAGES
var combo_window := DEFAULT_COMBO_WINDOW
var buffer_window := DEFAULT_BUFFER_WINDOW

var stage := 0
var swing_left := 0.0
var swing_total := 0.0
var combo_left := 0.0
var hit_at := 0.0
var hit_stage := 0
var hit_pending := false
var buffered := false

var hit_this_tick := false
var chain_requested := false
var finished_this_tick := false
var reset_this_tick := false


func _init(stages: int = DEFAULT_MAX_STAGES, window: float = DEFAULT_COMBO_WINDOW, buffer: float = DEFAULT_BUFFER_WINDOW) -> void:
	max_stages = maxi(1, stages)
	combo_window = maxf(0.0, window)
	buffer_window = maxf(0.0, buffer)


func is_active() -> bool:
	return stage > 0 and (swing_left > 0.0 or combo_left > 0.0)


func is_swinging() -> bool:
	return stage > 0 and swing_left > 0.0


func active_stage() -> int:
	return stage if is_active() else 0


func progress() -> float:
	if swing_left <= 0.0 or swing_total <= 0.0:
		return 0.0
	return clampf(1.0 - swing_left / swing_total, 0.0, 1.0)


func next_stage() -> int:
	if stage > 0 and stage < max_stages and combo_left > 0.0 and swing_left <= 0.0:
		return stage + 1
	return 1


func buffer_attack() -> bool:
	if not is_swinging():
		return false
	if swing_left > buffer_window or stage >= max_stages:
		return false
	buffered = true
	return true


func begin(duration: float, contact_fraction: float, forced_stage: int = -1) -> int:
	stage = clampi(forced_stage if forced_stage > 0 else next_stage(), 1, max_stages)
	swing_total = maxf(0.01, duration)
	swing_left = swing_total
	combo_left = 0.0
	hit_at = clampf(contact_fraction, 0.0, 1.0)
	hit_stage = stage
	hit_pending = true
	buffered = false
	hit_this_tick = false
	chain_requested = false
	finished_this_tick = false
	reset_this_tick = false
	return stage


func tick(delta: float) -> void:
	hit_this_tick = false
	chain_requested = false
	finished_this_tick = false
	reset_this_tick = false
	if stage <= 0:
		return
	if swing_left > 0.0:
		var before := clampf(1.0 - swing_left / maxf(0.01, swing_total), 0.0, 1.0)
		swing_left = maxf(0.0, swing_left - delta)
		var after := clampf(1.0 - swing_left / maxf(0.01, swing_total), 0.0, 1.0)
		if hit_pending and before < hit_at and after >= hit_at:
			hit_pending = false
			hit_stage = stage
			hit_this_tick = true
		if swing_left <= 0.0:
			hit_pending = false
			finished_this_tick = true
			if stage < max_stages:
				combo_left = combo_window
				if buffered:
					buffered = false
					chain_requested = true
			else:
				_clear_swing()
				stage = 0
				combo_left = 0.0
				reset_this_tick = true
		return
	combo_left = maxf(0.0, combo_left - delta)
	if combo_left <= 0.0:
		stage = 0
		reset_this_tick = true


func cancel() -> void:
	stage = 0
	swing_left = 0.0
	swing_total = 0.0
	combo_left = 0.0
	hit_at = 0.0
	hit_stage = 0
	hit_pending = false
	buffered = false
	hit_this_tick = false
	chain_requested = false
	finished_this_tick = false
	reset_this_tick = false


func _clear_swing() -> void:
	swing_left = 0.0
	swing_total = 0.0
	hit_pending = false
