extends SceneTree
## UI 成本差分采样：同一场景下分别测“显示 / 隐藏 UI”，差值即 UI 的帧与渲染成本。
## 用法：Godot --path . --resolution 1280x720 --script res://ui_refactor/phase3/tools/perf_ui.gd -- --out=... --commit=<sha>

var _sampling := false
var _frame_ms: Array[float] = []
var _draw_calls: Array[float] = []
var _primitives: Array[float] = []
var _out_path := "user://perf_ui.json"
var _commit := ""
var _results: Array = []


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out_path = arg.trim_prefix("--out=")
		elif arg.begins_with("--commit="):
			_commit = arg.trim_prefix("--commit=")
	_run.call_deferred()


func _process(_delta: float) -> bool:
	if _sampling:
		_frame_ms.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
		_draw_calls.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		_primitives.append(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	return false


func _run() -> void:
	var result := {
		"generated_at": Time.get_datetime_string_from_system(true),
		"git_commit": _commit,
		"godot_version": Engine.get_version_info().get("string", "unknown"),
		"engine_commit": Engine.get_version_info().get("hash", ""),
		"gpu": RenderingServer.get_video_adapter_name(),
		"renderer": RenderingServer.get_current_rendering_method(),
		"stages": [],
	}

	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await create_timer(1.4).timeout
	paused = true

	await _sample("menu_visible", 300)
	game.menu.visible = false
	game.menu.process_mode = Node.PROCESS_MODE_DISABLED
	await create_timer(0.4).timeout
	await _sample("menu_hidden", 300)
	paused = false

	game.menu.solo_requested.emit("PERF", 4242)
	var deadline := Time.get_ticks_msec() + 25000
	while not game.game_started and Time.get_ticks_msec() < deadline:
		await process_frame
	if not game.game_started:
		push_error("Solo match did not start for perf run")
		quit(1)
		return
	await create_timer(2.2).timeout
	paused = true

	await _sample("hud_visible", 300)
	game.hud.visible = false
	game.hud.process_mode = Node.PROCESS_MODE_DISABLED
	await create_timer(0.4).timeout
	await _sample("hud_hidden", 300)
	paused = false

	game.hud.visible = true
	game.hud.process_mode = Node.PROCESS_MODE_INHERIT
	await create_timer(0.3).timeout
	if game.has_method("_apply_hud_demo"):
		game.call("_apply_hud_demo", "squad_low")
		await create_timer(0.6).timeout
		paused = true
		await _sample("hud_squad_four", 300)
		paused = false

	result["stages"] = _results
	result["ui_delta"] = {
		"menu": _delta("menu_visible", "menu_hidden"),
		"hud": _delta("hud_visible", "hud_hidden"),
	}
	_write(result)
	game.queue_free()
	await process_frame
	quit(0)


func _delta(visible_stage: String, hidden_stage: String) -> Dictionary:
	var visible := _find(visible_stage)
	var hidden := _find(hidden_stage)
	if visible.is_empty() or hidden.is_empty():
		return {}
	return {
		"frame_ms": snappedf(maxf(0.0, visible["frame_ms"]["p95"] - hidden["frame_ms"]["p95"]), 0.001),
		"draw_calls": snappedf(maxf(0.0, visible["draw_calls"]["p95"] - hidden["draw_calls"]["p95"]), 0.001),
		"primitives": snappedf(maxf(0.0, visible["primitives"]["p95"] - hidden["primitives"]["p95"]), 0.001),
	}


func _find(stage: String) -> Dictionary:
	for entry in _results:
		if entry["stage"] == stage:
			return entry
	return {}


func _sample(stage: String, frames: int) -> void:
	_frame_ms.clear()
	_draw_calls.clear()
	_primitives.clear()
	_sampling = true
	for i in range(frames):
		await process_frame
	_sampling = false
	var entry := {
		"stage": stage,
		"frames": _frame_ms.size(),
		"frame_ms": _stats(_frame_ms),
		"draw_calls": _stats(_draw_calls),
		"primitives": _stats(_primitives),
	}
	_results.append(entry)
	print("[perf] %s n=%d frame p50=%.3f p95=%.3f p99=%.3f | draws p95=%.1f | prims p95=%.1f" % [
		stage, entry["frames"],
		entry["frame_ms"]["p50"], entry["frame_ms"]["p95"], entry["frame_ms"]["p99"],
		entry["draw_calls"]["p95"], entry["primitives"]["p95"],
	])


func _stats(values: Array[float]) -> Dictionary:
	var sorted_values := values.duplicate()
	sorted_values.sort()
	var count := sorted_values.size()
	if count == 0:
		return {"avg": 0.0, "p50": 0.0, "p95": 0.0, "p99": 0.0, "max": 0.0}
	var total := 0.0
	for value in sorted_values:
		total += value
	return {
		"avg": snappedf(total / float(count), 0.001),
		"p50": snappedf(sorted_values[count >> 1], 0.001),
		"p95": snappedf(sorted_values[int(ceil(float(count) * 0.95)) - 1], 0.001),
		"p99": snappedf(sorted_values[int(ceil(float(count) * 0.99)) - 1], 0.001),
		"max": snappedf(sorted_values[count - 1], 0.001),
	}


func _write(payload: Dictionary) -> void:
	var file := FileAccess.open(_out_path, FileAccess.WRITE)
	if file == null:
		push_error("Cannot write perf report: %s" % _out_path)
		return
	file.store_string(JSON.stringify(payload, "\t"))
	file.close()
	print("[perf] report -> %s" % _out_path)
