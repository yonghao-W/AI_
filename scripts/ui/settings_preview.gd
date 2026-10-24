class_name SettingsPreview
extends Control
## 设置页右栏示意：FOV 与准星大小/颜色/粗细。

var _fov := 78.0
var _color := Color(0.94, 0.98, 0.96, 0.92)
var _size_scale := 1.0
var _thickness := 1.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(0, 168)


func set_state(fov: float, color_name: String, size_scale: float, thickness: float) -> void:
	_fov = clampf(fov, 40.0, 120.0)
	_size_scale = clampf(size_scale, 0.6, 1.6)
	_thickness = clampf(thickness, 0.5, 2.2)
	match color_name:
		"amber":
			_color = DeadCityUI.AMBER
		"mint":
			_color = DeadCityUI.CYAN
		_:
			_color = Color(0.94, 0.98, 0.96, 0.92)
	queue_redraw()


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	draw_rect(rect, Color(0.018, 0.023, 0.028, 0.96))
	draw_rect(rect.grow(-1.0), Color(0.85, 0.82, 0.76, 0.16), false, 1.0)
	var center := size * 0.5
	var half := size.x * 0.5
	var spread := deg_to_rad(_fov * 0.5)
	var length := minf(size.y * 0.42, half * 0.9)
	draw_line(center, center + Vector2(-sin(spread), cos(spread)) * length, Color(0.85, 0.82, 0.76, 0.18), 1.0)
	draw_line(center, center + Vector2(sin(spread), cos(spread)) * length, Color(0.85, 0.82, 0.76, 0.18), 1.0)
	var gap := 7.0 * _size_scale
	var line_length := 7.0 * _size_scale
	for direction in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		var start: Vector2 = center + direction * gap
		var finish: Vector2 = center + direction * (gap + line_length)
		draw_line(start, finish, Color(0, 0, 0, 0.6), 3.0 * _thickness)
		draw_line(start, finish, _color, 1.4 * _thickness)
	draw_circle(center, 2.2 * _size_scale, _color)
