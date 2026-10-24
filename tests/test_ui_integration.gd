extends SceneTree
## UI v3 集成回归：菜单真实入口、设置持久化、HUD 真实状态、覆盖层输入恢复、
## 暂停行为与退出后的界面清理。所有断言都基于实际运行场景，不依赖截图。

const SETTINGS_PATH := "user://ui_settings.cfg"

var checks := 0
var failures := 0
var settings_existed := false
var settings_baseline := {}


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)


func _run() -> void:
	settings_existed = FileAccess.file_exists(SETTINGS_PATH)
	var settings = root.get_node_or_null("UISettings")
	if settings != null:
		settings_baseline = {
			"hud_scale": float(settings.hud_scale),
			"reduced_motion": bool(settings.reduced_motion),
			"high_contrast": bool(settings.high_contrast),
		}
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await process_frame

	_test_menu_structure(game)
	await _test_keyboard_focus(game)
	await _test_menu_views(game)
	await _test_settings(game)
	await _start_solo(game)
	await _test_hud_real_state(game)
	await _test_overlays_and_pause(game)
	await _test_roster_presentation(game)
	await _test_return_cleanup(game)

	game.queue_free()
	await process_frame
	if not settings_existed and FileAccess.file_exists("user://ui_settings.cfg"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://ui_settings.cfg"))
	print("UI integration: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


func _test_menu_structure(game: Node) -> void:
	var menu = game.menu
	_check(menu.visible, "Main menu is not visible at boot")
	_check(not game.hud.visible, "HUD must stay hidden before a match")
	var nav: Array = menu.get("_nav_items")
	_check(nav.size() == 6, "Main menu must expose six root entries, got %d" % nav.size())
	_check(nav.size() > 0 and nav[0].disabled, "Continue must be honestly disabled without a save system")
	_check(nav.size() > 0 and String(nav[0].get("_sub").text).contains("不保存"), "Continue subtitle must explain why it is disabled")
	_check(menu.find_children("*", "GPUParticles2D", true, false).size() > 0, "Menu scene background has no ambient dust particles")
	var backdrop = menu.get("_backdrop")
	_check(backdrop != null, "Menu has no scene-first backdrop")
	_check(backdrop != null and backdrop.get("_photo") != null, "Menu backdrop has no E-07 photographic plate")


func _test_keyboard_focus(game: Node) -> void:
	# 键盘焦点：方向键移动时必须有真实焦点承接，Enter 走与鼠标相同的入口。
	var menu = game.menu
	var nav: Array = menu.get("_nav_items")
	var down := InputEventAction.new()
	down.action = "ui_down"
	down.pressed = true
	_check(nav[1].has_focus(), "Boot focus is not on the first enabled menu entry")
	var start := int(menu.get("_selected"))
	menu.call("_unhandled_input", down)
	await process_frame
	await process_frame
	var next := 2 if start == 1 else start + 1
	_check(int(menu.get("_selected")) == next, "Keyboard down did not move to the next entry")
	_check(nav[next].has_focus(), "Keyboard navigation did not move visible focus with the selection")
	var accept := InputEventAction.new()
	accept.action = "ui_accept"
	accept.pressed = true
	var key := InputEventKey.new()
	key.keycode = KEY_ENTER
	key.physical_keycode = KEY_ENTER
	key.pressed = true
	menu.get_viewport().push_input(key)
	var key_up := key.duplicate() as InputEventKey
	key_up.pressed = false
	menu.get_viewport().push_input(key_up)
	await process_frame
	await process_frame
	_check(not String(menu.get("_view")).is_empty(), "Keyboard Enter did not open the focused menu view")
	menu.call("_close_view")
	await process_frame
	_check(String(menu.get("_view")).is_empty(), "Keyboard view did not close")


func _test_menu_views(game: Node) -> void:
	var menu = game.menu
	var nav: Array = menu.get("_nav_items")
	# 继续行动：只给诚实提示，不打开任何虚构存档界面。
	nav[0].pressed.emit()
	await process_frame
	_check(String(menu.get("_view")).is_empty(), "Continue opened a view despite being disabled")
	_check(String(menu.get("_toast").text).contains("不保存"), "Continue did not explain the missing save")
	# 单人 / 联机 / 设置 / 退出 都必须进入真实子界面。
	for entry in [[1, "solo"], [2, "coop"], [5, "quit"]]:
		nav[int(entry[0])].pressed.emit()
		await process_frame
		_check(String(menu.get("_view")) == String(entry[1]), "Menu entry %d did not open view %s" % [int(entry[0]), entry[1]])
		_check(menu.get_node_or_null("MenuView_" + String(entry[1])) != null, "View layer for %s was not built" % entry[1])
		menu.call("_close_view")
		await process_frame
		_check(String(menu.get("_view")).is_empty(), "View %s did not close" % entry[1])
	# 设置：用户入口打开新的原生设置中心，而不是旧的内联视图。
	nav[4].pressed.emit()
	await process_frame
	var settings_panel = game.get("_settings_panel")
	_check(settings_panel != null and settings_panel.visible, "Settings center did not open from the main menu")
	if settings_panel != null:
		var nav_buttons: Dictionary = settings_panel.get("_nav_buttons")
		_check(nav_buttons.size() == 6, "Settings center must expose six categories, got %d" % nav_buttons.size())
		settings_panel.close()
		await process_frame
		_check(not settings_panel.visible, "Settings center did not close")

	# 角色整备：真实军械库，使用真实档案。
	nav[3].pressed.emit()
	await process_frame
	var armory = menu.get("_armory_layer")
	_check(armory != null and armory.visible, "Armory did not open from 角色整备")
	var cards: GridContainer = menu.get("_armory_cards")
	_check(cards.get_child_count() == WeaponCatalog.ORDER.size(), "Armory must list all %d catalog weapons, got %d" % [WeaponCatalog.ORDER.size(), cards.get_child_count()])
	var credits_label: Label = menu.get("_armory_credits")
	_check(credits_label.text == str(int(menu.get("_profile").get("credits", 0))), "Armory credits do not match the real profile")
	var has_in_use := false
	for raw in armory.find_children("*", "Button", true, false):
		var button := raw as Button
		if button != null and button.text == "使用中":
			has_in_use = true
	_check(has_in_use, "Armory does not mark the equipped weapon as 使用中")
	menu.close_armory()
	await process_frame
	_check(menu.get("_root_layer").visible, "Closing armory did not restore the menu root")


func _test_settings(game: Node) -> void:
	var settings = root.get_node_or_null("UISettings")
	_check(settings != null, "UISettings autoload is missing")
	if settings == null:
		return
	# 新设置中心从主菜单打开，六分类可见。
	game.menu.settings_requested.emit()
	await process_frame
	var panel = game.get("_settings_panel")
	_check(panel != null and panel.visible, "Settings center did not open from menu")
	if panel != null:
		_check(panel.get("_nav_buttons").size() == 6, "Settings center must expose six categories")
		panel.close()
		await process_frame
		_check(not panel.visible, "Settings center did not close")
	# 复用统一服务验证 HUD 缩放/高对比/减少动效与持久化。
	settings.set_hud_scale(1.0)
	settings.set_reduced_motion(false)
	settings.set_high_contrast(false)
	await process_frame
	settings.set_hud_scale(1.1)
	await process_frame
	var hud_layer: Control = game.hud.get("_game_layer")
	_check(is_equal_approx(hud_layer.scale.x, 1.1), "HUD content did not scale to 110%%")
	_check(is_equal_approx(hud_layer.size.x, game.hud.size.x / 1.1), "HUD 110%% layout width is inconsistent")
	settings.set_high_contrast(true)
	await process_frame
	var health_label: Label = game.hud.get("_health_label")
	_check(health_label.get_theme_constant("outline_size") == 3, "High contrast did not outline HUD labels")
	var backdrop = game.menu.get("_backdrop")
	_check(backdrop.get("_contrast_layer").visible, "High contrast did not strengthen the menu backdrop")
	settings.set_reduced_motion(true)
	await process_frame
	_check(not backdrop.get("_dust").emitting, "Reduced motion left menu dust emitting")
	_check(is_equal_approx(float(settings.motion_duration(0.4)), 0.001), "Reduced motion did not collapse animation duration")
	var saved := ConfigFile.new()
	var loaded := saved.load(SETTINGS_PATH) == OK
	_check(loaded, "Settings were not persisted to user://ui_settings.cfg")
	if loaded:
		_check(is_equal_approx(float(saved.get_value("ui", "hud_scale", 0.0)), 1.1), "Persisted HUD scale mismatch")
		_check(bool(saved.get_value("accessibility", "reduced_motion", false)), "Persisted reduced-motion mismatch")
		_check(bool(saved.get_value("accessibility", "high_contrast", false)), "Persisted high-contrast mismatch")
	settings.set_high_contrast(false)
	settings.set_reduced_motion(false)
	settings.set_hud_scale(1.0)
	await process_frame
	_check(not bool(settings.high_contrast) and not bool(settings.reduced_motion), "Settings test did not restore defaults")
	_check(is_equal_approx(float(settings.hud_scale), 1.0), "HUD scale did not restore to 100%")
	if not settings_baseline.is_empty():
		settings.set_hud_scale(float(settings_baseline["hud_scale"]))
		settings.set_reduced_motion(bool(settings_baseline["reduced_motion"]))
		settings.set_high_contrast(bool(settings_baseline["high_contrast"]))
		await process_frame


func _start_solo(game: Node) -> void:
	game.menu.solo_requested.emit("UI TEST", 4242)
	for i in range(360):
		await process_frame
		if game.game_started:
			break
	_check(game.game_started, "Solo chapter failed to start from the menu")
	if not game.game_started:
		return
	for i in range(8):
		await process_frame
	_check(game.hud.visible and not game.menu.visible, "HUD/menu visibility is wrong after deployment")
	_check(game.player != null, "Solo deployment produced no local player")
	if game.director != null:
		game.director.stop()
	if game.player != null:
		game.player.set_input_enabled(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _test_hud_real_state(game: Node) -> void:
	var hud = game.hud
	var player = game.player
	if player == null:
		return
	_check(hud.get("_health_label").text == str(int(ceil(player.health))), "HUD health does not match player health at spawn")
	_check(hud.get("_ammo_mag").text == str(player.mag), "HUD magazine does not match real ammo at spawn")
	# 真实伤害链路：服务器扣血 -> 快照 -> 本地玩家 -> HUD。
	game.call("_on_zombie_attacked", game.local_id, 72.0)
	for i in range(20):
		await process_frame
	_check(player.health <= 30.0, "Real damage did not reach the local player")
	_check(hud.get("_health_label").text == str(int(ceil(player.health))), "HUD did not receive the real damaged health")
	_check(hud.get("_health_state").text == "危险", "HUD did not mark low health as 危险")
	game.players[game.local_id]["health"] = 100.0
	game.players[game.local_id]["hurt_cool"] = 0.0
	player.apply_health(100.0)
	for i in range(4):
		await process_frame
	_check(hud.get("_health_state").text == "稳定", "HUD did not recover to 稳定")
	# 真实弹药 / 换弹状态。
	player.reloading = false
	player.mag = 0
	player.reserve = 20
	await process_frame
	await process_frame
	_check(hud.get("_ammo_mag").text == "0", "HUD did not show the real empty magazine")
	_check(hud.get("_ammo_state").text.contains("空仓"), "HUD did not show 空仓 without ammo")
	player.start_reload()
	await process_frame
	await process_frame
	_check(player.reloading, "Player did not enter real reload")
	_check(hud.get("_ammo_state").text == "换弹中", "HUD did not show 换弹中 during real reload")
	_check(hud.get("_reload_bar").visible, "Reload progress bar stayed hidden during real reload")
	player.call("_finish_reload")
	await process_frame
	await process_frame
	_check(not player.reloading and player.mag > 0, "Reload did not finish with real ammo")
	_check(hud.get("_ammo_mag").text == str(player.mag), "HUD magazine is stale after reload")
	_check(hud.get("_ammo_state").text == "就绪", "HUD did not return to 就绪 after reload")
	# 真实搬运状态：任务层与弹药层都应反映。
	player.set_carrying(true)
	await process_frame
	await process_frame
	_check(hud.get("_ammo_state").text.contains("核心搬运"), "HUD did not show the real carry state")
	_check(not hud.get("_reload_bar").visible, "Reload bar must hide while carrying a core")
	player.set_carrying(false)
	await process_frame
	# 倒地信息。
	hud.set_down(true, 8.0)
	_check(hud.get("_death_overlay").visible, "Down overlay did not open")
	_check(hud.get("_health_state").text.contains("倒地"), "Down state did not replace the health status")
	hud.set_down(false)
	_check(not hud.get("_death_overlay").visible, "Down overlay did not close")


func _test_overlays_and_pause(game: Node) -> void:
	var hud = game.hud
	var player = game.player
	if player == null:
		return
	# 情报 / 背包：真实打开、输入释放、关闭后恢复。
	game.call("_open_intel")
	await process_frame
	_check(hud.intel_open(), "Intel overlay did not open")
	_check(not player.input_enabled, "Player input stayed enabled while intel was open")
	game.call("_close_overlays")
	await process_frame
	_check(not hud.intel_open() and player.input_enabled, "Intel close did not restore player input")
	game.call("_open_backpack")
	await process_frame
	_check(hud.backpack_open(), "Backpack overlay did not open")
	_check(not player.input_enabled, "Player input stayed enabled while backpack was open")
	game.call("_close_overlays")
	await process_frame
	_check(not hud.backpack_open() and player.input_enabled, "Backpack close did not restore player input")
	# 单人暂停：真实暂停世界，恢复后输入回来。
	var break_before := float(game.director.get("_break_left")) if game.director != null else 0.0
	game.call("_pause_game")
	await process_frame
	_check(bool(game.get("_paused")), "Solo pause did not set the paused flag")
	_check(paused, "Solo pause did not pause the SceneTree")
	_check(hud.get("_pause_overlay").visible, "Pause overlay did not open")
	_check(not player.input_enabled, "Player input stayed enabled while paused")
	for i in range(20):
		await process_frame
	var break_after := float(game.director.get("_break_left")) if game.director != null else 0.0
	_check(is_equal_approx(break_before, break_after), "Solo pause still advanced the director break timer")
	game.call("_resume_game")
	await process_frame
	_check(not bool(game.get("_paused")) and not paused, "Solo resume did not unpause")
	_check(not hud.get("_pause_overlay").visible and player.input_enabled, "Solo resume did not restore HUD and input")
	# 抽卡与结算覆盖层不遮挡准星永久驻留。
	hud.show_draw([
		{"title": "扩容弹匣", "desc": "全队弹匣 +6", "level": 0, "accent": "#7fc3ba"},
		{"title": "快速装填", "desc": "全队换弹 -10%", "level": 0, "accent": "#e6c07a"},
		{"title": "枪机抛光", "desc": "全队射速 +7%", "level": 0, "accent": "#e08a6f"},
	])
	await process_frame
	_check(hud.get("_draw_overlay").visible, "Draw overlay did not open")
	_check(hud.get("_draw_cards_box").get_child_count() == 3, "Draw overlay must show three cards")
	hud.hide_draw()
	_check(not hud.get("_draw_overlay").visible, "Draw overlay did not close")
	hud.show_game_over("核心回收完成 · 得分 300", true)
	await process_frame
	_check(hud.get("_gameover_overlay").visible, "Victory overlay did not open")
	hud.reset_for_match()
	_check(not hud.get("_gameover_overlay").visible, "Victory overlay did not reset")


func _test_roster_presentation(game: Node) -> void:
	# 结构化检查 1–4 人自适应与状态文本；主循环随后会覆盖为真实单人数据。
	game.hud.set_roster([
		{"id": 1, "name": "你", "color": DeadCityUI.CYAN, "health": 22.0, "alive": true, "kills": 3, "distance": 0.0, "is_local": true},
		{"id": 2, "name": "阿岚", "color": DeadCityUI.AMBER, "health": 46.0, "alive": true, "kills": 1, "distance": 9.0},
		{"id": 3, "name": "老周", "color": DeadCityUI.VIOLET, "health": 0.0, "alive": false, "kills": 0, "distance": 12.0},
		{"id": 4, "name": "米拉", "color": DeadCityUI.CORAL, "health": 88.0, "alive": true, "kills": 2, "distance": 74.0},
	])
	_check(game.hud.get("_roster_box").get_child_count() == 4, "Four-player roster did not render four rows")
	var texts: Array[String] = []
	for raw in game.hud.get("_roster_box").find_children("*", "Label", true, false):
		texts.append(String((raw as Label).text))
	var joined := " ".join(texts)
	_check(joined.contains("危险"), "Four-player roster did not mark a 22 HP teammate as 危险")
	_check(joined.contains("倒地"), "Four-player roster did not mark a downed teammate")
	_check(joined.contains("脱离"), "Four-player roster did not mark a distant teammate")
	_check(joined.contains("你"), "Four-player roster lost the local player marker")


func _test_return_cleanup(game: Node) -> void:
	game.hud.lobby_requested.emit()
	await process_frame
	await process_frame
	_check(not game.game_started, "Returning to menu kept the match running")
	_check(game.menu.visible and not game.hud.visible, "Returning to menu did not restore menu visibility")
	_check(game.player == null and game.director == null, "Returning to menu left world actors alive")
	_check(not bool(game.get("_paused")) and not paused, "Returning to menu left the tree paused")
	for key in ["_pause_overlay", "_death_overlay", "_gameover_overlay", "_draw_overlay", "_intel_overlay", "_backpack_overlay", "_loading_overlay"]:
		var overlay = game.hud.get(key)
		_check(overlay != null and not overlay.visible, "Overlay %s is still visible after returning to menu" % key)
	_check(not game.hud.overlay_open(), "HUD still reports an open overlay after returning to menu")
