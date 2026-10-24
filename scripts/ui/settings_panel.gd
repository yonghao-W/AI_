class_name SettingsPanel
extends Control
## 原生 Godot 设置中心。所有值写入 UISettings；不复制第二套配置。
## 主菜单与暂停菜单共用同一实例。

signal closed

const DISPLAY_KEYS := ["window_mode", "resolution", "vsync", "fps_limit", "render_scale"]

var _service: Node
var _from_game := false
var _category := "controls"
var _nav_buttons: Dictionary = {}
var _content: VBoxContainer
var _scroll: ScrollContainer
var _category_title: Label
var _category_description: Label
var _detail_title: Label
var _detail_body: Label
var _preview: SettingsPreview
var _status: Label
var _dirty_label: Label
var _capture_action := ""
var _capture_button: Button
var _confirm_layer: Control
var _confirm_text: Label
var _confirm_seconds := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_service = get_node_or_null("/root/UISettings")
	_build()
	visible = false


func open(from_game: bool) -> void:
	_from_game = from_game
	_close_confirm()
	if _service != null:
		_service.cancel()
	_category = "controls"
	visible = true
	_select_category("controls")
	_update_dirty()
	_status.text = "调整后点击应用保存；Esc 放弃未应用修改。"
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func close() -> void:
	_end_capture()
	_close_confirm()
	if _service != null:
		_service.cancel()
	visible = false
	closed.emit()


func _build() -> void:
	var tint := ColorRect.new()
	tint.color = Color(0.006, 0.008, 0.01, 0.94)
	tint.mouse_filter = Control.MOUSE_FILTER_STOP
	tint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(tint)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 22 if side in ["left", "right"] else 18)
	add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	margin.add_child(root)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 16)
	root.add_child(top)
	var titles := VBoxContainer.new()
	titles.add_theme_constant_override("separation", 1)
	top.add_child(titles)
	titles.add_child(_label("游戏设置", 30, DeadCityUI.TEXT, DeadCityUI.serif_font()))
	titles.add_child(_label("LOCAL PROFILE  /  本机设置  ·  不会改变联机战斗数值", 10, DeadCityUI.MUTED_2))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)
	var close_button := Button.new()
	close_button.text = "返回  ESC"
	close_button.custom_minimum_size = Vector2(132, 38)
	DeadCityUI.style_button(close_button, DeadCityUI.MUTED, false)
	close_button.pressed.connect(close)
	top.add_child(close_button)
	root.add_child(_line())

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 18)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(columns)
	columns.add_child(_build_nav())
	columns.add_child(_build_center())
	columns.add_child(_build_context())

	root.add_child(_line())
	root.add_child(_build_footer())


func _build_nav() -> Control:
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(218, 0)
	box.add_theme_constant_override("separation", 4)
	box.add_child(_label("OPTIONS  /  01 — 06", 9, DeadCityUI.MUTED_2))
	box.add_child(_label("设置分类", 17, DeadCityUI.TEXT, DeadCityUI.serif_font()))
	for item in SettingsSchema.CATEGORIES:
		var button := Button.new()
		button.text = String(item["title"])
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size = Vector2(0, 42)
		button.focus_mode = Control.FOCUS_ALL
		button.add_theme_stylebox_override("focus", DeadCityUI.focus_style(DeadCityUI.AMBER))
		DeadCityUI.style_button(button, DeadCityUI.MUTED, false)
		button.pressed.connect(_select_category.bind(String(item["id"])))
		box.add_child(button)
		_nav_buttons[String(item["id"])] = button
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(spacer)
	var note := _label("鼠标与键盘均可操作。\nEsc 返回并放弃未应用修改。", 9, DeadCityUI.MUTED_2)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(note)
	return box


func _build_center() -> Control:
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 6)
	var head := VBoxContainer.new()
	head.add_theme_constant_override("separation", 1)
	box.add_child(head)
	_category_title = _label("操作与鼠标", 24, DeadCityUI.TEXT, DeadCityUI.serif_font())
	head.add_child(_category_title)
	_category_description = _label("", 11, DeadCityUI.MUTED)
	_category_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	head.add_child(_category_description)
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.follow_focus = true
	_scroll.resized.connect(_sync_content_width)
	box.add_child(_scroll)
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 8)
	_scroll.add_child(_content)
	return box


func _sync_content_width() -> void:
	if _scroll == null or _content == null:
		return
	_content.custom_minimum_size.x = maxf(320.0, _scroll.size.x - 18.0)


func _build_context() -> Control:
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(286, 0)
	box.add_theme_constant_override("separation", 6)
	box.add_child(_label("FIELD NOTES", 9, DeadCityUI.MUTED_2))
	_preview = SettingsPreview.new()
	_preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(_preview)
	box.add_child(_label("当前选项", 9, DeadCityUI.MUTED_2))
	_detail_title = _label("", 17, DeadCityUI.TEXT, DeadCityUI.serif_font())
	box.add_child(_detail_title)
	_detail_body = _label("", 10, DeadCityUI.MUTED)
	_detail_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_detail_body)
	box.add_child(_label("预览只示意 FOV / 准星；真实效果以游戏内为准。", 9, DeadCityUI.MUTED_2))
	return box


func _build_footer() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_status = _label("", 10, DeadCityUI.MUTED)
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(_status)
	_dirty_label = _label("已保存", 10, DeadCityUI.MUTED_2)
	row.add_child(_dirty_label)
	var reset_page := Button.new()
	reset_page.text = "本页默认"
	reset_page.custom_minimum_size = Vector2(96, 40)
	DeadCityUI.style_button(reset_page, DeadCityUI.MUTED, false)
	reset_page.pressed.connect(_reset_page)
	row.add_child(reset_page)
	var reset_all := Button.new()
	reset_all.text = "全部默认"
	reset_all.custom_minimum_size = Vector2(96, 40)
	DeadCityUI.style_button(reset_all, DeadCityUI.MUTED, false)
	reset_all.pressed.connect(_reset_all)
	row.add_child(reset_all)
	var cancel := Button.new()
	cancel.text = "取消修改"
	cancel.custom_minimum_size = Vector2(112, 40)
	DeadCityUI.style_button(cancel, DeadCityUI.MUTED, false)
	cancel.pressed.connect(_cancel)
	row.add_child(cancel)
	var apply := Button.new()
	apply.text = "应用设置"
	apply.custom_minimum_size = Vector2(124, 40)
	DeadCityUI.style_button(apply, DeadCityUI.AMBER, true)
	apply.pressed.connect(_apply)
	row.add_child(apply)
	return row


func _select_category(category: String) -> void:
	if not SettingsSchema.CATEGORY_FIELDS.has(category):
		return
	_category = category
	for id in _nav_buttons.keys():
		var button := _nav_buttons[id] as Button
		if button == null:
			continue
		var active: bool = String(id) == category
		button.add_theme_color_override("font_color", DeadCityUI.AMBER if active else DeadCityUI.MUTED)
	_category_title.text = SettingsSchema.category_title(category)
	_category_description.text = _category_description_text(category)
	_clear_content()
	for key in SettingsSchema.category_fields(category):
		_add_field(key)
	var category_fields := SettingsSchema.category_fields(category)
	if not category_fields.is_empty():
		_set_detail(String(category_fields[0]))
	var note := SettingsSchema.category_note(category)
	if not note.is_empty():
		var label := _label(note, 9, DeadCityUI.MUTED_2)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_content.add_child(label)
	_refresh_preview()
	_sync_content_width()
	_update_dirty()


func _category_description_text(category: String) -> String:
	for item in SettingsSchema.CATEGORIES:
		if String(item["id"]) == category:
			return String(item.get("description", ""))
	return ""


func _clear_content() -> void:
	for child in _content.get_children():
		_content.remove_child(child)
		child.queue_free()


func _add_field(key: String) -> void:
	var definition := SettingsSchema.definition(key)
	if definition.is_empty():
		return
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	row.add_child(head)
	head.add_child(_label(String(definition.get("label", key)), 12, DeadCityUI.TEXT))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(spacer)
	if SettingsSchema.KEY_ACTIONS.has(key):
		_key_row(row, head, key)
	elif String(definition.get("type", "")) == "slider":
		_slider_row(row, head, key, definition)
	elif String(definition.get("type", "")) == "select":
		_select_row(row, head, key, definition)
	else:
		_toggle_row(row, head, key, definition)
	_content.add_child(row)


func _slider_row(row: VBoxContainer, head: HBoxContainer, key: String, definition: Dictionary) -> void:
	var value_label := _label(_format_value(key, float(_service.get_value(key))), 11, DeadCityUI.AMBER)
	head.add_child(value_label)
	var slider := HSlider.new()
	slider.min_value = float(definition["min"])
	slider.max_value = float(definition["max"])
	slider.step = float(definition.get("step", 0.01))
	slider.value = float(_service.get_value(key))
	slider.custom_minimum_size = Vector2(0, 22)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.focus_mode = Control.FOCUS_ALL
	slider.add_theme_stylebox_override("focus", DeadCityUI.focus_style(DeadCityUI.AMBER))
	slider.value_changed.connect(func(value: float) -> void:
		_service.set_pending(key, value)
		value_label.text = _format_value(key, value)
		_refresh_preview()
		_update_dirty()
	)
	slider.focus_entered.connect(_set_detail.bind(key))
	slider.mouse_entered.connect(_set_detail.bind(key))
	row.add_child(slider)


func _toggle_row(row: VBoxContainer, head: HBoxContainer, key: String, definition: Dictionary) -> void:
	var toggle := CheckButton.new()
	toggle.button_pressed = bool(_service.get_value(key))
	toggle.focus_mode = Control.FOCUS_ALL
	toggle.add_theme_stylebox_override("focus", DeadCityUI.focus_style(DeadCityUI.AMBER))
	toggle.toggled.connect(func(value: bool) -> void:
		_service.set_pending(key, value)
		_update_dirty()
	)
	toggle.focus_entered.connect(_set_detail.bind(key))
	toggle.mouse_entered.connect(_set_detail.bind(key))
	head.add_child(toggle)
	var hint := _label(String(definition.get("hint", "")), 9, DeadCityUI.MUTED_2)
	row.add_child(hint)


func _select_row(row: VBoxContainer, head: HBoxContainer, key: String, definition: Dictionary) -> void:
	var select := OptionButton.new()
	select.custom_minimum_size = Vector2(190, 30)
	select.focus_mode = Control.FOCUS_ALL
	select.add_theme_stylebox_override("focus", DeadCityUI.focus_style(DeadCityUI.AMBER))
	var options := _options_for(key, definition)
	var current := String(_service.get_value(key))
	var selected_index := 0
	for index in range(options.size()):
		var option: Array = options[index]
		select.add_item(String(option[1]), index)
		select.set_item_metadata(index, String(option[0]))
		if String(option[0]) == current:
			selected_index = index
	select.selected = selected_index
	select.item_selected.connect(func(index: int) -> void:
		_service.set_pending(key, String(select.get_item_metadata(index)))
		_update_dirty()
	)
	select.focus_entered.connect(_set_detail.bind(key))
	select.mouse_entered.connect(_set_detail.bind(key))
	head.add_child(select)
	var hint := _label(String(definition.get("hint", "")), 9, DeadCityUI.MUTED_2)
	row.add_child(hint)


func _key_row(row: VBoxContainer, head: HBoxContainer, action: String) -> void:
	var button := Button.new()
	button.text = _service.key_label(action)
	button.custom_minimum_size = Vector2(190, 30)
	button.focus_mode = Control.FOCUS_ALL
	DeadCityUI.style_button(button, DeadCityUI.AMBER, false)
	button.pressed.connect(_begin_capture.bind(action, button))
	button.focus_entered.connect(_set_detail.bind(action))
	button.mouse_entered.connect(_set_detail.bind(action))
	head.add_child(button)
	row.add_child(_label(String(SettingsSchema.KEY_ACTIONS[action].get("hint", "")), 9, DeadCityUI.MUTED_2))


func _options_for(key: String, definition: Dictionary) -> Array:
	if key != "resolution":
		return definition.get("options", [])
	var values: Array = []
	for size in [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080), Vector2i(2560, 1440)]:
		values.append(["%dx%d" % [size.x, size.y], "%d × %d" % [size.x, size.y]])
	var screen := DisplayServer.screen_get_size()
	var current := String(_service.get_value("resolution"))
	var actual := "%dx%d" % [screen.x, screen.y]
	if not values.any(func(item: Array) -> bool: return item[0] == actual):
		values.append([actual, "%d × %d（当前屏幕）" % [screen.x, screen.y]])
	if not values.any(func(item: Array) -> bool: return item[0] == current):
		values.append([current, current])
	return values


func _format_value(key: String, value: float) -> String:
	var definition := SettingsSchema.definition(key)
	if bool(definition.get("percent", false)):
		return "%d%%" % int(round(value * 100.0))
	var precision := int(definition.get("precision", 0))
	var unit := String(definition.get("unit", ""))
	if precision > 0:
		return ("%." + str(precision) + "f%s") % [value, unit]
	return "%d%s" % [int(round(value)), unit]


func _set_detail(key: String) -> void:
	var definition := SettingsSchema.definition(key)
	if definition.is_empty():
		return
	_detail_title.text = String(definition.get("label", key))
	_detail_body.text = String(definition.get("description", ""))
	_refresh_preview()


func _refresh_preview() -> void:
	if _preview == null or _service == null:
		return
	_preview.set_state(
		float(_service.get_value("fov")),
		String(_service.get_value("crosshair_color")),
		float(_service.get_value("crosshair_size")),
		float(_service.get_value("crosshair_thickness"))
	)


func _update_dirty() -> void:
	if _service == null:
		return
	var dirty: bool = _service.has_pending_changes()
	_dirty_label.text = "未应用修改" if dirty else "已保存"
	_dirty_label.add_theme_color_override("font_color", DeadCityUI.AMBER if dirty else DeadCityUI.MUTED_2)


func _reset_page() -> void:
	_service.reset_category(_category)
	_select_category(_category)
	_status.text = "本页已恢复默认，点击应用后保存。"
	_update_dirty()


func _reset_all() -> void:
	_service.reset_all()
	_select_category(_category)
	_status.text = "全部设置已恢复默认，点击应用后保存。"
	_update_dirty()


func _cancel() -> void:
	_service.cancel()
	_select_category(_category)
	_status.text = "已恢复到上次应用的值。"
	_update_dirty()


func _apply() -> void:
	if not _service.has_pending_changes():
		_status.text = "没有未应用的修改。"
		return
	var display_dirty := false
	for key in _service.pending_keys():
		if key in DISPLAY_KEYS:
			display_dirty = true
			break
	if display_dirty:
		_show_display_confirm()
		return
	_service.apply()
	_update_dirty()
	_status.text = "设置已应用并保存。"


func _show_display_confirm() -> void:
	if _confirm_layer != null:
		return
	_confirm_seconds = 10.0
	_confirm_layer = Control.new()
	_confirm_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_confirm_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_confirm_layer)
	var tint := ColorRect.new()
	tint.color = Color(0, 0, 0, 0.62)
	tint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_confirm_layer.add_child(tint)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_confirm_layer.add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", DeadCityUI.panel_style(Color(0.035, 0.04, 0.042, 0.99), 4, DeadCityUI.AMBER, 1))
	panel.custom_minimum_size = Vector2(460, 190)
	center.add_child(panel)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 10)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 22)
	margin.add_child(body)
	panel.add_child(margin)
	body.add_child(_label("保留显示设置？", 24, DeadCityUI.TEXT, DeadCityUI.serif_font()))
	_confirm_text = _label("", 11, DeadCityUI.MUTED)
	body.add_child(_confirm_text)
	var hint := _label("如果画面异常，等待倒计时结束或点击恢复原设置。", 10, DeadCityUI.MUTED_2)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(hint)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 10)
	body.add_child(actions)
	var keep := Button.new()
	keep.text = "保留设置"
	keep.custom_minimum_size = Vector2(0, 40)
	keep.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	DeadCityUI.style_button(keep, DeadCityUI.AMBER, true)
	keep.pressed.connect(_keep_display)
	actions.add_child(keep)
	var revert := Button.new()
	revert.text = "恢复原设置"
	revert.custom_minimum_size = Vector2(0, 40)
	revert.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	DeadCityUI.style_button(revert, DeadCityUI.MUTED, false)
	revert.pressed.connect(_revert_display)
	actions.add_child(revert)
	_update_confirm_text()
	keep.grab_focus.call_deferred()


func _process(delta: float) -> void:
	if _confirm_layer == null:
		return
	_confirm_seconds -= delta
	_update_confirm_text()
	if _confirm_seconds <= 0.0:
		_revert_display()


func _update_confirm_text() -> void:
	if _confirm_text != null:
		_confirm_text.text = "%d 秒后自动恢复原显示设置。" % int(ceil(maxf(_confirm_seconds, 0.0)))


func _keep_display() -> void:
	_service.apply()
	_close_confirm()
	_status.text = "显示设置已保留并保存。"
	_update_dirty()


func _revert_display() -> void:
	_service.cancel()
	_close_confirm()
	_select_category(_category)
	_status.text = "显示设置已恢复。"
	_update_dirty()


func _close_confirm() -> void:
	if _confirm_layer != null:
		_confirm_layer.queue_free()
		_confirm_layer = null
	_confirm_text = null


func _begin_capture(action: String, button: Button) -> void:
	_capture_action = action
	_capture_button = button
	button.text = "按下新按键…"
	_status.text = "按下键盘或鼠标按键；Esc 取消。冲突键会被拒绝。"


func _end_capture() -> void:
	if _capture_button != null and is_instance_valid(_capture_button) and not _capture_action.is_empty():
		_capture_button.text = _service.key_label(_capture_action)
	_capture_action = ""
	_capture_button = null


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if _confirm_layer != null:
		if event.is_action_pressed("ui_cancel"):
			_revert_display()
			get_viewport().set_input_as_handled()
		return
	if not _capture_action.is_empty():
		if event is InputEventKey:
			var key := event as InputEventKey
			if not key.pressed or key.echo:
				return
			if key.physical_keycode == KEY_ESCAPE or key.keycode == KEY_ESCAPE:
				_end_capture()
				_status.text = "已取消按键捕获。"
				get_viewport().set_input_as_handled()
				return
			_try_bind(event)
		elif event is InputEventMouseButton:
			var mouse := event as InputEventMouseButton
			if mouse.pressed:
				_try_bind(event)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func _try_bind(event: InputEvent) -> void:
	var action := _capture_action
	var encoded := SettingsSchema.string_from_event(event)
	if encoded.is_empty():
		_end_capture()
		_status.text = "这个输入不能用于绑定。"
		return
	var conflict: String = _service.find_key_conflict(action, encoded)
	if not conflict.is_empty():
		_end_capture()
		_status.text = "冲突：该按键已用于「%s」。" % SettingsSchema.KEY_ACTIONS[conflict].get("label", conflict)
		return
	if not _service.set_pending_key(action, event):
		_end_capture()
		_status.text = "绑定失败。"
		return
	_capture_button.text = _service.key_label(action)
	_end_capture()
	_status.text = "已绑定「%s」为 %s，点击应用后保存。" % [
		SettingsSchema.KEY_ACTIONS[action].get("label", action),
		SettingsSchema.event_label(encoded)
	]
	_set_detail(action)
	_update_dirty()


func _label(text: String, size: int, color: Color, font: Font = null) -> Label:
	return DeadCityUI.make_label(text, size, color, font if font != null else DeadCityUI.display_font())


func _line() -> Control:
	var line := ColorRect.new()
	line.color = Color(0.85, 0.82, 0.76, 0.16)
	line.custom_minimum_size = Vector2(0, 1)
	return line
