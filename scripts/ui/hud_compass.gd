class_name HUDCompass
extends Control
## V3 顶部罗盘：真实玩家朝向驱动的刻度，中心琥珀标记，N/E/S/W + 度数。

var _heading := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	custom_minimum_size = Vector2(560, 38)


func set_heading(radians: float) -> void:
	_heading = radians
	queue_redraw()


func _draw() -> void:
	var width := size.x
	var center := width * 0.5
	var pixels_per_degree := width / 180.0
	var heading_degrees := fposmod(-rad_to_deg(_heading), 360.0)
	draw_line(Vector2(0, size.y - 4), Vector2(width, size.y - 4), Color(0.9, 0.9, 0.86, 0.16), 1.0)
	var font: Font = ThemeDB.fallback_font
	var first_bearing := ceili((heading_degrees - 90.0) / 5.0) * 5
	var last_bearing := floori((heading_degrees + 90.0) / 5.0) * 5
	for bearing_step in range(first_bearing, last_bearing + 1, 5):
		var bearing := fposmod(float(bearing_step), 360.0)
		var x := center + (bearing_step - heading_degrees) * pixels_per_degree
		var is_major := bearing_step % 15 == 0
		var tick_height := 9.0 if is_major else 4.0
		draw_line(Vector2(x, size.y - 4), Vector2(x, size.y - 4 - tick_height), Color(0.9, 0.9, 0.86, 0.62 if is_major else 0.28), 1.0)
		if is_major:
			var label := _label_for(bearing)
			var label_size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 10)
			var label_x := x - label_size.x * 0.5
			if label_x >= 2.0 and label_x + label_size.x <= width - 2.0:
				draw_string(font, Vector2(label_x, size.y - 18), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.92, 0.9, 0.84, 0.9))
	var marker := PackedVector2Array([
		Vector2(center, size.y - 4),
		Vector2(center - 4.0, size.y + 2.0),
		Vector2(center + 4.0, size.y + 2.0),
	])
	draw_colored_polygon(marker, Color("#e6a75e"))


func _label_for(degrees: float) -> String:
	var rounded := int(round(degrees)) % 360
	match rounded:
		0:
			return "N"
		45:
			return "NE"
		90:
			return "E"
		135:
			return "SE"
		180:
			return "S"
		225:
			return "SW"
		270:
			return "W"
		315:
			return "NW"
		_:
			return "%03d" % rounded
