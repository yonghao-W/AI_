class_name DeadMiniMap
extends Control

var _layout: Dictionary = {}
var _half := 100.0
var _local_pos := Vector3.ZERO
var _local_yaw := 0.0
var _remotes: Array = []
var _zombies: Array = []
var _markers: Array = []
var _has_local := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(188, 188)
	size = Vector2(188, 188)


func setup(layout: Dictionary) -> void:
	_layout = layout
	_half = float(layout.get("total_size", 200.0)) * 0.5
	queue_redraw()


func update_entities(local_pos: Vector3, local_yaw: float, remotes: Array, zombies: Array, markers: Array = []) -> void:
	_local_pos = local_pos
	_local_yaw = local_yaw
	_remotes = remotes
	_zombies = zombies
	_markers = markers
	_has_local = true
	queue_redraw()


func _map_point(world: Vector3) -> Vector2:
	var rect := Rect2(Vector2(7, 7), size - Vector2(14, 14))
	var u := (world.x + _half) / (_half * 2.0)
	var v := (world.z + _half) / (_half * 2.0)
	return rect.position + Vector2(clampf(u, 0.0, 1.0), clampf(v, 0.0, 1.0)) * rect.size


func _draw_diamond(center: Vector2, radius: float, color: Color) -> void:
	var outer := PackedVector2Array([
		center + Vector2(0, -radius - 1.2), center + Vector2(radius + 1.2, 0),
		center + Vector2(0, radius + 1.2), center + Vector2(-radius - 1.2, 0),
	])
	draw_colored_polygon(outer, Color(0, 0, 0, 0.72))
	var inner := PackedVector2Array([
		center + Vector2(0, -radius), center + Vector2(radius, 0),
		center + Vector2(0, radius), center + Vector2(-radius, 0),
	])
	draw_colored_polygon(inner, color)


func _draw_square(center: Vector2, radius: float, color: Color, outline: Color = Color(0, 0, 0, 0.72)) -> void:
	draw_rect(Rect2(center - Vector2(radius + 1.0, radius + 1.0), Vector2(radius + 1.0, radius + 1.0) * 2.0), outline)
	draw_rect(Rect2(center - Vector2(radius, radius), Vector2(radius, radius) * 2.0), color)


func _draw_triangle(center: Vector2, radius: float, color: Color) -> void:
	var outer := PackedVector2Array([
		center + Vector2(0, -radius - 1.2),
		center + Vector2(radius + 1.0, radius),
		center + Vector2(-radius - 1.0, radius),
	])
	draw_colored_polygon(outer, Color(0, 0, 0, 0.72))
	var inner := PackedVector2Array([
		center + Vector2(0, -radius),
		center + Vector2(radius, radius * 0.78),
		center + Vector2(-radius, radius * 0.78),
	])
	draw_colored_polygon(inner, color)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.035, 0.04, 0.04, 0.84))
	draw_rect(Rect2(Vector2(3, 3), size - Vector2(6, 6)), Color(0.82, 0.78, 0.7, 0.16), false, 1.0)
	if _layout.is_empty():
		return
	var blocks: Array = _layout.get("blocks", [])
	var block_size := float(_layout.get("block_size", 28.0))
	for block in blocks:
		var center: Vector2 = block["center"]
		var top_left := _map_point(Vector3(center.x - block_size * 0.5, 0, center.y - block_size * 0.5))
		var bottom_right := _map_point(Vector3(center.x + block_size * 0.5, 0, center.y + block_size * 0.5))
		var rect := Rect2(top_left, bottom_right - top_left)
		if block["kind"] == "park":
			draw_rect(rect, Color("#313b2e"))
			draw_rect(rect.grow(-2.0), Color("#3b4736"))
		else:
			draw_rect(rect, Color("#282d2e"))
			for building in block["buildings"]:
				var b_center: Vector2 = building["center"]
				var b_size: Vector3 = building["size"]
				var btl := _map_point(Vector3(b_center.x - b_size.x * 0.5, 0, b_center.y - b_size.z * 0.5))
				var bbr := _map_point(Vector3(b_center.x + b_size.x * 0.5, 0, b_center.y + b_size.z * 0.5))
				draw_rect(Rect2(btl, bbr - btl), Color("#3e4544"))
				draw_rect(Rect2(btl, Vector2(bbr.x - btl.x, 1.0)), Color(0.78, 0.72, 0.62, 0.22))
		if bool(block.get("fountain", false)):
			draw_circle(_map_point(Vector3(center.x, 0, center.y)), 3.0, Color("#7fc3ba"))
	for marker in _markers:
		var marker_pos: Vector3 = marker.get("pos", Vector3.ZERO)
		var color: Color = marker.get("color", Color.WHITE)
		var kind := String(marker.get("kind", "point"))
		var point := _map_point(marker_pos)
		if kind == "safe":
			var radius := float(marker.get("radius", 7.0)) * (size.x - 14.0) / (_half * 2.0)
			draw_circle(point, radius, Color(color, 0.12))
			draw_arc(point, radius, 0.0, TAU, 32, Color(color, 0.65), 1.0)
			draw_circle(point, 2.4, color)
		elif kind == "gateway":
			_draw_diamond(point, 4.6, color)
		elif kind == "core":
			_draw_square(point, 3.4, color)
			draw_arc(point, 5.2, 0.0, TAU, 16, Color(color, 0.45), 1.0)
		else:
			draw_circle(point, 4.2, Color(0, 0, 0, 0.75))
			draw_circle(point, 2.6, color)
			draw_arc(point, 4.6, 0.0, TAU, 16, Color(color, 0.55), 1.0)
	for zombie in _zombies:
		var pos: Vector3 = zombie.get("pos", Vector3.ZERO)
		var kind := String(zombie.get("kind", "walker"))
		var color := Color("#96a06a")
		var shape := "circle"
		if kind == "crawler":
			color = Color("#c9b46a")
			shape = "diamond"
		elif kind == "runner":
			color = Color("#c2cb62")
			shape = "triangle"
		elif kind == "brute":
			color = Color("#cf7a52")
			shape = "square"
		var p := _map_point(pos)
		match shape:
			"diamond":
				_draw_diamond(p, 3.0, color)
			"triangle":
				_draw_triangle(p, 3.1, color)
			"square":
				_draw_square(p, 2.9, color)
			_:
				draw_circle(p, 3.2, Color(0, 0, 0, 0.7))
				draw_circle(p, 1.9, color)
	for remote in _remotes:
		var pos: Vector3 = remote.get("pos", Vector3.ZERO)
		var color: Color = remote.get("color", Color.WHITE)
		var p := _map_point(pos)
		if bool(remote.get("alive", true)):
			_draw_square(p, 2.9, color, Color(0.95, 0.94, 0.9, 0.55))
		else:
			draw_arc(p, 4.0, 0.0, TAU, 16, Color(color, 0.55), 1.0)
			draw_line(p + Vector2(-2.6, -2.6), p + Vector2(2.6, 2.6), DeadCityUI.RED, 1.2)
			draw_line(p + Vector2(2.6, -2.6), p + Vector2(-2.6, 2.6), DeadCityUI.RED, 1.2)
	if not _has_local:
		return
	var local := _map_point(_local_pos)
	var forward := Vector2(-sin(_local_yaw), -cos(_local_yaw))
	var side := Vector2(-forward.y, forward.x)
	var triangle := PackedVector2Array([
		local + forward * 7.0,
		local - forward * 4.0 + side * 4.0,
		local - forward * 4.0 - side * 4.0,
	])
	draw_colored_polygon(triangle, Color(0.06, 0.06, 0.05, 0.85))
	var inner := PackedVector2Array([
		local + forward * 5.8,
		local - forward * 3.0 + side * 3.1,
		local - forward * 3.0 - side * 3.1,
	])
	draw_colored_polygon(inner, Color("#f4f0e6"))
	draw_circle(local, 1.8, Color("#7fc3ba"))
	var font := DeadCityUI.display_font()
	draw_string(font, Vector2(9, 16), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.78, 0.74, 0.66, 0.7))
