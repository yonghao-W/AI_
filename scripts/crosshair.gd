class_name DeadCrosshair
extends Control

var _spread := 0.25
var _hit_timer := 0.0
var _headshot := false
var _kill := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(56, 56)
	size = Vector2(56, 56)


func set_spread(value: float) -> void:
	_spread = clampf(value, 0.0, 1.0)


func show_hit(headshot: bool, kill: bool = false) -> void:
	_hit_timer = 0.22
	_headshot = headshot
	_kill = kill


func _process(delta: float) -> void:
	if _hit_timer > 0.0:
		_hit_timer = maxf(0.0, _hit_timer - delta)
	queue_redraw()


func _draw() -> void:
	var center := size * 0.5
	var gap := 5.0 + _spread * 14.0
	var length := 6.0 + _spread * 3.0
	var color := Color(0.94, 0.98, 0.96, 0.92)
	var shadow := Color(0.0, 0.0, 0.0, 0.55)
	for direction in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		var start: Vector2 = center + direction * gap
		var finish: Vector2 = center + direction * (gap + length)
		draw_line(start, finish, shadow, 3.2)
		draw_line(start, finish, color, 1.4)
	draw_circle(center, 2.7, shadow)
	draw_circle(center, 1.5, color)
	if _hit_timer > 0.0:
		var alpha := clampf(_hit_timer / 0.22, 0.0, 1.0)
		var hit_color := Color(1.0, 0.83, 0.38, alpha)
		if _headshot:
			hit_color = Color(1.0, 0.35, 0.3, alpha)
		if _kill:
			hit_color = Color(1.0, 0.56, 0.24, alpha)
		var inner := 5.0
		var outer := 12.0
		for direction in [Vector2(1, 1), Vector2(1, -1), Vector2(-1, 1), Vector2(-1, -1)]:
			var dir := (direction as Vector2).normalized()
			draw_line(center + dir * inner, center + dir * outer, Color(0, 0, 0, alpha * 0.6), 3.0)
			draw_line(center + dir * inner, center + dir * outer, hit_color, 1.8)
