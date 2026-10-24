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


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.025, 0.045, 0.055, 0.86))
	draw_rect(Rect2(Vector2(3, 3), size - Vector2(6, 6)), Color(0.17, 0.29, 0.32, 0.65), false, 1.0)
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
			draw_rect(rect, Color("#35543b"))
			draw_rect(rect.grow(-2.0), Color("#416448"))
		else:
			draw_rect(rect, Color("#303e47"))
			for building in block["buildings"]:
				var b_center: Vector2 = building["center"]
				var b_size: Vector3 = building["size"]
				var btl := _map_point(Vector3(b_center.x - b_size.x * 0.5, 0, b_center.y - b_size.z * 0.5))
				var bbr := _map_point(Vector3(b_center.x + b_size.x * 0.5, 0, b_center.y + b_size.z * 0.5))
				draw_rect(Rect2(btl, bbr - btl), Color("#50616b"))
				draw_rect(Rect2(btl, Vector2(bbr.x - btl.x, 1.0)), Color(0.55, 0.66, 0.68, 0.35))
		if bool(block.get("fountain", false)):
			draw_circle(_map_point(Vector3(center.x, 0, center.y)), 3.0, Color("#66c3c8"))
	draw_rect(Rect2(Vector2(4, 4), size - Vector2(8, 8)), Color(0.75, 0.28, 0.23, 0.6), false, 2.0)
	for marker in _markers:
		var marker_pos: Vector3 = marker.get("pos", Vector3.ZERO)
		var color: Color = marker.get("color", Color.WHITE)
		var kind := String(marker.get("kind", "point"))
		var point := _map_point(marker_pos)
		if kind == "safe":
			var radius := float(marker.get("radius", 7.0)) * (size.x - 14.0) / (_half * 2.0)
			draw_circle(point, radius, Color(color, 0.14))
			draw_arc(point, radius, 0.0, TAU, 32, Color(color, 0.75), 1.4)
			draw_circle(point, 2.8, color)
		elif kind == "gateway":
			var diamond := PackedVector2Array([
				point + Vector2(0, -5.0), point + Vector2(4.2, 0),
				point + Vector2(0, 5.0), point + Vector2(-4.2, 0),
			])
			draw_colored_polygon(diamond, Color(0, 0, 0, 0.7))
			var inner := PackedVector2Array([
				point + Vector2(0, -3.4), point + Vector2(2.8, 0),
				point + Vector2(0, 3.4), point + Vector2(-2.8, 0),
			])
			draw_colored_polygon(inner, color)
		else:
			draw_circle(point, 4.4, Color(0, 0, 0, 0.8))
			draw_circle(point, 2.8, color)
			draw_arc(point, 4.8, 0.0, TAU, 16, Color(color, 0.6), 1.0)
	for zombie in _zombies:
		var pos: Vector3 = zombie.get("pos", Vector3.ZERO)
		var kind := String(zombie.get("kind", "walker"))
		var color := Color("#88b95b")
		if kind == "crawler":
			color = Color("#d8c36b")
		elif kind == "runner":
			color = Color("#c4cf5d")
		elif kind == "brute":
			color = Color("#d07650")
		draw_circle(_map_point(pos), 3.2, Color(0, 0, 0, 0.75))
		draw_circle(_map_point(pos), 2.1, color)
	for remote in _remotes:
		var pos: Vector3 = remote.get("pos", Vector3.ZERO)
		var color: Color = remote.get("color", Color.WHITE)
		draw_circle(_map_point(pos), 3.6, Color(0, 0, 0, 0.7))
		draw_circle(_map_point(pos), 2.6, color)
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
	draw_colored_polygon(triangle, Color("#f4f7f2"))
	draw_circle(local, 2.2, Color("#59d8c8"))
	var font := DeadCityUI.display_font()
	draw_string(font, Vector2(9, 16), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.72, 0.85, 0.82, 0.8))
