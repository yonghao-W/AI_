class_name MainMenu
extends Control

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

var _name_edit: LineEdit
var _seed_edit: LineEdit
var _ip_edit: LineEdit
var _port_edit: LineEdit
var _host_button: Button
var _join_button: Button
var _solo_button: Button
var _quit_button: Button
var _status_label: Label
var _profile_level: Label
var _profile_stats: Label
var _profile_last: Label
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
var _armory_cards: HBoxContainer
var _armory_credits: Label
var _armory_status: Label
var _profile: Dictionary = MetaProfile.empty_profile()
var _busy := false


func _ready() -> void:
	theme = DeadCityUI.make_theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()


func _build() -> void:
	var backdrop := MenuBackdrop.new()
	add_child(backdrop)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 62)
	margin.add_theme_constant_override("margin_right", 62)
	margin.add_theme_constant_override("margin_top", 34)
	margin.add_theme_constant_override("margin_bottom", 26)
	add_child(margin)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 38)
	margin.add_child(columns)

	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 1.35
	left.add_theme_constant_override("separation", 8)
	columns.add_child(left)

	var eyebrow := _label("LOW-POLY CO-OP SURVIVAL  //  低多边形协作生存", 12, DeadCityUI.CYAN)
	eyebrow.add_theme_constant_override("outline_size", 0)
	left.add_child(eyebrow)
	var title := _label("死城突围", 64, DeadCityUI.TEXT)
	title.add_theme_constant_override("outline_size", 0)
	title.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.55))
	title.add_theme_constant_override("shadow_offset_y", 4)
	left.add_child(title)
	var title_line := HBoxContainer.new()
	title_line.add_theme_constant_override("separation", 14)
	left.add_child(title_line)
	title_line.add_child(_label("DEAD CITY", 20, DeadCityUI.AMBER))
	var accent := ColorRect.new()
	accent.color = DeadCityUI.CYAN
	accent.custom_minimum_size = Vector2(64, 3)
	accent.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	title_line.add_child(accent)
	title_line.add_child(_label("第一章 · 失联信号 · 1–4 人合作", 15, DeadCityUI.MUTED))
	left.add_child(_spacer(14))

	var form_panel := PanelContainer.new()
	form_panel.add_theme_stylebox_override("panel", DeadCityUI.panel_style(Color(0.035, 0.065, 0.083, 0.9), 16, Color(0.22, 0.34, 0.4, 0.8), 1))
	left.add_child(form_panel)
	var form := VBoxContainer.new()
	form.add_theme_constant_override("separation", 13)
	form_panel.add_child(form)
	var form_header := HBoxContainer.new()
	form.add_child(form_header)
	form_header.add_child(_label("部署终端", 18, DeadCityUI.TEXT))
	var header_spacer := Control.new()
	header_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	form_header.add_child(header_spacer)
	form_header.add_child(_label("LINK / ENET", 11, Color(0.42, 0.55, 0.6, 0.8)))

	var identity_row := HBoxContainer.new()
	identity_row.add_theme_constant_override("separation", 12)
	form.add_child(identity_row)
	_name_edit = _line_edit("幸存者", "输入呼号")
	identity_row.add_child(_field("行动呼号", _name_edit, true))
	_seed_edit = _line_edit("", "留空则随机生成")
	identity_row.add_child(_field("地图种子", _seed_edit, true))

	var network_row := HBoxContainer.new()
	network_row.add_theme_constant_override("separation", 12)
	form.add_child(network_row)
	_ip_edit = _line_edit("127.0.0.1", "主机局域网 IP")
	network_row.add_child(_field("主机地址", _ip_edit, true, 2.1))
	_port_edit = _line_edit("7777", "端口")
	network_row.add_child(_field("端口", _port_edit, true, 0.9))

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	form.add_child(buttons)
	_host_button = _button("创建房间", DeadCityUI.AMBER, true)
	_host_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_child(_host_button)
	_join_button = _button("加入房间", DeadCityUI.CYAN, false)
	_join_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_child(_join_button)
	_solo_button = _button("开始第一章", Color("#8d9caa"), false)
	buttons.add_child(_solo_button)

	_status_label = _label("等待部署 — 创建房间或加入队友。", 14, DeadCityUI.MUTED)
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.custom_minimum_size = Vector2(0, 20)
	form.add_child(_status_label)
	var hint := _label("同一局域网内：主机创建房间后，把本机 IP 与端口告诉队友即可加入。", 12, Color(0.48, 0.58, 0.62, 0.9))
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	form.add_child(hint)

	_build_archive(left)
	var flex := Control.new()
	flex.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(flex)
	var footer := HBoxContainer.new()
	left.add_child(footer)
	footer.add_child(_label("GODOT 4.7.2 STABLE  ·  ENET  ·  服务端权威", 11, Color(0.4, 0.5, 0.54, 0.8)))
	var footer_spacer := Control.new()
	footer_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(footer_spacer)
	_quit_button = _button("退出", Color("#6f7d85"), false)
	_quit_button.custom_minimum_size = Vector2(76, 34)
	footer.add_child(_quit_button)

	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(352, 0)
	right.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_child(right)
	_build_briefing(right)
	_build_lobby()
	_build_armory()
	_host_button.pressed.connect(_on_host_pressed)
	_join_button.pressed.connect(_on_join_pressed)
	_solo_button.pressed.connect(_on_solo_pressed)
	_quit_button.pressed.connect(func() -> void: quit_requested.emit())
	_name_edit.text_submitted.connect(func(_t: String) -> void: _on_host_pressed())
	_port_edit.text_submitted.connect(func(_t: String) -> void: _on_join_pressed())


func _build_archive(parent: VBoxContainer) -> void:
	var panel := PanelContainer.new()
	var style := DeadCityUI.panel_style(Color(0.035, 0.062, 0.075, 0.9), 12, Color(0.24, 0.48, 0.48, 0.65), 1)
	style.content_margin_left = 14.0
	style.content_margin_right = 14.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 16)
	panel.add_child(body)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 1)
	body.add_child(left)
	left.add_child(_label("局外档案  /  META PROFILE", 10, DeadCityUI.CYAN))
	_profile_level = _label("幸存者血脉 Lv.0", 17, DeadCityUI.TEXT)
	left.add_child(_profile_level)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 2)
	body.add_child(right)
	_profile_stats = _label("行动 0 次 · 完成 0 次 · 最佳战力 0", 11, DeadCityUI.MUTED)
	right.add_child(_profile_stats)
	_profile_last = _label(MetaProfile.last_run_line(MetaProfile.empty_profile()), 10, Color(0.48, 0.6, 0.62))
	_profile_last.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(_profile_last)
	var armory := _button("军械库", DeadCityUI.AMBER, true)
	armory.custom_minimum_size = Vector2(116, 40)
	armory.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	armory.pressed.connect(open_armory)
	body.add_child(armory)


func _build_lobby() -> void:
	_lobby_layer = Control.new()
	_lobby_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_lobby_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	_lobby_layer.visible = false
	add_child(_lobby_layer)
	var tint := ColorRect.new()
	tint.color = Color(0.008, 0.02, 0.028, 0.94)
	tint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lobby_layer.add_child(tint)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lobby_layer.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(792, 0)
	panel.add_theme_stylebox_override("panel", DeadCityUI.panel_style(Color(0.035, 0.06, 0.073, 0.99), 18, Color(0.32, 0.66, 0.62, 0.75), 1))
	center.add_child(panel)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 11)
	panel.add_child(body)
	var header := HBoxContainer.new()
	body.add_child(header)
	var titles := VBoxContainer.new()
	titles.add_theme_constant_override("separation", 0)
	header.add_child(titles)
	titles.add_child(_label("行动准备", 34, DeadCityUI.TEXT))
	titles.add_child(_label("READY CHECK  //  所有队员就绪后由房主开始行动", 11, DeadCityUI.CYAN))
	var header_spacer := Control.new()
	header_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(header_spacer)
	var room := VBoxContainer.new()
	room.add_theme_constant_override("separation", 1)
	header.add_child(room)
	var room_tag := _label("小队频道", 10, DeadCityUI.MUTED)
	room_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	room.add_child(room_tag)
	_lobby_room = _label("PORT ----  ·  MAP #----", 12, DeadCityUI.AMBER)
	_lobby_room.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	room.add_child(_lobby_room)
	body.add_child(_divider())
	var roster_title := HBoxContainer.new()
	body.add_child(roster_title)
	roster_title.add_child(_label("小队状态", 14, DeadCityUI.TEXT))
	var roster_spacer := Control.new()
	roster_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	roster_title.add_child(roster_spacer)
	roster_title.add_child(_label("最多 4 人  ·  中途加入将被拒绝", 10, Color(0.48, 0.6, 0.62)))
	_lobby_roster_box = VBoxContainer.new()
	_lobby_roster_box.add_theme_constant_override("separation", 6)
	_lobby_roster_box.custom_minimum_size = Vector2(0, 186)
	body.add_child(_lobby_roster_box)
	body.add_child(_divider())
	_lobby_archive = _label(MetaProfile.archive_line(MetaProfile.empty_profile()), 11, Color(0.62, 0.74, 0.74))
	body.add_child(_lobby_archive)
	_lobby_hint = _label("等待小队同步…", 12, DeadCityUI.MUTED)
	_lobby_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(_lobby_hint)
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 10)
	body.add_child(footer)
	var leave := _button("离开房间", DeadCityUI.CORAL, false)
	leave.custom_minimum_size = Vector2(150, 44)
	leave.pressed.connect(func() -> void: lobby_leave_requested.emit())
	footer.add_child(leave)
	var footer_spacer := Control.new()
	footer_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(footer_spacer)
	_lobby_ready_button = _button("准备就绪", DeadCityUI.CYAN, true)
	_lobby_ready_button.custom_minimum_size = Vector2(196, 44)
	_lobby_ready_button.pressed.connect(_on_lobby_ready_pressed)
	footer.add_child(_lobby_ready_button)
	_lobby_start_button = _button("开始行动", DeadCityUI.GREEN, true)
	_lobby_start_button.custom_minimum_size = Vector2(220, 44)
	_lobby_start_button.pressed.connect(func() -> void: lobby_start_requested.emit())
	footer.add_child(_lobby_start_button)


func _on_lobby_ready_pressed() -> void:
	_lobby_local_ready = not _lobby_local_ready
	lobby_ready_requested.emit(_lobby_local_ready)


func _build_armory() -> void:
	_armory_layer = Control.new()
	_armory_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_armory_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	_armory_layer.visible = false
	add_child(_armory_layer)
	var tint := ColorRect.new()
	tint.color = Color(0.008, 0.02, 0.028, 0.95)
	tint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_armory_layer.add_child(tint)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_armory_layer.add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", DeadCityUI.panel_style(Color(0.035, 0.06, 0.073, 0.99), 18, Color(0.72, 0.58, 0.28, 0.8), 1))
	center.add_child(panel)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 11)
	panel.add_child(body)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 16)
	body.add_child(header)
	var titles := VBoxContainer.new()
	titles.add_theme_constant_override("separation", 0)
	header.add_child(titles)
	titles.add_child(_label("军械库", 32, DeadCityUI.TEXT))
	titles.add_child(_label("ARMORY  //  信用点永久解锁武器，行动时携带所选主武器", 11, DeadCityUI.AMBER))
	var header_spacer := Control.new()
	header_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(header_spacer)
	var credits_box := VBoxContainer.new()
	credits_box.add_theme_constant_override("separation", 0)
	header.add_child(credits_box)
	var credits_tag := _label("可用信用点", 10, DeadCityUI.MUTED)
	credits_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	credits_box.add_child(credits_tag)
	_armory_credits = _label("0", 24, DeadCityUI.AMBER)
	_armory_credits.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	credits_box.add_child(_armory_credits)
	var close := _button("关闭", DeadCityUI.MUTED, false)
	close.custom_minimum_size = Vector2(102, 38)
	close.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	close.pressed.connect(close_armory)
	header.add_child(close)
	body.add_child(_divider())
	_armory_cards = HBoxContainer.new()
	_armory_cards.add_theme_constant_override("separation", 12)
	body.add_child(_armory_cards)
	body.add_child(_divider())
	_armory_status = _label("击杀感染者与回收核心可获得信用点。", 12, DeadCityUI.MUTED)
	_armory_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(_armory_status)
	var hint := _label("行动中按 1-5 或滚轮切换武器；搬运核心时无法开火。未解锁武器可在行动结算后购买。", 11, Color(0.48, 0.6, 0.62))
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(hint)


func open_armory() -> void:
	if _armory_layer == null:
		return
	hide_lobby()
	_armory_layer.visible = true
	set_armory_status("击杀感染者与回收核心可获得信用点。", false)
	_render_armory()


func close_armory() -> void:
	if _armory_layer != null:
		_armory_layer.visible = false


func refresh_armory() -> void:
	if _armory_layer != null and _armory_layer.visible:
		_render_armory()


func set_armory_status(text: String, is_error: bool = false) -> void:
	if _armory_status == null:
		return
	_armory_status.text = text
	_armory_status.add_theme_color_override("font_color", DeadCityUI.RED if is_error else DeadCityUI.MUTED)


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
		card.custom_minimum_size = Vector2(132, 0)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var border := accent if active else Color(accent.r, accent.g, accent.b, 0.5 if owned else 0.24)
		var fill := Color(0.06, 0.1, 0.11, 0.95) if active else Color(0.04, 0.062, 0.072, 0.85 if owned else 0.5)
		var style := DeadCityUI.panel_style(fill, 9, border, 2 if active else 1)
		style.content_margin_left = 10.0
		style.content_margin_right = 10.0
		style.content_margin_top = 13.0
		style.content_margin_bottom = 13.0
		card.add_theme_stylebox_override("panel", style)
		_armory_cards.add_child(card)
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 5)
		card.add_child(box)
		var kind_text := "近战" if WeaponCatalog.is_melee(weapon_id) else "枪械"
		box.add_child(_label("%s · %s" % [kind_text, "出战" if in_loadout else "库存"], 10, accent if owned else Color(0.44, 0.5, 0.52)))
		box.add_child(_label(String(weapon.get("name", "未知")), 15, DeadCityUI.TEXT if owned else Color(0.6, 0.66, 0.68)))
		box.add_child(_label(String(weapon.get("tag", "")), 10, accent if owned else Color(0.44, 0.5, 0.52)))
		var stat := _label(WeaponCatalog.stat_line(weapon_id), 10, Color(0.6, 0.72, 0.73) if owned else Color(0.44, 0.5, 0.52))
		stat.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		stat.custom_minimum_size = Vector2(0, 50)
		box.add_child(stat)
		var gap := Control.new()
		gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
		box.add_child(gap)
		var button := Button.new()
		button.custom_minimum_size = Vector2(0, 38)
		button.focus_mode = Control.FOCUS_NONE
		if active:
			box.add_child(_label("当前出战", 10, DeadCityUI.GREEN))
			button.text = "使用中"
			button.disabled = true
			DeadCityUI.style_button(button, accent, false)
		elif owned:
			box.add_child(_label("出战编成 %d/%d" % [equipped.size(), WeaponCatalog.MAX_CARRY], 10, DeadCityUI.MUTED))
			button.text = "切换" if in_loadout else ("替换出战" if equipped.size() >= WeaponCatalog.MAX_CARRY else "装备")
			DeadCityUI.style_button(button, accent, true)
			button.pressed.connect(_on_equip_pressed.bind(weapon_id))
		else:
			box.add_child(_label("售价 %d 信用点" % price, 10, DeadCityUI.AMBER))
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


func _on_buy_pressed(weapon_id: String) -> void:
	buy_weapon_requested.emit(weapon_id)


func _on_equip_pressed(weapon_id: String) -> void:
	equip_weapon_requested.emit(weapon_id)


func show_lobby(is_host: bool, local_id: int, payload: Dictionary) -> void:
	_lobby_is_host = is_host
	_lobby_local_id = local_id
	_lobby_layer.visible = true
	update_lobby(payload, local_id)


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


func _lobby_row(entry: Dictionary, ready: bool, is_host_row: bool, is_local: bool) -> Control:
	var row := PanelContainer.new()
	var style := DeadCityUI.panel_style(Color(0.045, 0.082, 0.092, 0.9), 9, Color(0.2, 0.34, 0.36, 0.65), 1)
	style.content_margin_left = 14.0
	style.content_margin_right = 14.0
	style.content_margin_top = 9.0
	style.content_margin_bottom = 9.0
	row.add_theme_stylebox_override("panel", style)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 10)
	row.add_child(line)
	var color: Color = entry.get("color", DeadCityUI.CYAN)
	var dot := PanelContainer.new()
	dot.custom_minimum_size = Vector2(12, 12)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	dot.add_theme_stylebox_override("panel", DeadCityUI.panel_style(color, 4))
	line.add_child(dot)
	var name_text := String(entry.get("name", "幸存者"))
	if is_local:
		name_text += "（你）"
	var name_label := _label(name_text, 16, DeadCityUI.TEXT)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(name_label)
	var tag_text := "房主" if is_host_row else "队员"
	line.add_child(_label(tag_text, 10, DeadCityUI.CYAN if is_host_row else Color(0.48, 0.6, 0.62)))
	var status := _label("已就绪" if ready else "未准备", 12, DeadCityUI.GREEN if ready else DeadCityUI.AMBER)
	status.custom_minimum_size = Vector2(60, 0)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	line.add_child(status)
	return row


func _lobby_empty_row() -> Control:
	var row := PanelContainer.new()
	var style := DeadCityUI.panel_style(Color(0.03, 0.052, 0.062, 0.55), 9, Color(0.16, 0.25, 0.28, 0.5), 1)
	style.content_margin_left = 14.0
	style.content_margin_right = 14.0
	style.content_margin_top = 9.0
	style.content_margin_bottom = 9.0
	row.add_theme_stylebox_override("panel", style)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 10)
	row.add_child(line)
	var dot := PanelContainer.new()
	dot.custom_minimum_size = Vector2(12, 12)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	dot.add_theme_stylebox_override("panel", DeadCityUI.panel_style(Color(0.2, 0.28, 0.3), 4))
	line.add_child(dot)
	var label := _label("等待队员加入…", 14, Color(0.36, 0.46, 0.48))
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(label)
	line.add_child(_label("空位", 10, Color(0.34, 0.44, 0.46)))
	return row


func hide_lobby() -> void:
	if _lobby_layer != null:
		_lobby_layer.visible = false


func set_lobby_status(text: String, is_error: bool = false) -> void:
	if _lobby_hint == null:
		return
	_lobby_hint.text = text
	_lobby_hint.add_theme_color_override("font_color", DeadCityUI.RED if is_error else DeadCityUI.MUTED)


func set_profile(profile: Dictionary) -> void:
	_profile = profile
	if _profile_level == null:
		return
	var level := MetaProfile.legacy_level(profile)
	var bonus := MetaProfile.legacy_bonus(profile)
	_profile_level.text = "幸存者血脉 Lv.%d" % level
	_profile_level.add_theme_color_override("font_color", DeadCityUI.CYAN if level > 0 else DeadCityUI.TEXT)
	_profile_stats.text = "行动 %d 次 · 完成 %d 次 · 最佳战力 %d · 起始备弹 +%d · 信用点 %d" % [
		int(profile.get("runs", 0)),
		int(profile.get("victories", 0)),
		int(profile.get("best_power", 0)),
		int(bonus["reserve"]),
		int(profile.get("credits", 0)),
	]
	_profile_last.text = MetaProfile.last_run_line(profile)
	if _lobby_archive != null:
		_lobby_archive.text = MetaProfile.archive_line(profile)
	if _armory_layer != null and _armory_layer.visible:
		_render_armory()


func _build_briefing(parent: VBoxContainer) -> void:
	var panel := PanelContainer.new()
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", DeadCityUI.panel_style(Color(0.035, 0.06, 0.075, 0.88), 16, Color(0.2, 0.31, 0.36, 0.75), 1))
	parent.add_child(panel)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 10)
	panel.add_child(body)
	var top := HBoxContainer.new()
	body.add_child(top)
	top.add_child(_label("行动简报", 20, DeadCityUI.TEXT))
	var top_spacer := Control.new()
	top_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(top_spacer)
	top.add_child(_label("NIGHT 07", 11, DeadCityUI.RED))
	body.add_child(_divider())
	body.add_child(_brief_row("01", "失联信号", "从 E-07 三楼观察室出发，经西侧楼梯下楼，到青色基地补给。", DeadCityUI.CYAN))
	body.add_child(_brief_row("02", "尸潮递增", "每回收一枚核心，尸潮生成更快、数量更多，威胁倍率持续上涨。", DeadCityUI.AMBER))
	body.add_child(_brief_row("03", "深入回收", "沿市中心公园坡道步行下到 B1，抱回 3 枚核心；搬运时无法开枪。", Color("#ffc861")))
	body.add_child(_brief_row("04", "交付抽卡", "核心交付立即弹出 3 选 1 全队强化；战力写入局外档案，累积血脉加成。", DeadCityUI.GREEN))
	body.add_child(_divider())
	body.add_child(_label("色彩识别", 13, DeadCityUI.MUTED))
	var team := HBoxContainer.new()
	team.add_theme_constant_override("separation", 10)
	body.add_child(team)
	var names := ["青", "黄", "紫", "珊瑚"]
	for i in range(DeadCityUI.PLAYER_COLORS.size()):
		team.add_child(_color_chip(DeadCityUI.PLAYER_COLORS[i], names[i]))
	var threat := HBoxContainer.new()
	threat.add_theme_constant_override("separation", 10)
	body.add_child(threat)
	threat.add_child(_color_chip(Color("#759b50"), "普通"))
	threat.add_child(_color_chip(Color("#d8c36b"), "爬行"))
	threat.add_child(_color_chip(Color("#b1bf52"), "疾行"))
	threat.add_child(_color_chip(Color("#bb6b48"), "重装"))
	body.add_child(_divider())
	body.add_child(_label("操作", 13, DeadCityUI.MUTED))
	body.add_child(_label("WASD 移动 · Shift 冲刺 · Space 跳跃", 12, DeadCityUI.TEXT))
	body.add_child(_label("左键射击 · 右键瞄准 · R 换弹", 12, DeadCityUI.TEXT))
	body.add_child(_label("E 互动 / 补给 · G 放下核心 · Esc 菜单", 12, DeadCityUI.TEXT))
	body.add_child(_label("Tab 情报 · B 背包 · 1-5 / 滚轮切枪", 12, DeadCityUI.TEXT))
	var gap := Control.new()
	gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(gap)
	body.add_child(_divider())
	var tip := _label("提示：基地是安全区，丧尸会停止追击；弹药台按 E 补满弹药；组队需全员准备后由房主开始。", 12, Color(0.5, 0.6, 0.62))
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(tip)


func _brief_row(number: String, title: String, text: String, accent: Color) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var badge := _label(number, 13, accent)
	badge.custom_minimum_size = Vector2(26, 0)
	row.add_child(badge)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(column)
	column.add_child(_label(title, 16, DeadCityUI.TEXT))
	var detail := _label(text, 12, Color(0.55, 0.65, 0.68))
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(detail)
	return row


func _color_chip(color: Color, label_text: String) -> Control:
	var chip := HBoxContainer.new()
	chip.add_theme_constant_override("separation", 5)
	var swatch := PanelContainer.new()
	swatch.custom_minimum_size = Vector2(12, 12)
	swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	swatch.add_theme_stylebox_override("panel", DeadCityUI.panel_style(color, 3))
	chip.add_child(swatch)
	chip.add_child(_label(label_text, 12, Color(0.68, 0.76, 0.78)))
	return chip


func _field(title: String, edit: LineEdit, expand: bool, ratio: float = 1.0) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	if expand:
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		box.size_flags_stretch_ratio = ratio
	box.add_child(_label(title, 11, Color(0.52, 0.63, 0.67)))
	box.add_child(edit)
	return box


func _line_edit(default_text: String, placeholder: String) -> LineEdit:
	var edit := LineEdit.new()
	edit.text = default_text
	edit.placeholder_text = placeholder
	edit.custom_minimum_size = Vector2(0, 40)
	edit.max_length = 64
	return edit


func _button(text: String, accent: Color, filled: bool) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 46)
	DeadCityUI.style_button(button, accent, filled)
	return button


func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.4))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	return label


func _divider() -> ColorRect:
	var line := ColorRect.new()
	line.color = Color(0.26, 0.38, 0.42, 0.45)
	line.custom_minimum_size = Vector2(0, 1)
	return line


func _spacer(height: int) -> Control:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, height)
	return spacer


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
	var address := _ip_edit.text.strip_edges()
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
	var value := _name_edit.text.replace("\n", " ").replace("\t", " ").strip_edges()
	if value.is_empty():
		value = "幸存者"
	if value.length() > 12:
		value = value.left(12)
	_name_edit.text = value
	return value


func _parse_seed() -> int:
	var value := _seed_edit.text.strip_edges()
	if value.is_empty():
		return randi_range(1, 2147483000)
	if value.is_valid_int():
		return int(value)
	return abs(hash(value)) + 1


func _parse_port() -> int:
	var value := _port_edit.text.strip_edges()
	if not value.is_valid_int():
		set_status("端口需要是 1024–65535 之间的数字。", true)
		return -1
	var port := int(value)
	if port < 1024 or port > 65535:
		set_status("端口需要是 1024–65535 之间的数字。", true)
		return -1
	return port


func set_busy(value: bool, message: String = "") -> void:
	_busy = value
	_host_button.disabled = value
	_join_button.disabled = value
	_solo_button.disabled = value
	_name_edit.editable = not value
	_seed_edit.editable = not value
	_ip_edit.editable = not value
	_port_edit.editable = not value
	if not message.is_empty():
		set_status(message, false)


func set_status(text: String, is_error: bool = false) -> void:
	if _status_label == null:
		return
	_status_label.text = text
	_status_label.add_theme_color_override("font_color", DeadCityUI.RED if is_error else DeadCityUI.MUTED)


func present(message: String = "", is_error: bool = false) -> void:
	visible = true
	hide_lobby()
	close_armory()
	set_busy(false)
	if not message.is_empty():
		set_status(message, is_error)
	else:
		set_status("等待部署 — 创建房间或加入队友。", false)


func focus_name() -> void:
	if _name_edit != null:
		_name_edit.grab_focus()
