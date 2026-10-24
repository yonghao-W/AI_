class_name MenuFeedback
extends Control
## 单节点、可复用的菜单点击反馈；不创建/销毁大量临时节点。

var _ripples: Array = []
var _enabled := true


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	set_process(true)


func set_enabled(value: bool) -> void:
	_enabled = value
	if not value:
		_ripples.clear()
		queue_redraw()


func add_ripple(point: Vector2) -> void:
	if not _enabled:
		return
	_ripples.append({"pos": point, "age": 0.0})
	queue_redraw()


func _process(delta: float) -> void:
	if _ripples.is_empty():
		return
	for ripple in _ripples:
		ripple["age"] = float(ripple["age"]) + delta
	_ripples = _ripples.filter(func(r: Dictionary) -> bool: return float(r["age"]) < 0.6)
	queue_redraw()


func _draw() -> void:
	for ripple in _ripples:
		var age := float(ripple["age"])
		var t := clampf(age / 0.55, 0.0, 1.0)
		var radius := lerpf(5.0, 62.0, ease(t, 0.3))
		var alpha := (1.0 - t) * 0.55
		draw_arc(ripple["pos"], radius, 0.0, TAU, 40, Color(0.95, 0.80, 0.55, alpha), 1.0, true)
		if t < 0.65:
			for i in range(3):
				var angle := TAU * float(i) / 3.0 + 0.4
				var start: Vector2 = ripple["pos"] + Vector2(cos(angle), sin(angle)) * (8.0 + t * 18.0)
				var end: Vector2 = start + Vector2(cos(angle), sin(angle)) * 5.0
				draw_line(start, end, Color(0.98, 0.86, 0.64, alpha * 0.8), 1.0, true)
