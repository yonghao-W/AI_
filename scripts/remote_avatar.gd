class_name RemoteAvatar
extends Node3D

var player_color := Color("#58d6d0")
var player_name := "幸存者"
var _target_pos := Vector3.ZERO
var _target_yaw := 0.0
var _alive := true
var _initialized := false
var _walk_phase := 0.0
var _last_pos := Vector3.ZERO
var _carrying := false
var _model: Node3D
var _rifle: Node3D
var _carry_orb: Node3D
var _left_leg: Node3D
var _right_leg: Node3D
var _left_arm: Node3D
var _right_arm: Node3D
var _name_label: Label3D
var _materials: Dictionary = {}
var _unit_box: BoxMesh


func setup(display_name: String, color: Color) -> void:
	player_name = display_name
	player_color = color
	_unit_box = BoxMesh.new()
	_unit_box.size = Vector3.ONE
	_build_model()


func _build_model() -> void:
	_model = Node3D.new()
	add_child(_model)
	var uniform := _mat(player_color, 0.85)
	var uniform_dark := _mat(player_color.darkened(0.35), 0.9)
	var pants := _mat(Color("#26313a"), 0.95)
	var boots := _mat(Color("#171e24"), 0.9)
	var skin := _mat(Color("#c79b78"), 0.9)
	var helmet := _mat(Color("#3a4750"), 0.75, 0.15)
	var metal := _mat(Color("#2d363d"), 0.6, 0.4)
	var glow := _mat(player_color.lightened(0.2), 0.5, 0.0)
	glow.emission_enabled = true
	glow.emission = player_color
	glow.emission_energy_multiplier = 1.8

	_part(_model, Vector3(0.52, 0.62, 0.3), Vector3(0.0, 1.22, 0.0), uniform)
	_part(_model, Vector3(0.56, 0.22, 0.34), Vector3(0.0, 1.0, 0.0), uniform_dark)
	_part(_model, Vector3(0.32, 0.18, 0.34), Vector3(0.0, 0.94, 0.0), metal)
	_part(_model, Vector3(0.36, 0.36, 0.34), Vector3(0.0, 1.66, 0.0), skin)
	_part(_model, Vector3(0.44, 0.18, 0.44), Vector3(0.0, 1.88, 0.0), helmet)
	_part(_model, Vector3(0.36, 0.08, 0.06), Vector3(0.0, 1.75, -0.19), glow)
	_part(_model, Vector3(0.34, 0.46, 0.2), Vector3(0.0, 1.25, 0.26), metal)
	_part(_model, Vector3(0.08, 0.36, 0.06), Vector3(0.0, 1.28, 0.37), glow)

	_left_leg = Node3D.new()
	_left_leg.position = Vector3(-0.15, 0.9, 0.0)
	_model.add_child(_left_leg)
	_part(_left_leg, Vector3(0.2, 0.78, 0.22), Vector3(0.0, -0.39, 0.0), pants)
	_part(_left_leg, Vector3(0.23, 0.2, 0.32), Vector3(0.0, -0.82, -0.04), boots)

	_right_leg = Node3D.new()
	_right_leg.position = Vector3(0.15, 0.9, 0.0)
	_model.add_child(_right_leg)
	_part(_right_leg, Vector3(0.2, 0.78, 0.22), Vector3(0.0, -0.39, 0.0), pants)
	_part(_right_leg, Vector3(0.23, 0.2, 0.32), Vector3(0.0, -0.82, -0.04), boots)

	_left_arm = Node3D.new()
	_left_arm.position = Vector3(-0.36, 1.44, 0.0)
	_model.add_child(_left_arm)
	_part(_left_arm, Vector3(0.16, 0.55, 0.17), Vector3(0.0, -0.27, -0.08), uniform)
	_part(_left_arm, Vector3(0.14, 0.16, 0.16), Vector3(0.0, -0.57, -0.16), skin)
	_left_arm.rotation.x = -0.85

	_right_arm = Node3D.new()
	_right_arm.position = Vector3(0.36, 1.44, 0.0)
	_model.add_child(_right_arm)
	_part(_right_arm, Vector3(0.16, 0.55, 0.17), Vector3(0.0, -0.27, -0.08), uniform)
	_part(_right_arm, Vector3(0.14, 0.16, 0.16), Vector3(0.0, -0.57, -0.16), skin)
	_right_arm.rotation.x = -1.05

	_rifle = Node3D.new()
	_rifle.position = Vector3(0.04, 1.23, -0.4)
	_rifle.rotation.x = 0.08
	_model.add_child(_rifle)
	_part(_rifle, Vector3(0.11, 0.11, 0.62), Vector3(0.0, 0.0, 0.0), metal)
	_part(_rifle, Vector3(0.07, 0.07, 0.3), Vector3(0.0, 0.02, -0.42), _mat(Color("#171d21"), 0.8))
	_part(_right_arm, Vector3(0.05, 0.05, 0.3), Vector3(0.0, -0.56, -0.4), metal)

	_carry_orb = Node3D.new()
	_carry_orb.position = Vector3(0.0, 1.26, -0.38)
	_carry_orb.visible = false
	_model.add_child(_carry_orb)
	var core_mat := _mat(Color("#ffc861"), 0.35, 0.1)
	core_mat.emission_enabled = true
	core_mat.emission = Color("#ffc861")
	core_mat.emission_energy_multiplier = 2.6
	var core_mesh := MeshInstance3D.new()
	var core_sphere := SphereMesh.new()
	core_sphere.radius = 0.17
	core_sphere.height = 0.34
	core_sphere.radial_segments = 10
	core_sphere.rings = 6
	core_mesh.mesh = core_sphere
	core_mesh.material_override = core_mat
	_carry_orb.add_child(core_mesh)
	var core_ring := MeshInstance3D.new()
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 0.2
	ring_mesh.outer_radius = 0.25
	ring_mesh.rings = 18
	ring_mesh.ring_segments = 5
	core_ring.mesh = ring_mesh
	core_ring.material_override = metal
	_carry_orb.add_child(core_ring)

	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.42
	torus.outer_radius = 0.54
	torus.rings = 20
	torus.ring_segments = 6
	ring.mesh = torus
	ring.position.y = 0.035
	ring.material_override = glow
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring)

	_name_label = Label3D.new()
	_name_label.text = player_name
	_name_label.font = DeadCityUI.display_font()
	_name_label.font_size = 42
	_name_label.pixel_size = 0.0035
	_name_label.position = Vector3(0.0, 2.2, 0.0)
	_name_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_name_label.no_depth_test = true
	_name_label.modulate = player_color.lightened(0.25)
	_name_label.outline_size = 10
	_name_label.outline_modulate = Color(0.02, 0.03, 0.04, 0.9)
	add_child(_name_label)


func _part(parent: Node3D, size: Vector3, pos: Vector3, material: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = _unit_box
	node.scale = size
	node.position = pos
	node.material_override = material
	parent.add_child(node)
	return node


func _mat(color: Color, roughness: float = 0.9, metallic: float = 0.0) -> StandardMaterial3D:
	var key := "%s|%.2f|%.2f" % [color.to_html(), roughness, metallic]
	if _materials.has(key):
		return _materials[key]
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	_materials[key] = material
	return material


func set_network_state(pos: Vector3, yaw: float, alive: bool) -> void:
	if not _initialized:
		global_position = pos
		rotation.y = yaw
		_last_pos = pos
		_initialized = true
	_target_pos = pos
	_target_yaw = yaw
	if alive != _alive:
		_alive = alive
		_apply_alive()
		_initialized = true


func snap_to(pos: Vector3, yaw: float, alive: bool = true) -> void:
	global_position = pos
	rotation.y = yaw
	_target_pos = pos
	_target_yaw = yaw
	_last_pos = pos
	_initialized = true
	if alive != _alive:
		_alive = alive
		_apply_alive()


func set_carrying(value: bool) -> void:
	_carrying = value
	if _rifle != null:
		_rifle.visible = _alive and not value
	if _carry_orb != null:
		_carry_orb.visible = _alive and value


func _apply_alive() -> void:
	if _alive:
		_model.rotation.z = 0.0
		_model.position.y = 0.0
		_name_label.modulate = player_color.lightened(0.25)
		_name_label.text = player_name
		_name_label.position.y = 2.2
	else:
		_model.rotation.z = -PI * 0.5
		_model.position.y = 0.2
		_name_label.modulate = Color("#ff7777")
		_name_label.text = player_name + "（倒地）"
		_name_label.position.y = 1.1
	if _rifle != null:
		_rifle.visible = _alive and not _carrying
	if _carry_orb != null:
		_carry_orb.visible = _alive and _carrying


func _process(delta: float) -> void:
	if not _initialized:
		return
	var previous := global_position
	global_position = global_position.lerp(_target_pos, clampf(delta * 10.0, 0.0, 1.0))
	rotation.y = lerp_angle(rotation.y, _target_yaw, clampf(delta * 9.0, 0.0, 1.0))
	var speed := previous.distance_to(global_position) / maxf(delta, 0.0001)
	if _alive:
		if speed > 0.4:
			_walk_phase += delta * clampf(speed * 1.8, 3.0, 12.0)
		var swing := sin(_walk_phase) * 0.55 * clampf(speed / 4.0, 0.0, 1.0)
		_left_leg.rotation.x = swing
		_right_leg.rotation.x = -swing
		if _carrying:
			_left_arm.rotation.x = -1.42 + swing * 0.12
			_right_arm.rotation.x = -1.52 - swing * 0.12
		else:
			_left_arm.rotation.x = -0.85 - swing * 0.3
			_right_arm.rotation.x = -1.05 + swing * 0.12
		_model.position.y = absf(sin(_walk_phase)) * 0.035
		if _carrying and _carry_orb != null:
			_carry_orb.position.y = 1.26 + absf(sin(_walk_phase)) * 0.02
			_carry_orb.rotation.y += delta * 1.5
	_last_pos = global_position


func display_name() -> String:
	return player_name
