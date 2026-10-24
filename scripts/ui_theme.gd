class_name DeadCityUI
extends RefCounted
## 统一视觉 token。菜单、HUD、大厅、整备、情报、暂停共用同一套语义色与控件状态。
## 颜色只表达语义，不承担唯一编码：所有状态同时有文字/形状。

const BG := Color("#08090a")
const PANEL := Color("#101315")
const PANEL_SOFT := Color("#171b1d")
const PANEL_RAISED := Color("#1d2123")
const LINE := Color("#2b2f30")
const LINE_SOFT := Color("#202425")
const TEXT := Color("#f3ede3")
const MUTED := Color("#b6aa99")
const MUTED_2 := Color("#968b7d")
const CYAN := Color("#7fc3ba")
const AMBER := Color("#e6a75e")
const AMBER_DIM := Color("#8f6b3f")
const RED := Color("#e06b5a")
const GREEN := Color("#9bc284")
const VIOLET := Color("#b9a6d9")
const CORAL := Color("#e08a6f")
const ZOMBIE := Color("#9aad72")

const PLAYER_COLORS := [
	Color("#7fc3ba"), Color("#e6a75e"), Color("#b9a6d9"), Color("#e08a6f"),
]

const FONT_UI := ["Microsoft YaHei UI", "Microsoft YaHei", "Noto Sans CJK SC", "Source Han Sans SC", "Arial"]
const FONT_SERIF := ["Source Han Serif SC", "Noto Serif CJK SC", "STSong", "SimSun", "Songti SC", "Georgia"]
const FONT_MONO := ["Cascadia Mono", "Consolas", "Noto Sans Mono CJK SC", "monospace"]


static func display_font() -> SystemFont:
	return _system_font(FONT_UI)


static func serif_font() -> SystemFont:
	return _system_font(FONT_SERIF)


static func mono_font() -> SystemFont:
	return _system_font(FONT_MONO)


static func _system_font(names: Array) -> SystemFont:
	var font := SystemFont.new()
	font.font_names = PackedStringArray(names)
	font.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_AUTO
	return font


static func high_contrast() -> bool:
	var loop := Engine.get_main_loop()
	if loop is SceneTree:
		var node := (loop as SceneTree).root.get_node_or_null("UISettings")
		if node != null:
			return bool(node.get("high_contrast"))
	return false


static func reduced_motion() -> bool:
	var loop := Engine.get_main_loop()
	if loop is SceneTree:
		var node := (loop as SceneTree).root.get_node_or_null("UISettings")
		if node != null:
			return bool(node.get("reduced_motion"))
	return false


static func text_color(base: Color = TEXT) -> Color:
	return base.lightened(0.12) if high_contrast() else base


static func muted_color() -> Color:
	return MUTED if not high_contrast() else Color("#d3cabd")


static func panel_style(color: Color = PANEL, radius: int = 6, border_color: Color = Color.TRANSPARENT, border_width: int = 0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.content_margin_left = 16.0
	style.content_margin_right = 16.0
	style.content_margin_top = 12.0
	style.content_margin_bottom = 12.0
	if border_width > 0:
		style.border_color = border_color
		style.set_border_width_all(border_width)
	return style


static func meter_style(color: Color, radius: int = 0) -> StyleBoxFlat:
	## 细条状态条专用：普通 panel_style 的 12/16 内边距会把 2–3px 的条撑到 24px。
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.content_margin_left = 0.0
	style.content_margin_right = 0.0
	style.content_margin_top = 0.0
	style.content_margin_bottom = 0.0
	return style


static func hairline(color: Color = LINE) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.content_margin_top = 0.0
	style.content_margin_bottom = 0.0
	return style


static func focus_style(accent: Color = AMBER) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	style.border_color = accent
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.draw_center = false
	return style


static func make_theme() -> Theme:
	var theme := Theme.new()
	theme.default_font = display_font()
	theme.default_font_size = 16

	var normal := panel_style(Color(0.07, 0.08, 0.085, 0.92), 6, Color(0.25, 0.26, 0.25, 0.8), 1)
	var hover := panel_style(Color(0.10, 0.11, 0.115, 0.96), 6, Color(AMBER.r, AMBER.g, AMBER.b, 0.75), 1)
	var pressed := panel_style(Color(0.12, 0.115, 0.10, 0.98), 6, AMBER, 1)
	var disabled := panel_style(Color(0.06, 0.065, 0.07, 0.55), 6, Color(0.18, 0.19, 0.19, 0.7), 1)
	theme.set_stylebox("normal", "Button", normal)
	theme.set_stylebox("hover", "Button", hover)
	theme.set_stylebox("pressed", "Button", pressed)
	theme.set_stylebox("disabled", "Button", disabled)
	theme.set_stylebox("focus", "Button", focus_style())
	theme.set_color("font_color", "Button", TEXT)
	theme.set_color("font_hover_color", "Button", Color.WHITE)
	theme.set_color("font_pressed_color", "Button", AMBER)
	theme.set_color("font_disabled_color", "Button", MUTED_2)
	theme.set_font_size("font_size", "Button", 15)

	var edit := panel_style(Color(0.045, 0.05, 0.052, 0.96), 4, Color(0.28, 0.29, 0.28, 0.9), 1)
	var edit_focus := panel_style(Color(0.045, 0.05, 0.052, 0.98), 4, AMBER, 1)
	theme.set_stylebox("normal", "LineEdit", edit)
	theme.set_stylebox("focus", "LineEdit", edit_focus)
	theme.set_color("font_color", "LineEdit", TEXT)
	theme.set_color("font_placeholder_color", "LineEdit", MUTED_2)
	theme.set_color("caret_color", "LineEdit", AMBER)
	theme.set_color("selection_color", "LineEdit", Color(0.35, 0.28, 0.18, 0.7))
	theme.set_font_size("font_size", "LineEdit", 15)

	theme.set_color("font_color", "Label", TEXT)
	theme.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0.35))

	var panel := panel_style(Color(0.06, 0.07, 0.075, 0.94), 6, Color(0.24, 0.25, 0.24, 0.7), 1)
	theme.set_stylebox("panel", "PanelContainer", panel)
	theme.set_stylebox("background", "ProgressBar", meter_style(Color(0.09, 0.10, 0.10, 0.9), 2))
	theme.set_stylebox("fill", "ProgressBar", meter_style(AMBER, 2))

	theme.set_stylebox("normal", "CheckBox", StyleBoxEmpty.new())
	theme.set_stylebox("hover", "CheckBox", StyleBoxEmpty.new())
	theme.set_stylebox("pressed", "CheckBox", StyleBoxEmpty.new())
	theme.set_stylebox("focus", "CheckBox", focus_style())
	theme.set_color("font_color", "CheckBox", TEXT)
	theme.set_color("font_hover_color", "CheckBox", Color.WHITE)

	theme.set_stylebox("slider", "HSlider", panel_style(Color(0.12, 0.13, 0.13, 1), 2))
	theme.set_stylebox("grabber_area", "HSlider", panel_style(AMBER_DIM, 2))
	theme.set_stylebox("grabber_area_highlight", "HSlider", panel_style(AMBER, 2))
	return theme


static func style_button(button: Button, accent: Color, filled: bool = false) -> void:
	var base := Color(0.075, 0.085, 0.09, 0.94) if not filled else Color(accent.r, accent.g, accent.b, 0.16)
	var hover := Color(0.11, 0.12, 0.125, 0.98) if not filled else Color(accent.r, accent.g, accent.b, 0.25)
	var pressed := Color(accent.r, accent.g, accent.b, 0.28) if filled else Color(0.13, 0.125, 0.115, 1)
	button.add_theme_stylebox_override("normal", panel_style(base, 6, Color(accent.r, accent.g, accent.b, 0.55 if filled else 0.42), 1))
	button.add_theme_stylebox_override("hover", panel_style(hover, 6, accent, 1))
	button.add_theme_stylebox_override("pressed", panel_style(pressed, 6, accent, 1))
	button.add_theme_stylebox_override("disabled", panel_style(Color(0.06, 0.065, 0.07, 0.6), 6, Color(0.2, 0.2, 0.2, 0.6), 1))
	button.add_theme_stylebox_override("focus", focus_style(accent))
	button.add_theme_color_override("font_color", TEXT)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", accent.lightened(0.2))
	button.add_theme_color_override("font_disabled_color", MUTED_2)


static func style_ghost_button(button: Button, accent: Color = AMBER) -> void:
	var empty := StyleBoxEmpty.new()
	button.add_theme_stylebox_override("normal", empty)
	button.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("disabled", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("focus", focus_style(accent))
	button.add_theme_color_override("font_color", TEXT)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", accent)
	button.add_theme_color_override("font_disabled_color", MUTED_2)


static func style_label(label: Label, size: int, color: Color = TEXT) -> void:
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)


static func make_label(text_value: String, size: int, color: Color = TEXT, font: Font = null) -> Label:
	var label := Label.new()
	label.text = text_value
	style_label(label, size, color)
	if font != null:
		label.add_theme_font_override("font", font)
	return label
