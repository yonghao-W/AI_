class_name DeadCityUI
extends RefCounted

const BG := Color("#0a1017")
const PANEL := Color("#121b25")
const PANEL_SOFT := Color("#18242f")
const LINE := Color("#2b3b49")
const TEXT := Color("#e7eef2")
const MUTED := Color("#8d9caa")
const CYAN := Color("#59d8c8")
const AMBER := Color("#ffcb66")
const RED := Color("#ff5b5b")
const GREEN := Color("#83d66f")
const VIOLET := Color("#b997ff")
const CORAL := Color("#ff8d6b")
const ZOMBIE := Color("#83b35a")

const PLAYER_COLORS := [
	Color("#58d6d0"), Color("#ffc65c"), Color("#b498ff"), Color("#ff8b6f"),
]


static func display_font() -> SystemFont:
	var font := SystemFont.new()
	font.font_names = PackedStringArray([
		"Microsoft YaHei UI", "Microsoft YaHei", "Noto Sans CJK SC",
		"Source Han Sans SC", "Arial",
	])
	font.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_AUTO
	return font


static func panel_style(color: Color = PANEL, radius: int = 14, border_color: Color = Color.TRANSPARENT, border_width: int = 0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.content_margin_left = 18.0
	style.content_margin_right = 18.0
	style.content_margin_top = 14.0
	style.content_margin_bottom = 14.0
	if border_width > 0:
		style.border_color = border_color
		style.set_border_width_all(border_width)
	return style


static func make_theme() -> Theme:
	var theme := Theme.new()
	var font := display_font()
	theme.default_font = font
	theme.default_font_size = 18

	theme.set_stylebox("normal", "Button", panel_style(Color("#1a2833"), 10, Color("#304553"), 1))
	theme.set_stylebox("hover", "Button", panel_style(Color("#223847"), 10, Color("#4a807a"), 1))
	theme.set_stylebox("pressed", "Button", panel_style(Color("#163034"), 10, Color("#59d8c8"), 2))
	theme.set_stylebox("disabled", "Button", panel_style(Color("#141c24"), 10, Color("#25313b"), 1))
	theme.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	theme.set_color("font_color", "Button", TEXT)
	theme.set_color("font_hover_color", "Button", Color("#ffffff"))
	theme.set_color("font_pressed_color", "Button", CYAN)
	theme.set_color("font_disabled_color", "Button", Color("#5b6874"))
	theme.set_font_size("font_size", "Button", 18)

	theme.set_stylebox("normal", "LineEdit", panel_style(Color("#0d151d"), 8, Color("#2d404d"), 1))
	theme.set_stylebox("focus", "LineEdit", panel_style(Color("#0d151d"), 8, CYAN, 1))
	theme.set_color("font_color", "LineEdit", TEXT)
	theme.set_color("font_placeholder_color", "LineEdit", Color("#667682"))
	theme.set_color("caret_color", "LineEdit", CYAN)
	theme.set_color("selection_color", "LineEdit", Color("#2c5b5c"))
	theme.set_font_size("font_size", "LineEdit", 17)

	theme.set_color("font_color", "Label", TEXT)
	theme.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0.35))

	theme.set_stylebox("panel", "PanelContainer", panel_style(PANEL, 16, LINE, 1))
	theme.set_stylebox("background", "ProgressBar", panel_style(Color("#0c141b"), 4))
	theme.set_stylebox("fill", "ProgressBar", panel_style(Color("#d94848"), 4))
	return theme


static func style_button(button: Button, accent: Color, filled: bool = false) -> void:
	var base := Color("#172630") if not filled else accent.darkened(0.55)
	var hover := Color("#213a46") if not filled else accent.darkened(0.35)
	var pressed := accent.darkened(0.62)
	button.add_theme_stylebox_override("normal", panel_style(base, 10, accent.darkened(0.25), 1))
	button.add_theme_stylebox_override("hover", panel_style(hover, 10, accent, 1))
	button.add_theme_stylebox_override("pressed", panel_style(pressed, 10, accent, 2))
	button.add_theme_stylebox_override("disabled", panel_style(Color("#111920"), 10, Color("#24303a"), 1))
	button.add_theme_color_override("font_color", TEXT)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", accent.lightened(0.35))
