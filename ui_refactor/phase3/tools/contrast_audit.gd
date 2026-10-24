extends SceneTree
## 渲染像素对比度取证：采集真实状态下每个可见 Label/Button 的字号、字色与矩形，
## 然后仅隐藏文字（保留布局与背景）截取背景图，交给 contrast_report.py 计算对比度。
## 用法：Godot --path . --resolution 1280x720 --script res://ui_refactor/phase3/tools/contrast_audit.gd -- --commit=<sha>

const SIZE := Vector2i(1280, 720)
const SEED := 4242
const COLOR_KEYS := [
	"font_color", "font_shadow_color", "font_outline_color",
	"font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color",
]
const DRAW_OPTIONS := [
	{"title": "磁轨弹匣", "desc": "弹匣容量 +2，换弹速度 -8%。", "accent": "#ffcb66", "level": 2},
	{"title": "肾上腺素", "desc": "低生命时移动速度 +12%。", "accent": "#7fc3ba", "level": 1},
	{"title": "回收协议", "desc": "每回收一个核心，回复 8 点生命。", "accent": "#b997ff", "level": 0},
]

var _commit := ""
var _viewport: SubViewport
var _game: Node
var _states: Array = []


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--commit="):
			_commit = arg.trim_prefix("--commit=")
	_run.call_deferred()


func _run() -> void:
	await _menu_states()
	await _lobby_state()
	await _hud_states()
	_write()
	print("[contrast] %d states -> ui_refactor/phase3/evidence/contrast_elements.json" % _states.size())
	quit(0)


func _menu_states() -> void:
	_open_game()
	await _wait(1.4)
	await _capture_state("menu")
	_game.menu.open_view("coop")
	await _wait(0.6)
	await _capture_state("menu_coop")
	_game.menu.open_armory()
	await _wait(0.8)
	await _capture_state("menu_armory")
	await _close_game()


func _lobby_state() -> void:
	_open_game()
	_game.menu.host_requested.emit("HOST", 17940, SEED)
	await _wait(1.5)
	await _capture_state("lobby")
	await _close_game()


func _hud_states() -> void:
	_open_game()
	_game.menu.solo_requested.emit("CONTRAST", SEED)
	var deadline := Time.get_ticks_msec() + 25000
	while not _game.game_started and Time.get_ticks_msec() < deadline:
		await process_frame
	if not _game.game_started:
		push_error("Solo match did not start for contrast audit")
		await _close_game()
		return
	await _wait(2.0)
	await _capture_state("hud_normal")
	_game.call("_apply_hud_demo", "lowhealth")
	await _wait(0.4)
	await _capture_state("hud_low_health")
	_game.call("_apply_hud_demo", "squad_low")
	await _wait(0.5)
	await _capture_state("hud_squad_four")
	_game.hud.set_pause_note("单人行动已暂停 · 服务器模拟停止")
	_game.hud.set_pause_visible(true)
	await _wait(0.4)
	await _capture_state("pause")
	_game.hud.set_pause_visible(false)
	await _wait(0.2)
	_game.hud.show_draw(DRAW_OPTIONS)
	await _wait(0.5)
	await _capture_state("draw")
	_game.hud.hide_draw()
	await _wait(0.2)
	_game.call("_open_backpack")
	await _wait(0.5)
	await _capture_state("backpack")
	_game.call("_close_overlays")
	await _wait(0.2)
	_game.call("_open_intel")
	await _wait(0.5)
	await _capture_state("intel")
	_game.call("_close_overlays")
	await _close_game()


func _open_game() -> void:
	_viewport = SubViewport.new()
	_viewport.size = SIZE
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


func _capture_state(state: String) -> void:
	paused = true
	await process_frame
	await process_frame
	var viewport_rect := Rect2(Vector2.ZERO, Vector2(_viewport.size))
	var elements: Array = []
	var targets: Array = []
	_collect(_game, viewport_rect, elements, targets)

	var saved: Array = []
	for node in targets:
		var record := {}
		for key in COLOR_KEYS:
			record[key] = {
				"had_override": node.has_theme_color_override(key),
				"color": node.get_theme_color(key),
			}
			node.add_theme_color_override(key, Color(0, 0, 0, 0))
		saved.append({"node": node, "record": record})

	await RenderingServer.frame_post_draw
	var image: Image = _viewport.get_texture().get_image()
	var background_path := "ui_refactor/phase3/shots/contrast/%s_bg.png" % state
	var absolute := ProjectSettings.globalize_path("res://" + background_path)
	DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
	var err := image.save_png(absolute)

	for entry in saved:
		var node: Node = entry["node"]
		for key in COLOR_KEYS:
			var record: Dictionary = entry["record"][key]
			if record["had_override"]:
				node.add_theme_color_override(key, record["color"])
			else:
				node.remove_theme_color_override(key)

	paused = false
	_states.append({
		"state": state,
		"background": background_path,
		"background_saved": err == OK,
		"width": _viewport.size.x,
		"height": _viewport.size.y,
		"elements": elements,
	})
	print("[contrast] %s elements=%d bg=%s" % [state, elements.size(), background_path])


func _collect(node: Node, viewport_rect: Rect2, elements: Array, targets: Array) -> void:
	var control := node as Control
	if control != null and control.is_visible_in_tree():
		var text := ""
		var font_size := 0
		var color := Color.WHITE
		var kind := ""
		if control is Label:
			text = String(control.text).strip_edges()
			font_size = control.get_theme_font_size("font_size")
			color = control.get_theme_color("font_color")
			kind = "label"
		elif control is Button:
			text = String(control.text).strip_edges()
			font_size = control.get_theme_font_size("font_size")
			color = control.get_theme_color("font_color")
			kind = "button"
		if not text.is_empty() and font_size >= 9:
			var rect := control.get_global_rect()
			var clipped := rect.intersection(viewport_rect)
			if clipped.size.x >= 4.0 and clipped.size.y >= 4.0:
				var modulate := _effective_modulate(control)
				var effective := Color(
					color.r * modulate.r,
					color.g * modulate.g,
					color.b * modulate.b,
					color.a * modulate.a
				)
				elements.append({
					"kind": kind,
					"text": text.left(80),
					"font_size": font_size,
					"color": [effective.r, effective.g, effective.b, effective.a],
					"rect": [rect.position.x, rect.position.y, rect.size.x, rect.size.y],
					"shadow": control.get_theme_color("font_shadow_color").a > 0.01,
					"outline": control.get_theme_constant("outline_size") > 0,
					"path": String(control.get_path()),
				})
				targets.append(control)
	for child in node.get_children():
		_collect(child, viewport_rect, elements, targets)


func _effective_modulate(node: Node) -> Color:
	var result := Color.WHITE
	var current := node
	while current != null and current is CanvasItem:
		var item := current as CanvasItem
		result *= item.modulate
		current = current.get_parent()
	return result


func _write() -> void:
	var payload := {
		"generated_at": Time.get_datetime_string_from_system(true),
		"git_commit": _commit,
		"godot_version": Engine.get_version_info().get("string", "unknown"),
		"viewport": [SIZE.x, SIZE.y],
		"states": _states,
	}
	var path := "ui_refactor/phase3/evidence/contrast_elements.json"
	var file := FileAccess.open(ProjectSettings.globalize_path("res://" + path), FileAccess.WRITE)
	if file == null:
		push_error("Cannot write %s" % path)
		return
	file.store_string(JSON.stringify(payload, "\t"))
	file.close()
