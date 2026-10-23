class_name MenuBackdrop
extends Control

var _time := 0.0
var _far_buildings: Array[Rect2] = []
var _near_buildings: Array[Rect2] = []
var _windows: Array[Dictionary] = []
var _ash: Array[Vector3] = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_rng.seed = 731993
	_build_city()
	for i in range(46):
		_ash.append(Vector3(_rng.randf(), _rng.randf(), _rng.randf_range(0.2, 1.0)))


func _build_city() -> void:
	var x := -40.0
	while x < 1320.0:
		var width := _rng.randf_range(45.0, 130.0)
		var height := _rng.randf_range(70.0, 260.0)
		_far_buildings.append(Rect2(x, 520.0 - height, width, height))
		x += width + _rng.randf_range(6.0, 26.0)
	x = -60.0
	while x < 1340.0:
		var width := _rng.randf_range(70.0, 190.0)
		var height := _rng.randf_range(130.0, 360.0)
		_near_buildings.append(Rect2(x, 720.0 - height, width, height))
		var cols := int(width / 26.0)
		var rows := int(height / 38.0)
		for cx in range(cols):
			for cy in range(rows):
				if _rng.randf() < 0.32:
					continue
				var w := _rng.randf_range(5.0, 12.0)
				var h := _rng.randf_range(3.0, 8.0)
				_windows.append({
					"pos": Vector2(x + 14.0 + cx * 26.0, 720.0 - height + 22.0 + cy * 38.0),
					"size": Vector2(w, h),
					"warm": _rng.randf() < 0.64,
					"alpha": _rng.randf_range(0.25, 0.9),
				})
		x += width + _rng.randf_range(10.0, 36.0)


func _process(delta: float) -> void:
	_time += delta
	for i in range(_ash.size()):
		var particle := _ash[i]
		particle.y += delta * (0.012 + particle.z * 0.025)
		particle.x += delta * (0.004 + particle.z * 0.006) * sin(_time * 0.3 + i)
		if particle.y > 1.0:
			particle.y = -0.02
			particle.x = _rng.randf()
		_ash[i] = particle
	queue_redraw()


func _draw() -> void:
	var size := get_rect().size
	_draw_sky(size)
	_draw_moon(size)
	_draw_far_skyline(size)
	_draw_near_skyline(size)
	_draw_fog(size)
	_draw_ash(size)
	_draw_corner_marks(size)


func _draw_sky(size: Vector2) -> void:
	var top := Color("#081018")
	var middle := Color("#15232a")
	var bottom := Color("#242e2d")
	var bands := 48
	for i in range(bands):
		var t := float(i) / float(bands - 1)
		var color := top.lerp(middle, clampf(t * 1.8, 0.0, 1.0)) if t < 0.55 else middle.lerp(bottom, (t - 0.55) / 0.45)
		draw_rect(Rect2(0.0, size.y * t, size.x, size.y / bands + 1.0), color)
	var glow := Color(0.36, 0.66, 0.58, 0.05)
	draw_circle(Vector2(size.x * 0.76, size.y * 0.24), size.y * 0.5, glow)
	draw_circle(Vector2(size.x * 0.76, size.y * 0.24), size.y * 0.28, Color(0.36, 0.66, 0.58, 0.035))


func _draw_moon(size: Vector2) -> void:
	var moon := Vector2(size.x * 0.775, size.y * 0.22)
	for radius in [130.0, 82.0, 56.0]:
		draw_circle(moon, radius, Color(0.85, 0.88, 0.77, 0.015))
	draw_circle(moon, 38.0, Color("#d4d9c5"))
	draw_circle(moon + Vector2(-12.0, -8.0), 31.0, Color("#aab5a4").lerp(Color("#d4d9c5"), 0.5))
	draw_circle(moon + Vector2(7.0, 5.0), 38.0, Color(0.09, 0.12, 0.14, 0.93))
	for i in range(28):
		var x := fmod(i * 137.0 + 40.0, size.x)
		var y := fmod(i * 83.0 + 20.0, size.y * 0.6)
		var alpha := 0.25 + 0.25 * sin(_time * 0.7 + i)
		draw_circle(Vector2(x, y), 1.2, Color(0.85, 0.9, 0.85, alpha))


func _draw_far_skyline(size: Vector2) -> void:
	var offset_y := (size.y - 720.0) * 0.35
	for building in _far_buildings:
		var rect := Rect2(building.position.x, building.position.y + offset_y, building.size.x, building.size.y)
		draw_rect(rect, Color("#18262b"))
		draw_rect(Rect2(rect.position, Vector2(rect.size.x, 4.0)), Color("#21333a"))
		if int(rect.size.x) % 3 == 0:
			draw_rect(Rect2(rect.position.x + 8.0, rect.position.y - 20.0, 4.0, 20.0), Color("#1d2d33"))


func _draw_near_skyline(size: Vector2) -> void:
	var offset_y := (size.y - 720.0) * 0.7
	for building in _near_buildings:
		var rect := Rect2(building.position.x, building.position.y + offset_y, building.size.x, building.size.y)
		draw_rect(rect, Color("#0e171c"))
		draw_rect(Rect2(rect.position, Vector2(rect.size.x, 5.0)), Color("#1c2c30"))
		for wx in range(int(rect.position.x / 37.0), int(rect.end.x / 37.0)):
			var beam := Color(0.18, 0.3, 0.29, 0.04)
			draw_rect(Rect2(wx * 37.0, rect.position.y, 1.0, rect.size.y), beam)
	for window in _windows:
		var pos: Vector2 = window["pos"] + Vector2(0.0, offset_y)
		var color := Color(1.0, 0.79, 0.48, float(window["alpha"])) if bool(window["warm"]) else Color(0.52, 0.78, 0.81, float(window["alpha"]) * 0.8)
		draw_rect(Rect2(pos, window["size"]), color)
	var horizon_y := 720.0 - 130.0 + offset_y
	draw_line(Vector2(0.0, horizon_y), Vector2(size.x, horizon_y), Color(0.74, 0.25, 0.21, 0.22), 2.0)


func _draw_fog(size: Vector2) -> void:
	for i in range(5):
		var y := size.y * (0.62 + i * 0.07) + sin(_time * 0.16 + i * 1.7) * 5.0
		var alpha := 0.035 + i * 0.017
		var drift := fmod(_time * (6.0 + i * 2.0), size.x)
		draw_rect(Rect2(-size.x + drift, y, size.x * 2.0, 26.0 + i * 9.0), Color(0.58, 0.68, 0.66, alpha))
		draw_rect(Rect2(drift, y + 9.0, size.x * 2.0, 16.0), Color(0.55, 0.66, 0.64, alpha * 0.7))
	var pulse := 0.05 + 0.03 * sin(_time * 1.4)
	draw_rect(Rect2(0.0, size.y - 160.0, size.x, 160.0), Color(0.35, 0.08, 0.06, pulse))


func _draw_ash(size: Vector2) -> void:
	for particle in _ash:
		var pos := Vector2(particle.x * size.x + sin(_time + particle.y * 20.0) * 4.0, particle.y * size.y)
		draw_circle(pos, 0.8 + particle.z * 1.6, Color(0.82, 0.84, 0.78, 0.12 + particle.z * 0.2))


func _draw_corner_marks(size: Vector2) -> void:
	var color := Color(0.35, 0.85, 0.8, 0.28)
	var length := 32.0
	var margin := 22.0
	draw_line(Vector2(margin, margin), Vector2(margin + length, margin), color, 2.0)
	draw_line(Vector2(margin, margin), Vector2(margin, margin + length), color, 2.0)
	draw_line(Vector2(size.x - margin, margin), Vector2(size.x - margin - length, margin), color, 2.0)
	draw_line(Vector2(size.x - margin, margin), Vector2(size.x - margin, margin + length), color, 2.0)
	draw_line(Vector2(margin, size.y - margin), Vector2(margin + length, size.y - margin), color, 2.0)
	draw_line(Vector2(margin, size.y - margin), Vector2(margin, size.y - margin - length), color, 2.0)
	draw_line(Vector2(size.x - margin, size.y - margin), Vector2(size.x - margin - length, size.y - margin), color, 2.0)
	draw_line(Vector2(size.x - margin, size.y - margin), Vector2(size.x - margin, size.y - margin - length), color, 2.0)
	draw_string(DeadCityUI.display_font(), Vector2(margin + 8.0, size.y - margin - 8.0), "DEAD CITY // CO-OP", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.55, 0.7, 0.7, 0.45))
	draw_string(DeadCityUI.display_font(), Vector2(size.x - 260.0, margin + 16.0), "QUARANTINE ZONE 07", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.72, 0.32, 0.28, 0.55))
