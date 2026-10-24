class_name MenuNavItem
extends Button
## 主菜单根导航项：无大卡片、无粗边框，只用位置/亮度/琥珀括号表达焦点。

signal highlighted(index: int)

var item_index := 0
var primary := false
var minor := false
var subtitle := "":
	set(value):
		subtitle = value
		if _sub != null:
			_sub.text = value
			_sub.visible = not value.is_empty()
			_queue_layout()
var _name_label: Label
var _sub: Label
var _chev: Label
var _selected := false
var _tween: Tween
var _pending_name := ""


func configure(index: int, name_text: String, sub_text: String = "", is_primary: bool = false, is_minor: bool = false) -> void:
	item_index = index
	primary = is_primary
	minor = is_minor
	_pending_name = name_text
	if _name_label != null:
		_name_label.text = name_text
	subtitle = sub_text
	_queue_layout()


func _ready() -> void:
	flat = true
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	add_theme_stylebox_override("disabled", StyleBoxEmpty.new())
	_name_label = DeadCityUI.make_label(_pending_name, 21, DeadCityUI.MUTED, DeadCityUI.display_font())
	_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_name_label)
	_chev = DeadCityUI.make_label("›", 22, DeadCityUI.AMBER, DeadCityUI.display_font())
	_chev.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chev.modulate.a = 0.0
	add_child(_chev)
	_sub = DeadCityUI.make_label(subtitle, 11, DeadCityUI.MUTED_2, DeadCityUI.display_font())
	_sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sub.visible = not subtitle.is_empty()
	add_child(_sub)
	resized.connect(_queue_layout)
	mouse_entered.connect(_on_hover)
	focus_entered.connect(_on_focus)
	_apply_enabled()
	_queue_layout()


func _queue_layout() -> void:
	call_deferred("_layout_labels")


func _layout_labels() -> void:
	if _name_label == null:
		return
	var size_value := 25 if primary else (18 if minor else 21)
	_name_label.add_theme_font_size_override("font_size", size_value)
	var top := 8.0 if primary else 6.0
	_name_label.position = Vector2(5.0 if _selected else 0.0, top)
	_name_label.size = Vector2(size.x - 40.0, 32.0)
	var text_width := _name_label.get_theme_font("font").get_string_size(
		_name_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_value
	).x
	_chev.position = Vector2((5.0 if _selected else 0.0) + text_width + 12.0, top + 1.0)
	_chev.size = Vector2(28.0, 28.0)
	_chev.add_theme_color_override("font_color", DeadCityUI.AMBER if not disabled else DeadCityUI.MUTED_2)
	_sub.position = Vector2(0.0, top + size_value + 8.0)
	_sub.size = Vector2(maxf(0.0, size.x - 24.0), 22.0)


func set_selected(value: bool) -> void:
	if _selected == value:
		return
	_selected = value
	if _tween != null and _tween.is_valid():
		_tween.kill()
	var reduced := DeadCityUI.reduced_motion()
	var duration := 0.001 if reduced else 0.16
	_name_label.add_theme_color_override("font_color", Color.WHITE if value else (DeadCityUI.MUTED))
	_tween = create_tween()
	if not reduced:
		_tween.set_parallel(true)
	_tween.tween_property(_name_label, "position:x", 5.0 if value else 0.0, duration)
	_tween.tween_property(_chev, "position:x", (5.0 if value else 0.0) + _text_width() + 12.0, duration)
	_tween.tween_property(_chev, "modulate:a", 1.0 if value else 0.0, duration)
	_tween.tween_property(_sub, "modulate:a", 1.0 if value else 0.55, duration)
	queue_redraw()


func _text_width() -> float:
	if _name_label == null:
		return 0.0
	var size_value := 25 if primary else (18 if minor else 21)
	return _name_label.get_theme_font("font").get_string_size(
		_name_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_value
	).x


func is_selected() -> bool:
	return _selected


func set_enabled_visual(value: bool) -> void:
	disabled = not value
	_apply_enabled()


func _apply_enabled() -> void:
	modulate.a = 1.0 if not disabled else 0.72
	if _sub != null:
		_sub.add_theme_color_override("font_color", DeadCityUI.MUTED_2 if not disabled else Color(0.55, 0.5, 0.45))


func _on_hover() -> void:
	if not disabled:
		highlighted.emit(item_index)


func _on_focus() -> void:
	if not disabled:
		highlighted.emit(item_index)


func _draw() -> void:
	if not _selected:
		return
	var color := DeadCityUI.AMBER if not disabled else DeadCityUI.MUTED_2
	var top := 8.0 if primary else 7.0
	var bottom := size.y - (8.0 if primary else 7.0)
	draw_line(Vector2(-18.0, top), Vector2(-7.0, top), color, 1.5)
	draw_line(Vector2(-18.0, top), Vector2(-18.0, bottom), color, 1.5)
	draw_line(Vector2(-18.0, bottom), Vector2(-7.0, bottom), color, 1.5)
