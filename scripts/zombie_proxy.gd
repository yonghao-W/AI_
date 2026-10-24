class_name ZombieProxy
extends Node3D

var zombie_id := 0
var kind := "walker"
var _scale := 1.0
var _base_scale := 1.0
var _visual_scale := 1.0
var _ability := "none"
var _mass := 0
var _tint := Color.WHITE
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
var _collision_shape: CollisionShape3D
var _left_leg: Node3D
var _right_leg: Node3D
var _left_arm: Node3D
var _right_arm: Node3D
var _head: MeshInstance3D
var _meshes: Array[MeshInstance3D] = []
var _materials: Dictionary = {}
var _base_albedo: Dictionary = {}
var _eye_material: StandardMaterial3D
var _decor: Node3D
var _unit_box: BoxMesh
var _overlay_material: StandardMaterial3D
var _model_base_rx := 0.0


func setup(id: int, kind_id: String) -> void:
	zombie_id = id
	kind = kind_id
	_unit_box = BoxMesh.new()
	_unit_box.size = Vector3.ONE
	_materials.clear()
	_base_albedo.clear()
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
	_base_scale = _scale
	_visual_scale = _scale
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
	_eye_material = eye

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
	_model_base_rx = _model.rotation.x
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
	if material is StandardMaterial3D and not _base_albedo.has(material):
		_base_albedo[material] = (material as StandardMaterial3D).albedo_color
	return node


func _build_collision() -> void:
	_body = StaticBody3D.new()
	_body.collision_layer = 4
	_body.collision_mask = 0
	_body.name = "Hitbox"
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.34 if kind == "crawler" else 0.4 * _scale
	capsule.height = 1.15 if kind == "crawler" else 1.95 * _scale
	_collision_shape = CollisionShape3D.new()
	_collision_shape.shape = capsule
	_collision_shape.position.y = 0.58 if kind == "crawler" else 0.98 * _scale
	_body.add_child(_collision_shape)
	_body.set_meta("zombie_id", zombie_id)
	_body.set_meta("zombie_proxy", self)
	add_child(_body)


func _resize_collision() -> void:
	if _collision_shape == null:
		return
	var capsule := _collision_shape.shape as CapsuleShape3D
	if capsule == null:
		capsule = CapsuleShape3D.new()
		_collision_shape.shape = capsule
	if kind == "crawler":
		var ratio := _visual_scale / maxf(0.1, _base_scale)
		capsule.radius = 0.34 * ratio
		capsule.height = 1.15 * ratio
		_collision_shape.position.y = 0.58 * ratio
	else:
		capsule.radius = 0.4 * _visual_scale
		capsule.height = 1.95 * _visual_scale
		_collision_shape.position.y = 0.98 * _visual_scale


func apply_traits(scale_value: float, tint: Color, ability: String, mass: int) -> void:
	var changed := false
	if absf(scale_value - _visual_scale) > 0.02:
		_visual_scale = clampf(scale_value, 0.4, 2.8)
		_head_height = (0.95 if kind == "crawler" else 1.5) * _visual_scale
		_resize_collision()
		changed = true
	if ability != _ability:
		_ability = ability
		changed = true
	if mass != _mass:
		_mass = mass
		changed = true
	if not tint.is_equal_approx(_tint):
		_tint = tint
		changed = true
	if not changed:
		return
	var target := Vector3.ONE * _visual_scale
	var tween := create_tween()
	tween.tween_property(_rig, "scale", target, 0.16)
	_refresh_tint()
	_rebuild_decor()


func _refresh_tint() -> void:
	var strength := 0.0
	match _ability:
		"climber":
			strength = 0.26
		"armored":
			strength = 0.4
		"volatile":
			strength = 0.52
	if _mass > 0:
		strength = maxf(strength, 0.42)
	for material in _base_albedo.keys():
		var mat := material as StandardMaterial3D
		if mat == null:
			continue
		var base: Color = _base_albedo[material]
		mat.albedo_color = base.lerp(_tint, strength)
		if _ability == "volatile" and mat != _eye_material:
			mat.emission_enabled = true
			mat.emission = Color("#ff4a35")
			mat.emission_energy_multiplier = 0.5 + 0.12 * _mass
		elif mat != _eye_material:
			mat.emission_enabled = false


func _rebuild_decor() -> void:
	if _decor != null and is_instance_valid(_decor):
		_decor.queue_free()
	_decor = Node3D.new()
	_model.add_child(_decor)
	var bone := _decor_mat(Color("#cfc3a8"))
	var steel := _decor_mat(Color("#525d63"))
	if _ability == "climber":
		for side in [-1.0, 1.0]:
			var arm: Node3D = _left_arm if side < 0.0 else _right_arm
			for i in range(2):
				var claw := _decor_box(arm, Vector3(0.045, 0.05, 0.32), Vector3(0.045 * i - 0.03, -0.04, -0.82), bone)
				claw.rotation.x = -0.35 + 0.25 * i
			_decor_box(arm, Vector3(0.1, 0.08, 0.2), Vector3(0.0, 0.0, -0.68), steel)
		_decor_box(_model, Vector3(0.5, 0.1, 0.12), Vector3(0.0, 1.7, 0.2), bone)
	if _ability == "armored":
		_decor_box(_model, Vector3(0.42, 0.2, 0.16), Vector3(-0.36, 1.62, 0.0), steel)
		_decor_box(_model, Vector3(0.42, 0.2, 0.16), Vector3(0.36, 1.62, 0.0), steel)
		_decor_box(_model, Vector3(0.5, 0.3, 0.1), Vector3(0.0, 1.28, -0.2), steel)
		_decor_box(_model, Vector3(0.5, 0.14, 0.42), Vector3(0.0, 1.99, 0.03), steel)
	if _ability == "volatile":
		for i in range(2 + _mass):
			var angle := TAU * i / float(2 + _mass)
			_decor_box(_model, Vector3(0.14, 0.14, 0.14), Vector3(cos(angle) * 0.3, 1.24 + sin(angle) * 0.16, 0.22), _decor_mat(Color("#ff5a3c"), true))
	for i in range(_mass):
		var spike := _decor_box(_model, Vector3(0.09, 0.42, 0.09), Vector3(-0.22 + 0.22 * i, 1.55, 0.22), bone)
		spike.rotation.x = -0.4
	if _mass > 0:
		_decor_box(_model, Vector3(0.74, 0.16, 0.12), Vector3(0.0, 1.0, 0.2), bone)
		_decor_box(_model, Vector3(0.12, 0.16, 0.5), Vector3(-0.44, 1.33, 0.22), bone)
		_decor_box(_model, Vector3(0.12, 0.16, 0.5), Vector3(0.44, 1.33, 0.22), bone)


func _decor_box(parent: Node3D, size: Vector3, pos: Vector3, material: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = _unit_box
	node.scale = size
	node.position = pos
	node.material_override = material
	parent.add_child(node)
	return node


func _decor_mat(color: Color, glow: bool = false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.6
	if glow:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = 2.2
	return material


func set_network_state(pos: Vector3, yaw: float, state: int, scale_value: float = 0.0, tint: Color = Color.WHITE, ability: String = "none", mass: int = 0) -> void:
	if _dying:
		return
	if scale_value > 0.0:
		apply_traits(scale_value, tint, ability, mass)
	_target_pos = Vector3(pos.x, clampf(pos.y, -30.0, 80.0), pos.z)
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
	_rig.rotation.x = 0.0
	_model.rotation.x = _model_base_rx
	if _state == 2:
		var climb := sin(_phase * 3.4)
		_model.rotation.x = 0.16
		_rig.rotation.x = -0.12
		_left_arm.rotation.x = -2.35 + climb * 0.55
		_right_arm.rotation.x = -2.35 - climb * 0.55
		_left_leg.rotation.x = 0.62 - climb * 0.3
		_right_leg.rotation.x = 0.62 + climb * 0.3
		_model.position.z = 0.0
	elif _state == 3:
		_rig.rotation.x = -0.32
		_left_arm.rotation.x = -1.75
		_right_arm.rotation.x = -1.75
		_left_leg.rotation.x = 0.55
		_right_leg.rotation.x = 0.2
		_model.position.z = -0.05
	elif kind == "crawler":
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
	if _ability == "volatile" and _decor != null and is_instance_valid(_decor):
		_decor.scale = Vector3.ONE * (1.0 + sin(_phase * 2.4) * 0.06)
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
