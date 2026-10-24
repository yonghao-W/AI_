extends Node
## 全局显示 / 无障碍设置。真实写入 user://ui_settings.cfg，并在启动时应用。
## 只包含当前工程确实支持的选项；没有音乐总线时不伪造“音乐音量”。

signal changed(key: String)

const SETTINGS_PATH := "user://ui_settings.cfg"

const HUD_SCALES := [0.9, 1.0, 1.1]

var master_volume := 0.85
var fullscreen := false
var vsync := true
var hud_scale := 1.0
var reduced_motion := false
var high_contrast := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_settings()
	apply_all()


func load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return
	master_volume = clampf(float(config.get_value("audio", "master_volume", master_volume)), 0.0, 1.0)
	fullscreen = bool(config.get_value("display", "fullscreen", fullscreen))
	vsync = bool(config.get_value("display", "vsync", vsync))
	hud_scale = clampf(float(config.get_value("ui", "hud_scale", hud_scale)), HUD_SCALES[0], HUD_SCALES[HUD_SCALES.size() - 1])
	reduced_motion = bool(config.get_value("accessibility", "reduced_motion", reduced_motion))
	high_contrast = bool(config.get_value("accessibility", "high_contrast", high_contrast))


func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("audio", "master_volume", master_volume)
	config.set_value("display", "fullscreen", fullscreen)
	config.set_value("display", "vsync", vsync)
	config.set_value("ui", "hud_scale", hud_scale)
	config.set_value("accessibility", "reduced_motion", reduced_motion)
	config.set_value("accessibility", "high_contrast", high_contrast)
	config.save(SETTINGS_PATH)


func apply_all() -> void:
	apply_audio()
	apply_display()
	changed.emit("all")


func apply_audio() -> void:
	var bus := AudioServer.get_bus_index("Master")
	if bus < 0:
		return
	if master_volume <= 0.001:
		AudioServer.set_bus_mute(bus, true)
	else:
		AudioServer.set_bus_mute(bus, false)
		AudioServer.set_bus_volume_db(bus, linear_to_db(master_volume))


func apply_display() -> void:
	if DisplayServer.get_name() == "headless":
		return
	DisplayServer.window_set_vsync_mode(
		DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED
	)
	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)


func set_master_volume(value: float) -> void:
	master_volume = clampf(value, 0.0, 1.0)
	apply_audio()
	save_settings()
	changed.emit("master_volume")


func set_fullscreen(value: bool) -> void:
	fullscreen = value
	apply_display()
	save_settings()
	changed.emit("fullscreen")


func set_vsync(value: bool) -> void:
	vsync = value
	apply_display()
	save_settings()
	changed.emit("vsync")


func set_hud_scale(value: float) -> void:
	hud_scale = clampf(value, HUD_SCALES[0], HUD_SCALES[HUD_SCALES.size() - 1])
	save_settings()
	changed.emit("hud_scale")


func set_reduced_motion(value: bool) -> void:
	reduced_motion = value
	save_settings()
	changed.emit("reduced_motion")


func set_high_contrast(value: bool) -> void:
	high_contrast = value
	save_settings()
	changed.emit("high_contrast")


func motion_duration(seconds: float) -> float:
	return 0.001 if reduced_motion else seconds


func hud_scale_percent() -> int:
	return int(round(hud_scale * 100.0))
