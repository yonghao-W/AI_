extends SceneTree
## 设置中心截图：4 分辨率 × 6 分类，另加暂停菜单入口。

const SIZES := [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(1920, 1200), Vector2i(2560, 1080)]
const CATEGORIES := ["controls", "display", "audio", "hud", "keybind", "accessibility"]
const OUT := "ui_refactor/settings_v2/shots"

var _viewport: SubViewport
var _game: Node


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for size in SIZES:
		_open_game(size)
		await _wait(1.2)
		_game.menu.settings_requested.emit()
		await _wait(0.6)
		paused = true
		var panel = _game.get("_settings_panel")
		for category in CATEGORIES:
			panel.call("_select_category", category)
			await process_frame
			await process_frame
			await _shot("settings_%s_%dx%d" % [category, size.x, size.y])
		paused = false
		panel.close()
		await _wait(0.2)
		await _close_game()
	await _capture_pause_entry()
	quit(0)


func _capture_pause_entry() -> void:
	_open_game(Vector2i(1280, 720))
	await _wait(1.2)
	_game.menu.solo_requested.emit("SETTINGS SHOT", 4242)
	var deadline := Time.get_ticks_msec() + 22000
	while not _game.game_started and Time.get_ticks_msec() < deadline:
		await process_frame
	if not _game.game_started:
		await _close_game()
		return
	await _wait(1.6)
	_game.call("_pause_game")
	await _wait(0.5)
	_game.hud.settings_requested.emit()
	await _wait(0.6)
	paused = true
	await process_frame
	await process_frame
	await _shot("settings_from_pause_1280x720")
	paused = false
	_game.get("_settings_panel").close()
	await _close_game()


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


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = _viewport.get_texture().get_image()
	if image == null:
		push_error("capture failed: " + name)
		return
	var path := "%s/%s.png" % [OUT, name]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://" + OUT))
	var err := image.save_png(ProjectSettings.globalize_path("res://" + path))
	print("[settings-shot] %s %dx%d err=%d" % [name, _viewport.size.x, _viewport.size.y, err])
