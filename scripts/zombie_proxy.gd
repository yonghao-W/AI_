class_name ZombieProxy
extends Node3D

var zombie_id := 0
var kind := "walker"
var _scale := 1.0
var _head_height := 1.55
var _target_pos := Vector3.ZERO
var _target_yaw := 0.0
var _state := 0
var _phase := 0.0
var _initialized := false
var _dying := false
var _flash_timer := 0.0
var _rig: Node3D
var _model: Node3D
var _body: StaticBody3D
var _left_leg: Node3D
var _right_leg: Node3D
var _left_arm: Node3D
var _right_arm: Node3D
var _head: MeshInstance3D
var _meshes: Array[MeshInstance3D] = []
var _materials: Dictionary = {}
var _unit_box: BoxMesh
var _overlay_material: StandardMaterial3D


func setup(id: int, kind_id: String) -> void:
	zombie_id = id
	kind = kind_id
	_unit_box = BoxMesh.new()
	_unit_box.size = Vector3.ONE
	_materials.clear()
	_meshes.clear()
	match kind:
		"crawler":
			_scale = 0.64
		"runner":
			_scale = 0.9
		"brute":
			_scale = 1.32
		_:
			_scale = 1.0
	_head_height = 0.95 if kind == "crawler" else 1.5 * _scale
	add_to_group("zombie_proxies")
	_build()
	_build_collision()
	_rig.scale = Vector3.ONE * _scale * 0.1
	var tween := create_tween()
	tween.tween_property(_rig, "scale", Vector3.ONE * _scale, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _build() -> void:
	_rig = Node3D.new()
	add_child(_rig)
	_model = Node3D.new()
	_rig.add_child(_model)
	var body_color := Color("#759b50")
	var skin := Color("#93b563")
	var pants := Color("#38423a")
	var shirt_dark := Color("#4e6339")
	if kind == "crawler":
		body_color = Color("#c2b26a")
		skin = Color("#d2c583")
		pants = Color("#4a4433")
		shirt_dark = Color("#786d42")
	elif kind == "runner":
		body_color = Color("#b1bf52")
		skin = Color("#c6ce6c")
		pants = Color("#41442f")
		shirt_dark = Color("#6d7838")
	elif kind == "brute":
		body_color = Color("#bb6b48")
		skin = Color("#cd8058")
		pants = Color("#4b3831")
		shirt_dark = Color("#7c4534")
	var uniform := _mat(body_color, 0.95)
	var skin_mat := _mat(skin, 0.9)
	var pants_mat := _mat(pants, 0.98)
	var dark := _mat(shirt_dark, 0.98)
	var eye := _mat(Color("#ff5b4d"), 0.4)
	eye.emission_enabled = true
	eye.emission = Color("#ff5b4d")
	eye.emission_energy_multiplier = 4.0
	eye.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	_part(_model, Vector3(0.68, 0.82, 0.4), Vector3(0.0, 1.26, 0.0), uniform)
	_part(_model, Vector3(0.72, 0.22, 0.44), Vector3(0.0, 0.9, 0.0), pants_mat)
	_part(_model, Vector3(0.5, 0.28, 0.42), Vector3(0.0, 1.58, 0.0), dark)
	if kind == "brute":
		_part(_model, Vector3(0.92, 0.26, 0.52), Vector3(0.0, 1.5, 0.0), dark)
		_part(_model, Vector3(0.28, 0.18, 0.5), Vector3(-0.48, 1.48, 0.0), uniform)
		_part(_model, Vector3(0.28, 0.18, 0.5), Vector3(0.48, 1.48, 0.0), uniform)
	_head = _part(_model, Vector3(0.42, 0.42, 0.4), Vector3(0.0, 1.79, 0.0), skin_mat)
	_part(_model, Vector3(0.32, 0.14, 0.12), Vector3(0.0, 1.63, -0.21), skin_mat)
	_part(_model, Vector3(0.24, 0.05, 0.06), Vector3(0.0, 1.62, -0.28), _mat(Color("#3d2b23"), 0.9))
	_part(_model, Vector3(0.075, 0.055, 0.055), Vector3(-0.1, 1.84, -0.21), eye)
	_part(_model, Vector3(0.075, 0.055, 0.055), Vector3(0.1, 1.84, -0.21), eye)
	_part(_model, Vector3(0.2, 0.08, 0.05), Vector3(0.0, 1.91, -0.19), _mat(Color("#242c23"), 0.9))
	for side in [-1.0, 1.0]:
		var hair := _part(_model, Vector3(0.13, 0.08, 0.3), Vector3(0.16 * side, 2.01, 0.02), _mat(Color("#2e372a"), 1.0))
		hair.rotation.z = 0.15 * side
	_left_arm = Node3D.new()
	_left_arm.position = Vector3(-0.43, 1.48, 0.0)
	_model.add_child(_left_arm)
	_part(_left_arm, Vector3(0.16, 0.16, 0.72), Vector3(0.0, 0.0, -0.3), uniform)
	_part(_left_arm, Vector3(0.14, 0.14, 0.16), Vector3(0.0, 0.0, -0.72), skin_mat)
	_right_arm = Node3D.new()
	_right_arm.position = Vector3(0.43, 1.48, 0.0)
	_model.add_child(_right_arm)
	_part(_right_arm, Vector3(0.16, 0.16, 0.72), Vector3(0.0, 0.0, -0.3), uniform)
	_part(_right_arm, Vector3(0.14, 0.14, 0.16), Vector3(0.0, 0.0, -0.72), skin_mat)
	_left_leg = Node3D.new()
	_left_leg.position = Vector3(-0.18, 0.85, 0.0)
	_model.add_child(_left_leg)
	_part(_left_leg, Vector3(0.22, 0.84, 0.24), Vector3(0.0, -0.42, 0.0), pants_mat)
	_part(_left_leg, Vector3(0.24, 0.14, 0.34), Vector3(0.0, -0.8, -0.05), _mat(Color("#232a24"), 0.95))
	_right_leg = Node3D.new()
	_right_leg.position = Vector3(0.18, 0.85, 0.0)
	_model.add_child(_right_leg)
	_part(_right_leg, Vector3(0.22, 0.84, 0.24), Vector3(0.0, -0.42, 0.0), pants_mat)
	_part(_right_leg, Vector3(0.24, 0.14, 0.34), Vector3(0.0, -0.8, -0.05), _mat(Color("#232a24"), 0.95))
	if kind == "crawler":
		_model.rotation.x = 0.92
		_model.position.y = -0.05
		_left_arm.rotation.x = -1.4
		_right_arm.rotation.x = -1.4
	elif kind == "runner":
		_left_arm.rotation.x = -0.35
		_right_arm.rotation.x = -0.45
		_model.rotation.x = -0.16
	elif kind == "brute":
		_model.rotation.x = 0.08
	_overlay_material = _mat(Color("#ffffff"), 0.0)
	_overlay_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED


func _part(parent: Node3D, size: Vector3, pos: Vector3, material: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = _unit_box
	node.scale = size
	node.position = pos
	node.material_override = material
	parent.add_child(node)
	_meshes.append(node)
	return node


func _build_collision() -> void:
	_body = StaticBody3D.new()
	_body.collision_layer = 4
	_body.collision_mask = 0
	_body.name = "Hitbox"
	var capsule := CapsuleShape3D.new()
	if kind == "crawler":
		capsule.radius = 0.34
		capsule.height = 1.15
	else:
		capsule.radius = 0.4 * _scale
		capsule.height = 1.95 * _scale
	var shape := CollisionShape3D.new()
	shape.shape = capsule
	shape.position.y = 0.58 if kind == "crawler" else 0.98 * _scale
	_body.add_child(shape)
	_body.set_meta("zombie_id", zombie_id)
	_body.set_meta("zombie_proxy", self)
	add_child(_body)


func set_network_state(pos: Vector3, yaw: float, state: int) -> void:
	if _dying:
		return
	_target_pos = Vector3(pos.x, maxf(pos.y, 0.0), pos.z)
	_target_yaw = yaw
	_state = state
	if not _initialized:
		global_position = _target_pos
		rotation.y = yaw
		_initialized = true


func _process(delta: float) -> void:
	if not _initialized or _dying:
		return
	var previous := global_position
	global_position = global_position.lerp(_target_pos, clampf(delta * 11.0, 0.0, 1.0))
	rotation.y = lerp_angle(rotation.y, _target_yaw, clampf(delta * 10.0, 0.0, 1.0))
	var moved := previous.distance_to(global_position) / maxf(delta, 0.0001)
	_phase += delta * (3.0 + minf(moved, 8.0) * 1.4)
	var swing := sin(_phase) * clampf(moved * 0.18, 0.0, 0.75)
	if kind == "crawler":
		var crawl := sin(_phase * 2.2)
		if _state == 1:
			_left_arm.rotation.x = -1.72 + sin(_phase * 6.0) * 0.24
			_right_arm.rotation.x = -1.72 - sin(_phase * 6.0) * 0.24
			_model.position.z = -0.16
		else:
			_left_arm.rotation.x = -1.4 + crawl * 0.32
			_right_arm.rotation.x = -1.4 - crawl * 0.32
			_model.position.z = 0.0
		_left_leg.rotation.x = 0.5 - crawl * 0.28
		_right_leg.rotation.x = 0.5 + crawl * 0.28
	elif _state == 1:
		swing = sin(_phase * 2.6) * 0.2
		var lunge := -1.15 + sin(_phase * 5.0) * 0.32
		_left_arm.rotation.x = lunge
		_right_arm.rotation.x = lunge - 0.18
		_model.position.z = -0.14 + sin(_phase * 4.0) * 0.05
		_left_leg.rotation.x = swing
		_right_leg.rotation.x = -swing
	else:
		_left_arm.rotation.x = -0.18 + swing * 0.35
		_right_arm.rotation.x = -0.24 - swing * 0.35
		_model.position.z = 0.0
		_left_leg.rotation.x = swing
		_right_leg.rotation.x = -swing
	_head.rotation.z = sin(_phase * 0.7) * 0.08
	_rig.position.y = absf(sin(_phase)) * 0.035
	_flash_timer = maxf(0.0, _flash_timer - delta)
	for mesh in _meshes:
		mesh.material_overlay = _overlay_material if _flash_timer > 0.0 else null


func receive_hit(headshot: bool) -> void:
	if _dying:
		return
	_flash_timer = 0.065 if not headshot else 0.11


func play_death() -> void:
	if _dying:
		return
	_dying = true
	remove_from_group("zombie_proxies")
	_body.collision_layer = 0
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_model, "rotation:x", -PI * 0.5, 0.38).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(_rig, "position:y", 0.18, 0.38)
	tween.chain().tween_interval(0.45)
	tween.chain().tween_callback(queue_free)


func is_targetable() -> bool:
	return _initialized and not _dying and is_inside_tree()


func head_height() -> float:
	return _head_height


func _mat(color: Color, roughness: float = 0.9) -> StandardMaterial3D:
	var key := "%s|%.2f" % [color.to_html(), roughness]
	if _materials.has(key):
		return _materials[key]
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	_materials[key] = material
	return material
