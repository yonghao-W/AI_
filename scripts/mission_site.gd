class_name MissionSite
extends Node3D

const BASE_CENTER := Vector3(0.0, 0.16, -98.0)
const SAFE_RADIUS := 7.0
const CONSOLE_POINT := Vector3(0.0, 0.16, -101.4)
const AMMO_POINT := Vector3(-4.6, 0.16, -94.6)
const FOUNTAIN_POINT := Vector3(0.0, 0.12, 0.0)
const FOUNTAIN_RETURN := Vector3(0.0, 0.2, 13.0)
const BASEMENT_Y := -14.0
const BASEMENT_ARRIVAL := Vector3(0.0, -13.84, -9.4)
const BASEMENT_EXIT := Vector3(0.0, -13.84, -9.6)
const RAMP_TOP := Vector3(0.0, 0.18, 12.6)
const RAMP_BOTTOM := Vector3(0.0, -14.0, -8.2)
const RAMP_ANGLE := 0.5985
const HOLE_MIN := Vector2(-3.8, -8.6)
const HOLE_MAX := Vector2(3.8, 12.6)
const CORE_COUNT := 3
const CORE_SITES := [
	Vector3(-4.6, -14.0, 0.6),
	Vector3(4.6, -14.0, 0.6),
	Vector3(-7.2, -14.0, -9.4),
]
const SAFE_SPAWNS := [
	Vector3(-2.6, 0.18, -95.9),
	Vector3(2.6, 0.18, -95.9),
	Vector3(-3.4, 0.18, -99.2),
	Vector3(3.4, 0.18, -99.2),
]
const SAFE_COLOR := Color("#59d8c8")
const CORE_COLOR := Color("#ffc861")

var _materials: Dictionary = {}
var _unit_box: BoxMesh
var _time := 0.0
var _base_ring: MeshInstance3D
var _gateway_ring: MeshInstance3D
var _core_nodes: Array[MeshInstance3D] = []
var _core_lights: Array[OmniLight3D] = []
var _core_anchors: Array[Vector3] = []
var _secured_nodes: Array[MeshInstance3D] = []


func build() -> void:
	_unit_box = BoxMesh.new()
	_unit_box.size = Vector3.ONE
	_build_base()
	_build_surface_entrance()
	_build_basement()
	reset_visuals()


func reset_visuals() -> void:
	for i in range(_core_nodes.size()):
		set_core_state(i, "site", CORE_SITES[i])
	set_secured_count(0)
	_time = 0.0


func spawn_point(index: int) -> Vector3:
	return SAFE_SPAWNS[index % SAFE_SPAWNS.size()]


func core_site_pos(index: int) -> Vector3:
	return CORE_SITES[index % CORE_SITES.size()]


func is_in_safe_zone(pos: Vector3) -> bool:
	if pos.y < -2.0:
		return false
	return _flat_distance(pos, BASE_CENTER) <= SAFE_RADIUS


func is_in_basement(pos: Vector3) -> bool:
	return pos.y < BASEMENT_Y + 5.0


func is_zombie_target(pos: Vector3) -> bool:
	return not is_in_safe_zone(pos) and not is_in_basement(pos)


func console_distance(pos: Vector3) -> float:
	return _flat_distance(pos, CONSOLE_POINT)


func ammo_distance(pos: Vector3) -> float:
	return _flat_distance(pos, AMMO_POINT)


func fountain_distance(pos: Vector3) -> float:
	return _flat_distance(pos, FOUNTAIN_POINT)


func entrance_distance(pos: Vector3) -> float:
	return _flat_distance(pos, Vector3(0.0, 0.16, 12.8))


func basement_spawn_points() -> Array:
	return [
		Vector3(-9.2, -13.84, -9.4), Vector3(9.2, -13.84, -9.4),
		Vector3(-9.6, -13.84, 8.8), Vector3(9.6, -13.84, 8.8),
		Vector3(0.0, -13.84, -9.8), Vector3(0.0, -13.84, 9.9),
		Vector3(-9.8, -13.84, -0.5), Vector3(9.8, -13.84, -0.5),
	]


func exit_distance(pos: Vector3) -> float:
	return _flat_distance(pos, BASEMENT_EXIT)


func core_distance(pos: Vector3, index: int) -> float:
	if index < 0 or index >= CORE_SITES.size():
		return 9999.0
	return _flat_distance(pos, CORE_SITES[index])


func set_core_state(index: int, state: String, pos: Vector3) -> void:
	if index < 0 or index >= _core_nodes.size():
		return
	var visible_core := state == "site" or state == "dropped"
	_core_nodes[index].visible = visible_core
	_core_lights[index].visible = visible_core
	if state == "site":
		_core_anchors[index] = CORE_SITES[index] + Vector3(0.0, 1.3, 0.0)
	elif state == "dropped":
		_core_anchors[index] = Vector3(pos.x, maxf(pos.y, -14.0) + 0.95, pos.z)
		_core_nodes[index].global_position = _core_anchors[index]
		_core_lights[index].global_position = _core_anchors[index] + Vector3(0.0, 0.2, 0.0)


func set_secured_count(count: int) -> void:
	for i in range(_secured_nodes.size()):
		_secured_nodes[i].visible = i < count


func _process(delta: float) -> void:
	_time += delta
	if _gateway_ring != null:
		_gateway_ring.rotate_object_local(Vector3.UP, delta * 0.6)
	if _base_ring != null:
		_base_ring.rotation.y -= delta * 0.22
	for i in range(_core_nodes.size()):
		var orb := _core_nodes[i]
		if orb == null or not orb.visible:
			continue
		orb.position = _core_anchors[i] + Vector3(0.0, sin(_time * 1.8 + i * 1.7) * 0.07, 0.0)
		orb.rotation.y += delta * 1.6
		if i < _core_lights.size() and _core_lights[i].visible:
			_core_lights[i].position = orb.position + Vector3(0.0, 0.15, 0.0)
	for i in range(_secured_nodes.size()):
		if _secured_nodes[i].visible:
			_secured_nodes[i].rotation.y += delta * 2.2


func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _build_base() -> void:
	var root := Node3D.new()
	root.name = "SafeZone"
	add_child(root)
	var platform := _cylinder(6.4, 0.14, 28)
	_mesh(root, platform, BASE_CENTER + Vector3(0.0, -0.01, 0.0), _mat(Color("#142027"), 0.92, 0.1))
	var inner := _cylinder(5.6, 0.05, 28)
	_mesh(root, inner, BASE_CENTER + Vector3(0.0, 0.07, 0.0), _mat(Color("#1c3036"), 0.88, 0.15))
	_base_ring = _mesh(root, _torus(5.85, 6.15, 40, 6), BASE_CENTER + Vector3(0.0, 0.14, 0.0), _emissive(SAFE_COLOR, 1.7))
	_base_ring.rotation.x = 0.0
	for i in range(12):
		var angle := TAU * i / 12.0
		var direction := Vector3(cos(angle), 0.0, sin(angle))
		var stripe := _box(root, Vector3(0.16, 0.03, 0.72), BASE_CENTER + direction * 5.15 + Vector3(0.0, 0.12, 0.0), _emissive(SAFE_COLOR, 1.1))
		stripe.rotation.y = -angle + PI * 0.5
	for i in range(4):
		var angle := PI * 0.25 + PI * 0.5 * i
		var pos := BASE_CENTER + Vector3(cos(angle) * 5.5, 0.0, sin(angle) * 5.5)
		_box(root, Vector3(0.26, 3.1, 0.26), pos + Vector3(0.0, 1.55, 0.0), _mat(Color("#2b3d43"), 0.7, 0.35))
		var cap := _box(root, Vector3(0.4, 0.22, 0.4), pos + Vector3(0.0, 3.2, 0.0), _emissive(SAFE_COLOR, 2.4))
		cap.rotation.y = angle
		_box(root, Vector3(0.62, 0.1, 0.62), pos + Vector3(0.0, 0.1, 0.0), _mat(Color("#36484f"), 0.8, 0.2))
		var light := OmniLight3D.new()
		light.position = pos + Vector3(0.0, 3.0, 0.0)
		light.light_color = SAFE_COLOR
		light.light_energy = 1.1
		light.omni_range = 6.5
		light.shadow_enabled = false
		root.add_child(light)
	_build_console(root)
	var beacon := OmniLight3D.new()
	beacon.position = BASE_CENTER + Vector3(0.0, 4.0, 0.0)
	beacon.light_color = SAFE_COLOR
	beacon.light_energy = 1.5
	beacon.omni_range = 16.0
	beacon.shadow_enabled = false
	root.add_child(beacon)
	_crate(root, BASE_CENTER + Vector3(-4.1, 0.0, -2.2), 0.9)
	_crate(root, BASE_CENTER + Vector3(-4.5, 0.0, -3.05), 0.7)
	_crate(root, BASE_CENTER + Vector3(4.3, 0.0, -2.6), 0.85)
	_crate(root, BASE_CENTER + Vector3(4.6, 0.0, 3.1), 0.75)
	_build_ammo(root)
	var label := _label3d(root, "安全区 · SAFE ZONE", 48, SAFE_COLOR)
	label.position = BASE_CENTER + Vector3(0.0, 2.9, 0.0)
	label.pixel_size = 0.0036
	var sub_label := _label3d(root, "感染者不会进入", 26, Color(0.42, 0.78, 0.74))
	sub_label.position = BASE_CENTER + Vector3(0.0, 2.5, 0.0)
	sub_label.pixel_size = 0.0032


func _build_console(root: Node3D) -> void:
	var body := _static_box(root, Vector3(1.9, 0.95, 0.75), CONSOLE_POINT + Vector3(0.0, 0.48, 0.0), Color("#283a40"))
	body.name = "BaseConsole"
	var screen := _box(root, Vector3(1.55, 0.06, 0.5), CONSOLE_POINT + Vector3(0.0, 0.98, 0.0), _emissive(CORE_COLOR, 2.6))
	screen.rotation.x = -0.42
	var rim := _box(root, Vector3(1.75, 0.12, 0.62), CONSOLE_POINT + Vector3(0.0, 0.12, 0.0), _emissive(SAFE_COLOR, 0.9))
	rim.rotation.y = 0.0
	var light := OmniLight3D.new()
	light.position = CONSOLE_POINT + Vector3(0.0, 1.6, 0.4)
	light.light_color = CORE_COLOR
	light.light_energy = 1.3
	light.omni_range = 5.5
	light.shadow_enabled = false
	root.add_child(light)
	var label := _label3d(root, "核心交付台  [E]", 42, CORE_COLOR)
	label.position = CONSOLE_POINT + Vector3(0.0, 1.75, 0.0)
	label.pixel_size = 0.0036
	for i in range(CORE_COUNT):
		var orb := _mesh(root, _sphere(0.2, 12, 6), CONSOLE_POINT + Vector3((i - 1) * 0.65, 1.55, 0.2), _emissive(CORE_COLOR, 2.8))
		orb.visible = false
		_secured_nodes.append(orb)


func _build_ammo(root: Node3D) -> void:
	var table := _static_box(root, Vector3(1.55, 0.74, 0.9), AMMO_POINT + Vector3(0.0, 0.37, 0.0), Color("#26372f"))
	table.name = "AmmoStation"
	_box(root, Vector3(1.68, 0.08, 0.98), AMMO_POINT + Vector3(0.0, 0.76, 0.0), _mat(Color("#3c5144"), 0.85, 0.1))
	var ammo_colors := [Color("#d7a84e"), Color("#6f8a45"), Color("#c9b36a")]
	for i in range(3):
		_box(root, Vector3(0.4, 0.27, 0.44), AMMO_POINT + Vector3(-0.45 + i * 0.45, 0.94, 0.02), _mat(ammo_colors[i], 0.8, 0.05))
	_box(root, Vector3(1.36, 0.06, 0.06), AMMO_POINT + Vector3(0.0, 0.7, -0.5), _emissive(Color("#9fe08a"), 1.8))
	var light := OmniLight3D.new()
	light.position = AMMO_POINT + Vector3(0.0, 1.5, -0.3)
	light.light_color = Color("#b6e59c")
	light.light_energy = 0.9
	light.omni_range = 4.5
	light.shadow_enabled = false
	root.add_child(light)
	var label := _label3d(root, "弹药补给  [E]", 34, Color("#b6e59c"))
	label.position = AMMO_POINT + Vector3(0.0, 1.7, 0.0)
	label.pixel_size = 0.0034


func _build_surface_entrance() -> void:
	var root := Node3D.new()
	root.name = "VaultEntrance"
	add_child(root)
	_static_box(root, Vector3(10.2, 0.28, 28.0), Vector3(-8.9, 0.04, 0.0), Color("#3c5a40"))
	_static_box(root, Vector3(10.2, 0.28, 28.0), Vector3(8.9, 0.04, 0.0), Color("#3c5a40"))
	_static_box(root, Vector3(7.6, 0.28, 5.4), Vector3(0.0, 0.04, -11.3), Color("#3c5a40"))
	_static_box(root, Vector3(7.6, 0.28, 1.4), Vector3(0.0, 0.04, 13.3), Color("#3c5a40"))
	_static_box(root, Vector3(1.2, 0.32, 21.2), Vector3(-4.4, 0.02, 2.0), Color("#59636c"))
	_static_box(root, Vector3(1.2, 0.32, 21.2), Vector3(4.4, 0.02, 2.0), Color("#59636c"))
	_static_box(root, Vector3(10.0, 0.32, 1.2), Vector3(0.0, 0.02, -9.2), Color("#59636c"))
	_static_box(root, Vector3(10.0, 0.32, 1.2), Vector3(0.0, 0.02, 13.2), Color("#59636c"))
	_build_ramp(root)
	_static_box(root, Vector3(0.5, 11.0, 22.4), Vector3(-4.05, -4.9, 2.0), Color("#3a484e"))
	_static_box(root, Vector3(0.5, 11.0, 22.4), Vector3(4.05, -4.9, 2.0), Color("#3a484e"))
	for side in [-1.0, 1.0]:
		var rail_x := 4.15 * float(side)
		for i in range(9):
			var z := -7.8 + i * 2.5
			_box(root, Vector3(0.12, 1.1, 0.12), Vector3(rail_x, 0.75, z), _mat(Color("#2c4148"), 0.7, 0.4))
		_box(root, Vector3(0.1, 0.1, 20.6), Vector3(rail_x, 1.28, 2.0), _mat(Color("#4e7378"), 0.6, 0.5))
	_box(root, Vector3(8.4, 0.12, 0.12), Vector3(0.0, 1.28, -9.2), _mat(Color("#4e7378"), 0.6, 0.5))
	for side in [-1.0, 1.0]:
		_box(root, Vector3(0.42, 4.4, 0.42), Vector3(4.7 * side, 2.2, 12.6), _mat(Color("#32454b"), 0.7, 0.4))
	_box(root, Vector3(10.2, 0.36, 3.6), Vector3(0.0, 4.45, 12.2), _mat(Color("#33474d"), 0.8, 0.25))
	_box(root, Vector3(10.4, 0.14, 0.14), Vector3(0.0, 4.2, 10.4), _emissive(SAFE_COLOR, 1.5))
	_gateway_ring = _mesh(root, _torus(1.72, 1.9, 40, 6), Vector3(0.0, 2.2, 13.9), _emissive(SAFE_COLOR, 1.7))
	_gateway_ring.rotation.x = PI * 0.5
	_box(root, Vector3(8.2, 0.08, 0.28), Vector3(0.0, 4.24, 12.4), _emissive(Color("#7fd4c8"), 1.1))
	_box(root, Vector3(0.24, 0.08, 3.0), Vector3(-4.55, 4.24, 12.4), _emissive(Color("#7fd4c8"), 0.9))
	_box(root, Vector3(0.24, 0.08, 3.0), Vector3(4.55, 4.24, 12.4), _emissive(Color("#7fd4c8"), 0.9))
	var canopy_light := OmniLight3D.new()
	canopy_light.position = Vector3(0.0, 3.5, 12.8)
	canopy_light.light_color = Color("#bfe6df")
	canopy_light.light_energy = 2.2
	canopy_light.omni_range = 9.0
	canopy_light.shadow_enabled = false
	root.add_child(canopy_light)
	for i in range(7):
		var bar := _box(root, Vector3(0.85, 0.04, 0.28), Vector3(-3.0 + i * 1.0, RAMP_TOP.y + 0.03, 12.35), _emissive(Color("#d8b25e"), 0.8))
		bar.rotation.x = -RAMP_ANGLE
	var label := _label3d(root, "核心储藏层 B1\n沿坡道下行", 48, SAFE_COLOR)
	label.position = Vector3(0.0, 5.35, 12.2)
	label.pixel_size = 0.0044
	var sub := _label3d(root, "无传送 · 步行通道", 26, Color(0.55, 0.8, 0.77))
	sub.position = Vector3(0.0, 4.82, 12.2)
	sub.pixel_size = 0.0034
	var light := OmniLight3D.new()
	light.position = Vector3(0.0, 2.6, 12.0)
	light.light_color = SAFE_COLOR
	light.light_energy = 1.6
	light.omni_range = 11.0
	light.shadow_enabled = false
	root.add_child(light)
	var down_light := OmniLight3D.new()
	down_light.position = Vector3(0.0, -1.4, 9.0)
	down_light.light_color = Color("#bfe6df")
	down_light.light_energy = 1.4
	down_light.omni_range = 10.0
	down_light.shadow_enabled = false
	root.add_child(down_light)


func _build_ramp(root: Node3D) -> void:
	var drop := RAMP_BOTTOM - RAMP_TOP
	var length := drop.length()
	var direction := drop.normalized()
	var up := Vector3(0.0, cos(RAMP_ANGLE), -sin(RAMP_ANGLE))
	var box_length := length + 0.4
	var surface_center := RAMP_TOP + direction * (box_length * 0.5)
	var body := StaticBody3D.new()
	body.position = surface_center - up * 0.25
	body.rotation.x = -RAMP_ANGLE
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(7.3, 0.5, box_length)
	shape.shape = box
	body.add_child(shape)
	var mesh := MeshInstance3D.new()
	mesh.mesh = _unit_box
	mesh.scale = Vector3(7.3, 0.5, box_length)
	mesh.material_override = _mat(Color("#4a585e"), 0.9, 0.05)
	body.add_child(mesh)
	root.add_child(body)
	for i in range(18):
		var t := (i + 0.5) / 18.0
		var world := RAMP_TOP.lerp(RAMP_BOTTOM, t) + up * 0.02
		var tread := _box(root, Vector3(7.0, 0.05, 0.34), world, _mat(Color("#6f8087"), 0.85, 0.1))
		tread.rotation.x = -RAMP_ANGLE
	for side in [-1.0, 1.0]:
		for i in range(6):
			var t := (i + 0.5) / 6.0
			var pos := RAMP_TOP.lerp(RAMP_BOTTOM, t) + up * 0.06 + Vector3(3.45 * side, 0.0, 0.0)
			var strip := _box(root, Vector3(0.1, 0.06, 1.1), pos, _emissive(Color("#7fd4c8"), 1.4))
			strip.rotation.x = -RAMP_ANGLE
		for i in range(7):
			var t := (i + 0.5) / 7.0
			var pos := RAMP_TOP.lerp(RAMP_BOTTOM, t) + up * 1.35 + Vector3(3.72 * side, 0.0, 0.0)
			var guide := _box(root, Vector3(0.1, 0.5, 0.22), pos, _emissive(Color("#7fd4c8"), 1.8))
			guide.rotation.x = -RAMP_ANGLE
	for i in range(5):
		var t := (i + 0.5) / 5.0
		var pos := RAMP_TOP.lerp(RAMP_BOTTOM, t) + up * 2.5
		var light := OmniLight3D.new()
		light.position = pos
		light.light_color = Color("#cfe3e2")
		light.light_energy = 2.2
		light.omni_range = 11.5
		light.shadow_enabled = false
		root.add_child(light)
	var landing_light := OmniLight3D.new()
	landing_light.position = Vector3(0.0, -9.4, -7.8)
	landing_light.light_color = Color("#cfe3e2")
	landing_light.light_energy = 0.9
	landing_light.omni_range = 8.0
	landing_light.shadow_enabled = false
	root.add_child(landing_light)


func _build_basement() -> void:
	var root := Node3D.new()
	root.name = "CoreVault"
	add_child(root)
	_static_box(root, Vector3(23.6, 0.5, 23.6), Vector3(0.0, -14.25, 0.0), Color("#20272b"))
	_static_box(root, Vector3(7.95, 0.4, 23.6), Vector3(-7.825, -10.4, 0.0), Color("#171d21"))
	_static_box(root, Vector3(7.95, 0.4, 23.6), Vector3(7.825, -10.4, 0.0), Color("#171d21"))
	_static_box(root, Vector3(7.7, 0.4, 3.2), Vector3(0.0, -10.4, -10.2), Color("#171d21"))
	_static_box(root, Vector3(7.7, 0.4, 13.6), Vector3(0.0, -10.4, 5.0), Color("#171d21"))
	for side in [-1.0, 1.0]:
		_box(root, Vector3(0.12, 0.1, 6.8), Vector3(3.85 * side, -10.62, -5.2), _emissive(Color("#4f8c8a"), 0.7))
	_box(root, Vector3(7.7, 0.1, 0.12), Vector3(0.0, -10.62, -1.8), _emissive(Color("#4f8c8a"), 0.7))
	_static_box(root, Vector3(23.6, 3.4, 0.5), Vector3(0.0, -12.3, -11.25), Color("#2a3236"))
	_static_box(root, Vector3(23.6, 3.4, 0.5), Vector3(0.0, -12.3, 11.25), Color("#2a3236"))
	_static_box(root, Vector3(0.5, 3.4, 23.0), Vector3(-11.25, -12.3, 0.0), Color("#2a3236"))
	_static_box(root, Vector3(0.5, 3.4, 23.0), Vector3(11.25, -12.3, 0.0), Color("#2a3236"))
	_mesh(root, _cylinder(8.2, 0.04, 32), Vector3(0.0, -13.97, 0.0), _mat(Color("#2b363a"), 0.85, 0.1))
	var floor_ring := _mesh(root, _torus(6.6, 6.85, 40, 6), Vector3(0.0, -13.9, 0.0), _emissive(Color(0.22, 0.5, 0.5), 0.8))
	floor_ring.rotation.x = 0.0
	for i in range(8):
		var angle := TAU * i / 8.0
		var mark := _box(root, Vector3(0.14, 0.03, 1.2), Vector3(cos(angle) * 7.4, -13.94, sin(angle) * 7.4), _emissive(Color(0.25, 0.46, 0.46), 0.6))
		mark.rotation.y = -angle
	var strip := _box(root, Vector3(7.0, 0.08, 0.4), Vector3(0.0, -10.62, -4.2), _emissive(Color("#cfe9e4"), 1.6))
	strip.name = "CeilingLight"
	var strip2 := _box(root, Vector3(7.0, 0.08, 0.4), Vector3(0.0, -10.62, 4.2), _emissive(Color("#cfe9e4"), 1.6))
	strip2.name = "CeilingLight2"
	var light_a := OmniLight3D.new()
	light_a.position = Vector3(-4.0, -11.4, -3.0)
	light_a.light_color = Color("#cfe3e2")
	light_a.light_energy = 2.2
	light_a.omni_range = 15.0
	light_a.shadow_enabled = false
	root.add_child(light_a)
	var light_b := OmniLight3D.new()
	light_b.position = Vector3(4.0, -11.4, 3.0)
	light_b.light_color = Color("#cfe3e2")
	light_b.light_energy = 2.0
	light_b.omni_range = 15.0
	light_b.shadow_enabled = false
	root.add_child(light_b)
	var light_c := OmniLight3D.new()
	light_c.position = Vector3(0.0, -11.6, 8.0)
	light_c.light_color = SAFE_COLOR
	light_c.light_energy = 1.4
	light_c.omni_range = 9.0
	light_c.shadow_enabled = false
	root.add_child(light_c)
	_build_exit_pad(root)
	for i in range(CORE_COUNT):
		_build_core_pedestal(root, i)
	for i in range(4):
		var x := -9.0 if i % 2 == 0 else 9.0
		var z := -8.2 if i < 2 else 8.6
		_crate(root, Vector3(x, -14.0, z), 0.9 + 0.1 * (i % 2))
		_crate(root, Vector3(x, -14.0, z + 1.0), 0.65)
	_box(root, Vector3(6.4, 0.16, 0.5), Vector3(0.0, -10.7, -11.0), _mat(Color("#39474c"), 0.7, 0.3))
	var sign_label := _label3d(root, "核心储藏层 · B1", 58, CORE_COLOR)
	sign_label.position = Vector3(0.0, -11.15, -10.9)
	sign_label.pixel_size = 0.0045
	var warning := _label3d(root, "感染者从坡道涌入 · 回收全部核心后步行返回基地", 28, Color(0.72, 0.82, 0.82))
	warning.position = Vector3(0.0, -11.6, -10.9)
	warning.pixel_size = 0.0036


func _build_exit_pad(root: Node3D) -> void:
	var pad := _mesh(root, _cylinder(1.45, 0.06, 24), BASEMENT_EXIT + Vector3(0.0, -0.03, 0.0), _mat(Color("#224146"), 0.7, 0.2))
	pad.name = "ExitPad"
	var ring := _mesh(root, _torus(1.3, 1.45, 28, 6), BASEMENT_EXIT + Vector3(0.0, 0.1, 0.0), _emissive(SAFE_COLOR, 2.2))
	ring.name = "ExitRing"
	for i in range(2):
		var arrow := _box(root, Vector3(0.85, 0.14, 0.3), BASEMENT_EXIT + Vector3(0.0, 0.14, -0.5 + i * 0.55), _emissive(SAFE_COLOR, 1.5))
		arrow.rotation.y = 0.0
	var label := _label3d(root, "上行坡道 · 返回地表", 38, SAFE_COLOR)
	label.position = BASEMENT_EXIT + Vector3(0.0, 1.9, 0.0)
	label.pixel_size = 0.0034
	var light := OmniLight3D.new()
	light.position = BASEMENT_EXIT + Vector3(0.0, 1.4, 0.0)
	light.light_color = SAFE_COLOR
	light.light_energy = 1.3
	light.omni_range = 5.0
	light.shadow_enabled = false
	root.add_child(light)


func _build_core_pedestal(root: Node3D, index: int) -> void:
	var site: Vector3 = CORE_SITES[index]
	_static_cylinder(root, 0.95, 1.0, site + Vector3(0.0, 0.5, 0.0), Color("#323e42"))
	var plate := _mesh(root, _cylinder(1.35, 0.05, 20), site + Vector3(0.0, 0.03, 0.0), _mat(Color("#3b4a4e"), 0.8, 0.25))
	plate.name = "CorePlate"
	var top_ring := _mesh(root, _torus(0.62, 0.78, 24, 6), site + Vector3(0.0, 1.03, 0.0), _emissive(CORE_COLOR, 1.8))
	top_ring.name = "CoreRing"
	var orb := _mesh(root, _sphere(0.33, 12, 8), site + Vector3(0.0, 1.3, 0.0), _emissive(CORE_COLOR, 3.1))
	orb.name = "CoreOrb"
	_core_nodes.append(orb)
	_core_anchors.append(site + Vector3(0.0, 1.3, 0.0))
	var light := OmniLight3D.new()
	light.position = site + Vector3(0.0, 1.7, 0.0)
	light.light_color = CORE_COLOR
	light.light_energy = 1.6
	light.omni_range = 5.6
	light.shadow_enabled = false
	root.add_child(light)
	_core_lights.append(light)


func _crate(parent: Node3D, pos: Vector3, size: float) -> void:
	var mesh := _box(parent, Vector3(size, size * 0.8, size), pos + Vector3(0.0, size * 0.4, 0.0), _mat(Color("#3a4648"), 0.9, 0.15))
	mesh.rotation.y = 0.18
	var stripe := _box(parent, Vector3(size * 1.02, 0.08, size * 0.18), pos + Vector3(0.0, size * 0.55, 0.0), _emissive(SAFE_COLOR, 0.8))
	stripe.rotation.y = 0.18


func _label3d(parent: Node3D, text: String, font_size: int, color: Color) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font = DeadCityUI.display_font()
	label.font_size = font_size
	label.pixel_size = 0.004
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = false
	label.modulate = color
	label.outline_size = 12
	label.outline_modulate = Color(0.02, 0.03, 0.04, 0.92)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(label)
	return label


func _mesh(parent: Node3D, mesh: Mesh, pos: Vector3, material: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = pos
	node.material_override = material
	parent.add_child(node)
	return node


func _box(parent: Node3D, size: Vector3, pos: Vector3, material: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = _unit_box
	node.scale = size
	node.position = pos
	node.material_override = material
	parent.add_child(node)
	return node


func _static_box(parent: Node3D, size: Vector3, pos: Vector3, color: Color) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = pos
	body.collision_layer = 1
	body.collision_mask = 0
	var mesh := MeshInstance3D.new()
	mesh.mesh = _unit_box
	mesh.scale = size
	mesh.material_override = _mat(color, 0.88, 0.08)
	body.add_child(mesh)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	parent.add_child(body)
	return body


func _static_cylinder(parent: Node3D, radius: float, height: float, pos: Vector3, color: Color) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = pos
	body.collision_layer = 1
	body.collision_mask = 0
	var mesh := MeshInstance3D.new()
	mesh.mesh = _cylinder(radius, height, 16)
	mesh.material_override = _mat(color, 0.82, 0.18)
	body.add_child(mesh)
	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = radius
	cylinder.height = height
	shape.shape = cylinder
	body.add_child(shape)
	parent.add_child(body)
	return body


func _cylinder(radius: float, height: float, segments: int) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = segments
	return mesh


func _sphere(radius: float, segments: int, rings: int) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = segments
	mesh.rings = rings
	return mesh


func _torus(inner_radius: float, outer_radius: float, rings: int, ring_segments: int) -> TorusMesh:
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner_radius
	mesh.outer_radius = outer_radius
	mesh.rings = rings
	mesh.ring_segments = ring_segments
	return mesh


func _mat(color: Color, roughness: float = 0.9, metallic: float = 0.0) -> StandardMaterial3D:
	var key := "m|%s|%.2f|%.2f" % [color.to_html(), roughness, metallic]
	if _materials.has(key):
		return _materials[key]
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	_materials[key] = material
	return material


func _emissive(color: Color, energy: float) -> StandardMaterial3D:
	var key := "e|%s|%.2f" % [color.to_html(), energy]
	if _materials.has(key):
		return _materials[key]
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.4
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	_materials[key] = material
	return material
