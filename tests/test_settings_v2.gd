extends SceneTree
## 设置中心 V2 回归：服务、迁移、键位、音频总线、HUD 联动、主菜单/暂停入口。

const SETTINGS_PATH := "user://ui_settings.cfg"

var checks := 0
var failures := 0
var _service: Node
var _backup: PackedByteArray
var _had_file := false


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("[settings] " + message)


func _run() -> void:
	var absolute := ProjectSettings.globalize_path(SETTINGS_PATH)
	_had_file = FileAccess.file_exists(absolute)
	if _had_file:
		_backup = FileAccess.get_file_as_bytes(absolute)
	_service = root.get_node_or_null("UISettings")
	_check(_service != null, "UISettings autoload missing")
	if _service == null:
		quit(1)
		return

	_test_defaults()
	_test_validation_and_pending()
	_test_migration_and_corruption(absolute)
	_test_keybindings()
	_test_audio()
	await _test_hud_and_panels()
	await _test_player_connections()
	await _test_pause_entry()

	_restore(absolute)
	print("Settings V2: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


func _test_defaults() -> void:
	_service.reset_all()
	_service.apply()
	_check(is_equal_approx(float(_service.get_value("fov")), 78.0), "Default FOV is not 78")
	_check(is_equal_approx(float(_service.get_value("mouse_x")), 1.0), "Default mouse X is not 1.0")
	_check(String(_service.get_value("aim_mode")) == "hold", "Default aim mode is not hold")
	_check(_service.bus_names().has("SFX") and _service.bus_names().has("UI"), "SFX/UI audio buses missing")
	for action in ["move_forward", "fire", "aim", "reload", "interact", "intel", "backpack", "pause"]:
		_check(InputMap.has_action(action), "InputMap action missing: " + action)
		_check(InputMap.action_get_events(action).size() > 0, "InputMap action has no event: " + action)


func _test_validation_and_pending() -> void:
	_service.reset_all()
	_service.apply()
	_service.set_pending("mouse_x", 99.0)
	_check(is_equal_approx(float(_service.get_value("mouse_x")), 3.0), "mouse_x did not clamp to 3.0")
	_service.set_pending("aim_mode", "invalid")
	_check(String(_service.get_value("aim_mode")) == "hold", "Invalid select did not fall back")
	_service.set_pending("fov", 100.0)
	_check(is_equal_approx(float(_service.get_applied("fov")), 78.0), "Pending FOV leaked into applied value")
	_service.cancel()
	_check(is_equal_approx(float(_service.get_value("fov")), 78.0), "Cancel did not revert pending FOV")

	_service.set_pending("fov", 100.0)
	_service.apply()
	_check(is_equal_approx(float(_service.get_applied("fov")), 100.0), "Apply did not commit FOV")
	var config := ConfigFile.new()
	_check(config.load(SETTINGS_PATH) == OK, "Applied settings were not written")
	_check(int(config.get_value("meta", "version", 0)) == 2, "Config version is not 2")
	_check(is_equal_approx(float(config.get_value("controls", "fov", 0.0)), 100.0), "Saved FOV mismatch")

	_service.reset_category("controls")
	_check(is_equal_approx(float(_service.get_value("fov")), 78.0), "Reset page did not preview default FOV")
	_check(is_equal_approx(float(_service.get_applied("fov")), 100.0), "Reset page changed applied FOV before apply")
	_service.cancel()
	_check(is_equal_approx(float(_service.get_value("fov")), 100.0), "Cancel after reset did not restore applied FOV")


func _test_migration_and_corruption(absolute: String) -> void:
	var old := ConfigFile.new()
	old.set_value("audio", "master_volume", 0.5)
	old.set_value("display", "fullscreen", true)
	old.set_value("display", "vsync", false)
	old.set_value("ui", "hud_scale", 1.1)
	old.set_value("accessibility", "reduced_motion", true)
	old.set_value("accessibility", "high_contrast", true)
	old.save(absolute)
	_service.load_settings()
	_check(is_equal_approx(float(_service.get_value("master_volume")), 0.5), "Legacy master volume not migrated")
	_check(String(_service.get_value("window_mode")) == "fullscreen", "Legacy fullscreen not migrated")
	_check(not bool(_service.get_value("vsync")), "Legacy vsync not migrated")
	_check(is_equal_approx(float(_service.get_value("hud_scale")), 1.1), "Legacy HUD scale not migrated")
	_check(bool(_service.get_value("reduced_motion")), "Legacy reduced motion not migrated")
	_check(bool(_service.get_value("high_contrast")), "Legacy high contrast not migrated")

	var broken := FileAccess.open(absolute, FileAccess.WRITE)
	broken.store_string("this is not a config file")
	broken.close()
	_service.load_settings()
	_check(is_equal_approx(float(_service.get_value("fov")), 78.0), "Corrupt config did not fall back to defaults")
	_check(is_equal_approx(float(_service.get_value("master_volume")), 0.85), "Corrupt config kept stale master volume")


func _test_keybindings() -> void:
	_service.reset_all()
	_service.apply()
	var w_event := InputEventKey.new()
	w_event.physical_keycode = KEY_W
	_check(_service.find_key_conflict("jump", "K:%d" % KEY_W) == "move_forward", "Key conflict was not detected")
	_check(not _service.set_pending_key("jump", w_event), "Conflicting rebind was accepted")
	var j_event := InputEventKey.new()
	j_event.physical_keycode = KEY_J
	_check(_service.set_pending_key("jump", j_event), "Non-conflicting rebind was rejected")
	_check(_service.key_label("jump") == "J", "Rebound key label is not J")
	_service.apply()
	var saved := ConfigFile.new()
	_check(saved.load(SETTINGS_PATH) == OK, "Keybinding was not saved")
	_check(String(saved.get_value("input", "jump", "")) == "K:%d" % KEY_J, "Saved keybinding mismatch")
	_service.load_settings()
	_check(_service.key_label("jump") == "J", "Keybinding did not survive reload")
	_service.reset_all()
	_service.apply()


func _test_audio() -> void:
	_service.set_pending("sfx_volume", 0.5)
	_service.apply()
	var index := AudioServer.get_bus_index("SFX")
	_check(index >= 0, "SFX bus missing after apply")
	if index >= 0:
		_check(absf(db_to_linear(AudioServer.get_bus_volume_db(index)) - 0.5) < 0.02, "SFX bus volume mismatch")
	_service.set_pending("sfx_volume", 0.0)
	_service.apply()
	if index >= 0:
		_check(AudioServer.is_bus_mute(index), "SFX bus did not mute at 0%")
	_service.reset_all()
	_service.apply()


func _test_hud_and_panels() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	game.menu.settings_requested.emit()
	await process_frame
	var panel = game.get("_settings_panel")
	_check(panel != null and panel.visible, "Settings center did not open from menu")
	if panel == null:
		game.queue_free()
		return
	_check(panel.get("_nav_buttons").size() == 6, "Settings center does not have six categories")
	panel.call("_select_category", "keybind")
	await process_frame
	_check(panel.get("_content").get_child_count() >= 20, "Keybind category is missing rows")
	panel.call("_select_category", "hud")
	await process_frame
	_service.set_pending("crosshair_size", 1.3)
	_service.set_pending("crosshair_color", "amber")
	_service.set_pending("show_minimap", false)
	_service.apply()
	await process_frame
	var crosshair = game.hud.get("_crosshair")
	_check(crosshair != null and is_equal_approx(float(crosshair.get("_size_scale")), 1.3), "Crosshair size did not reach HUD")
	_check(crosshair != null and crosshair.get("_color") == DeadCityUI.AMBER, "Crosshair color did not reach HUD")
	_check(not game.hud.get("_minimap").visible, "Minimap toggle did not reach HUD")
	_service.set_pending("show_minimap", true)
	_service.apply()
	await process_frame
	_check(game.hud.get("_minimap").visible, "Minimap did not restore")
	_service.set_pending("show_objective", false)
	_service.set_pending("hints", false)
	_service.set_pending("hud_opacity", 0.6)
	_service.set_pending("damage_flash", 0.0)
	_service.apply()
	await process_frame
	_check(not game.hud.get("_mission_panel").visible, "Objective toggle did not hide mission panel")
	game.hud.set_interaction("E  测试交互")
	_check(not game.hud.get("_interaction_panel").visible, "Hints toggle did not hide interaction prompt")
	_check(is_equal_approx(float(game.hud.get("_scrim_top").modulate.a), 0.6), "HUD opacity did not reach scrim")
	_check(is_equal_approx(float(game.hud.get("_vignette").get("_strength_scale")), 0.0), "Damage flash strength did not reach vignette")
	_service.set_pending("show_objective", true)
	_service.set_pending("hints", true)
	_service.set_pending("hud_opacity", 0.9)
	_service.set_pending("damage_flash", 1.0)
	_service.apply()
	await process_frame
	_check(game.hud.get("_mission_panel").visible, "Mission panel did not restore")

	# 应用/取消：控件改动先进入 pending，取消必须回到已应用值。
	panel.call("_select_category", "controls")
	await process_frame
	var slider: HSlider = null
	for raw in panel.get("_content").find_children("*", "HSlider", true, false):
		var candidate := raw as HSlider
		if candidate != null and is_equal_approx(candidate.max_value, 110.0):
			slider = candidate
			break
	_check(slider != null, "Controls category has no slider")
	if slider != null:
		slider.value = 100.0
		await process_frame
		_check(is_equal_approx(float(_service.get_value("fov")), 100.0), "Slider did not update pending FOV")
		panel.call("_cancel")
		await process_frame
		_check(is_equal_approx(float(_service.get_applied("fov")), 78.0), "Cancel did not restore FOV")
		_service.set_pending("fov", 95.0)
		panel.call("_apply")
		await process_frame
		_check(is_equal_approx(float(_service.get_applied("fov")), 95.0), "Apply did not commit FOV")

	# 按键捕获与冲突。
	panel.call("_select_category", "keybind")
	await process_frame
	var key_button: Button = null
	for raw in panel.get("_content").find_children("*", "Button", true, false):
		var button := raw as Button
		if button != null and button.text == "W":
			key_button = button
			break
	_check(key_button != null, "Keybind row for W is missing")
	if key_button != null:
		panel.call("_begin_capture", "move_forward", key_button)
		var j_event := InputEventKey.new()
		j_event.physical_keycode = KEY_J
		panel.call("_try_bind", j_event)
		_check(_service.key_label("move_forward") == "J", "Key capture did not bind J")
		var conflict_event := InputEventKey.new()
		conflict_event.physical_keycode = KEY_J
		panel.call("_begin_capture", "jump", key_button)
		panel.call("_try_bind", conflict_event)
		_check(String(panel.get("_status").text).contains("冲突"), "Conflict was not reported in UI")
		_check(_service.key_label("jump") != "J", "Conflict overwrote jump binding")
		panel.call("_cancel")
		await process_frame

	# 显示设置必须经过 10 秒确认；取消确认要恢复原值。
	_service.set_pending("window_mode", "borderless")
	panel.call("_show_display_confirm")
	await process_frame
	_check(panel.get("_confirm_layer") != null, "Display change did not ask for confirmation")
	panel.set("_confirm_seconds", 0.01)
	panel.call("_process", 0.02)
	await process_frame
	_check(panel.get("_confirm_layer") == null, "Display confirmation timeout did not close")
	_check(String(_service.get_value("window_mode")) == "windowed", "Display timeout did not restore window mode")

	_service.set_pending("window_mode", "borderless")
	panel.call("_apply")
	await process_frame
	_check(panel.get("_confirm_layer") != null, "Display apply did not ask for confirmation")
	panel.call("_revert_display")
	await process_frame
	_check(panel.get("_confirm_layer") == null, "Display revert did not close confirmation")
	_check(String(_service.get_value("window_mode")) == "windowed", "Display revert did not restore window mode")

	_service.reset_all()
	_service.apply()
	panel.close()
	await process_frame
	_check(not panel.visible, "Settings center did not close")
	# 重复开关，确认没有残留控件或状态。
	for i in range(5):
		game.menu.settings_requested.emit()
		await process_frame
		_check(panel.visible, "Settings center failed to reopen")
		panel.close()
		await process_frame
	game.queue_free()
	await process_frame


func _test_player_connections() -> void:
	_service.reset_all()
	_service.apply()
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	game.menu.solo_requested.emit("SETTINGS CAMERA", 4242)
	for i in range(360):
		await process_frame
		if game.game_started:
			break
	_check(game.game_started, "Solo match did not start for camera settings test")
	if not game.game_started:
		game.queue_free()
		return
	var player = game.player
	player.set_view_direction(0.0, 0.0)
	player.aiming = false
	_service.set_pending("mouse_x", 2.0)
	_service.apply()
	player.set_view_direction(0.0, 0.0)
	player.call("_apply_mouse_look", Vector2(10.0, 0.0))
	_check(absf(float(player.get("_yaw")) + 0.044) < 0.002, "Mouse X multiplier did not reach the camera")

	_service.set_pending("mouse_x", 1.0)
	_service.set_pending("invert_y", true)
	_service.apply()
	player.set_view_direction(0.0, 0.0)
	player.call("_apply_mouse_look", Vector2(0.0, 10.0))
	_check(float(player.get("_pitch")) > 0.005, "Invert Y did not reverse vertical look")

	_service.set_pending("invert_y", false)
	_service.set_pending("ads_sens", 0.5)
	_service.apply()
	player.aiming = true
	player.set_view_direction(0.0, 0.0)
	player.call("_apply_mouse_look", Vector2(10.0, 0.0))
	_check(absf(float(player.get("_yaw")) + 0.011) < 0.002, "ADS sensitivity multiplier did not reach the camera")

	_service.set_pending("fov", 90.0)
	_service.set_pending("ads_fov", 60.0)
	_service.apply()
	player.aiming = false
	player.call("_update_visuals", 1.0)
	var camera = player.get("_camera")
	_check(camera != null and absf(float(camera.fov) - 90.0) < 0.01, "Base FOV did not reach Camera3D")
	player.aiming = true
	player.call("_update_visuals", 1.0)
	_check(camera != null and absf(float(camera.fov) - 60.0) < 0.01, "ADS FOV did not reach Camera3D")
	player.aiming = false

	# 瞄准切换模式。
	_service.set_pending("aim_mode", "toggle")
	_service.apply()
	var aim_event := InputEventMouseButton.new()
	aim_event.button_index = MOUSE_BUTTON_RIGHT
	aim_event.pressed = true
	player.call("_unhandled_input", aim_event)
	player.call("_physics_process", 0.016)
	_check(player.aiming, "Toggle aim did not enter aiming")
	player.call("_unhandled_input", aim_event)
	player.call("_physics_process", 0.016)
	_check(not player.aiming, "Toggle aim did not leave aiming")

	# 键位重绑后实际玩家输入生效。
	var j_event := InputEventKey.new()
	j_event.physical_keycode = KEY_J
	_service.set_pending_key("jump", j_event)
	_service.apply()
	player.set("_jump_queued", false)
	var jump_event := InputEventKey.new()
	jump_event.physical_keycode = KEY_J
	jump_event.pressed = true
	player.call("_unhandled_input", jump_event)
	_check(bool(player.get("_jump_queued")), "Rebound jump key did not reach the player")

	# 主流程动作也必须走 InputMap。
	var intel_event := InputEventKey.new()
	intel_event.physical_keycode = KEY_I
	_service.set_pending_key("intel", intel_event)
	_service.apply()
	var intel_press := InputEventKey.new()
	intel_press.physical_keycode = KEY_I
	intel_press.pressed = true
	game.call("_unhandled_input", intel_press)
	await process_frame
	_check(game.hud.intel_open(), "Rebound intel key did not open the intel overlay")
	game.call("_close_overlays")
	await process_frame

	_service.reset_all()
	_service.apply()
	game.queue_free()
	await process_frame


func _test_pause_entry() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	game.menu.solo_requested.emit("SETTINGS", 4242)
	for i in range(360):
		await process_frame
		if game.game_started:
			break
	_check(game.game_started, "Solo match did not start for pause settings test")
	if not game.game_started:
		game.queue_free()
		return
	game.call("_pause_game")
	await process_frame
	game.hud.settings_requested.emit()
	await process_frame
	var panel = game.get("_settings_panel")
	_check(panel != null and panel.visible, "Settings center did not open from pause")
	_check(bool(game.get("_paused")), "Opening settings from pause cleared paused state")
	_check(game.hud.get("_pause_overlay").visible, "Pause overlay disappeared behind settings")
	panel.close()
	await process_frame
	_check(bool(game.get("_paused")), "Closing settings from pause resumed the game unexpectedly")
	_check(game.hud.get("_pause_overlay").visible, "Pause overlay did not return after settings")
	game.call("_resume_game")
	await process_frame
	_check(not bool(game.get("_paused")), "Resume after settings failed")
	game.queue_free()
	await process_frame


func _restore(absolute: String) -> void:
	if _had_file:
		var file := FileAccess.open(absolute, FileAccess.WRITE)
		file.store_buffer(_backup)
		file.close()
	else:
		DirAccess.remove_absolute(absolute)
	_service.load_settings()
	_service.apply_all()
