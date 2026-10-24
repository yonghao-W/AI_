class_name DamageVignette
extends Control

var _flash := 0.0
var _low_health := false
var _time := 0.0
var _strength_scale := 1.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func flash(strength: float = 0.8) -> void:
	_flash = maxf(_flash, strength)


func set_low_health(value: bool) -> void:
	_low_health = value


func set_strength(value: float) -> void:
	_strength_scale = clampf(value, 0.0, 1.0)
	queue_redraw()


func _process(delta: float) -> void:
	_time += delta
	_flash = maxf(0.0, _flash - delta * 2.6)
	queue_redraw()


func _draw() -> void:
	var size := get_rect().size
	var strength := _flash * 0.8 * _strength_scale
	if _low_health:
		strength = maxf(strength, (0.35 + 0.15 * sin(_time * 4.2)) * _strength_scale)
	if strength <= 0.01:
		return
	for i in range(9):
		var depth := 3.0 + i * 5.0
		var alpha := strength * 0.12 * (1.0 - i / 9.0)
		var color := Color(0.65, 0.06, 0.05, alpha)
		draw_rect(Rect2(0, 0, size.x, depth), color)
		draw_rect(Rect2(0, size.y - depth, size.x, depth), color)
		draw_rect(Rect2(0, 0, depth, size.y), color)
		draw_rect(Rect2(size.x - depth, 0, depth, size.y), color)
	if _flash > 0.05:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.7, 0.05, 0.04, _flash * 0.08))
