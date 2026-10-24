extends Node
## 统一玩家设置服务（V2）。所有 UI、Player、HUD、Audio、Display、InputMap 都从这里读写。
## 旧版 user://ui_settings.cfg 仍可读取；写入时升级为 [meta] version=2。

signal changed(key: String)
signal pending_changed(key: String)
signal applied

const SETTINGS_PATH := "user://ui_settings.cfg"
const VERSION := 2
const HUD_SCALES := [0.9, 1.0, 1.1]

var _applied: Dictionary = {}
var _pending: Dictionary = {}
var _loaded_version := 0

var master_volume: float:
	get:
		return float(_pending.get("master_volume", 0.85))
	set(value):
		set_pending("master_volume", value)
var fullscreen: bool:
	get:
		return String(_pending.get("window_mode", "windowed")) != "windowed"
	set(value):
		set_pending("window_mode", "fullscreen" if value else "windowed")
var vsync: bool:
	get:
		return bool(_pending.get("vsync", true))
	set(value):
		set_pending("vsync", value)
var hud_scale: float:
	get:
		return float(_pending.get("hud_scale", 1.0))
	set(value):
		set_pending("hud_scale", value)
var reduced_motion: bool:
	get:
		return bool(_pending.get("reduced_motion", false))
	set(value):
		set_pending("reduced_motion", value)
var high_contrast: bool:
	get:
		return bool(_pending.get("high_contrast", false))
	set(value):
		set_pending("high_contrast", value)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_buses()
	load_settings()
	apply_all()


func get_value(key: String) -> Variant:
	if _pending.has(key):
		return _pending[key]
	return SettingsSchema.defaults().get(key, null)


func get_applied(key: String) -> Variant:
	return _applied.get(key, get_value(key))


func set_pending(key: String, value: Variant) -> void:
	if not SettingsSchema.FIELDS.has(key) and not SettingsSchema.KEY_ACTIONS.has(key):
		return
	var normalized: Variant = _validate(key, value)
	if _pending.has(key) and _pending[key] == normalized:
		return
	_pending[key] = normalized
	_preview(key)
	pending_changed.emit(key)


func set_pending_key(action: String, event: InputEvent) -> bool:
	if not SettingsSchema.KEY_ACTIONS.has(action):
		return false
	var encoded := SettingsSchema.string_from_event(event)
	if encoded.is_empty():
		return false
	var conflict := find_key_conflict(action, encoded)
	if not conflict.is_empty():
		return false
	_pending[action] = encoded
	_apply_input()
	changed.emit(action)
	pending_changed.emit(action)
	return true


func find_key_conflict(action: String, encoded: String) -> String:
	for other in SettingsSchema.KEY_ACTIONS.keys():
		if other == action:
			continue
		if String(_pending.get(other, "")) == encoded:
			return other
	return ""


func apply() -> void:
	_applied = _pending.duplicate(true)
	save_settings()
	apply_all()
	applied.emit()


func cancel() -> void:
	_pending = _applied.duplicate(true)
	apply_all()
	changed.emit("all")


func reset_category(category: String) -> void:
	for key in SettingsSchema.category_fields(category):
		_pending[key] = SettingsSchema.definition(key).get("default", null)
	apply_all_preview()
	pending_changed.emit(category)


func reset_all() -> void:
	_pending = SettingsSchema.defaults()
	apply_all_preview()
	pending_changed.emit("all")


func has_pending_changes() -> bool:
	for key in _pending.keys():
		if not _applied.has(key) or _pending[key] != _applied[key]:
			return true
	return false


func pending_keys() -> Array:
	var result: Array = []
	for key in _pending.keys():
		if not _applied.has(key) or _pending[key] != _applied[key]:
			result.append(key)
	return result


func key_label(action: String) -> String:
	return SettingsSchema.event_label(String(_pending.get(action, "")))


func load_settings() -> void:
	_applied = SettingsSchema.defaults()
	_pending = SettingsSchema.defaults()
	_loaded_version = 0
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return
	_loaded_version = int(config.get_value("meta", "version", 1))
	for key in _applied.keys():
		var stored: Variant = _read_stored(config, key, _loaded_version)
		if stored != null:
			_applied[key] = _validate(key, stored)
	_pending = _applied.duplicate(true)


func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("meta", "version", VERSION)
	for key in _applied.keys():
		var section := _section_for(key)
		config.set_value(section, key, _applied[key])
	config.save(SETTINGS_PATH)


func apply_all() -> void:
	_ensure_buses()
	_apply_audio()
	_apply_display()
	_apply_input()
	changed.emit("all")


func apply_all_preview() -> void:
	_apply_audio()
	_apply_display()
	_apply_input()
	changed.emit("all")


func _preview(key: String) -> void:
	if key in ["master_volume", "sfx_volume", "ui_volume"]:
		_apply_audio()
	elif key in ["window_mode", "resolution", "vsync", "fps_limit", "render_scale"]:
		_apply_display()
	elif SettingsSchema.KEY_ACTIONS.has(key):
		_apply_input()
	changed.emit(key)


func _validate(key: String, value: Variant) -> Variant:
	var definition := SettingsSchema.definition(key)
	if definition.is_empty():
		return value
	var type := String(definition.get("type", "toggle"))
	if SettingsSchema.KEY_ACTIONS.has(key):
		var encoded := String(value)
		if encoded.is_empty():
			return definition.get("default", "")
		var event := SettingsSchema.event_from_string(encoded)
		return encoded if SettingsSchema.string_from_event(event) == encoded else definition.get("default", "")
	match type:
		"slider":
			var number := clampf(float(value), float(definition["min"]), float(definition["max"]))
			var step := float(definition.get("step", 0.0))
			if step > 0.0:
				number = snappedf(number, step)
			return number
		"toggle":
			return bool(value)
		"select":
			var selected := String(value)
			if key == "resolution":
				var parts := selected.split("x")
				if parts.size() == 2 and int(parts[0]) > 0 and int(parts[1]) > 0:
					return selected
				return String(definition.get("default", ""))
			for option in definition.get("options", []):
				if String(option[0]) == selected:
					return selected
			return String(definition.get("default", ""))
	return value


func _read_stored(config: ConfigFile, key: String, version: int) -> Variant:
	var section := _section_for(key)
	if config.has_section_key(section, key):
		return config.get_value(section, key)
	if version < 2:
		match key:
			"master_volume":
				return _legacy_value(config, "audio", "master_volume")
			"window_mode":
				var legacy_fullscreen = _legacy_value(config, "display", "fullscreen")
				return "fullscreen" if legacy_fullscreen != null and bool(legacy_fullscreen) else "windowed"
			"vsync":
				return _legacy_value(config, "display", "vsync")
			"hud_scale":
				return _legacy_value(config, "ui", "hud_scale")
			"reduced_motion":
				return _legacy_value(config, "accessibility", "reduced_motion")
			"high_contrast":
				return _legacy_value(config, "accessibility", "high_contrast")
			_:
				return null
	return null


func _legacy_value(config: ConfigFile, section: String, key: String) -> Variant:
	if config.has_section_key(section, key):
		return config.get_value(section, key)
	return null


func _section_for(key: String) -> String:
	if SettingsSchema.KEY_ACTIONS.has(key):
		return "input"
	var category := String(SettingsSchema.definition(key).get("category", "ui"))
	match category:
		"controls": return "controls"
		"display": return "display"
		"audio": return "audio"
		"accessibility": return "accessibility"
		_: return "ui"


func _ensure_buses() -> void:
	for bus_name in ["SFX", "UI"]:
		if AudioServer.get_bus_index(bus_name) >= 0:
			continue
		AudioServer.add_bus()
		var index := AudioServer.bus_count - 1
		AudioServer.set_bus_name(index, bus_name)
		AudioServer.set_bus_send(index, "Master")


func _apply_audio() -> void:
	_set_bus("Master", float(_pending.get("master_volume", 0.85)))
	_set_bus("SFX", float(_pending.get("sfx_volume", 1.0)))
	_set_bus("UI", float(_pending.get("ui_volume", 1.0)))


func _set_bus(bus_name: String, value: float) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	if index < 0:
		return
	if value <= 0.001:
		AudioServer.set_bus_mute(index, true)
	else:
		AudioServer.set_bus_mute(index, false)
		AudioServer.set_bus_volume_db(index, linear_to_db(clampf(value, 0.0, 1.0)))


func _apply_display() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var mode := String(_pending.get("window_mode", "windowed"))
	match mode:
		"borderless":
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		"fullscreen":
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
		_:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	if mode != "fullscreen":
		var parts := String(_pending.get("resolution", "1280x720")).split("x")
		if parts.size() == 2:
			DisplayServer.window_set_size(Vector2i(int(parts[0]), int(parts[1])))
	DisplayServer.window_set_vsync_mode(
		DisplayServer.VSYNC_ENABLED if bool(_pending.get("vsync", true)) else DisplayServer.VSYNC_DISABLED
	)
	Engine.max_fps = int(_pending.get("fps_limit", 0))
	var root := get_tree().root
	if root != null:
		root.scaling_3d_scale = clampf(float(_pending.get("render_scale", 1.0)), 0.5, 1.0)


func _apply_input() -> void:
	for action in SettingsSchema.KEY_ACTIONS.keys():
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		InputMap.action_erase_events(action)
		var encoded := String(_pending.get(action, SettingsSchema.KEY_ACTIONS[action]["default"]))
		var event := SettingsSchema.event_from_string(encoded)
		if SettingsSchema.string_from_event(event) == encoded:
			InputMap.action_add_event(action, event)
		else:
			InputMap.action_add_event(action, SettingsSchema.event_from_string(SettingsSchema.KEY_ACTIONS[action]["default"]))


func set_master_volume(value: float) -> void:
	set_pending("master_volume", value)
	apply()


func set_fullscreen(value: bool) -> void:
	set_pending("window_mode", "fullscreen" if value else "windowed")
	apply()


func set_vsync(value: bool) -> void:
	set_pending("vsync", value)
	apply()


func set_hud_scale(value: float) -> void:
	set_pending("hud_scale", value)
	apply()


func set_reduced_motion(value: bool) -> void:
	set_pending("reduced_motion", value)
	apply()


func set_high_contrast(value: bool) -> void:
	set_pending("high_contrast", value)
	apply()


func motion_duration(seconds: float) -> float:
	return 0.001 if reduced_motion else seconds


func hud_scale_percent() -> int:
	return int(round(hud_scale * 100.0))


func settings_version() -> int:
	return VERSION


func loaded_version() -> int:
	return _loaded_version


func bus_names() -> Array:
	var result: Array = []
	for i in range(AudioServer.bus_count):
		result.append(AudioServer.get_bus_name(i))
	return result
