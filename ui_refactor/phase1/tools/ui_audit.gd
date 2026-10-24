extends SceneTree

## Phase-1 UI audit harness (read-only with respect to production UI code).
## Renders existing MainMenu / GameHUD inside an off-screen SubViewport at an
## arbitrary size, injects representative state, saves a PNG, and dumps a JSON
## geometry/text report. Run with:
##   godot --path . --resolution 1280x720 --script res://ui_refactor/phase1/tools/ui_audit.gd -- \
##     --screen=hud --w=1920 --h=1200 --out=D:/.../shots/audit
##
## This script deliberately calls the same public/underscore methods the game
## calls; it does not fork or patch production UI behaviour.

var _screen := "hud"
var _w := 1280
var _h := 720
var _out := ""
var _bg := "dark"
var _viewport: SubViewport
var _screen_root: Control
var _report := {}
var _ui_scale := 1.0
var _logical := Vector2(1280, 720)


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--screen="):
			_screen = arg.trim_prefix("--screen=")
		elif arg.begins_with("--w="):
			_w = int(arg.trim_prefix("--w="))
		elif arg.begins_with("--h="):
			_h = int(arg.trim_prefix("--h="))
		elif arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
		elif arg.begins_with("--bg="):
			_bg = arg.trim_prefix("--bg=")
	if _out.is_empty():
		_out = "user://ui_audit"
	DirAccess.make_dir_recursive_absolute(_out)
	_run()


func _run() -> void:
	# Emulate project.godot: stretch mode "canvas_items", aspect "expand".
	# Physical pixels = logical UI pixels * scale; the leftover axis is extra
	# logical space, not a non-uniform stretch.
	_ui_scale = minf(float(_w) / 1280.0, float(_h) / 720.0)
	_logical = Vector2(float(_w) / _ui_scale, float(_h) / _ui_scale)
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(_w, _h)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.transparent_bg = false
	_viewport.disable_3d = true
	root.add_child(_viewport)

	var bg := ColorRect.new()
	bg.size = Vector2(_w, _h)
	bg.color = Color("#18222c") if _bg == "dark" else Color("#b9c6c9")
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_viewport.add_child(bg)

	match _screen:
		"menu", "armory", "lobby":
			_screen_root = await _make_menu()
		_:
			_screen_root = await _make_hud()

	_screen_root.size = _logical
	_screen_root.scale = Vector2(_ui_scale, _ui_scale)
	_screen_root.position = Vector2.ZERO

	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw

	var img := _viewport.get_texture().get_image()
	if img != null:
		img.save_png("%s/%s_%dx%d_%s.png" % [_out, _screen, _w, _h, _bg])
	_report = _collect(_screen_root)
	_report["screen"] = _screen
	_report["size"] = [_w, _h]
	_report["background"] = _bg
	_report["render"] = "SubViewport offscreen; production UI nodes, injected state"
	_report["ui_scale"] = _ui_scale
	_report["logical_size"] = [_logical.x, _logical.y]
	var f := FileAccess.open("%s/%s_%dx%d_%s.json" % [_out, _screen, _w, _h, _bg], FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(_report, "  "))
		f.close()
	quit()


func _make_menu() -> Control:
	var menu := MainMenu.new()
	menu.name = "MainMenuAudit"
	menu.size = _logical
	_viewport.add_child(menu)
	await process_frame
	menu.set_profile(_fake_profile())
	if _screen == "armory":
		menu.open_armory()
	elif _screen == "lobby":
		menu.show_lobby(true, 1, _fake_lobby())
	else:
		menu.present("等待部署 — 创建房间或加入队友。", false)
	await process_frame
	return menu


func _make_hud() -> Control:
	var hud := GameHUD.new()
	hud.name = "GameHUDAudit"
	hud.size = _logical
	_viewport.add_child(hud)
	await process_frame
	var loadout := [
		{"id": "smg", "name": "VX-9 冲锋枪", "slot": 1, "active": true, "melee": false, "mag": 0, "mag_size": 36, "reserve": 0},
		{"id": "machete", "name": "M-2 开山砍刀", "slot": 2, "active": false, "melee": true, "mag": 0, "mag_size": 0, "reserve": 0},
	]
	var profile := WeaponCatalog.data("smg")
	var upgrades := {"mag": 1, "reload": 2, "damage": 1, "rate": 0, "speed": 2, "armor": 1}
	hud.setup_world({"seed": 4242, "grid": 5, "total_size": 200.0, "blocks": []})
	hud.set_roster(_fake_roster())
	hud.set_wave({"wave": 4, "phase": "fight", "alive": 18, "remaining": 42, "threat": 3,
		"threat_mult": 1.32, "active": true, "break_left": 3.0})
	hud.set_score(1280)
	hud.set_weapon_strip(loadout, profile)
	hud.set_health(18.0, 100.0)
	hud.set_ammo(0, 0, false, 0.0, false)
	hud.set_mission(2, 3, 1, "回收核心，然后从绿色出口返回地表", "核心储藏层 B1",
		DeadCityUI.AMBER, upgrades, true, 7)
	hud.set_interaction("E   交付核心 · 立即抽卡")
	if _screen == "pause":
		hud.set_pause_note("已释放鼠标 · 战斗仍在服务器上继续")
		hud.set_pause_visible(true)
	elif _screen == "intel":
		hud.open_intel(_fake_intel(upgrades, loadout, profile))
	elif _screen == "backpack":
		hud.open_backpack(loadout, profile, upgrades)
	elif _screen == "draw":
		hud.show_draw([
			{"title": "扩容弹匣", "desc": "全队弹匣容量 +6 发（霰弹 +2）", "accent": "#59d8c8", "level": 0},
			{"title": "快速装填", "desc": "全队换弹时间 -10%", "accent": "#ffcb66", "level": 0},
			{"title": "枪机抛光", "desc": "全队射速 +7%", "accent": "#83c8ff", "level": 0},
		])
	elif _screen == "gameover_victory":
		hud.show_game_over("核心回收完成    ·    全队击杀 37    ·    行动得分 1280\n行动 1 次 · 完成 1 次 · 最佳战力 7 · 血脉 Lv.1 · 信用点 315", true)
	elif _screen == "gameover_fail":
		hud.show_game_over("抵达第 4 波    ·    全队击杀 37    ·    核心 2 / 3    ·    行动得分 980\n行动 2 次 · 完成 1 次 · 最佳战力 7 · 血脉 Lv.1 · 信用点 315", false)
	elif _screen == "death":
		hud.set_down(true, 6.0)
	elif _screen == "loading":
		hud.show_loading("正在生成街区 #4242…")
	return hud


func _fake_profile() -> Dictionary:
	var p := MetaProfile.empty_profile()
	p["runs"] = 12
	p["victories"] = 7
	p["best_power"] = 18
	p["credits"] = 315
	p["best_score"] = 2480
	p["total_cores"] = 9
	p["selected_weapon"] = "smg"
	p["owned_weapons"] = ["pistol", "smg", "machete", "rifle"]
	p["equipped_weapons"] = ["smg", "machete"]
	p["last_run"] = {"victory": true, "cores": 3, "power": 7, "score": 660, "wave": 4}
	return p


func _fake_roster() -> Array:
	return [
		{"id": 1, "name": "阿岚", "health": 82.0, "kills": 14, "alive": true, "is_local": true, "color": Color("#58d6d0")},
		{"id": 2, "name": "老周", "health": 41.0, "kills": 9, "alive": true, "is_local": false, "color": Color("#ffc65c")},
		{"id": 3, "name": "小满", "health": 0.0, "kills": 6, "alive": false, "is_local": false, "color": Color("#b498ff")},
		{"id": 4, "name": "K-7", "health": 100.0, "kills": 8, "alive": true, "is_local": false, "color": Color("#ff8b6f")},
	]


func _fake_lobby() -> Dictionary:
	return {
		"seed": 4242, "port": 7777, "host_id": 1,
		"players": _fake_roster(),
		"ready": {1: true, 2: true, 3: false, 4: true},
		"all_ready": false,
	}


func _fake_intel(upgrades: Dictionary, loadout: Array, profile: Dictionary) -> Dictionary:
	return {
		"mission": {
			"cores": 2, "required": 3, "tokens": 1,
			"hint": "搬运核心 · 无法射击、换弹或冲刺，返回基地交付台",
			"zone": "核心储藏层 B1", "upgrades": upgrades, "power": 7,
			"frenzy": true, "wave": 4, "score": 1280,
		},
		"roster": _fake_roster(),
		"player": {
			"name": "阿岚", "health": 18.0, "weapon": profile,
			"loadout": loadout, "kills": 14, "reserve_bonus": 2,
		},
	}


func _collect(node: Node) -> Dictionary:
	var out := {
		"controls": [],
		"out_of_viewport": [],
		"clipped_labels": [],
		"content_overflows": [],
		"invisible_focus_buttons": [],
		"focus_none_buttons": [],
		"font_sizes": {},
		"panel_content_overflow": [],
		"panel_overlaps": [],
		"top_panels": [],
	}
	_walk(node, out)
	var panels: Array = []
	for child in node.get_children():
		if child is PanelContainer and (child as Control).is_visible_in_tree():
			panels.append(child as PanelContainer)
	for panel in panels:
		var pc := panel as PanelContainer
		var pr := pc.get_global_rect()
		out["top_panels"].append({"path": str(pc.get_path()), "rect": [pr.position.x, pr.position.y, pr.size.x, pr.size.y]})
	for i in range(panels.size()):
		for j in range(i + 1, panels.size()):
			var a := (panels[i] as PanelContainer).get_global_rect()
			var b := (panels[j] as PanelContainer).get_global_rect()
			var hit := a.intersection(b)
			if hit.size.x > 1.0 and hit.size.y > 1.0:
				out["panel_overlaps"].append({
					"a": str((panels[i] as PanelContainer).get_path()),
					"b": str((panels[j] as PanelContainer).get_path()),
					"rect": [hit.position.x, hit.position.y, hit.size.x, hit.size.y],
					"overlap_px": hit.size.x * hit.size.y,
				})
	return out


func _walk(node: Node, out: Dictionary) -> void:
	if node is Control:
		var c := node as Control
		if not c.is_visible_in_tree():
			return
		var rect := c.get_global_rect()
		var entry := {
			"path": str(c.get_path()),
			"type": c.get_class(),
			"rect": [rect.position.x, rect.position.y, rect.size.x, rect.size.y],
			"min": [c.get_combined_minimum_size().x, c.get_combined_minimum_size().y],
		}
		if c is Label:
			var l := c as Label
			entry["text"] = l.text
			entry["font_size"] = l.get_theme_font_size("font_size")
			entry["lines"] = l.get_line_count()
			entry["visible_lines"] = l.get_visible_line_count()
			var fs := int(entry["font_size"])
			out["font_sizes"][str(fs)] = int(out["font_sizes"].get(str(fs), 0)) + 1
			if l.get_visible_line_count() < l.get_line_count():
				out["clipped_labels"].append(entry)
		if c is Button:
			var b := c as Button
			entry["text"] = b.text
			entry["focus_mode"] = b.focus_mode
			entry["disabled"] = b.disabled
			if b.focus_mode == Control.FOCUS_NONE:
				out["focus_none_buttons"].append(entry)
			var focus_style := b.get_theme_stylebox("focus")
			if focus_style == null or focus_style is StyleBoxEmpty:
				out["invisible_focus_buttons"].append(entry)
		if c is PanelContainer:
			var pc := c as PanelContainer
			var ms := pc.get_combined_minimum_size()
			if pc.size.x + 0.5 < ms.x or pc.size.y + 0.5 < ms.y:
				entry["overflow_by"] = [ms.x - pc.size.x, ms.y - pc.size.y]
				out["content_overflows"].append(entry)
		if rect.position.x < -1.0 or rect.position.y < -1.0 \
				or rect.end.x > float(_w) + 1.0 or rect.end.y > float(_h) + 1.0:
			out["out_of_viewport"].append(entry)
		var panel := _nearest_panel(c.get_parent())
		if panel != null and panel != c:
			var pr := panel.get_global_rect()
			var dx := maxf(0.0, rect.end.x - pr.end.x)
			var dy := maxf(0.0, rect.end.y - pr.end.y)
			var dx0 := maxf(0.0, pr.position.x - rect.position.x)
			var dy0 := maxf(0.0, pr.position.y - rect.position.y)
			if maxf(maxf(dx, dy), maxf(dx0, dy0)) > 1.0:
				entry["panel"] = str(panel.get_path())
				entry["outside_panel_by"] = [maxf(dx, dx0), maxf(dy, dy0)]
				out["panel_content_overflow"].append(entry)
		out["controls"].append(entry)
	for child in node.get_children():
		_walk(child, out)


func _nearest_panel(node: Node) -> PanelContainer:
	var current := node
	while current != null:
		if current is PanelContainer:
			return current as PanelContainer
		current = current.get_parent()
	return null
