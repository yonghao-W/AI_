class_name ChapterOneStation
extends Node3D

const MODEL = preload("res://assets/chapter_01/e07_station.glb")
const CENTER := Vector3(80.0, 0.0, -80.0)
const FOOTPRINT := Rect2(62.0, -88.0, 31.0, 17.0)
const BASEMENT_HOLE := Rect2(67.8, -87.2, 24.4, 14.4)
const SPAWN_YAW := -1.13
const SPAWNS := [
	CENTER + Vector3(-1.0, 7.58, 1.8), CENTER + Vector3(1.0, 7.58, 1.8),
	CENTER + Vector3(-1.0, 7.58, -0.7), CENTER + Vector3(1.0, 7.58, -0.7),
]
const RADIO_POINT := CENTER + Vector3(4.1, 7.52, 1.4)


static func prepare_layout(layout: Dictionary) -> void:
	# 保留完整地块，随机建筑、树木、车辆和坡台不能堵住维护站出口。
	var reserved := FOOTPRINT.grow(1.0)
	for block in layout["blocks"]:
		if block["center"].is_equal_approx(Vector2(CENTER.x, CENTER.z)):
			block["kind"] = "station"
			block["buildings"] = []
			block["trees"] = []
			block["fountain"] = false
	layout["buildings"] = layout["buildings"].filter(func(b: Dictionary) -> bool:
		var size: Vector3 = b["size"]
		return not Rect2(b["center"] - Vector2(size.x, size.z) * 0.5, Vector2(size.x, size.z)).intersects(reserved)
	)
	for key in ["cars", "cover", "streetlights", "zombie_spawns"]:
		layout[key] = layout[key].filter(func(item: Variant) -> bool:
			var point: Vector3 = item["pos"] if item is Dictionary else item
			return not reserved.has_point(Vector2(point.x, point.z))
		)
	layout["terrain"] = layout["terrain"].filter(func(t: Dictionary) -> bool:
		return not Rect2(t["center"] - t["size"] * 0.5, t["size"]).grow(4.0).intersects(reserved)
	)
	layout["ground_holes"] = [CityBuilder.VAULT_HOLE_RECT, BASEMENT_HOLE]


func build() -> void:
	position = CENTER
	var model := MODEL.instantiate() as Node3D
	model.name = "Architecture"
	# 原包将 Z-up 坐标直接写进 GLB，这里统一转换为 Godot 的 Y-up。
	model.rotation.x = -PI * 0.5
	add_child(model)
	var faces := PackedVector3Array()
	_collect_geometry(model, model.transform, faces)
	var body := StaticBody3D.new()
	body.name = "ArchitectureCollision"
	var shape := CollisionShape3D.new()
	var trimesh := ConcavePolygonShape3D.new()
	trimesh.set_faces(faces)
	shape.shape = trimesh
	body.add_child(shape)
	add_child(body)
	_build_stair_ramps()
	_build_context()
	_add_sign("第一章 · 失联信号\nE-07 高架信号维护站", Vector3(0.0, 2.7, 7.25), 0.0, 46)
	_add_sign("西侧楼梯  ←  基地 / 核心回收", Vector3(-2.72, 9.2, 3.65), PI * 0.5, 30)
	_add_sign("出口  ←", Vector3(-5.77, 2.6, 3.65), PI * 0.5, 38)
	_add_sign("无线电终端", Vector3(4.1, 9.1, 0.3), 0.0, 26)
	for height in [-1.6, 2.1, 5.5, 9.0]:
		var light := OmniLight3D.new()
		light.position = Vector3(-7.0, height, 3.5)
		light.light_color = Color("#b6cbd0")
		light.light_energy = 1.4
		light.omni_range = 12.0
		add_child(light)
	var observation_light := OmniLight3D.new()
	observation_light.position = Vector3(4.5, 9.7, -1.5)
	observation_light.light_color = Color("#ffd6a0")
	observation_light.light_energy = 0.7
	observation_light.omni_range = 14.0
	add_child(observation_light)


func _collect_geometry(node: Node3D, transform_to_station: Transform3D, faces: PackedVector3Array) -> void:
	if node is MeshInstance3D:
		var mesh_node := node as MeshInstance3D
		var label := String(node.name)
		if label.begins_with("MARKER_"):
			mesh_node.hide()
		else:
			var is_step := label.begins_with("B1_TO_F1_") or label.begins_with("F1_TO_F2_") or label.begins_with("F2_TO_F3_") or label.contains("_FLIGHT_")
			# 楼板已负责承重；略高于楼面的框架梁不能形成数厘米高的隐形门槛。
			if (not is_step or label.ends_with("LANDING")) and not label.begins_with("STR_BEAM_"):
				for vertex in mesh_node.mesh.get_faces():
					faces.append(transform_to_station * vertex)
	for child in node.get_children():
		if child is Node3D:
			_collect_geometry(child, transform_to_station * child.transform, faces)


func contains_point(point: Vector3) -> bool:
	return FOOTPRINT.has_point(Vector2(point.x, point.z)) and point.y > -3.5 and point.y < 13.0


func zone_name(point: Vector3) -> String:
	if point.y < -0.5:
		return "E-07 · 地下配电层"
	if point.y < 3.8:
		return "E-07 · 一楼维修车间"
	if point.y < 7.2:
		return "E-07 · 二楼通信室"
	return "第一章 · E-07 三楼观察室"


func can_use_radio(point: Vector3) -> bool:
	return absf(point.y - RADIO_POINT.y) < 1.0 and Vector2(point.x - RADIO_POINT.x, point.z - RADIO_POINT.z).length() < 2.5


func _build_stair_ramps() -> void:
	var levels := [-3.2, 0.0, 4.0, 7.4]
	for height in [0.0, 4.0, 7.4]:
		# 原包西侧楼板余宽不足胶囊直径，补足外门与楼梯顶平台之间的通道。
		_add_box("WestExitWalkway", Vector3(1.0, 0.16, 3.95), Vector3(-11.5, height + 0.04, 4.875), Color("#858781"), true)
	for i in range(3):
		var bottom: float = levels[i]
		var top: float = levels[i + 1]
		var middle := (bottom + top) * 0.5
		_add_ramp("Interior%dA" % i, Vector3(-10.75, bottom + 0.12, 6.4), Vector3(-10.75, middle + 0.1, 1.85), 1.35)
		_add_ramp("Interior%dB" % i, Vector3(-8.25, middle + 0.1, 1.85), Vector3(-8.25, top + 0.12, 6.4), 1.35)
	for i in range(2):
		var bottom: float = levels[i + 1]
		var top: float = levels[i + 2]
		var middle := (bottom + top) * 0.5
		_add_ramp("Exterior%dA" % i, Vector3(-14.2, bottom + 0.16, 3.8), Vector3(-14.2, middle + 0.09, 0.08), 1.2)
		_add_ramp("Exterior%dB" % i, Vector3(-16.1, middle + 0.09, 0.08), Vector3(-16.1, top + 0.16, 3.75), 1.2)
		# 原包的高层平台只覆盖内侧梯段，补桥接才能从外侧梯段走回门口。
		_add_box("ExteriorBridge%d" % i, Vector3(4.6, 0.16, 1.3), Vector3(-14.2, top + 0.08, 4.4), Color("#58676a"), true)


func _add_ramp(label: String, start: Vector3, end: Vector3, width: float) -> void:
	var body := StaticBody3D.new()
	body.name = label
	var rise := end.y - start.y
	var run := end.z - start.z
	var angle := atan(rise / run)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(width, 0.1, Vector2(run, rise).length())
	shape.shape = box
	body.position = (start + end) * 0.5 - Vector3(0.0, 0.05 / cos(angle), 0.0)
	body.rotation.x = -angle
	body.add_child(shape)
	add_child(body)


func _add_box(label: String, size: Vector3, point: Vector3, color: Color, solid: bool = false) -> void:
	var mesh := MeshInstance3D.new()
	mesh.name = label
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.95
	mesh.material_override = material
	mesh.position = point
	add_child(mesh)
	if solid:
		mesh.create_trimesh_collision()


func _build_context() -> void:
	_add_box("ViaductDeck", Vector3(180.0, 0.6, 5.0), Vector3(10.0, 7.1, -28.0), Color("#53636d"))
	for x in [-30.0, -10.0, 10.0, 30.0, 50.0, 70.0]:
		_add_box("ViaductPier", Vector3(1.4, 7.0, 1.8), Vector3(x, 3.5, -28.0), Color("#5c6565"))
	_add_box("AbandonedTrain", Vector3(14.0, 2.3, 2.9), Vector3(-1.0, 8.85, -28.0), Color("#72857d"))
	for x in range(-6, 6, 2):
		_add_box("TrainWindow", Vector3(1.2, 0.8, 0.03), Vector3(x, 9.1, -26.53), Color("#20343f"))
	for i in range(6):
		var height := 16.0 + (i % 3) * 7.0
		_add_box("DistantCity", Vector3(9.0, height, 10.0), Vector3(i * 16.0 - 5.0, height * 0.5, -48.0 - (i % 2) * 14.0), Color("#2a3c49"))


func _add_sign(text: String, point: Vector3, yaw: float, font_size_value: int) -> void:
	var label := Label3D.new()
	label.text = text
	label.position = point
	label.rotation.y = yaw
	label.font = DeadCityUI.display_font()
	label.font_size = font_size_value
	label.pixel_size = 0.004
	label.modulate = Color("#e8d5a6")
	label.outline_size = 6
	add_child(label)
