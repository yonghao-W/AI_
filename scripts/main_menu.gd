class_name MainMenu
extends Control
## 原生 Godot 主菜单。保留旧 MainMenu 的公开信号与方法；内部改为场景背景 + 左侧导航 +
## 右侧可中断子界面。所有按钮都调用真实流程，不使用 HTML 或虚构存档。

signal host_requested(player_name: String, port: int, seed_value: int)
signal join_requested(player_name: String, address: String, port: int)
signal solo_requested(player_name: String, seed_value: int)
signal quit_requested
signal lobby_ready_requested(ready: bool)
signal lobby_start_requested
signal lobby_leave_requested
signal buy_weapon_requested(weapon_id: String)
signal equip_weapon_requested(weapon_id: String)

const MAX_PLAYER_ROWS := 4
const ROOT_ITEMS := [
	{"title": "继续行动", "sub": "当前版本不保存行动进度", "primary": true, "minor": false, "disabled": true},
	{"title": "单人行动", "sub": "", "primary": false, "minor": false, "disabled": false},
	{"title": "联机作战", "sub": "", "primary": false, "minor": false, "disabled": false},
	{"title": "角色整备", "sub": "", "primary": false, "minor": true, "disabled": false},
	{"title": "设置", "sub": "", "primary": false, "minor": true, "disabled": false},
	{"title": "退出", "sub": "", "primary": false, "minor": true, "disabled": false},
]

var _backdrop: MenuBackdrop
var _root_layer: Control
var _menu_col: VBoxContainer
var _nav_menu: VBoxContainer
var _nav_items: Array[MenuNavItem] = []
var _selected := 1
var _title: Label

var _view := ""
var _view_layer: Control
var _view_panel: PanelContainer
var _name_edit: LineEdit
var _seed_edit: LineEdit
var _ip_edit: LineEdit
var _port_edit: LineEdit
var _solo_name_edit: LineEdit
var _solo_seed_edit: LineEdit
var _coop_name_edit: LineEdit
var _coop_seed_edit: LineEdit
var _coop_ip_edit: LineEdit
var _coop_port_edit: LineEdit
var _host_button: Button
var _join_button: Button
var _solo_button: Button
var _quit_button: Button
var _status_label: Label
var _last_status := ""
var _last_status_error := false

var _profile_level: Label
var _profile_stats: Label
var _profile_last: Label
var _meta_line: Label

var _toast: Label
var _toast_tween: Tween
var _feedback: MenuFeedback

var _lobby_layer: Control
var _lobby_room: Label
var _lobby_roster_box: VBoxContainer
var _lobby_hint: Label
var _lobby_archive: Label
var _lobby_ready_button: Button
var _lobby_start_button: Button
var _lobby_payload: Dictionary = {}
var _lobby_local_id := 1
var _lobby_is_host := false
var _lobby_local_ready := false

var _armory_layer: Control
var _armory_cards: GridContainer
var _armory_credits: Label
var _armory_status: Label
var _armory_profile_level: Label
var _armory_profile_stats: Label
var _armory_loadout: VBoxContainer
var _profile: Dictionary = MetaProfile.empty_profile()
var _busy := false


func _ready() -> void:
	theme = DeadCityUI.make_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()
	_apply_accessibility()
	var settings = _settings()
	if settings != null and settings.has_signal("changed"):
		settings.changed.connect(_on_settings_changed)


func _build() -> void:
	_backdrop = MenuBackdrop.new()
	_backdrop.name = "Backdrop"
	add_child(_backdrop)
	_feedback = MenuFeedback.new()
	_feedback.name = "ClickFeedback"
	add_child(_feedback)
	_build_root()
	_build_lobby()
	_build_armory()
	_build_toast()
	resized.connect(_layout_root)
	_layout_root()
	_select(1, true)


func _build_root() -> void:
	_root_layer = Control.new()
	_root_layer.name = "Root"
	_root_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root_layer)

	_menu_col = VBoxContainer.new()
	_menu_col.add_theme_constant_override("separation", 0)
	_root_layer.add_child(_menu_col)

	var eyebrow := DeadCityUI.make_label("低多边形协作生存  //  1–4 人", 10, DeadCityUI.AMBER, DeadCityUI.display_font())
	eyebrow.custom_minimum_size = Vector2(0, 24)
	_menu_col.add_child(eyebrow)

	_title = DeadCityUI.make_label("死城突围", 64, DeadCityUI.TEXT, DeadCityUI.serif_font())
	_title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.62))
	_title.add_theme_constant_override("shadow_offset_x", 1)
	_title.add_theme_constant_override("shadow_offset_y", 3)
	_menu_col.add_child(_title)

	var tagline := DeadCityUI.make_label("在崩塌的世界，寻找回家的路", 11, DeadCityUI.MUTED, DeadCityUI.display_font())
	tagline.custom_minimum_size = Vector2(0, 30)
	_menu_col.add_child(tagline)

	var top_gap := Control.new()
	top_gap.custom_minimum_size = Vector2(0, 62)
	_menu_col.add_child(top_gap)

	_nav_menu = VBoxContainer.new()
	_nav_menu.add_theme_constant_override("separation", 2)
	_nav_menu.custom_minimum_size = Vector2(0, 0)
	_menu_col.add_child(_nav_menu)

	for index in range(ROOT_ITEMS.size()):
		if index == 3:
			var rule_gap := Control.new()
			rule_gap.custom_minimum_size = Vector2(0, 28)
			_nav_menu.add_child(rule_gap)
			var rule := ColorRect.new()
			rule.color = Color(0.85, 0.82, 0.76, 0.26)
			rule.custom_minimum_size = Vector2(46, 1)
			rule.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			_nav_menu.add_child(rule)
			var rule_gap_after := Control.new()
			rule_gap_after.custom_minimum_size = Vector2(0, 26)
			_nav_menu.add_child(rule_gap_after)
		var entry: Dictionary = ROOT_ITEMS[index]
		var item := MenuNavItem.new()
		item.custom_minimum_size = Vector2(0, 58 if bool(entry["primary"]) else 44)
		item.configure(index, String(entry["title"]), String(entry["sub"]), bool(entry["primary"]), bool(entry["minor"]))
		item.highlighted.connect(_on_item_highlighted)
		item.pressed.connect(_on_item_pressed.bind(index))
		_nav_menu.add_child(item)
		_nav_items.append(item)
		if bool(entry["disabled"]):
			item.disabled = true
			item.modulate.a = 0.4

	var flex := Control.new()
	flex.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_menu_col.add_child(flex)

	_meta_line = DeadCityUI.make_label("幸存者血脉 Lv.0  ·  信用点 0", 10, DeadCityUI.MUTED_2, DeadCityUI.display_font())
	_menu_col.add_child(_meta_line)
	var meta_gap := Control.new()
	meta_gap.custom_minimum_size = Vector2(0, 14)
	_menu_col.add_child(meta_gap)

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 10)
	_menu_col.add_child(footer)
	var bar := ColorRect.new()
	bar.color = DeadCityUI.AMBER_DIM
	bar.custom_minimum_size = Vector2(1.5, 13)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	footer.add_child(bar)
	footer.add_child(DeadCityUI.make_label("第一章 · E-07 高架信号维护站", 10, DeadCityUI.MUTED, DeadCityUI.display_font()))
	var dot := ColorRect.new()
	dot.color = Color(0.85, 0.82, 0.76, 0.35)
	dot.custom_minimum_size = Vector2(3, 3)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	footer.add_child(dot)
	footer.add_child(DeadCityUI.make_label("UI v3 · 场景背景", 10, DeadCityUI.MUTED_2, DeadCityUI.display_font()))

	var hint := DeadCityUI.make_label("↑ ↓ 选择  ·  Enter 确认  ·  Esc 返回", 10, Color(0.85, 0.82, 0.76, 0.62), DeadCityUI.display_font())
	hint.name = "InputHint"
	hint.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	hint.anchor_left = 1.0
	hint.anchor_top = 1.0
	hint.anchor_right = 1.0
	hint.anchor_bottom = 1.0
	hint.offset_left = -330.0
	hint.offset_top = -34.0
	hint.offset_right = -24.0
	hint.offset_bottom = -14.0
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_root_layer.add_child(hint)


func _layout_root() -> void:
	if _menu_col == null:
		return
	var viewport := size
	var x := maxf(24.0, viewport.x * 0.052)
	var y := maxf(20.0, viewport.y * 0.105)
	var width := clampf(viewport.x * 0.34, 320.0, 440.0)
	_menu_col.position = Vector2(x, y)
	_menu_col.size = Vector2(width, maxf(420.0, viewport.y - y - 36.0))
	_title.add_theme_font_size_override("font_size", 64 if viewport.x >= 1100.0 else 54)


func _select(index: int, grab: bool = false) -> void:
	if _nav_items.is_empty():
		return
	index = clampi(index, 0, _nav_items.size() - 1)
	if _nav_items[index].disabled:
		index = _next_enabled(index, 1)
	_selected = index
	for i in range(_nav_items.size()):
		_nav_items[i].set_selected(i == index)
	if grab:
		_nav_items[index].grab_focus.call_deferred()


func _next_enabled(from: int, direction: int) -> int:
	var count := _nav_items.size()
	for step in range(1, count + 1):
		var candidate := posmod(from + direction * step, count)
		if not _nav_items[candidate].disabled:
			return candidate
	return from


func _move_selection(direction: int) -> void:
	var next := posmod(_selected + direction, _nav_items.size())
	next = _next_enabled(next - direction, direction)
	_select(next, true)


func _on_item_highlighted(index: int) -> void:
	if _view.is_empty() and not _busy:
		_select(index)


func _on_item_pressed(index: int) -> void:
	_activate(index)


func _activate(index: int) -> void:
	if _busy:
		_show_toast("正在连接或部署，请稍候。")
		return
	match index:
		0:
			_show_toast("当前版本不保存行动进度，无法继续上次行动。")
		1:
			_open_view("solo")
		2:
			_open_view("coop")
		3:
			open_armory()
		4:
			_open_view("settings")
		5:
			_open_view("quit")


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if not _view.is_empty():
		if event.is_action_pressed("ui_cancel"):
			_close_view()
			get_viewport().set_input_as_handled()
		return
	if _lobby_layer != null and _lobby_layer.visible:
		return
	if _armory_layer != null and _armory_layer.visible:
		return
	if event.is_action_pressed("ui_up"):
		_move_selection(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_down"):
		_move_selection(1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept"):
		if not _nav_items.is_empty() and not _nav_items[_selected].has_focus():
			_activate(_selected)
			get_viewport().set_input_as_handled()


func _input(event: InputEvent) -> void:
	if not visible or _feedback == null:
		return
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT and not DeadCityUI.reduced_motion():
			_feedback.add_ripple(mouse.position)


func _open_view(kind: String) -> void:
	_close_view()
	_view = kind
	_view_layer = Control.new()
	_view_layer.name = "MenuView_" + kind
	_view_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_view_layer)
	move_child(_view_layer, _root_layer.get_index() + 1)

	var tint := ColorRect.new()
	tint.color = Color(0.015, 0.017, 0.018, 0.58)
	tint.mouse_filter = Control.MOUSE_FILTER_STOP
	tint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_view_layer.add_child(tint)

	_view_panel = PanelContainer.new()
	var style := DeadCityUI.panel_style(Color(0.035, 0.04, 0.042, 0.975), 3, Color(0.85, 0.82, 0.76, 0.18), 1)
	style.content_margin_left = 30.0
	style.content_margin_right = 30.0
	style.content_margin_top = 26.0
	style.content_margin_bottom = 26.0
	_view_panel.add_theme_stylebox_override("panel", style)
	_view_layer.add_child(_view_panel)
	_place_panel(_view_panel)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	_view_panel.add_child(body)
	match kind:
		"solo":
			_build_solo_view(body)
		"coop":
			_build_coop_view(body)
		"settings":
			_build_settings_view(body)
		"quit":
			_build_quit_view(body)

	_root_layer.modulate = Color(1, 1, 1, 0.26)
	_view_panel.modulate = Color(1, 1, 1, 0)
	if DeadCityUI.reduced_motion():
		_view_panel.modulate = Color.WHITE
	else:
		var start_x := _view_panel.position.x
		_view_panel.position.x = start_x + 26.0
		var tween := create_tween().set_parallel(true)
		tween.tween_property(_view_panel, "modulate:a", 1.0, 0.18)
		tween.tween_property(_view_panel, "position:x", start_x, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_fit_panel.call_deferred()


func _place_panel(panel: Control) -> void:
	var viewport := size
	var width := clampf(viewport.x * 0.42, 420.0, 520.0)
	var left := viewport.x - width - maxf(28.0, viewport.x * 0.056)
	var top := maxf(42.0, viewport.y * 0.12)
	panel.anchor_left = 0.0
	panel.anchor_right = 0.0
	panel.anchor_top = 0.0
	panel.anchor_bottom = 0.0
	panel.offset_left = left
	panel.offset_right = left + width
	panel.offset_top = top
	panel.offset_bottom = top + 320.0


func _fit_panel() -> void:
	if _view_panel == null or not is_instance_valid(_view_panel):
		return
	var viewport := size
	var top := maxf(42.0, viewport.y * 0.12)
	var limit := viewport.y - top - maxf(36.0, viewport.y * 0.08)
	var wanted := _view_panel.get_combined_minimum_size().y
	_view_panel.offset_top = top
	_view_panel.offset_bottom = top + clampf(wanted, 260.0, limit)


func _close_view() -> void:
	if _view_layer != null and is_instance_valid(_view_layer):
		_view_layer.queue_free()
	_view_layer = null
	_view_panel = null
	_view = ""
	_status_label = null
	_name_edit = null
	_seed_edit = null
	_ip_edit = null
	_port_edit = null
	_solo_name_edit = null
	_solo_seed_edit = null
	_coop_name_edit = null
	_coop_seed_edit = null
	_coop_ip_edit = null
	_coop_port_edit = null
	_host_button = null
	_join_button = null
	_solo_button = null
	_quit_button = null
	_root_layer.modulate = Color.WHITE
	if visible:
		_select(_selected, true)


func _view_header(body: VBoxContainer, title_text: String, sub_text: String) -> void:
	body.add_child(DeadCityUI.make_label(title_text, 30, DeadCityUI.TEXT, DeadCityUI.serif_font()))
	body.add_child(DeadCityUI.make_label(sub_text, 11, DeadCityUI.MUTED, DeadCityUI.display_font()))
	body.add_child(_hairline())


func _hairline() -> ColorRect:
	var line := ColorRect.new()
	line.color = Color(0.85, 0.82, 0.76, 0.20)
	line.custom_minimum_size = Vector2(0, 1)
	return line


func _field_box(title_text: String, edit: LineEdit) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	box.add_child(DeadCityUI.make_label(title_text, 10, DeadCityUI.MUTED_2, DeadCityUI.display_font()))
	box.add_child(edit)
	return box


func _line_edit(text_value: String, placeholder: String) -> LineEdit:
	var edit := LineEdit.new()
	edit.text = text_value
	edit.placeholder_text = placeholder
	edit.custom_minimum_size = Vector2(0, 40)
	edit.max_length = 64
	return edit


func _view_buttons(body: VBoxContainer) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	body.add_child(row)
	return row


func _build_solo_view(body: VBoxContainer) -> void:
	_view_header(body, "单人行动", "第一章 · 失联信号  //  本地权威 · 真实任务流程")
	_solo_name_edit = _line_edit("幸存者", "输入行动呼号")
	_name_edit = _solo_name_edit
	body.add_child(_field_box("行动呼号", _solo_name_edit))
	_solo_seed_edit = _line_edit("", "留空则随机生成")
	_seed_edit = _solo_seed_edit
	body.add_child(_field_box("地图种子", _solo_seed_edit))
	body.add_child(DeadCityUI.make_label("从 E-07 三楼观察室出发，经西侧楼梯下楼，到基地补给并回收 3 枚核心。", 11, DeadCityUI.MUTED, DeadCityUI.display_font()))
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(spacer)
	_status_label = DeadCityUI.make_label("", 11, DeadCityUI.MUTED, DeadCityUI.display_font())
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(_status_label)
	var buttons := _view_buttons(body)
	_solo_button = Button.new()
	_solo_button.text = "开始部署"
	_solo_button.custom_minimum_size = Vector2(0, 46)
	_solo_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	DeadCityUI.style_button(_solo_button, DeadCityUI.AMBER, true)
	_solo_button.pressed.connect(_on_solo_pressed)
	buttons.add_child(_solo_button)
	var back := Button.new()
	back.text = "返回"
	back.custom_minimum_size = Vector2(100, 46)
	DeadCityUI.style_button(back, DeadCityUI.MUTED, false)
	back.pressed.connect(_close_view)
	buttons.add_child(back)
	_solo_name_edit.text_submitted.connect(func(_t: String) -> void: _on_solo_pressed())
	_solo_name_edit.grab_focus.call_deferred()


func _build_coop_view(body: VBoxContainer) -> void:
	_view_header(body, "联机作战", "ENET · 1–4 人  //  主机创建房间，队友加入")
	_coop_name_edit = _line_edit("幸存者", "输入行动呼号")
	_coop_seed_edit = _line_edit("", "留空则随机生成")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var name_box := _field_box("行动呼号", _coop_name_edit)
	name_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_box)
	var seed_box := _field_box("地图种子", _coop_seed_edit)
	seed_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(seed_box)
	body.add_child(row)
	_coop_ip_edit = _line_edit("127.0.0.1", "主机局域网 IP")
	_coop_port_edit = _line_edit("7777", "端口")
	var net_row := HBoxContainer.new()
	net_row.add_theme_constant_override("separation", 10)
	var ip_box := _field_box("主机地址", _coop_ip_edit)
	ip_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ip_box.size_flags_stretch_ratio = 2.0
	net_row.add_child(ip_box)
	var port_box := _field_box("端口", _coop_port_edit)
	port_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	net_row.add_child(port_box)
	body.add_child(net_row)
	body.add_child(DeadCityUI.make_label("同一局域网内：主机创建房间后，把本机 IP 与端口告诉队友。", 10, DeadCityUI.MUTED_2, DeadCityUI.display_font()))
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(spacer)
	_status_label = DeadCityUI.make_label("", 11, DeadCityUI.MUTED, DeadCityUI.display_font())
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(_status_label)
	var buttons := _view_buttons(body)
	_host_button = Button.new()
	_host_button.text = "创建房间"
	_host_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_host_button.custom_minimum_size = Vector2(0, 46)
	DeadCityUI.style_button(_host_button, DeadCityUI.AMBER, true)
	_host_button.pressed.connect(_on_host_pressed)
	buttons.add_child(_host_button)
	_join_button = Button.new()
	_join_button.text = "加入房间"
	_join_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_join_button.custom_minimum_size = Vector2(0, 46)
	DeadCityUI.style_button(_join_button, DeadCityUI.CYAN, false)
	_join_button.pressed.connect(_on_join_pressed)
	buttons.add_child(_join_button)
	var back := Button.new()
	back.text = "返回"
	back.custom_minimum_size = Vector2(84, 46)
	DeadCityUI.style_button(back, DeadCityUI.MUTED, false)
	back.pressed.connect(_close_view)
	buttons.add_child(back)
	_name_edit = _coop_name_edit
	_seed_edit = _coop_seed_edit
	_ip_edit = _coop_ip_edit
	_port_edit = _coop_port_edit
	_coop_name_edit.grab_focus.call_deferred()


func _build_settings_view(body: VBoxContainer) -> void:
	_view_header(body, "设置", "立即生效并保存到 user://ui_settings.cfg")
	var settings = _settings()
	body.add_child(_settings_slider("主音量", float(settings.master_volume) if settings != null else 0.85, func(value: float) -> void:
		if settings != null:
			settings.set_master_volume(value)
	))
	body.add_child(_settings_check("全屏", bool(settings.fullscreen) if settings != null else false, func(value: bool) -> void:
		if settings != null:
			settings.set_fullscreen(value)
	))
	body.add_child(_settings_check("垂直同步", bool(settings.vsync) if settings != null else true, func(value: bool) -> void:
		if settings != null:
			settings.set_vsync(value)
	))
	var scale_row := HBoxContainer.new()
	scale_row.add_theme_constant_override("separation", 12)
	scale_row.add_child(DeadCityUI.make_label("HUD 缩放", 12, DeadCityUI.TEXT, DeadCityUI.display_font()))
	var scale_spacer := Control.new()
	scale_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scale_row.add_child(scale_spacer)
	var scale_option := OptionButton.new()
	scale_option.custom_minimum_size = Vector2(150, 34)
	scale_option.add_item("90%", 0)
	scale_option.add_item("100%", 1)
	scale_option.add_item("110%", 2)
	var current_scale := float(settings.hud_scale) if settings != null else 1.0
	scale_option.selected = 0 if current_scale < 0.95 else (2 if current_scale > 1.05 else 1)
	scale_option.item_selected.connect(func(index: int) -> void:
		if settings != null:
			settings.set_hud_scale([0.9, 1.0, 1.1][index])
	)
	scale_row.add_child(scale_option)
	body.add_child(scale_row)
	body.add_child(_settings_check("减弱动态（关闭浮尘、视差与位移动画）", bool(settings.reduced_motion) if settings != null else false, func(value: bool) -> void:
		if settings != null:
			settings.set_reduced_motion(value)
	))
	body.add_child(_settings_check("高对比度", bool(settings.high_contrast) if settings != null else false, func(value: bool) -> void:
		if settings != null:
			settings.set_high_contrast(value)
	))
	body.add_child(DeadCityUI.make_label("联机暂停不会停止服务器模拟；单人暂停会停止世界。", 10, DeadCityUI.MUTED_2, DeadCityUI.display_font()))
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(spacer)
	var buttons := _view_buttons(body)
	var back := Button.new()
	back.text = "完成"
	back.custom_minimum_size = Vector2(0, 44)
	back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	DeadCityUI.style_button(back, DeadCityUI.AMBER, true)
	back.pressed.connect(_close_view)
	buttons.add_child(back)
	back.grab_focus.call_deferred()


func _settings_slider(label_text: String, value: float, on_change: Callable) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	var row := HBoxContainer.new()
	box.add_child(row)
	row.add_child(DeadCityUI.make_label(label_text, 12, DeadCityUI.TEXT, DeadCityUI.display_font()))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	var value_label := DeadCityUI.make_label("%d%%" % int(round(value * 100.0)), 11, DeadCityUI.AMBER, DeadCityUI.display_font())
	row.add_child(value_label)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = value
	slider.custom_minimum_size = Vector2(0, 22)
	slider.value_changed.connect(func(v: float) -> void:
		value_label.text = "%d%%" % int(round(v * 100.0))
		on_change.call(v)
	)
	box.add_child(slider)
	return box


func _settings_check(label_text: String, value: bool, on_change: Callable) -> CheckBox:
	var check := CheckBox.new()
	check.text = label_text
	check.button_pressed = value
	check.custom_minimum_size = Vector2(0, 36)
	check.add_theme_font_size_override("font_size", 12)
	check.toggled.connect(on_change)
	return check


func _build_quit_view(body: VBoxContainer) -> void:
	_view_header(body, "退出游戏", "确认结束当前客户端？")
	body.add_child(DeadCityUI.make_label("未保存的行动进度将不会保留。", 12, DeadCityUI.MUTED, DeadCityUI.display_font()))
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(spacer)
	var buttons := _view_buttons(body)
	var cancel := Button.new()
	cancel.text = "取消"
	cancel.custom_minimum_size = Vector2(0, 46)
	cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	DeadCityUI.style_button(cancel, DeadCityUI.AMBER, true)
	cancel.pressed.connect(_close_view)
	buttons.add_child(cancel)
	var confirm := Button.new()
	confirm.text = "退出"
	confirm.custom_minimum_size = Vector2(0, 46)
	confirm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	DeadCityUI.style_button(confirm, DeadCityUI.RED, false)
	confirm.pressed.connect(func() -> void: quit_requested.emit())
	buttons.add_child(confirm)
	cancel.grab_focus.call_deferred()


func _build_toast() -> void:
	_toast = DeadCityUI.make_label("", 12, DeadCityUI.TEXT, DeadCityUI.display_font())
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_toast.anchor_left = 0.5
	_toast.anchor_right = 0.5
	_toast.anchor_top = 1.0
	_toast.anchor_bottom = 1.0
	_toast.offset_left = -260.0
	_toast.offset_right = 260.0
	_toast.offset_top = -92.0
	_toast.offset_bottom = -58.0
	_toast.modulate.a = 0.0
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_toast)


func _show_toast(text: String, error: bool = false) -> void:
	if _toast == null:
		return
	_toast.text = text
	_toast.add_theme_color_override("font_color", DeadCityUI.RED if error else DeadCityUI.TEXT)
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast.modulate.a = 1.0
	_toast_tween = create_tween()
	_toast_tween.tween_interval(2.2)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.35)


# ---------------------------------------------------------------------------
# Lobby
# ---------------------------------------------------------------------------

func _build_lobby() -> void:
	_lobby_layer = Control.new()
	_lobby_layer.name = "Lobby"
	_lobby_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_lobby_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	_lobby_layer.visible = false
	add_child(_lobby_layer)
	var tint := ColorRect.new()
	tint.color = Color(0.015, 0.017, 0.018, 0.80)
	tint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lobby_layer.add_child(tint)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lobby_layer.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(820, 548)
	var style := DeadCityUI.panel_style(Color(0.035, 0.04, 0.042, 0.985), 3, Color(0.85, 0.82, 0.76, 0.22), 1)
	style.content_margin_left = 32.0
	style.content_margin_right = 32.0
	style.content_margin_top = 26.0
	style.content_margin_bottom = 26.0
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	panel.add_child(body)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 16)
	body.add_child(header)
	var titles := VBoxContainer.new()
	titles.add_theme_constant_override("separation", 2)
	header.add_child(titles)
	titles.add_child(DeadCityUI.make_label("行动准备", 34, DeadCityUI.TEXT, DeadCityUI.serif_font()))
	titles.add_child(DeadCityUI.make_label("READY CHECK  //  所有队员就绪后由房主开始", 10, DeadCityUI.MUTED, DeadCityUI.display_font()))
	var header_spacer := Control.new()
	header_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(header_spacer)
	var room_box := VBoxContainer.new()
	room_box.add_theme_constant_override("separation", 1)
	header.add_child(room_box)
	var room_tag := DeadCityUI.make_label("小队频道", 9, DeadCityUI.MUTED_2, DeadCityUI.display_font())
	room_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	room_box.add_child(room_tag)
	_lobby_room = DeadCityUI.make_label("PORT ----  ·  MAP #----", 12, DeadCityUI.AMBER, DeadCityUI.display_font())
	_lobby_room.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	room_box.add_child(_lobby_room)
	body.add_child(_hairline())
	var roster_title := HBoxContainer.new()
	body.add_child(roster_title)
	roster_title.add_child(DeadCityUI.make_label("小队状态", 13, DeadCityUI.TEXT, DeadCityUI.display_font()))
	var roster_spacer := Control.new()
	roster_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	roster_title.add_child(roster_spacer)
	roster_title.add_child(DeadCityUI.make_label("最多 4 人  ·  中途加入将被拒绝", 9, DeadCityUI.MUTED_2, DeadCityUI.display_font()))
	_lobby_roster_box = VBoxContainer.new()
	_lobby_roster_box.add_theme_constant_override("separation", 5)
	_lobby_roster_box.custom_minimum_size = Vector2(0, 238)
	body.add_child(_lobby_roster_box)
	_lobby_archive = DeadCityUI.make_label(MetaProfile.archive_line(MetaProfile.empty_profile()), 10, DeadCityUI.MUTED, DeadCityUI.display_font())
	body.add_child(_lobby_archive)
	_lobby_hint = DeadCityUI.make_label("等待小队同步…", 11, DeadCityUI.MUTED, DeadCityUI.display_font())
	_lobby_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(_lobby_hint)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(spacer)
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 10)
	body.add_child(footer)
	var leave := Button.new()
	leave.text = "离开房间"
	leave.custom_minimum_size = Vector2(150, 44)
	DeadCityUI.style_button(leave, DeadCityUI.CORAL, false)
	leave.pressed.connect(func() -> void: lobby_leave_requested.emit())
	footer.add_child(leave)
	var footer_spacer := Control.new()
	footer_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(footer_spacer)
	_lobby_ready_button = Button.new()
	_lobby_ready_button.text = "准备就绪"
	_lobby_ready_button.custom_minimum_size = Vector2(190, 44)
	DeadCityUI.style_button(_lobby_ready_button, DeadCityUI.CYAN, true)
	_lobby_ready_button.pressed.connect(_on_lobby_ready_pressed)
	footer.add_child(_lobby_ready_button)
	_lobby_start_button = Button.new()
	_lobby_start_button.text = "开始行动"
	_lobby_start_button.custom_minimum_size = Vector2(210, 44)
	DeadCityUI.style_button(_lobby_start_button, DeadCityUI.AMBER, true)
	_lobby_start_button.pressed.connect(func() -> void: lobby_start_requested.emit())
	footer.add_child(_lobby_start_button)


func _on_lobby_ready_pressed() -> void:
	_lobby_local_ready = not _lobby_local_ready
	lobby_ready_requested.emit(_lobby_local_ready)


func _lobby_row(entry: Dictionary, ready: bool, is_host_row: bool, is_local: bool) -> Control:
	var row := PanelContainer.new()
	var style := DeadCityUI.panel_style(Color(0.055, 0.06, 0.062, 0.92), 3, Color(0.85, 0.82, 0.76, 0.12), 1)
	style.content_margin_left = 14.0
	style.content_margin_right = 14.0
	style.content_margin_top = 9.0
	style.content_margin_bottom = 9.0
	row.add_theme_stylebox_override("panel", style)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 10)
	row.add_child(line)
	var color: Color = entry.get("color", DeadCityUI.CYAN)
	var bar := ColorRect.new()
	bar.color = color
	bar.custom_minimum_size = Vector2(3, 24)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(bar)
	var name_text := String(entry.get("name", "幸存者"))
	if is_local:
		name_text += "（你）"
	var name_label := DeadCityUI.make_label(name_text, 15, DeadCityUI.TEXT, DeadCityUI.display_font())
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(name_label)
	if is_host_row:
		line.add_child(DeadCityUI.make_label("房主", 9, DeadCityUI.AMBER, DeadCityUI.display_font()))
	var status := DeadCityUI.make_label("已就绪" if ready else "未准备", 11, DeadCityUI.MUTED if not ready else DeadCityUI.MUTED, DeadCityUI.display_font())
	status.custom_minimum_size = Vector2(56, 0)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	if ready:
		status.add_theme_color_override("font_color", DeadCityUI.GREEN)
	else:
		status.add_theme_color_override("font_color", DeadCityUI.AMBER)
	line.add_child(status)
	return row


func _lobby_empty_row() -> Control:
	var row := PanelContainer.new()
	var style := DeadCityUI.panel_style(Color(0.025, 0.028, 0.03, 0.55), 3, Color(0.85, 0.82, 0.76, 0.06), 1)
	style.content_margin_left = 14.0
	style.content_margin_right = 14.0
	style.content_margin_top = 9.0
	style.content_margin_bottom = 9.0
	row.add_theme_stylebox_override("panel", style)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 10)
	row.add_child(line)
	var bar := ColorRect.new()
	bar.color = Color(0.24, 0.24, 0.23, 0.6)
	bar.custom_minimum_size = Vector2(3, 24)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(bar)
	var name_label := DeadCityUI.make_label("等待队员加入…", 13, Color(0.45, 0.44, 0.41), DeadCityUI.display_font())
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(name_label)
	line.add_child(DeadCityUI.make_label("空位", 9, Color(0.45, 0.44, 0.41), DeadCityUI.display_font()))
	return row


func show_lobby(is_host: bool, local_id: int, payload: Dictionary) -> void:
	_root_layer.visible = false
	_close_view()
	_lobby_is_host = is_host
	_lobby_local_id = local_id
	_lobby_layer.visible = true
	update_lobby(payload, local_id)
	if _lobby_is_host:
		_lobby_start_button.grab_focus.call_deferred()
	else:
		_lobby_ready_button.grab_focus.call_deferred()


func update_lobby(payload: Dictionary, local_id: int = -1) -> void:
	if local_id > 0:
		_lobby_local_id = local_id
	_lobby_payload = payload
	var players: Array = payload.get("players", [])
	var ready: Dictionary = payload.get("ready", {})
	var host_id := int(payload.get("host_id", 1))
	var all_ready := bool(payload.get("all_ready", false))
	_lobby_room.text = "PORT %d  ·  MAP #%d" % [int(payload.get("port", 0)), int(payload.get("seed", 0))]
	_lobby_local_ready = bool(ready.get(_lobby_local_id, ready.get(str(_lobby_local_id), false)))
	for child in _lobby_roster_box.get_children():
		_lobby_roster_box.remove_child(child)
		child.queue_free()
	for raw in players:
		if not raw is Dictionary:
			continue
		var entry: Dictionary = raw
		var id := int(entry.get("id", 0))
		_lobby_roster_box.add_child(_lobby_row(entry, bool(ready.get(id, ready.get(str(id), false))), id == host_id, id == _lobby_local_id))
	for i in range(MAX_PLAYER_ROWS - players.size()):
		_lobby_roster_box.add_child(_lobby_empty_row())
	_lobby_ready_button.visible = not _lobby_is_host
	_lobby_start_button.visible = _lobby_is_host
	_lobby_ready_button.text = "取消准备" if _lobby_local_ready else "准备就绪"
	_lobby_start_button.disabled = not all_ready or players.is_empty()
	_lobby_start_button.text = "开始行动" if all_ready else "等待队员准备"
	_lobby_hint.text = "全员已准备，等待房主开始行动。" if all_ready else "所有队员准备后，房主才能开始行动；中途无法加入行动。"
	_lobby_hint.add_theme_color_override("font_color", DeadCityUI.GREEN if all_ready else DeadCityUI.MUTED)
	_lobby_archive.text = MetaProfile.archive_line(_profile)


func hide_lobby() -> void:
	if _lobby_layer != null:
		_lobby_layer.visible = false
	if _root_layer != null:
		_root_layer.visible = true


func set_lobby_status(text: String, is_error: bool = false) -> void:
	if _lobby_hint == null:
		return
	_lobby_hint.text = text
	_lobby_hint.add_theme_color_override("font_color", DeadCityUI.RED if is_error else DeadCityUI.MUTED)


# ---------------------------------------------------------------------------
# Armory / loadout
# ---------------------------------------------------------------------------

func _build_armory() -> void:
	_armory_layer = Control.new()
	_armory_layer.name = "Armory"
	_armory_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_armory_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	_armory_layer.visible = false
	add_child(_armory_layer)
	var tint := ColorRect.new()
	tint.color = Color(0.015, 0.017, 0.018, 0.86)
	tint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_armory_layer.add_child(tint)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_armory_layer.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(1120, 620)
	var style := DeadCityUI.panel_style(Color(0.035, 0.04, 0.042, 0.99), 3, Color(0.85, 0.82, 0.76, 0.22), 1)
	style.content_margin_left = 28.0
	style.content_margin_right = 28.0
	style.content_margin_top = 24.0
	style.content_margin_bottom = 24.0
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 10)
	panel.add_child(body)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 16)
	body.add_child(header)
	var titles := VBoxContainer.new()
	titles.add_theme_constant_override("separation", 1)
	header.add_child(titles)
	titles.add_child(DeadCityUI.make_label("角色整备", 32, DeadCityUI.TEXT, DeadCityUI.serif_font()))
	titles.add_child(DeadCityUI.make_label("ARMORY / LOADOUT  //  真实装备 · 信用点永久解锁", 10, DeadCityUI.MUTED, DeadCityUI.display_font()))
	var header_spacer := Control.new()
	header_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(header_spacer)
	var credits_box := VBoxContainer.new()
	credits_box.add_theme_constant_override("separation", 0)
	header.add_child(credits_box)
	var credits_tag := DeadCityUI.make_label("可用信用点", 9, DeadCityUI.MUTED_2, DeadCityUI.display_font())
	credits_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	credits_box.add_child(credits_tag)
	_armory_credits = DeadCityUI.make_label("0", 24, DeadCityUI.AMBER, DeadCityUI.display_font())
	_armory_credits.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	credits_box.add_child(_armory_credits)
	var close := Button.new()
	close.text = "关闭  Esc"
	close.custom_minimum_size = Vector2(118, 36)
	close.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	DeadCityUI.style_button(close, DeadCityUI.MUTED, false)
	close.pressed.connect(close_armory)
	header.add_child(close)
	body.add_child(_hairline())
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 22)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(columns)
	var profile_col := VBoxContainer.new()
	profile_col.custom_minimum_size = Vector2(280, 0)
	profile_col.add_theme_constant_override("separation", 8)
	columns.add_child(profile_col)
	profile_col.add_child(DeadCityUI.make_label("幸存者档案", 12, DeadCityUI.AMBER, DeadCityUI.display_font()))
	_armory_profile_level = DeadCityUI.make_label("幸存者血脉 Lv.0", 20, DeadCityUI.TEXT, DeadCityUI.display_font())
	profile_col.add_child(_armory_profile_level)
	_armory_profile_stats = DeadCityUI.make_label("行动 0 次 · 完成 0 次", 10, DeadCityUI.MUTED, DeadCityUI.display_font())
	_armory_profile_stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	profile_col.add_child(_armory_profile_stats)
	profile_col.add_child(_hairline())
	profile_col.add_child(DeadCityUI.make_label("出战编成", 12, DeadCityUI.TEXT, DeadCityUI.display_font()))
	_armory_loadout = VBoxContainer.new()
	_armory_loadout.add_theme_constant_override("separation", 6)
	profile_col.add_child(_armory_loadout)
	profile_col.add_child(DeadCityUI.make_label("未拥有角色模型 / 技能系统：本页只展示工程中真实存在的装备与档案数据。", 9, DeadCityUI.MUTED_2, DeadCityUI.display_font()))
	var profile_spacer := Control.new()
	profile_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	profile_col.add_child(profile_spacer)
	var weapons_col := VBoxContainer.new()
	weapons_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	weapons_col.add_theme_constant_override("separation", 6)
	columns.add_child(weapons_col)
	weapons_col.add_child(DeadCityUI.make_label("武器库", 12, DeadCityUI.AMBER, DeadCityUI.display_font()))
	_armory_cards = GridContainer.new()
	_armory_cards.columns = 4
	_armory_cards.add_theme_constant_override("h_separation", 8)
	_armory_cards.add_theme_constant_override("v_separation", 8)
	_armory_cards.size_flags_vertical = Control.SIZE_EXPAND_FILL
	weapons_col.add_child(_armory_cards)
	_armory_status = DeadCityUI.make_label("击杀感染者与回收核心可获得信用点。", 10, DeadCityUI.MUTED, DeadCityUI.display_font())
	_armory_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	weapons_col.add_child(_armory_status)


func open_armory() -> void:
	if _armory_layer == null:
		return
	hide_lobby()
	_close_view()
	_root_layer.visible = false
	_armory_layer.visible = true
	set_armory_status("击杀感染者与回收核心可获得信用点。", false)
	_render_armory()
	_focus_first_armory_button.call_deferred()


func close_armory() -> void:
	if _armory_layer != null:
		_armory_layer.visible = false
	if _root_layer != null:
		_root_layer.visible = true
		_select(_selected, true)


func refresh_armory() -> void:
	if _armory_layer != null and _armory_layer.visible:
		_render_armory()


func set_armory_status(text: String, is_error: bool = false) -> void:
	if _armory_status == null:
		return
	_armory_status.text = text
	_armory_status.add_theme_color_override("font_color", DeadCityUI.RED if is_error else DeadCityUI.MUTED)


func _focus_first_armory_button() -> void:
	for child in _armory_cards.get_children():
		var buttons := child.find_children("*", "Button", true, false)
		for raw in buttons:
			var button := raw as Button
			if button != null and not button.disabled:
				button.grab_focus()
				return


func _render_armory() -> void:
	if _armory_cards == null:
		return
	for child in _armory_cards.get_children():
		_armory_cards.remove_child(child)
		child.queue_free()
	var credits := int(_profile.get("credits", 0))
	var selected := String(_profile.get("selected_weapon", WeaponCatalog.DEFAULT_SELECTED))
	var equipped := MetaProfile.equipped_weapons(_profile)
	if _armory_credits != null:
		_armory_credits.text = str(credits)
	if _armory_profile_level != null:
		_armory_profile_level.text = "幸存者血脉 Lv.%d" % MetaProfile.legacy_level(_profile)
	if _armory_profile_stats != null:
		_armory_profile_stats.text = "行动 %d 次 · 完成 %d 次 · 最佳战力 %d · 信用点 %d" % [
			int(_profile.get("runs", 0)), int(_profile.get("victories", 0)),
			int(_profile.get("best_power", 0)), credits,
		]
	_render_loadout(equipped, selected)
	var ids := WeaponCatalog.ordered_ids()
	for index in range(ids.size()):
		var weapon_id := String(ids[index])
		var weapon := WeaponCatalog.data(weapon_id)
		var owned := MetaProfile.owns_weapon(_profile, weapon_id)
		var active: bool = weapon_id == selected
		var in_loadout: bool = equipped.has(weapon_id)
		var price := WeaponCatalog.price_of(weapon_id)
		var accent := WeaponCatalog.accent(weapon_id)
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(176, 208)
		var border := accent if active else Color(accent.r, accent.g, accent.b, 0.45 if owned else 0.18)
		var fill := Color(0.065, 0.072, 0.074, 0.96) if active else Color(0.045, 0.05, 0.052, 0.9 if owned else 0.45)
		var style := DeadCityUI.panel_style(fill, 4, border, 1)
		style.content_margin_left = 10.0
		style.content_margin_right = 10.0
		style.content_margin_top = 10.0
		style.content_margin_bottom = 10.0
		card.add_theme_stylebox_override("panel", style)
		_armory_cards.add_child(card)
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 4)
		card.add_child(box)
		var kind_text := "近战" if WeaponCatalog.is_melee(weapon_id) else "枪械"
		box.add_child(DeadCityUI.make_label("%s · %s" % [kind_text, "出战" if in_loadout else "库存"], 9, accent if owned else DeadCityUI.MUTED_2, DeadCityUI.display_font()))
		box.add_child(DeadCityUI.make_label(String(weapon.get("name", "未知")), 14, DeadCityUI.TEXT if owned else Color(0.62, 0.60, 0.56), DeadCityUI.display_font()))
		box.add_child(DeadCityUI.make_label(String(weapon.get("tag", "")), 9, accent if owned else DeadCityUI.MUTED_2, DeadCityUI.display_font()))
		var stat := DeadCityUI.make_label(WeaponCatalog.stat_line(weapon_id), 9, DeadCityUI.MUTED if owned else DeadCityUI.MUTED_2, DeadCityUI.display_font())
		stat.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		stat.custom_minimum_size = Vector2(0, 42)
		box.add_child(stat)
		var gap := Control.new()
		gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
		box.add_child(gap)
		var button := Button.new()
		button.custom_minimum_size = Vector2(0, 34)
		button.focus_mode = Control.FOCUS_ALL
		if active:
			button.text = "使用中"
			button.disabled = true
			DeadCityUI.style_button(button, accent, false)
		elif owned:
			button.text = "切换" if in_loadout else ("替换出战" if equipped.size() >= WeaponCatalog.MAX_CARRY else "装备")
			DeadCityUI.style_button(button, accent, true)
			button.pressed.connect(_on_equip_pressed.bind(weapon_id))
		else:
			if price <= 0:
				button.text = "解锁"
				DeadCityUI.style_button(button, accent, true)
			else:
				button.text = "解锁 · %d" % price
				if credits < price:
					button.disabled = true
					DeadCityUI.style_button(button, DeadCityUI.MUTED, false)
				else:
					DeadCityUI.style_button(button, accent, true)
			button.pressed.connect(_on_buy_pressed.bind(weapon_id))
		box.add_child(button)


func _render_loadout(equipped: Array, selected: String) -> void:
	if _armory_loadout == null:
		return
	for child in _armory_loadout.get_children():
		_armory_loadout.remove_child(child)
		child.queue_free()
	for i in range(WeaponCatalog.MAX_CARRY):
		var id := String(equipped[i]) if i < equipped.size() else ""
		var slot := PanelContainer.new()
		var style := DeadCityUI.panel_style(Color(0.06, 0.065, 0.067, 0.9), 3, Color(0.85, 0.82, 0.76, 0.12), 1)
		style.content_margin_left = 10.0
		style.content_margin_right = 10.0
		style.content_margin_top = 8.0
		style.content_margin_bottom = 8.0
		slot.add_theme_stylebox_override("panel", style)
		_armory_loadout.add_child(slot)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		slot.add_child(row)
		row.add_child(DeadCityUI.make_label(str(i + 1), 10, DeadCityUI.MUTED_2, DeadCityUI.display_font()))
		var name_label := DeadCityUI.make_label(WeaponCatalog.display_name(id) if not id.is_empty() else "空槽", 13, DeadCityUI.TEXT if not id.is_empty() else DeadCityUI.MUTED_2, DeadCityUI.display_font())
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_label)
		if not id.is_empty() and id == selected:
			row.add_child(DeadCityUI.make_label("当前", 9, DeadCityUI.AMBER, DeadCityUI.display_font()))


func _on_buy_pressed(weapon_id: String) -> void:
	buy_weapon_requested.emit(weapon_id)


func _on_equip_pressed(weapon_id: String) -> void:
	equip_weapon_requested.emit(weapon_id)


func set_profile(profile: Dictionary) -> void:
	_profile = profile
	if _meta_line != null:
		_meta_line.text = "幸存者血脉 Lv.%d  ·  信用点 %d" % [MetaProfile.legacy_level(profile), int(profile.get("credits", 0))]
	if _lobby_archive != null:
		_lobby_archive.text = MetaProfile.archive_line(profile)
	if _armory_layer != null and _armory_layer.visible:
		_render_armory()


# ---------------------------------------------------------------------------
# Shared API used by main.gd
# ---------------------------------------------------------------------------

func set_busy(value: bool, message: String = "") -> void:
	_busy = value
	if is_instance_valid(_host_button):
		_host_button.disabled = value
	if is_instance_valid(_join_button):
		_join_button.disabled = value
	if is_instance_valid(_solo_button):
		_solo_button.disabled = value
	for edit in [_name_edit, _seed_edit, _ip_edit, _port_edit, _solo_name_edit, _solo_seed_edit, _coop_name_edit, _coop_seed_edit, _coop_ip_edit, _coop_port_edit]:
		if is_instance_valid(edit) and edit is LineEdit:
			(edit as LineEdit).editable = not value
	if not message.is_empty():
		set_status(message, false)


func set_status(text: String, is_error: bool = false) -> void:
	_last_status = text
	_last_status_error = is_error
	if is_instance_valid(_status_label):
		_status_label.text = text
		_status_label.add_theme_color_override("font_color", DeadCityUI.RED if is_error else DeadCityUI.MUTED)


func present(message: String = "", is_error: bool = false) -> void:
	visible = true
	close_armory()
	hide_lobby()
	_close_view()
	_root_layer.visible = true
	_root_layer.modulate = Color.WHITE
	set_busy(false)
	if not message.is_empty():
		_show_toast(message, is_error)
		set_status(message, is_error)
	else:
		set_status("", false)
	_select(_selected, true)


func focus_name() -> void:
	if _name_edit != null and _name_edit.is_visible_in_tree():
		_name_edit.grab_focus()


func open_view(kind: String) -> void:
	## 供自动化截图与外部流程打开指定子界面；不改变任何游戏数据。
	if kind.is_empty():
		return
	_open_view(kind)


func _on_host_pressed() -> void:
	if _busy:
		return
	var port := _parse_port()
	if port < 0:
		return
	host_requested.emit(_parse_name(), port, _parse_seed())


func _on_join_pressed() -> void:
	if _busy:
		return
	var address := _ip_edit.text.strip_edges() if _ip_edit != null else ""
	if address.is_empty():
		set_status("请输入主机地址，例如 127.0.0.1 或局域网 IP。", true)
		return
	var port := _parse_port()
	if port < 0:
		return
	join_requested.emit(_parse_name(), address, port)


func _on_solo_pressed() -> void:
	if _busy:
		return
	solo_requested.emit(_parse_name(), _parse_seed())


func _parse_name() -> String:
	var value := ""
	if _name_edit != null:
		value = _name_edit.text
	value = value.replace("\n", " ").replace("\t", " ").strip_edges()
	if value.is_empty():
		value = "幸存者"
	if value.length() > 12:
		value = value.left(12)
	if _name_edit != null:
		_name_edit.text = value
	return value


func _parse_seed() -> int:
	var value := ""
	if _seed_edit != null:
		value = _seed_edit.text.strip_edges()
	if value.is_empty():
		return randi_range(1, 2147483000)
	if value.is_valid_int():
		return int(value)
	return abs(hash(value)) + 1


func _parse_port() -> int:
	var value := ""
	if _port_edit != null:
		value = _port_edit.text.strip_edges()
	if not value.is_valid_int():
		set_status("端口需要是 1024–65535 之间的数字。", true)
		return -1
	var port := int(value)
	if port < 1024 or port > 65535:
		set_status("端口需要是 1024–65535 之间的数字。", true)
		return -1
	return port


func _settings() -> Node:
	return get_node_or_null("/root/UISettings")


func _on_settings_changed(_key: String) -> void:
	_apply_accessibility()


func _apply_accessibility() -> void:
	if _backdrop != null:
		_backdrop.set_reduced_motion(DeadCityUI.reduced_motion())
		_backdrop.set_high_contrast(DeadCityUI.high_contrast())
	if _feedback != null:
		_feedback.set_enabled(not DeadCityUI.reduced_motion())
