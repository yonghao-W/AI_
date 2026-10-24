class_name GameHUD
extends Control

signal resume_requested
signal lobby_requested
signal card_picked(index: int)
signal draw_cancelled
signal weapon_selected(weapon_id: String)

var _game_layer: Control
var _roster_panel: Control
var _roster_box: VBoxContainer
var _roster_count: Label
var _roster_rows: Dictionary = {}
var _roster_ids_key := ""
var _wave_label: Label
var _wave_sub: Label
var _score_label: Label
var _minimap: DeadMiniMap
var _seed_label: Label
var _map_chip: Label
var _health_label: Label
var _health_bar: ProgressBar
var _health_state: Label
var _conn_label: Label
var _ammo_mag: Label
var _ammo_reserve: Label
var _ammo_slash: Label
var _ammo_melee := false
var _ammo_state: Label
var _reload_bar: ProgressBar
var _crosshair: DeadCrosshair
var _vignette: DamageVignette
var _banner_box: VBoxContainer
var _banner_title: Label
var _banner_sub: Label
var _kill_feed: VBoxContainer
var _death_overlay: Control
var _death_sub: Label
var _gameover_overlay: Control
var _gameover_panel: PanelContainer
var _gameover_tag: Label
var _gameover_title: Label
var _gameover_sub: Label
var _gameover_stats: Label
var _gameover_button: Button
var _pause_overlay: Control
var _pause_note: Label
var _loading_overlay: Control
var _loading_label: Label
var _mission_panel: Control
var _mission_progress: Label
var _mission_pips: Array[ColorRect] = []
var _mission_hint: Label
var _mission_zone: Label
var _mission_tokens: Label
var _mission_upgrades: Label
var _interaction_panel: Control
var _interaction_label: Label
var _draw_overlay: Control
var _draw_cards_box: HBoxContainer
var _draw_footer: Label
var _weapon_title: Label
var _weapon_mode: Label
var _weapon_strip: HBoxContainer
var _weapon_slots: Dictionary = {}
var _weapon_profile: Dictionary = {}
var _loadout: Array = []
var _team_upgrades: Dictionary = {}
var _intel_overlay: Control
var _intel_body: HBoxContainer
var _intel_data: Dictionary = {}
var _intel_open := false
var _backpack_overlay: Control
var _backpack_body: HBoxContainer
var _backpack_footer: Label
var _backpack_open := false
var _down_active := false
var _down_left := 0.0
var _game_over := false
var _paused := false
var _loading_time := 0.0
var _last_health := 100.0
var _last_phase := ""
var _last_wave := 0
var _banner_tween: Tween
var _strip_tween: Tween
var _health_pulse: Tween
var _carrying_core := false
var _carry_preview := false
var _last_mag := 0
var _last_reloading := false
var _pause_resume: Button


func _ready() -> void:
	theme = DeadCityUI.make_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	resized.connect(_apply_hud_scale)
	_apply_hud_scale()
	var settings := get_node_or_null("/root/UISettings")
	if settings != null and settings.has_signal("changed"):
		settings.changed.connect(func(_key: String) -> void: _apply_hud_scale())


func _build() -> void:
	_vignette = DamageVignette.new()
	add_child(_vignette)
	_vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_game_layer = Control.new()
	_game_layer.name = "HUDContent"
	_game_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_game_layer.set_anchors_preset(Control.PRESET_TOP_LEFT)
	add_child(_game_layer)
	_build_roster()
	_build_mission_panel()
	_build_wave_panel()
	_build_minimap()
	_build_health()
	_build_ammo()
	_build_weapon_strip()
	_crosshair = DeadCrosshair.new()
	_crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_game_layer.add_child(_crosshair)
	_center_control(_crosshair, Vector2(56, 56))
	_build_interaction()
	_build_kill_feed()
	_build_banner()
	_build_death_overlay()
	_build_gameover_overlay()
	_build_pause_overlay()
	_build_loading_overlay()
	_build_draw_overlay()
	_build_intel_overlay()
	_build_backpack_overlay()
	_roster_panel.visible = true
	_mission_panel.visible = true
	_death_overlay.visible = false
	_gameover_overlay.visible = false
	_pause_overlay.visible = false
	_loading_overlay.visible = false
	_draw_overlay.visible = false
	_intel_overlay.visible = false
	_backpack_overlay.visible = false


func _apply_hud_scale() -> void:
	if _game_layer == null:
		return
	var value := 1.0
	var settings := get_node_or_null("/root/UISettings")
	if settings != null:
		value = float(settings.hud_scale)
	value = clampf(value, 0.85, 1.2)
	_game_layer.scale = Vector2(value, value)
	_game_layer.size = size / value
	_apply_accessibility()


func _apply_accessibility() -> void:
	var contrast := DeadCityUI.high_contrast()
	var shadow := Color(0, 0, 0, 0.9 if contrast else 0.5)
	for label in _game_layer.find_children("*", "Label", true, false):
		var item := label as Label
		if item != null:
			item.add_theme_color_override("font_shadow_color", shadow)
			item.add_theme_constant_override("shadow_offset_x", 1)
			item.add_theme_constant_override("shadow_offset_y", 1)
			# 高对比度：给所有 HUD 文字加 3px 黑色描边，保证动态场景前的最低可读性。
			item.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.92))
			item.add_theme_constant_override("outline_size", 3 if contrast else 0)


func _build_roster() -> void:
	_roster_panel = VBoxContainer.new()
	_roster_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_roster_panel.add_theme_constant_override("separation", 4)
	_game_layer.add_child(_roster_panel)
	_place(_roster_panel, Rect2(28, 146, 268, 0))
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	_roster_panel.add_child(top)
	top.add_child(_label("小队", 9, DeadCityUI.MUTED_2))
	var top_spacer := Control.new()
	top_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(top_spacer)
	_roster_count = _label("1 / 4", 9, DeadCityUI.MUTED_2)
	top.add_child(_roster_count)
	_roster_box = VBoxContainer.new()
	_roster_box.add_theme_constant_override("separation", 3)
	_roster_panel.add_child(_roster_box)
	_roster_panel.visible = false


func _build_mission_panel() -> void:
	_mission_panel = VBoxContainer.new()
	_mission_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mission_panel.add_theme_constant_override("separation", 3)
	_game_layer.add_child(_mission_panel)
	_place(_mission_panel, Rect2(28, 22, 300, 0))
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	_mission_panel.add_child(top)
	var bar := ColorRect.new()
	bar.color = DeadCityUI.AMBER
	bar.custom_minimum_size = Vector2(2, 15)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(bar)
	top.add_child(_label("核心回收", 10, DeadCityUI.MUTED))
	_mission_progress = _label("0 / 3", 15, DeadCityUI.AMBER)
	top.add_child(_mission_progress)
	var top_spacer := Control.new()
	top_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(top_spacer)
	_mission_tokens = _label("抽卡券 ×0", 9, DeadCityUI.AMBER)
	_mission_tokens.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(_mission_tokens)
	_mission_zone = _label("基地安全区", 10, DeadCityUI.CYAN)
	_mission_panel.add_child(_mission_zone)
	var pips := HBoxContainer.new()
	pips.add_theme_constant_override("separation", 4)
	_mission_panel.add_child(pips)
	for i in range(3):
		var pip := ColorRect.new()
		pip.color = Color(0.3, 0.29, 0.26, 0.6)
		pip.custom_minimum_size = Vector2(54, 2)
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pips.add_child(pip)
		_mission_pips.append(pip)
	_mission_hint = _label("沿市中心公园坡道下到核心储藏层 B1", 10, Color(0.72, 0.78, 0.76, 0.9))
	_mission_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_mission_hint.custom_minimum_size = Vector2(286, 0)
	_mission_hint.max_lines_visible = 2
	_mission_panel.add_child(_mission_hint)
	_mission_upgrades = _label("", 9, Color(0.5, 0.62, 0.63))
	_mission_upgrades.visible = false
	_mission_panel.add_child(_mission_upgrades)


func _build_interaction() -> void:
	_interaction_panel = Control.new()
	_interaction_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_game_layer.add_child(_interaction_panel)
	_place(_interaction_panel, Rect2(-240, -124, 480, 24), 0.5, 1.0)
	_interaction_label = _label("", 12, DeadCityUI.AMBER)
	_interaction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_interaction_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	_interaction_label.add_theme_constant_override("shadow_offset_y", 2)
	_interaction_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_interaction_panel.add_child(_interaction_label)
	_interaction_panel.visible = false


func _build_wave_panel() -> void:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 9)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	_game_layer.add_child(row)
	_place(row, Rect2(-260, 18, 520, 22), 0.5, 0.0)
	_wave_label = _label("第 1 波", 12, DeadCityUI.TEXT)
	row.add_child(_wave_label)
	var dot_a := _label("·", 10, Color(0.6, 0.56, 0.5, 0.7))
	row.add_child(dot_a)
	_wave_sub = _label("部署中", 10, DeadCityUI.MUTED)
	row.add_child(_wave_sub)
	var dot_b := _label("·", 10, Color(0.6, 0.56, 0.5, 0.7))
	row.add_child(dot_b)
	_score_label = _label("得分 0", 10, Color(0.62, 0.68, 0.66, 0.9))
	row.add_child(_score_label)


func _build_minimap() -> void:
	_minimap = DeadMiniMap.new()
	_minimap.custom_minimum_size = Vector2(158, 158)
	_minimap.size = Vector2(158, 158)
	_minimap.modulate = Color(1, 1, 1, 0.92)
	_game_layer.add_child(_minimap)
	_place(_minimap, Rect2(-186, 20, 158, 158), 1.0, 0.0)
	_seed_label = _label("", 9, Color(0.5, 0.62, 0.63))
	_seed_label.visible = false
	_game_layer.add_child(_seed_label)
	_map_chip = _label("", 9, Color(0.44, 0.58, 0.58))
	_map_chip.visible = false
	_game_layer.add_child(_map_chip)


func _build_health() -> void:
	var holder := VBoxContainer.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_theme_constant_override("separation", 2)
	_game_layer.add_child(holder)
	_place(holder, Rect2(30, -86, 248, 66), 0.0, 1.0)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	holder.add_child(top)
	top.add_child(_label("生命", 9, DeadCityUI.MUTED_2))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)
	_health_state = _label("稳定", 9, DeadCityUI.GREEN)
	top.add_child(_health_state)
	var value_row := HBoxContainer.new()
	value_row.add_theme_constant_override("separation", 4)
	holder.add_child(value_row)
	_health_label = _label("100", 26, DeadCityUI.TEXT)
	value_row.add_child(_health_label)
	var max_label := _label("/ 100", 10, Color(0.55, 0.6, 0.58, 0.85))
	max_label.size_flags_vertical = Control.SIZE_SHRINK_END
	value_row.add_child(max_label)
	var value_spacer := Control.new()
	value_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value_row.add_child(value_spacer)
	_conn_label = _label("单人演练 · 本地权威", 8, Color(0.48, 0.56, 0.56, 0.75))
	_conn_label.size_flags_vertical = Control.SIZE_SHRINK_END
	value_row.add_child(_conn_label)
	_health_bar = ProgressBar.new()
	_health_bar.min_value = 0.0
	_health_bar.max_value = 100.0
	_health_bar.value = 100.0
	_health_bar.show_percentage = false
	_health_bar.custom_minimum_size = Vector2(220, 3)
	_health_bar.add_theme_stylebox_override("background", DeadCityUI.meter_style(Color(0.16, 0.17, 0.16, 0.65), 0))
	_health_bar.add_theme_stylebox_override("fill", DeadCityUI.meter_style(DeadCityUI.GREEN, 0))
	holder.add_child(_health_bar)


func _build_ammo() -> void:
	var holder := VBoxContainer.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_theme_constant_override("separation", 1)
	holder.alignment = BoxContainer.ALIGNMENT_END
	_game_layer.add_child(holder)
	_place(holder, Rect2(-298, -92, 268, 72), 1.0, 1.0)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	holder.add_child(top)
	var title_spacer := Control.new()
	title_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title_spacer)
	_weapon_mode = _label("全自动", 9, DeadCityUI.AMBER)
	top.add_child(_weapon_mode)
	var ammo_row := HBoxContainer.new()
	ammo_row.add_theme_constant_override("separation", 5)
	ammo_row.alignment = BoxContainer.ALIGNMENT_END
	holder.add_child(ammo_row)
	var ammo_spacer := Control.new()
	ammo_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ammo_row.add_child(ammo_spacer)
	_ammo_mag = _label("30", 30, DeadCityUI.TEXT)
	ammo_row.add_child(_ammo_mag)
	_ammo_slash = _label("/", 16, Color(0.5, 0.55, 0.53, 0.8))
	_ammo_slash.size_flags_vertical = Control.SIZE_SHRINK_END
	ammo_row.add_child(_ammo_slash)
	_ammo_reserve = _label("90", 15, Color(0.62, 0.66, 0.62, 0.9))
	_ammo_reserve.size_flags_vertical = Control.SIZE_SHRINK_END
	ammo_row.add_child(_ammo_reserve)
	var state_row := HBoxContainer.new()
	state_row.add_theme_constant_override("separation", 8)
	state_row.alignment = BoxContainer.ALIGNMENT_END
	holder.add_child(state_row)
	_weapon_title = _label("VX-9 冲锋枪", 9, Color(0.66, 0.68, 0.64, 0.9))
	state_row.add_child(_weapon_title)
	var state_spacer := Control.new()
	state_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	state_row.add_child(state_spacer)
	_ammo_state = _label("就绪", 10, DeadCityUI.GREEN)
	state_row.add_child(_ammo_state)
	_reload_bar = ProgressBar.new()
	_reload_bar.min_value = 0.0
	_reload_bar.max_value = 100.0
	_reload_bar.value = 0.0
	_reload_bar.show_percentage = false
	_reload_bar.custom_minimum_size = Vector2(190, 2)
	_reload_bar.add_theme_stylebox_override("background", DeadCityUI.meter_style(Color(0.2, 0.2, 0.18, 0.55), 0))
	_reload_bar.add_theme_stylebox_override("fill", DeadCityUI.meter_style(DeadCityUI.AMBER, 0))
	_reload_bar.visible = false
	holder.add_child(_reload_bar)


func _build_weapon_strip() -> void:
	_weapon_strip = HBoxContainer.new()
	_weapon_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_weapon_strip.add_theme_constant_override("separation", 16)
	_weapon_strip.alignment = BoxContainer.ALIGNMENT_END
	_game_layer.add_child(_weapon_strip)
	_place(_weapon_strip, Rect2(-298, -168, 268, 22), 1.0, 1.0)
	_weapon_strip.modulate = Color(1, 1, 1, 0)


func _refresh_weapon_strip() -> void:
	if _weapon_strip == null:
		return
	for child in _weapon_strip.get_children():
		_weapon_strip.remove_child(child)
		child.queue_free()
	_weapon_slots.clear()
	var active_id := String(_weapon_profile.get("id", ""))
	for i in range(WeaponCatalog.MAX_CARRY):
		var entry: Dictionary = _loadout[i] if i < _loadout.size() and _loadout[i] is Dictionary else {}
		var id := String(entry.get("id", ""))
		var has := not id.is_empty()
		var active := has and id == active_id
		var accent := WeaponCatalog.accent(id) if has else Color(0.42, 0.4, 0.36)
		var slot := HBoxContainer.new()
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_theme_constant_override("separation", 5)
		_weapon_strip.add_child(slot)
		var number := _label(str(i + 1), 9, accent if active else DeadCityUI.MUTED_2)
		slot.add_child(number)
		var short_label := _label(WeaponCatalog.short_name(id) if has else "空槽", 10, DeadCityUI.TEXT if active else DeadCityUI.MUTED)
		short_label.add_theme_font_size_override("font_size", 10)
		slot.add_child(short_label)
		if has and WeaponCatalog.is_melee(id):
			slot.add_child(_label("近战", 8, accent))
		_weapon_slots[i] = slot


func set_weapon_strip(loadout: Array, profile: Dictionary) -> void:
	_loadout = loadout.duplicate(true)
	_weapon_profile = profile.duplicate(true)
	if _weapon_title != null:
		_weapon_title.text = String(profile.get("name", "未知武器"))
	if _weapon_mode != null:
		_weapon_mode.text = String(profile.get("tag", ""))
		_weapon_mode.add_theme_color_override("font_color", WeaponCatalog.accent(String(profile.get("id", "smg"))))
	_refresh_weapon_strip()
	_flash_weapon_strip()


func _flash_weapon_strip() -> void:
	if _weapon_strip == null:
		return
	if _strip_tween != null and _strip_tween.is_valid():
		_strip_tween.kill()
	_weapon_strip.modulate = Color(1, 1, 1, 1)
	if DeadCityUI.reduced_motion():
		_strip_tween = create_tween()
		_strip_tween.tween_interval(1.8)
		_strip_tween.tween_property(_weapon_strip, "modulate:a", 0.0, 0.2)
		return
	_strip_tween = create_tween()
	_strip_tween.tween_property(_weapon_strip, "position:y", _weapon_strip.position.y - 6.0, 0.16).from_current().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_strip_tween.tween_interval(1.5)
	_strip_tween.tween_property(_weapon_strip, "modulate:a", 0.0, 0.35)


func _place(control: Control, rect: Rect2, anchor_x: float = 0.0, anchor_y: float = 0.0) -> void:
	control.anchor_left = anchor_x
	control.anchor_right = anchor_x
	control.anchor_top = anchor_y
	control.anchor_bottom = anchor_y
	control.offset_left = rect.position.x
	control.offset_top = rect.position.y
	control.offset_right = rect.position.x + rect.size.x
	control.offset_bottom = rect.position.y + rect.size.y


func _center_control(control: Control, control_size: Vector2) -> void:
	control.anchor_left = 0.5
	control.anchor_right = 0.5
	control.anchor_top = 0.5
	control.anchor_bottom = 0.5
	control.offset_left = -control_size.x * 0.5
	control.offset_right = control_size.x * 0.5
	control.offset_top = -control_size.y * 0.5
	control.offset_bottom = control_size.y * 0.5


func _label(text: String, font_size: int, color: Color, font: Font = null) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	if font != null:
		label.add_theme_font_override("font", font)
	return label


func _build_kill_feed() -> void:
	_kill_feed = VBoxContainer.new()
	_kill_feed.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_kill_feed.add_theme_constant_override("separation", 3)
	_kill_feed.alignment = BoxContainer.ALIGNMENT_BEGIN
	_game_layer.add_child(_kill_feed)
	_place(_kill_feed, Rect2(-330, 192, 300, 132), 1.0, 0.0)


func _build_banner() -> void:
	_banner_box = VBoxContainer.new()
	_banner_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner_box.add_theme_constant_override("separation", 1)
	_banner_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_banner_box.modulate = Color(1, 1, 1, 0)
	_game_layer.add_child(_banner_box)
	_place(_banner_box, Rect2(-320, 82, 640, 58), 0.5, 0.0)
	_banner_title = _label("", 22, DeadCityUI.TEXT)
	_banner_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	_banner_title.add_theme_constant_override("shadow_offset_y", 3)
	_banner_box.add_child(_banner_title)
	_banner_sub = _label("", 11, Color(0.82, 0.85, 0.82, 0.9))
	_banner_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_box.add_child(_banner_sub)


func _overlay(tint: Color) -> Control:
	var layer := Control.new()
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var back := ColorRect.new()
	back.color = tint
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(back)
	return layer


func _centered_box(layer: Control, width: float, height: float) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.anchor_left = 0.5
	box.anchor_right = 0.5
	box.anchor_top = 0.5
	box.anchor_bottom = 0.5
	box.offset_left = -width * 0.5
	box.offset_right = width * 0.5
	box.offset_top = -height * 0.5
	box.offset_bottom = height * 0.5
	layer.add_child(box)
	return box


func _build_death_overlay() -> void:
	_death_overlay = _overlay(Color(0.03, 0.018, 0.016, 0.72))
	add_child(_death_overlay)
	var box := _centered_box(_death_overlay, 560.0, 200.0)
	var tag := _label("  SIGNAL LOST  ", 12, Color(0.95, 0.55, 0.45, 0.9))
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(tag)
	var title := _label("你已倒下", 42, Color("#ff8a76"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	title.add_theme_constant_override("shadow_offset_y", 4)
	box.add_child(title)
	_death_sub = _label("正在重新部署…", 15, Color(0.92, 0.8, 0.72, 0.92))
	_death_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_death_sub)
	var tip := _label("阵亡期间无法行动 · 全队倒下则任务失败", 12, Color(0.72, 0.58, 0.52, 0.8))
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(tip)


func _build_gameover_overlay() -> void:
	_gameover_overlay = _overlay(Color(0.012, 0.012, 0.011, 0.86))
	_gameover_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_gameover_overlay)
	_gameover_panel = PanelContainer.new()
	var style := DeadCityUI.panel_style(Color(0.04, 0.04, 0.036, 0.97), 6, Color(0.65, 0.3, 0.24, 0.75), 1)
	style.content_margin_left = 40.0
	style.content_margin_right = 40.0
	style.content_margin_top = 28.0
	style.content_margin_bottom = 28.0
	_gameover_panel.add_theme_stylebox_override("panel", style)
	_gameover_overlay.add_child(_gameover_panel)
	_place(_gameover_panel, Rect2(-300, -150, 600, 300), 0.5, 0.5)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 8)
	_gameover_panel.add_child(body)
	_gameover_tag = _label("MISSION FAILED", 12, Color(0.9, 0.4, 0.34))
	body.add_child(_gameover_tag)
	_gameover_title = _label("任务失败", 46, Color("#ff6b5e"))
	body.add_child(_gameover_title)
	_gameover_sub = _label("全队阵亡，城市重归死寂。", 15, DeadCityUI.MUTED)
	body.add_child(_gameover_sub)
	var line := ColorRect.new()
	line.color = Color(0.85, 0.5, 0.42, 0.28)
	line.custom_minimum_size = Vector2(0, 1)
	body.add_child(line)
	_gameover_stats = _label("", 14, Color(0.85, 0.82, 0.75))
	_gameover_stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(_gameover_stats)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 4)
	body.add_child(gap)
	_gameover_button = Button.new()
	_gameover_button.text = "返回行动大厅"
	_gameover_button.custom_minimum_size = Vector2(0, 48)
	DeadCityUI.style_button(_gameover_button, DeadCityUI.RED, true)
	_gameover_button.pressed.connect(func() -> void: lobby_requested.emit())
	body.add_child(_gameover_button)


func _build_draw_overlay() -> void:
	_draw_overlay = _overlay(Color(0.01, 0.012, 0.013, 0.86))
	_draw_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_draw_overlay)
	var panel := PanelContainer.new()
	var style := DeadCityUI.panel_style(Color(0.035, 0.04, 0.042, 0.985), 3, Color(0.85, 0.82, 0.76, 0.20), 1)
	style.content_margin_left = 30.0
	style.content_margin_right = 30.0
	style.content_margin_top = 22.0
	style.content_margin_bottom = 22.0
	panel.add_theme_stylebox_override("panel", style)
	_draw_overlay.add_child(panel)
	_place(panel, Rect2(-440, -174, 880, 348), 0.5, 0.5)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 10)
	panel.add_child(body)
	var header := HBoxContainer.new()
	body.add_child(header)
	var titles := VBoxContainer.new()
	titles.add_theme_constant_override("separation", 1)
	header.add_child(titles)
	titles.add_child(_label("战术强化", 26, DeadCityUI.TEXT, DeadCityUI.serif_font()))
	titles.add_child(_label("选择一份强化，作用于全队  ·  点击或按 1 / 2 / 3 / 方向键 + Enter", 11, DeadCityUI.MUTED))
	var header_spacer := Control.new()
	header_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(header_spacer)
	_draw_footer = _label("核心券 ×1", 11, DeadCityUI.AMBER)
	_draw_footer.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(_draw_footer)
	var line := ColorRect.new()
	line.color = Color(0.85, 0.82, 0.76, 0.18)
	line.custom_minimum_size = Vector2(0, 1)
	body.add_child(line)
	_draw_cards_box = HBoxContainer.new()
	_draw_cards_box.add_theme_constant_override("separation", 12)
	_draw_cards_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_draw_cards_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(_draw_cards_box)
	var foot := HBoxContainer.new()
	body.add_child(foot)
	var foot_hint := _label("选择期间角色原地读取核心数据", 10, Color(0.48, 0.52, 0.5))
	foot.add_child(foot_hint)
	var foot_spacer := Control.new()
	foot_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(foot_spacer)
	var cancel := Button.new()
	cancel.text = "放弃抽卡（返还核心券）"
	cancel.custom_minimum_size = Vector2(230, 36)
	DeadCityUI.style_button(cancel, DeadCityUI.MUTED, false)
	cancel.pressed.connect(func() -> void: draw_cancelled.emit())
	foot.add_child(cancel)


func _build_intel_overlay() -> void:
	_intel_overlay = _overlay(Color(0.008, 0.018, 0.026, 0.86))
	_intel_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_intel_overlay)
	var panel := PanelContainer.new()
	var style := DeadCityUI.panel_style(Color(0.035, 0.04, 0.042, 0.985), 3, Color(0.85, 0.82, 0.76, 0.20), 1)
	style.content_margin_left = 26.0
	style.content_margin_right = 26.0
	style.content_margin_top = 18.0
	style.content_margin_bottom = 18.0
	panel.add_theme_stylebox_override("panel", style)
	_intel_overlay.add_child(panel)
	_place(panel, Rect2(-470, -244, 940, 488), 0.5, 0.5)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 9)
	panel.add_child(body)
	var header := HBoxContainer.new()
	body.add_child(header)
	var titles := VBoxContainer.new()
	titles.add_theme_constant_override("separation", 1)
	header.add_child(titles)
	titles.add_child(_label("战术情报", 26, DeadCityUI.TEXT, DeadCityUI.serif_font()))
	titles.add_child(_label("任务 · 小队 · 幸存者档案  |  TAB 关闭", 12, DeadCityUI.MUTED))
	var header_spacer := Control.new()
	header_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(header_spacer)
	var close := Button.new()
	close.text = "关闭  TAB"
	close.custom_minimum_size = Vector2(146, 36)
	DeadCityUI.style_button(close, DeadCityUI.MUTED, false)
	close.pressed.connect(close_overlays)
	header.add_child(close)
	var line := ColorRect.new()
	line.color = Color(0.85, 0.82, 0.76, 0.18)
	line.custom_minimum_size = Vector2(0, 1)
	body.add_child(line)
	_intel_body = HBoxContainer.new()
	_intel_body.add_theme_constant_override("separation", 14)
	_intel_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(_intel_body)


func _build_backpack_overlay() -> void:
	_backpack_overlay = _overlay(Color(0.012, 0.014, 0.015, 0.86))
	_backpack_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_backpack_overlay)
	var panel := PanelContainer.new()
	var style := DeadCityUI.panel_style(Color(0.035, 0.04, 0.042, 0.985), 3, Color(0.85, 0.82, 0.76, 0.20), 1)
	style.content_margin_left = 26.0
	style.content_margin_right = 26.0
	style.content_margin_top = 18.0
	style.content_margin_bottom = 18.0
	panel.add_theme_stylebox_override("panel", style)
	_backpack_overlay.add_child(panel)
	_place(panel, Rect2(-480, -184, 960, 368), 0.5, 0.5)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 9)
	panel.add_child(body)
	var header := HBoxContainer.new()
	body.add_child(header)
	var titles := VBoxContainer.new()
	titles.add_theme_constant_override("separation", 1)
	header.add_child(titles)
	titles.add_child(_label("战术背包 · 装备切换", 26, DeadCityUI.TEXT, DeadCityUI.serif_font()))
	titles.add_child(_label("选择携带的武器；搬运核心或换弹时无法切换  |  B 关闭", 12, DeadCityUI.MUTED))
	var header_spacer := Control.new()
	header_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(header_spacer)
	var close := Button.new()
	close.text = "关闭  B"
	close.custom_minimum_size = Vector2(146, 36)
	DeadCityUI.style_button(close, DeadCityUI.MUTED, false)
	close.pressed.connect(close_overlays)
	header.add_child(close)
	var line := ColorRect.new()
	line.color = Color(0.85, 0.82, 0.76, 0.18)
	line.custom_minimum_size = Vector2(0, 1)
	body.add_child(line)
	_backpack_body = HBoxContainer.new()
	_backpack_body.add_theme_constant_override("separation", 10)
	_backpack_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(_backpack_body)
	_backpack_footer = _label("", 11, DeadCityUI.MUTED_2)
	_backpack_footer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(_backpack_footer)


func _build_pause_overlay() -> void:
	_pause_overlay = _overlay(Color(0.012, 0.014, 0.015, 0.74))
	_pause_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_pause_overlay)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", DeadCityUI.panel_style(Color(0.035, 0.04, 0.042, 0.98), 3, Color(0.85, 0.82, 0.76, 0.20), 1))
	_pause_overlay.add_child(panel)
	_place(panel, Rect2(-240, -158, 480, 316), 0.5, 0.5)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 10)
	panel.add_child(body)
	body.add_child(_label("行动暂停", 30, DeadCityUI.TEXT, DeadCityUI.serif_font()))
	_pause_note = _label("已释放鼠标 · 联机时服务器仍在模拟战斗", 11, DeadCityUI.MUTED)
	body.add_child(_pause_note)
	var line := ColorRect.new()
	line.color = Color(0.85, 0.82, 0.76, 0.18)
	line.custom_minimum_size = Vector2(0, 1)
	body.add_child(line)
	var controls := _label("WASD 移动   ·   Shift 冲刺   ·   Space 跳跃\n鼠标左键 攻击   ·   右键 瞄准   ·   R 换弹\nE 互动 / 补给   ·   G 放下核心   ·   1–2 / 滚轮 切换武器\nTab 战术情报   ·   B 战术背包", 10, Color(0.68, 0.70, 0.66, 0.9))
	controls.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	controls.custom_minimum_size = Vector2(0, 58)
	body.add_child(controls)
	var hint := _label("换弹与奔跑时准星会扩散；搬运核心时无法开火。", 10, DeadCityUI.MUTED_2)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(hint)
	_pause_resume = Button.new()
	_pause_resume.text = "继续行动  (ESC)"
	_pause_resume.custom_minimum_size = Vector2(0, 46)
	DeadCityUI.style_button(_pause_resume, DeadCityUI.AMBER, true)
	_pause_resume.pressed.connect(func() -> void: resume_requested.emit())
	body.add_child(_pause_resume)
	var back := Button.new()
	back.text = "返回行动大厅"
	back.custom_minimum_size = Vector2(0, 40)
	DeadCityUI.style_button(back, DeadCityUI.MUTED, false)
	back.pressed.connect(func() -> void: lobby_requested.emit())
	body.add_child(back)


func _build_loading_overlay() -> void:
	_loading_overlay = _overlay(Color(0.02, 0.022, 0.023, 0.985))
	_loading_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_loading_overlay)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_loading_overlay.add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.custom_minimum_size = Vector2(420, 0)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(box)
	var tag := _label("第一章 · 失联信号", 10, DeadCityUI.AMBER)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(tag)
	var title := _label("正在部署", 34, DeadCityUI.TEXT, DeadCityUI.serif_font())
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var rule := ColorRect.new()
	rule.color = Color(0.85, 0.82, 0.76, 0.18)
	rule.custom_minimum_size = Vector2(120, 1)
	rule.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(rule)
	_loading_label = _label("初始化街区…", 11, Color(0.62, 0.66, 0.62))
	_loading_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_loading_label)
	var note := _label("E-07 高架信号维护站 · 程序化旧城区", 9, Color(0.45, 0.48, 0.46, 0.8))
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(note)


func setup_world(layout: Dictionary) -> void:
	_minimap.setup(layout)
	_seed_label.text = "地图 #%s" % str(layout.get("seed", 0))
	_map_chip.text = "%d×%d 街区" % [int(layout.get("grid", 5)), int(layout.get("grid", 5))]


func reset_for_match() -> void:
	_game_over = false
	_down_active = false
	_paused = false
	if _banner_tween != null and _banner_tween.is_valid():
		_banner_tween.kill()
	_banner_box.modulate = Color(1, 1, 1, 0)
	for child in _kill_feed.get_children():
		_kill_feed.remove_child(child)
		child.queue_free()
	for child in _roster_box.get_children():
		_roster_box.remove_child(child)
		child.queue_free()
	_roster_rows.clear()
	_roster_ids_key = ""
	_death_overlay.visible = false
	_gameover_overlay.visible = false
	_pause_overlay.visible = false
	if _draw_overlay != null:
		_draw_overlay.visible = false
	if _interaction_panel != null:
		_interaction_panel.visible = false
	_intel_open = false
	_backpack_open = false
	if _intel_overlay != null:
		_intel_overlay.visible = false
	if _backpack_overlay != null:
		_backpack_overlay.visible = false
	if _roster_panel != null:
		_roster_panel.visible = false
	_crosshair.visible = true
	_last_wave = 0
	_last_phase = ""
	_carrying_core = false
	_score_label.text = "得分 0"
	if _mission_progress != null:
		_mission_progress.text = "0 / 3"
		_mission_progress.add_theme_color_override("font_color", DeadCityUI.AMBER)
		_mission_hint.text = "沿市中心公园坡道下到核心储藏层 B1"
		_mission_zone.text = "基地安全区"
		_mission_zone.add_theme_color_override("font_color", DeadCityUI.CYAN)
		_mission_tokens.text = "抽卡券 ×0"
		_mission_tokens.visible = false
		_mission_upgrades.text = ""
		for pip in _mission_pips:
			pip.color = Color(0.3, 0.29, 0.26, 0.6)
	_wave_label.text = "第 1 波"
	_wave_sub.text = "部署中"
	_health_label.text = "100"
	_health_bar.value = 100.0
	_health_state.text = "稳定"
	_health_state.modulate = Color.WHITE
	_health_state.add_theme_color_override("font_color", DeadCityUI.GREEN)
	_vignette.set_low_health(false)
	_last_health = 100.0
	_last_mag = 0
	_last_reloading = false
	_update_ammo_state()
	if _weapon_strip != null:
		_weapon_strip.modulate = Color(1, 1, 1, 0)


func set_roster(players: Array) -> void:
	_roster_panel.visible = players.size() > 1
	var keys := PackedStringArray()
	for player in players:
		keys.append(str(int(player.get("id", 0))))
	var key := ",".join(keys)
	if key != _roster_ids_key:
		_rebuild_roster(players)
		_roster_ids_key = key
	for player in players:
		var id := int(player.get("id", 0))
		if not _roster_rows.has(id):
			continue
		var row: Dictionary = _roster_rows[id]
		var alive := bool(player.get("alive", true))
		var health := float(player.get("health", 100.0))
		var kills := int(player.get("kills", 0))
		var name_label: Label = row["name"]
		var status_label: Label = row["status"]
		var bar: ProgressBar = row["bar"]
		var dot: ColorRect = row["dot"]
		var base_color: Color = player.get("color", DeadCityUI.CYAN)
		var distance := float(player.get("distance", 0.0))
		var display := String(player.get("name", "幸存者"))
		if bool(player.get("is_local", false)):
			display += "（你）"
		name_label.text = display
		name_label.add_theme_color_override("font_color", DeadCityUI.TEXT if alive else Color(0.62, 0.55, 0.52))
		if not alive:
			status_label.text = "倒地 %.0fm" % distance if distance > 0.5 else "倒地"
			status_label.add_theme_color_override("font_color", DeadCityUI.RED)
		elif health <= 30.0:
			status_label.text = "危险"
			status_label.add_theme_color_override("font_color", DeadCityUI.RED)
		elif distance > 60.0:
			status_label.text = "脱离 %.0fm" % distance
			status_label.add_theme_color_override("font_color", DeadCityUI.AMBER)
		else:
			status_label.text = "%d 杀" % kills
			status_label.add_theme_color_override("font_color", DeadCityUI.MUTED_2)
		bar.value = clampf(health, 0.0, 100.0)
		bar.add_theme_stylebox_override("fill", DeadCityUI.meter_style(base_color if alive else DeadCityUI.MUTED_2, 0))
		bar.modulate = Color(1, 1, 1, 1) if alive else Color(0.6, 0.6, 0.6, 0.55)
		dot.color = base_color if alive else Color(0.4, 0.4, 0.4)
	_roster_count.text = "%d 人" % players.size()


func _rebuild_roster(players: Array) -> void:
	for child in _roster_box.get_children():
		_roster_box.remove_child(child)
		child.queue_free()
	_roster_rows.clear()
	for player in players:
		var id := int(player.get("id", 0))
		var color: Color = player.get("color", DeadCityUI.CYAN)
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_theme_constant_override("separation", 7)
		_roster_box.add_child(row)
		var dot := ColorRect.new()
		dot.color = color
		dot.custom_minimum_size = Vector2(2, 24)
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(dot)
		var info := VBoxContainer.new()
		info.add_theme_constant_override("separation", 1)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info)
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 6)
		info.add_child(line)
		var name_label := _label("幸存者", 10, DeadCityUI.TEXT)
		line.add_child(name_label)
		var line_spacer := Control.new()
		line_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(line_spacer)
		var status_label := _label("100", 9, DeadCityUI.MUTED_2)
		line.add_child(status_label)
		var bar := ProgressBar.new()
		bar.min_value = 0.0
		bar.max_value = 100.0
		bar.value = 100.0
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(0, 2)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.add_theme_stylebox_override("background", DeadCityUI.meter_style(Color(0.16, 0.17, 0.16, 0.55), 0))
		bar.add_theme_stylebox_override("fill", DeadCityUI.meter_style(color, 0))
		info.add_child(bar)
		_roster_rows[id] = {"name": name_label, "bar": bar, "status": status_label, "dot": dot}


func set_wave(summary: Dictionary) -> void:
	var wave := int(summary.get("wave", 1))
	var phase := String(summary.get("phase", "break"))
	var remaining := int(summary.get("remaining", 0))
	var alive := int(summary.get("alive", 0))
	var threat := int(summary.get("threat", 0))
	var threat_mult := float(summary.get("threat_mult", 1.0))
	_wave_label.text = "第 %d 波" % wave
	if phase == "fight":
		var detail := "交战中 · 场上 %d · 剩余 %d" % [alive, remaining]
		if threat > 0 and threat_mult > 1.01:
			detail += " · 威胁 ×%.1f" % threat_mult
		_wave_sub.text = detail
		_wave_sub.add_theme_color_override("font_color", DeadCityUI.CORAL)
	else:
		var break_left := int(ceil(float(summary.get("break_left", 0.0))))
		if bool(summary.get("active", false)):
			_wave_sub.text = "间歇 %d 秒 · 剩余 %d" % [break_left, remaining]
			_wave_sub.add_theme_color_override("font_color", DeadCityUI.AMBER)
		else:
			_wave_sub.text = "部署中"
			_wave_sub.add_theme_color_override("font_color", DeadCityUI.MUTED)
	if wave != _last_wave:
		_last_wave = wave
		_last_phase = phase
		announce("第 %d 波" % wave, "感染者正在逼近", DeadCityUI.AMBER, 2.0)
	elif phase != _last_phase:
		_last_phase = phase
		if phase == "fight":
			announce("接触开始", "清空这一波感染者", DeadCityUI.CORAL, 1.5)


func set_score(score: int) -> void:
	_score_label.text = "得分 %s" % _format_number(score)


func set_health(health: float, maximum: float = 100.0) -> void:
	var clamped := clampf(health, 0.0, maximum)
	_health_label.text = str(int(ceil(clamped)))
	_health_bar.value = clamped
	var ratio := clamped / maxf(1.0, maximum)
	var color := DeadCityUI.GREEN
	var state_text := "稳定"
	if clamped <= 0.0:
		color = DeadCityUI.RED
		state_text = "失去意识"
	elif ratio <= 0.3:
		color = DeadCityUI.RED
		state_text = "危险"
	elif ratio <= 0.6:
		color = DeadCityUI.AMBER
		state_text = "受伤"
	var previous := _health_state.text
	_health_label.add_theme_color_override("font_color", color if clamped < maximum else DeadCityUI.TEXT)
	_health_state.text = state_text
	_health_state.add_theme_color_override("font_color", color)
	_health_bar.add_theme_stylebox_override("fill", DeadCityUI.meter_style(color, 0))
	_vignette.set_low_health(clamped > 0.0 and ratio <= 0.3)
	if clamped < _last_health - 0.5:
		_vignette.flash(clampf((_last_health - clamped) / 30.0, 0.3, 1.0) * (0.0 if DeadCityUI.reduced_motion() else 1.0))
	if state_text != previous and (state_text == "受伤" or state_text == "危险" or state_text == "失去意识"):
		if _health_pulse != null and _health_pulse.is_valid():
			_health_pulse.kill()
		if not DeadCityUI.reduced_motion():
			_health_state.modulate = Color(1, 1, 1, 0.55)
			_health_pulse = create_tween()
			_health_pulse.tween_property(_health_state, "modulate:a", 1.0, 0.45)
	_last_health = clamped


func set_ammo(mag: int, reserve: int, reloading: bool = false, progress: float = 0.0, melee: bool = false) -> void:
	_ammo_melee = melee
	_last_mag = mag
	_last_reloading = reloading
	_reload_bar.visible = reloading and not melee and not _carrying_core
	_reload_bar.value = clampf(progress, 0.0, 1.0) * 100.0
	if melee:
		_ammo_mag.text = "近战"
		_ammo_mag.add_theme_font_size_override("font_size", 20)
		_ammo_reserve.text = "∞"
		_ammo_slash.visible = false
		_ammo_mag.add_theme_color_override("font_color", DeadCityUI.TEXT)
	else:
		_ammo_mag.add_theme_font_size_override("font_size", 30)
		_ammo_slash.visible = true
		_ammo_mag.text = str(mag)
		_ammo_reserve.text = str(reserve)
		_ammo_mag.add_theme_color_override("font_color", DeadCityUI.RED if mag <= 5 else DeadCityUI.TEXT)
	_update_ammo_state()


func _update_ammo_state() -> void:
	if _ammo_state == null:
		return
	if _carrying_core:
		_ammo_state.text = "核心搬运中 · 无法开火"
		_ammo_state.add_theme_color_override("font_color", DeadCityUI.AMBER)
	elif _ammo_melee:
		_ammo_state.text = "近战 · 可挥砍"
		_ammo_state.add_theme_color_override("font_color", DeadCityUI.AMBER)
	elif _last_reloading:
		_ammo_state.text = "换弹中"
		_ammo_state.add_theme_color_override("font_color", DeadCityUI.AMBER)
	elif _last_mag <= 0:
		_ammo_state.text = "空仓 · 按 R 换弹"
		_ammo_state.add_theme_color_override("font_color", DeadCityUI.RED)
	else:
		_ammo_state.text = "就绪"
		_ammo_state.add_theme_color_override("font_color", DeadCityUI.GREEN)
	if _reload_bar != null:
		_reload_bar.visible = _last_reloading and not _ammo_melee and not _carrying_core


func set_carry_preview(value: bool) -> void:
	_carry_preview = value
	_carrying_core = value
	_update_ammo_state()


func set_mission(cores: int, required: int, tokens: int, hint: String, zone_text: String, zone_color: Color, upgrades: Dictionary, carrying: bool, power: int = -1) -> void:
	var capped := mini(cores, required)
	carrying = carrying or _carry_preview
	_mission_progress.text = "%d / %d" % [capped, required]
	_mission_progress.add_theme_color_override("font_color", DeadCityUI.GREEN if capped >= required else DeadCityUI.AMBER)
	for i in range(_mission_pips.size()):
		_mission_pips[i].color = DeadCityUI.AMBER if i < capped else Color(0.3, 0.29, 0.26, 0.6)
	_mission_hint.text = hint
	_mission_hint.add_theme_color_override("font_color", DeadCityUI.AMBER if carrying else Color(0.72, 0.78, 0.76, 0.9))
	_mission_zone.text = zone_text
	_mission_zone.add_theme_color_override("font_color", zone_color)
	_mission_tokens.text = "抽卡券 ×%d" % tokens
	_mission_tokens.visible = tokens > 0
	_mission_tokens.add_theme_color_override("font_color", DeadCityUI.AMBER)
	var upgrade_text := "强化 %d/%d/%d/%d/%d/%d" % [
		int(upgrades.get("mag", 0)), int(upgrades.get("reload", 0)),
		int(upgrades.get("damage", 0)), int(upgrades.get("rate", 0)),
		int(upgrades.get("speed", 0)), int(upgrades.get("armor", 0)),
	]
	if power >= 0:
		upgrade_text += " · 战力 %d" % power
	_mission_upgrades.text = upgrade_text
	if carrying != _carrying_core:
		_carrying_core = carrying
		_update_ammo_state()


func set_interaction(text: String) -> void:
	if _interaction_label == null:
		return
	_interaction_label.text = text
	_interaction_panel.visible = not text.is_empty() and not _game_over and not _paused and not _down_active and not overlay_open()


func show_draw(options: Array) -> void:
	for child in _draw_cards_box.get_children():
		_draw_cards_box.remove_child(child)
		child.queue_free()
	for i in range(options.size()):
		var card: Dictionary = options[i]
		var accent := Color.from_string(String(card.get("accent", "#59d8c8")), DeadCityUI.CYAN)
		var button := Button.new()
		button.custom_minimum_size = Vector2(252, 182)
		button.focus_mode = Control.FOCUS_ALL
		DeadCityUI.style_button(button, accent, false)
		var card_focus := DeadCityUI.focus_style(DeadCityUI.AMBER)
		card_focus.set_border_width_all(2)
		button.add_theme_stylebox_override("focus", card_focus)
		button.pressed.connect(_on_card_button.bind(i))
		_draw_cards_box.add_child(button)
		var margin := MarginContainer.new()
		margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for side in ["left", "right", "top", "bottom"]:
			margin.add_theme_constant_override("margin_" + side, 16)
		button.add_child(margin)
		var box := VBoxContainer.new()
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_theme_constant_override("separation", 6)
		margin.add_child(box)
		box.add_child(_label("强化  %02d" % (i + 1), 9, accent))
		box.add_child(_label(String(card.get("title", "未知强化")), 21, DeadCityUI.TEXT))
		var level := _label("Lv %d  →  Lv %d" % [int(card.get("level", 0)), int(card.get("level", 0)) + 1], 11, DeadCityUI.AMBER)
		box.add_child(level)
		var desc := _label(String(card.get("desc", "")), 12, Color(0.72, 0.74, 0.70))
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
		box.add_child(desc)
		var hint := _label("按 %d 选择" % (i + 1), 11, accent)
		box.add_child(hint)
	_draw_footer.text = "从 %d 份强化中选择 1 份" % options.size()
	var buttons := _draw_cards_box.get_children()
	for i in range(buttons.size()):
		var button := buttons[i] as Button
		if button == null:
			continue
		var prev := buttons[(i - 1 + buttons.size()) % buttons.size()] as Button
		var next := buttons[(i + 1) % buttons.size()] as Button
		if prev != null:
			button.focus_neighbor_left = button.get_path_to(prev)
		if next != null:
			button.focus_neighbor_right = button.get_path_to(next)
	if not buttons.is_empty() and buttons[0] is Button:
		(buttons[0] as Button).grab_focus.call_deferred()
	_draw_overlay.visible = true
	_crosshair.visible = false
	_interaction_panel.visible = false
	_intel_open = false
	_backpack_open = false
	_intel_overlay.visible = false
	_backpack_overlay.visible = false


func hide_draw() -> void:
	if _draw_overlay != null:
		_draw_overlay.visible = false
	_crosshair.visible = not (_paused or _down_active or _game_over)


func _on_card_button(index: int) -> void:
	card_picked.emit(index)


func overlay_open() -> bool:
	return _intel_open or _backpack_open


func intel_open() -> bool:
	return _intel_open


func backpack_open() -> bool:
	return _backpack_open


func open_intel(data: Dictionary) -> void:
	if _draw_overlay != null and _draw_overlay.visible:
		return
	_intel_data = data.duplicate(true)
	_render_intel()
	_intel_open = true
	_backpack_open = false
	_intel_overlay.visible = true
	_backpack_overlay.visible = false
	_interaction_panel.visible = false
	_crosshair.visible = false


func open_backpack(loadout: Array, profile: Dictionary, upgrades: Dictionary) -> void:
	if _draw_overlay != null and _draw_overlay.visible:
		return
	_loadout = loadout.duplicate(true)
	_weapon_profile = profile.duplicate(true)
	_team_upgrades = upgrades.duplicate(true)
	_render_backpack()
	_backpack_open = true
	_intel_open = false
	_backpack_overlay.visible = true
	_intel_overlay.visible = false
	_interaction_panel.visible = false
	_crosshair.visible = false


func close_overlays() -> void:
	_intel_open = false
	_backpack_open = false
	if _intel_overlay != null:
		_intel_overlay.visible = false
	if _backpack_overlay != null:
		_backpack_overlay.visible = false
	_crosshair.visible = not (_paused or _down_active or _game_over)


func _clear_box(box: Node) -> void:
	for child in box.get_children():
		box.remove_child(child)
		child.queue_free()


func _intel_column(title: String, accent: Color) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_stretch_ratio = 1.0
	var style := DeadCityUI.panel_style(Color(0.055, 0.055, 0.05, 0.9), 8, Color(accent.r, accent.g, accent.b, 0.22), 1)
	style.content_margin_left = 15.0
	style.content_margin_right = 15.0
	style.content_margin_top = 13.0
	style.content_margin_bottom = 13.0
	panel.add_theme_stylebox_override("panel", style)
	_intel_body.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	panel.add_child(box)
	box.add_child(_label(title, 14, accent))
	var line := ColorRect.new()
	line.color = Color(accent.r, accent.g, accent.b, 0.28)
	line.custom_minimum_size = Vector2(0, 1)
	box.add_child(line)
	return box


func _render_intel() -> void:
	_clear_box(_intel_body)
	var mission: Dictionary = _intel_data.get("mission", {})
	var upgrades: Dictionary = mission.get("upgrades", {})
	var cores := int(mission.get("cores", 0))
	var required := maxi(1, int(mission.get("required", 3)))
	var power := int(mission.get("power", 0))

	var mission_box := _intel_column("行动目标", DeadCityUI.AMBER)
	mission_box.add_child(_label("核心回收  %d / %d" % [mini(cores, required), required], 24, DeadCityUI.GREEN if cores >= required else DeadCityUI.AMBER))
	mission_box.add_child(_label(String(mission.get("zone", "未知区域")), 12, DeadCityUI.CYAN))
	var hint := _label(String(mission.get("hint", "")), 12, DeadCityUI.MUTED)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size = Vector2(0, 48)
	mission_box.add_child(hint)
	mission_box.add_child(_label("街区压力  第 %d 波" % int(mission.get("wave", 1)), 12, Color(0.72, 0.82, 0.83)))
	mission_box.add_child(_label("队内得分  %s" % _format_number(int(mission.get("score", 0))), 12, DeadCityUI.CYAN))
	var frenzy := bool(mission.get("frenzy", false))
	mission_box.add_child(_label("尸潮状态  %s" % ("狂暴暴走" if frenzy else "常规推进"), 12, DeadCityUI.RED if frenzy else Color(0.55, 0.7, 0.7)))
	mission_box.add_child(_label("抽卡券 ×%d" % int(mission.get("tokens", 0)), 12, DeadCityUI.AMBER))
	var gap := Control.new()
	gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mission_box.add_child(gap)
	mission_box.add_child(_label("战术强化", 12, DeadCityUI.TEXT))
	var names := {"mag": "弹匣", "reload": "换弹", "damage": "伤害", "rate": "射速", "speed": "移速", "armor": "护甲"}
	for key in ["mag", "reload", "damage", "rate", "speed", "armor"]:
		var row := HBoxContainer.new()
		mission_box.add_child(row)
		row.add_child(_label(String(names[key]), 11, Color(0.56, 0.68, 0.69)))
		var row_spacer := Control.new()
		row_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(row_spacer)
		row.add_child(_label("Lv %d" % int(upgrades.get(key, 0)), 11, DeadCityUI.CYAN))
	mission_box.add_child(_label("团队战力  %d" % power, 12, DeadCityUI.AMBER))

	var roster_box := _intel_column("小队状态", DeadCityUI.CYAN)
	var roster: Array = _intel_data.get("roster", [])
	if roster.is_empty():
		roster_box.add_child(_label("暂无队友", 12, DeadCityUI.MUTED))
	for raw in roster:
		if not (raw is Dictionary):
			continue
		var member: Dictionary = raw
		var alive := bool(member.get("alive", true))
		var color: Color = member.get("color", DeadCityUI.CYAN)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 7)
		roster_box.add_child(row)
		var dot := ColorRect.new()
		dot.color = color if alive else Color(0.35, 0.4, 0.42)
		dot.custom_minimum_size = Vector2(4, 28)
		row.add_child(dot)
		var info := VBoxContainer.new()
		info.add_theme_constant_override("separation", 0)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info)
		info.add_child(_label(String(member.get("name", "幸存者")), 13, DeadCityUI.TEXT if alive else Color(0.5, 0.56, 0.58)))
		info.add_child(_label("生命 %d  ·  击杀 %d" % [int(ceil(float(member.get("health", 0.0)))), int(member.get("kills", 0))], 10, Color(0.56, 0.66, 0.67)))
		var status := _label("在阵线" if alive else "阵亡", 10, DeadCityUI.GREEN if alive else DeadCityUI.RED)
		status.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(status)
	if roster.size() < 4:
		var fill := Control.new()
		fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
		roster_box.add_child(fill)
		roster_box.add_child(_label("空余席位 %d  ·  可从大厅邀请" % (4 - roster.size()), 10, Color(0.42, 0.52, 0.54)))

	var player_box := _intel_column("幸存者档案", DeadCityUI.GREEN)
	var player: Dictionary = _intel_data.get("player", {})
	player_box.add_child(_label(String(player.get("name", "幸存者")), 20, DeadCityUI.TEXT))
	player_box.add_child(_label("生命 %d / 100  ·  击杀 %d" % [int(ceil(float(player.get("health", 100.0)))), int(player.get("kills", 0))], 12, Color(0.68, 0.8, 0.8)))
	var weapon: Dictionary = player.get("weapon", {})
	var weapon_id := String(weapon.get("id", "smg"))
	var weapon_name := _label(String(weapon.get("name", "未知武器")), 16, WeaponCatalog.accent(weapon_id))
	weapon_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	player_box.add_child(weapon_name)
	var stat := _label(WeaponCatalog.stat_line(weapon_id), 11, Color(0.66, 0.78, 0.79))
	stat.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	player_box.add_child(stat)
	var gap2 := Control.new()
	gap2.size_flags_vertical = Control.SIZE_EXPAND_FILL
	player_box.add_child(gap2)
	player_box.add_child(_label("携带装备", 12, DeadCityUI.TEXT))
	var loadout: Array = player.get("loadout", [])
	for raw in loadout:
		if not (raw is Dictionary):
			continue
		var entry: Dictionary = raw
		var active := bool(entry.get("active", false))
		var suffix := "  ◀ 当前" if active else ""
		var melee := bool(entry.get("melee", false))
		var ammo_text := "近战" if melee else "%d/%d" % [int(entry.get("mag", 0)), int(entry.get("reserve", 0))]
		var line := _label("%d  %s  %s%s" % [
			int(entry.get("slot", 0)), String(entry.get("name", "--")), ammo_text, suffix,
		], 11, WeaponCatalog.accent(String(entry.get("id", "smg"))) if active else Color(0.6, 0.72, 0.73))
		player_box.add_child(line)
	var bonus := int(player.get("reserve_bonus", 0))
	player_box.add_child(_label("血脉备弹加成  +%d" % bonus, 10, Color(0.5, 0.62, 0.63)))


func _render_backpack() -> void:
	_clear_box(_backpack_body)
	var active_id := String(_weapon_profile.get("id", ""))
	for i in range(WeaponCatalog.MAX_CARRY):
		var entry: Dictionary = _loadout[i] if i < _loadout.size() and _loadout[i] is Dictionary else {}
		var id := String(entry.get("id", ""))
		var has := not id.is_empty()
		var active := has and id == active_id
		var accent := WeaponCatalog.accent(id) if has else Color(0.42, 0.4, 0.36)
		var card := PanelContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.size_flags_vertical = Control.SIZE_EXPAND_FILL
		var border := DeadCityUI.AMBER if active else Color(0.72, 0.68, 0.60, 0.22 if has else 0.12)
		var fill := Color(0.085, 0.083, 0.075, 0.95) if active else Color(0.052, 0.052, 0.048, 0.8 if has else 0.45)
		var style := DeadCityUI.panel_style(fill, 8, border, 2 if active else 1)
		style.content_margin_left = 12.0
		style.content_margin_right = 12.0
		style.content_margin_top = 12.0
		style.content_margin_bottom = 12.0
		card.add_theme_stylebox_override("panel", style)
		_backpack_body.add_child(card)
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 6)
		card.add_child(box)
		box.add_child(_label("出战槽位 %d" % (i + 1), 10, accent if has else Color(0.5, 0.48, 0.44)))
		if not has:
			box.add_child(_label("空槽", 18, Color(0.55, 0.52, 0.47)))
			box.add_child(_label("返回行动大厅，在军械库调整出战编成", 10, DeadCityUI.MUTED))
			continue
		var title := _label(WeaponCatalog.display_name(id), 15, DeadCityUI.TEXT)
		title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(title)
		box.add_child(_label(String(WeaponCatalog.data(id).get("tag", "")), 10, accent))
		var stat := _label(WeaponCatalog.stat_line(id), 10, DeadCityUI.MUTED)
		stat.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(stat)
		var fill_space := Control.new()
		fill_space.size_flags_vertical = Control.SIZE_EXPAND_FILL
		box.add_child(fill_space)
		if WeaponCatalog.is_melee(id):
			box.add_child(_label("近战 · 第三人称搏杀 · 无需弹药", 10, DeadCityUI.MUTED_2))
		else:
			var ammo := "弹匣 %d/%d" % [int(entry.get("mag", 0)), int(entry.get("mag_size", 0))]
			ammo += "  ·  备弹 %d" % int(entry.get("reserve", 0))
			box.add_child(_label(ammo, 10, DeadCityUI.MUTED_2))
		var button := Button.new()
		button.custom_minimum_size = Vector2(0, 34)
		button.focus_mode = Control.FOCUS_NONE
		if active:
			button.text = "使用中"
			button.disabled = true
			DeadCityUI.style_button(button, accent, false)
		else:
			button.text = "切换装备"
			DeadCityUI.style_button(button, accent, true)
			button.pressed.connect(_on_weapon_button_pressed.bind(id))
		box.add_child(button)
	var up := _team_upgrades
	_backpack_footer.text = "出战编成最多携带两件 · 枪械第一人称 / 近战第三人称     |     队内强化  弹匣 %d · 换弹 %d · 伤害 %d · 射速 %d · 移速 %d · 护甲 %d" % [
		int(up.get("mag", 0)), int(up.get("reload", 0)), int(up.get("damage", 0)),
		int(up.get("rate", 0)), int(up.get("speed", 0)), int(up.get("armor", 0)),
	]


func _on_weapon_button_pressed(weapon_id: String) -> void:
	weapon_selected.emit(weapon_id)


func set_minimap_entities(local_pos: Vector3, local_yaw: float, remotes: Array, zombies: Array, markers: Array = []) -> void:
	_minimap.update_entities(local_pos, local_yaw, remotes, zombies, markers)


func set_spread(value: float) -> void:
	_crosshair.set_spread(value)


func show_hit(headshot: bool, kill: bool = false) -> void:
	_crosshair.show_hit(headshot, kill)


func push_kill(text: String, color: Color = DeadCityUI.TEXT) -> void:
	var entry := _label(text, 11, color)
	entry.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	entry.modulate = Color(1, 1, 1, 0)
	_kill_feed.add_child(entry)
	while _kill_feed.get_child_count() > 5:
		var oldest := _kill_feed.get_child(0)
		_kill_feed.remove_child(oldest)
		oldest.queue_free()
	var tween := create_tween()
	tween.tween_property(entry, "modulate:a", 1.0, 0.14)
	tween.tween_interval(3.0)
	tween.tween_property(entry, "modulate:a", 0.0, 0.5)
	tween.tween_callback(entry.queue_free)


func announce(title: String, sub: String = "", color: Color = DeadCityUI.TEXT, duration: float = 2.4) -> void:
	_banner_title.text = title
	_banner_title.add_theme_color_override("font_color", color)
	_banner_sub.text = sub
	_banner_sub.visible = sub != ""
	_banner_box.modulate = Color(1, 1, 1, 1)
	if _banner_tween != null and _banner_tween.is_valid():
		_banner_tween.kill()
	_banner_tween = create_tween()
	if DeadCityUI.reduced_motion():
		_banner_tween.tween_interval(duration)
		_banner_tween.tween_callback(func() -> void: _banner_box.modulate.a = 0.0)
		return
	_banner_tween.tween_interval(duration)
	_banner_tween.tween_property(_banner_box, "modulate:a", 0.0, 0.45)


func set_down(active: bool, countdown: float = 0.0) -> void:
	_down_active = active
	_down_left = countdown
	_death_overlay.visible = active
	_crosshair.visible = not (active or _paused or _game_over)
	if active:
		_interaction_panel.visible = false
		_health_state.text = "倒地 · 等待救援"
		_health_state.add_theme_color_override("font_color", DeadCityUI.RED)
		_update_down_text()


func _update_down_text() -> void:
	var seconds := int(ceil(_down_left))
	if seconds > 0:
		_death_sub.text = "重新部署倒计时 %d 秒" % seconds
	else:
		_death_sub.text = "正在重新部署…"


func show_game_over(stats_text: String, victory: bool = false) -> void:
	_game_over = true
	_down_active = false
	_death_overlay.visible = false
	if _draw_overlay != null:
		_draw_overlay.visible = false
	_intel_open = false
	_backpack_open = false
	_intel_overlay.visible = false
	_backpack_overlay.visible = false
	_interaction_panel.visible = false
	_gameover_stats.text = stats_text
	_gameover_overlay.visible = true
	_crosshair.visible = false
	if victory:
		_gameover_tag.text = "MISSION COMPLETE"
		_gameover_tag.add_theme_color_override("font_color", DeadCityUI.GREEN)
		_gameover_title.text = "任务完成"
		_gameover_title.add_theme_color_override("font_color", DeadCityUI.GREEN)
		_gameover_sub.text = "三枚核心全部回收，基地防线守住了。"
		_gameover_panel.add_theme_stylebox_override("panel", DeadCityUI.panel_style(Color(0.04, 0.042, 0.037, 0.98), 6, Color(0.61, 0.76, 0.52, 0.85), 1))
		DeadCityUI.style_button(_gameover_button, DeadCityUI.GREEN, true)
	else:
		_gameover_tag.text = "MISSION FAILED"
		_gameover_tag.add_theme_color_override("font_color", Color(0.9, 0.4, 0.34))
		_gameover_title.text = "任务失败"
		_gameover_title.add_theme_color_override("font_color", Color("#ff6b5e"))
		_gameover_sub.text = "全队阵亡，城市重归死寂。"
		_gameover_panel.add_theme_stylebox_override("panel", DeadCityUI.panel_style(Color(0.04, 0.038, 0.034, 0.97), 6, Color(0.65, 0.3, 0.24, 0.75), 1))
		DeadCityUI.style_button(_gameover_button, DeadCityUI.RED, true)


func set_pause_visible(value: bool) -> void:
	var draw_open := _draw_overlay != null and _draw_overlay.visible
	_paused = value and not _game_over and not draw_open
	_pause_overlay.visible = _paused
	if _paused:
		_intel_open = false
		_backpack_open = false
		_intel_overlay.visible = false
		_backpack_overlay.visible = false
	_crosshair.visible = not (_paused or _down_active or _game_over or draw_open)
	if _paused:
		_interaction_panel.visible = false
		if _pause_resume != null:
			_pause_resume.grab_focus.call_deferred()


func set_pause_note(text: String) -> void:
	if _pause_note != null:
		_pause_note.text = text


func show_loading(message: String = "初始化街区…") -> void:
	_loading_time = 0.0
	_loading_label.text = message
	_loading_overlay.visible = true


func hide_loading() -> void:
	_loading_overlay.visible = false


func set_connection_info(text: String) -> void:
	_conn_label.text = text
	_conn_label.add_theme_color_override("font_color", Color(0.48, 0.6, 0.61))


func trigger_damage_flash(strength: float = 0.7) -> void:
	_vignette.flash(strength)


func _format_number(value: int) -> String:
	var digits := str(absi(value))
	var out := ""
	var counter := 0
	for i in range(digits.length() - 1, -1, -1):
		out = digits.substr(i, 1) + out
		counter += 1
		if counter % 3 == 0 and i > 0:
			out = "," + out
	return ("-" if value < 0 else "") + out


func _process(delta: float) -> void:
	if _down_active and _down_left > 0.0:
		_down_left = maxf(0.0, _down_left - delta)
		_update_down_text()
	if _loading_overlay.visible:
		_loading_time += delta
		_loading_label.modulate = Color(1, 1, 1, 0.6 + 0.4 * absf(sin(_loading_time * 2.4)))
