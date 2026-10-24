extends SceneTree
## UI 视觉回归矩阵：4 种分辨率 × 13 个真实状态，离屏渲染并输出 manifest。
## 基线模式默认关闭动态效果并冻结 SceneTree，避免浮尘/粒子/丧尸运动导致像素漂移。
## 用法：
##   Godot --path . --headless --script res://ui_refactor/phase3/tools/capture_ui_matrix.gd -- \
##     --out=ui_refactor/phase3/baselines \
##     --manifest=ui_refactor/phase3/evidence/baseline_manifest.json \
##     --commit=<git sha>

const SIZES := [
	Vector2i(1280, 720),
	Vector2i(1920, 1080),
	Vector2i(1920, 1200),
	Vector2i(2560, 1080),
]
const SEED := 4242
const DRAW_OPTIONS := [
	{"title": "磁轨弹匣", "desc": "弹匣容量 +2，换弹速度 -8%。", "accent": "#ffcb66", "level": 2},
	{"title": "肾上腺素", "desc": "低生命时移动速度 +12%。", "accent": "#7fc3ba", "level": 1},
	{"title": "回收协议", "desc": "每回收一个核心，回复 8 点生命。", "accent": "#b997ff", "level": 0},
]

var _out_dir := "ui_refactor/phase3/baselines"
var _manifest_path := "ui_refactor/phase3/evidence/baseline_manifest.json"
var _commit := ""
var _entries: Array = []
var _viewport: SubViewport
var _game: Node


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out_dir = arg.trim_prefix("--out=")
		elif arg.begins_with("--manifest="):
			_manifest_path = arg.trim_prefix("--manifest=")
		elif arg.begins_with("--commit="):
			_commit = arg.trim_prefix("--commit=")
	_run.call_deferred()


func _run() -> void:
	var settings := root.get_node_or_null("UISettings")
	if settings != null:
		settings.set("hud_scale", 1.0)
		settings.set("high_contrast", false)
		settings.set("reduced_motion", true)
		settings.emit_signal("changed", "all")

	for index in range(SIZES.size()):
		var size: Vector2i = SIZES[index]
		await _capture_resolution(size, 17920 + index)

	_write_manifest()
	print("[matrix] %d captures -> %s" % [_entries.size(), _manifest_path])
	quit(0)


func _capture_resolution(size: Vector2i, port: int) -> void:
	print("[matrix] resolution %dx%d" % [size.x, size.y])

	# 菜单组：主菜单 → 联机子界面 → 设置 → 军械库。
	_open_game(size)
	await _wait(1.2)
	await _shot("menu")
	_game.menu.open_view("coop")
	await _wait(0.5)
	await _shot("menu_coop")
	_game.menu.open_view("settings")
	await _wait(0.5)
	await _shot("menu_settings")
	_game.menu.open_armory()
	await _wait(0.7)
	await _shot("menu_armory")
	await _close_game()

	# 联机大厅：单房主、未准备状态。
	_open_game(size)
	_game.menu.host_requested.emit("HOST", port, SEED)
	await _wait(1.4)
	await _shot("lobby")
	await _close_game()

	# 战斗 HUD 组：正常 → 低血 → 搬运 → 四人小队 → 暂停 → 强化 → 背包 → 情报。
	_open_game(size)
	_game.menu.solo_requested.emit("CAPTURE", SEED)
	var deadline := Time.get_ticks_msec() + 25000
	while not _game.game_started and Time.get_ticks_msec() < deadline:
		await process_frame
	if not _game.game_started:
		push_error("Solo match did not start at %dx%d" % [size.x, size.y])
		await _close_game()
		return
	# UI 回归只比较界面本身：隔离 3D 世界并关闭输入，避免丧尸、武器与弹药在等待期间变化。
	_game.player.set_input_enabled(false)
	var world := _game.get("_world") as Node3D
	if world != null:
		world.visible = false
	RenderingServer.set_default_clear_color(Color("#15181b"))
	await _wait(1.2)
	await _shot("hud_normal")

	_game.hud.set_pause_note("单人行动已暂停 · 服务器模拟停止")
	_game.hud.set_pause_visible(true)
	await _wait(0.35)
	await _shot("pause")
	_game.hud.set_pause_visible(false)
	await _wait(0.2)

	_game.hud.show_draw(DRAW_OPTIONS)
	await _wait(0.45)
	await _shot("draw")
	_game.hud.hide_draw()
	await _wait(0.2)

	_game.call("_open_backpack")
	await _wait(0.5)
	await _shot("backpack")
	_game.call("_close_overlays")
	await _wait(0.2)

	_game.call("_open_intel")
	await _wait(0.5)
	await _shot("intel")
	_game.call("_close_overlays")
	await _wait(0.2)

	_game.call("_apply_hud_demo", "lowhealth")
	await _wait(0.35)
	await _shot("hud_low_health")

	_reset_hud_demo()
	_game.hud.set_carry_preview(true)
	await _wait(0.35)
	await _shot("hud_carry")

	_reset_hud_demo()
	_game.call("_apply_hud_demo", "squad_low")
	await _wait(0.45)
	await _shot("hud_squad_four")
	await _close_game()

	await _wait(0.2)


func _reset_hud_demo() -> void:
	_game.set("_demo_active", false)
	_game.hud.set_carry_preview(false)
	_game.hud.set_health(100.0)
	_game.hud.set_ammo(_game.player.mag, _game.player.reserve, false, 0.0, _game.player.is_melee_equipped())


func _open_game(size: Vector2i) -> void:
	_viewport = SubViewport.new()
	_viewport.size = size
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_viewport)
	_game = load("res://scenes/main.tscn").instantiate()
	_viewport.add_child(_game)


func _close_game() -> void:
	if _game != null:
		_game.queue_free()
		_game = null
	if _viewport != null:
		_viewport.queue_free()
		_viewport = null
	await process_frame
	await process_frame


func _wait(seconds: float) -> void:
	await create_timer(seconds).timeout


func _shot(state: String) -> void:
	var was_paused := paused
	paused = true
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var banner := _game.hud.get("_banner_box") as Control
	if banner != null:
		banner.modulate.a = 0.0
	await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = _viewport.get_texture().get_image()
	paused = was_paused
	if image == null:
		push_error("Capture failed: %s" % state)
		return
	var relative := "%s/%s_%dx%d.png" % [_out_dir, state, _viewport.size.x, _viewport.size.y]
	var absolute := ProjectSettings.globalize_path("res://" + relative)
	DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
	var err := image.save_png(absolute)
	var sha := FileAccess.get_sha256(absolute) if err == OK else ""
	print("[matrix] %s %dx%d err=%d" % [state, _viewport.size.x, _viewport.size.y, err])
	_entries.append({
		"state": state,
		"width": _viewport.size.x,
		"height": _viewport.size.y,
		"path": relative,
		"sha256": sha,
		"seed": SEED,
		"reduced_motion": true,
		"hud_scale": 1.0,
		"high_contrast": false,
	})


func _write_manifest() -> void:
	var absolute := ProjectSettings.globalize_path("res://" + _manifest_path)
	DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
	var payload := {
		"generated_at": Time.get_datetime_string_from_system(true),
		"git_commit": _commit,
		"godot_version": Engine.get_version_info().get("string", "unknown"),
		"engine_commit": Engine.get_version_info().get("hash", ""),
		"seed": SEED,
		"reduced_motion": true,
		"command": "Godot --path . --headless --script res://ui_refactor/phase3/tools/capture_ui_matrix.gd -- --out=%s --manifest=%s --commit=%s" % [_out_dir, _manifest_path, _commit],
		"captures": _entries,
	}
	var file := FileAccess.open(absolute, FileAccess.WRITE)
	if file == null:
		push_error("Cannot write manifest: %s" % absolute)
		return
	file.store_string(JSON.stringify(payload, "\t"))
	file.close()
