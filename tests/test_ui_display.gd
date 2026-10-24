extends SceneTree
## 输入/显示矩阵：OS DPI 等效分辨率、125%/150% UI 缩放、焦点可见性与覆盖层开关循环。
## 说明：dpi125/dpi150 通过放大物理窗口保持 1280×720 逻辑视口，属于 DPI 等效检查；
## zoom125/zoom150 固定 1280×720 窗口并提高 content scale，属于 UI 放大压力检查，失败记为 warning。

var checks := 0
var failures := 0
var warnings := 0

const CASES := [
	{"name": "base", "size": Vector2i(1280, 720), "factor": 1.0, "required": true, "logical": Vector2i(1280, 720)},
	{"name": "dpi125", "size": Vector2i(1600, 900), "factor": 1.0, "required": true, "logical": Vector2i(1280, 720)},
	{"name": "dpi150", "size": Vector2i(1920, 1080), "factor": 1.0, "required": true, "logical": Vector2i(1280, 720)},
	{"name": "zoom125", "size": Vector2i(1280, 720), "factor": 1.25, "required": false, "logical": Vector2i(1024, 576)},
	{"name": "zoom150", "size": Vector2i(1280, 720), "factor": 1.5, "required": false, "logical": Vector2i(853, 480)},
]


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)


func _warn(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		warnings += 1
		print("[warn] %s" % message)


func _run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await process_frame

	for item in CASES:
		await _apply_case(item)
		_check_viewport(item)
		await _check_menu_layout(game, item)

	await _apply_case(CASES[0])
	game.menu.solo_requested.emit("DISPLAY", 4242)
	var deadline := Time.get_ticks_msec() + 25000
	while not game.game_started and Time.get_ticks_msec() < deadline:
		await process_frame
	_check(game.game_started, "Solo match did not start")
	if game.game_started:
		game.call("_apply_hud_demo", "squad_low")
		await create_timer(1.4).timeout
		for item in CASES:
			await _apply_case(item)
			_check_viewport(item)
			_check_hud_layout(game, item)
		await _apply_case(CASES[0])
		await _test_overlay_cycles(game)

	game.queue_free()
	await process_frame
	print("UI display: %d checks, %d failures, %d warnings" % [checks, failures, warnings])
	quit(1 if failures > 0 else 0)


func _apply_case(item: Dictionary) -> void:
	root.size = item["size"]
	root.content_scale_factor = item["factor"]
	await process_frame
	await process_frame
	await create_timer(0.12).timeout


func _check_viewport(item: Dictionary) -> void:
	var actual := root.get_visible_rect().size
	var expected: Vector2i = item["logical"]
	var ok := absf(actual.x - expected.x) <= 1.0 and absf(actual.y - expected.y) <= 1.0
	if bool(item["required"]):
		_check(ok, "%s logical viewport expected %s, got %s" % [item["name"], expected, actual])
	else:
		_warn(ok, "%s logical viewport expected %s, got %s" % [item["name"], expected, actual])


func _inside(rect: Rect2, viewport: Vector2, margin: float = 1.0) -> bool:
	return rect.position.x >= -margin and rect.position.y >= -margin \
		and rect.end.x <= viewport.x + margin and rect.end.y <= viewport.y + margin


func _check_menu_layout(game: Node, item: Dictionary) -> void:
	var viewport := root.get_visible_rect().size
	var nav: Array = game.menu.get("_nav_items")
	var visible_count := 0
	for raw in nav:
		var button := raw as Button
		if button == null or not button.is_visible_in_tree():
			continue
		visible_count += 1
		var ok := _inside(button.get_global_rect(), viewport)
		if bool(item["required"]):
			_check(ok, "%s menu nav '%s' outside viewport: %s" % [item["name"], button.name, button.get_global_rect()])
		else:
			_warn(ok, "%s menu nav '%s' outside viewport" % [item["name"], button.name])
	if bool(item["required"]):
		_check(visible_count >= 6, "%s menu nav count %d" % [item["name"], visible_count])

	if item["name"] == "base" and not nav.is_empty():
		var target := nav[1] as Button
		target.grab_focus()
		await process_frame
		_check(target.has_focus(), "Keyboard focus is not visible on the second root entry")


func _check_hud_layout(game: Node, item: Dictionary) -> void:
	var viewport := root.get_visible_rect().size
	var hud = game.hud
	var panels := {
		"roster": hud.get("_roster_panel"),
		"mission": hud.get("_mission_panel"),
		"interaction": hud.get("_interaction_panel"),
		"minimap": hud.get("_minimap"),
	}
	for panel_name in panels:
		var panel := panels[panel_name] as Control
		if panel == null or not panel.is_visible_in_tree():
			continue
		var ok := _inside(panel.get_global_rect(), viewport)
		if bool(item["required"]):
			_check(ok, "%s HUD %s outside viewport: %s" % [item["name"], panel_name, panel.get_global_rect()])
		else:
			_warn(ok, "%s HUD %s outside viewport" % [item["name"], panel_name])
	var roster := hud.get("_roster_panel") as Control
	var mission := hud.get("_mission_panel") as Control
	if roster != null and mission != null and roster.is_visible_in_tree() and mission.is_visible_in_tree():
		var overlap := roster.get_global_rect().intersects(mission.get_global_rect())
		if bool(item["required"]):
			_check(not overlap, "%s roster overlaps mission panel" % item["name"])
		else:
			_warn(not overlap, "%s roster overlaps mission panel" % item["name"])

	var labels: Array = hud.find_children("*", "Label", true, false)
	var clipped := 0
	for raw in labels:
		var label := raw as Label
		if label == null or not label.is_visible_in_tree() or label.text.is_empty():
			continue
		if not _inside(label.get_global_rect(), viewport, 2.0):
			clipped += 1
	if bool(item["required"]):
		_check(clipped == 0, "%s HUD has %d labels outside viewport" % [item["name"], clipped])
	else:
		_warn(clipped == 0, "%s HUD has %d labels outside viewport" % [item["name"], clipped])


func _test_overlay_cycles(game: Node) -> void:
	var hud = game.hud
	var player = game.player
	for index in range(10):
		game.call("_open_backpack")
		await process_frame
		await process_frame
		_check(hud.backpack_open(), "Overlay cycle %d: backpack did not open" % index)
		_check(not player.input_enabled, "Overlay cycle %d: player input not locked" % index)
		game.call("_close_overlays")
		await process_frame
		await process_frame
		_check(not hud.backpack_open(), "Overlay cycle %d: backpack did not close" % index)
		_check(player.input_enabled, "Overlay cycle %d: player input not restored" % index)
		var crosshair := hud.get("_crosshair") as Control
		_check(crosshair != null and crosshair.visible, "Overlay cycle %d: crosshair hidden after close" % index)
