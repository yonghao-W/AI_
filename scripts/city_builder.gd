class_name CityBuilder
extends Node3D

const ROAD_COLOR := Color("#242b32")
const SIDEWALK_COLOR := Color("#6f7881")
const PARK_COLOR := Color("#3c5a40")
const PARK_PATH_COLOR := Color("#767265")
const WALL_COLOR := Color("#3c444c")
const WALL_STRIPE := Color("#c74b45")
const POLE_COLOR := Color("#4b555e")
const TRUNK_COLOR := Color("#5c4938")
const VAULT_HOLE_RECT := Rect2(-3.8, -8.6, 7.6, 21.2)

var _layout: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _materials: Dictionary = {}
var _cylinders: Dictionary = {}
var _unit_box: BoxMesh
var _warm_windows: Array[Transform3D] = []
var _cool_windows: Array[Transform3D] = []


func build(layout: Dictionary) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_layout = layout
	_warm_windows.clear()
	_cool_windows.clear()
	_materials.clear()
	_cylinders.clear()
	_rng.seed = int(layout.get("seed", 0)) * 7919 + 17
	_unit_box = BoxMesh.new()
	_unit_box.size = Vector3.ONE
	_build_ground()
	_build_blocks()
	_build_terrain()
	_build_buildings()
	_build_props()
	_build_boundaries()
	_flush_windows()


func _build_ground() -> void:
	var total := float(_layout["total_size"])
	var ground_size := total + 36.0
	var half := ground_size * 0.5
	var holes: Array = _layout.get("ground_holes", [VAULT_HOLE_RECT])
	var xs: Array[float] = [-half, half]
	var zs: Array[float] = [-half, half]
	for hole: Rect2 in holes:
		xs.append(hole.position.x)
		xs.append(hole.end.x)
		zs.append(hole.position.y)
		zs.append(hole.end.y)
	xs.sort()
	zs.sort()
	for ix in range(xs.size() - 1):
		for iz in range(zs.size() - 1):
			var cell := Rect2(xs[ix], zs[iz], xs[ix + 1] - xs[ix], zs[iz + 1] - zs[iz])
			var is_hole := false
			for hole: Rect2 in holes:
				if hole.has_point(cell.get_center()):
					is_hole = true
					break
			if not is_hole and cell.has_area():
				_static_box(Vector3(cell.size.x, 1.0, cell.size.y), Vector3(cell.get_center().x, -0.5, cell.get_center().y), ROAD_COLOR, 0.98)
	var markings: Array[Transform3D] = []
	var road_centers: Array = _layout["road_centers"]
	for x in road_centers:
		var z := -half + 7.0
		while z < half - 6.0:
			if not _near_intersection(float(x), z, road_centers):
				markings.append(Transform3D(Basis.IDENTITY.scaled(Vector3(0.22, 0.03, 2.6)), Vector3(x, 0.02, z)))
			z += 6.4
	for z in road_centers:
		var x := -half + 7.0
		while x < half - 6.0:
			if not _near_intersection(x, float(z), road_centers):
				markings.append(Transform3D(Basis.IDENTITY.scaled(Vector3(2.6, 0.03, 0.22)), Vector3(x, 0.02, z)))
			x += 6.4
	_add_multimesh(markings, CityLayout.ROAD_MARK_COLOR, 0.0)


func _near_intersection(x: float, z: float, road_centers: Array) -> bool:
	for cx in road_centers:
		if absf(x - float(cx)) < 6.0:
			for cz in road_centers:
				if absf(z - float(cz)) < 6.0:
					return true
	return false


func _build_blocks() -> void:
	var block_size := float(_layout["block_size"])
	var blocks: Array = _layout["blocks"]
	for block in blocks:
		var center: Vector2 = block["center"]
		if bool(block.get("central", false)) or block["kind"] == "station":
			continue
		var is_park: bool = block["kind"] == "park"
		_add_box(self, Vector3(block_size, 0.14, block_size), Vector3(center.x, 0.07, center.y), SIDEWALK_COLOR, 0.95)
		if is_park:
			_add_box(self, Vector3(block_size - 2.2, 0.08, block_size - 2.2), Vector3(center.x, 0.16, center.y), PARK_COLOR, 1.0)
		else:
			_add_box(self, Vector3(block_size - 1.2, 0.04, block_size - 1.2), Vector3(center.x, 0.155, center.y), Color("#59636c"), 1.0)


func _build_buildings() -> void:
	var buildings: Array = _layout["buildings"]
	for building in buildings:
		var center: Vector2 = building["center"]
		var size: Vector3 = building["size"]
		var color: Color = CityLayout.BUILDING_COLORS[int(building["color_index"])]
		var base_y := 0.14
		if bool(building.get("enterable", false)):
			_build_enterable(building, color, base_y)
			continue
		var full_center := Vector3(center.x, base_y + size.y * 0.5, center.y)
		_static_box(size, full_center, color, 0.94)
		_add_box(self, Vector3(size.x + 0.45, 0.34, size.z + 0.45),
			Vector3(center.x, base_y + size.y + 0.17, center.y), color.darkened(0.34), 0.9)
		_add_box(self, Vector3(size.x + 0.18, 0.9, size.z + 0.18),
			Vector3(center.x, base_y + 0.45, center.y), color.darkened(0.28), 0.95)
		_add_windows(center, size, base_y, int(building["floors"]))
		_add_rooftop(center, size, base_y, color, int(building.get("roof_variant", 0)))
		if _rng.randf() < 0.34:
			var sign_y := base_y + _rng.randf_range(3.0, maxf(3.2, size.y - 1.4))
			var sign_color := Color("#8fd8dc") if _rng.randf() < 0.55 else Color("#e8a35e")
			var sign_side := -1.0 if _rng.randf() < 0.5 else 1.0
			var sign_x := center.x + sign_side * (size.x * 0.5 - 1.1)
			var t := Transform3D(Basis.IDENTITY.scaled(Vector3(0.55, 2.2, 0.08)), Vector3(sign_x, sign_y, center.y + size.z * 0.5 + 0.06))
			if sign_color.b > 0.7:
				_cool_windows.append(t)
			else:
				_warm_windows.append(t)


func _build_enterable(building: Dictionary, color: Color, base_y: float) -> void:
	var center: Vector2 = building["center"]
	var size: Vector3 = building["size"]
	var door_side := int(building.get("door_side", 0))
	var wall := 0.42
	var door_w := 2.6
	var door_h := 2.9
	var wall_h := size.y
	var roof_y := base_y + wall_h + 0.18
	_static_box(Vector3(size.x, 0.2, size.z), Vector3(center.x, base_y + 0.02, center.y), color.darkened(0.42), 0.95)
	_static_box(Vector3(size.x + 0.5, 0.4, size.z + 0.5), Vector3(center.x, roof_y, center.y), color.darkened(0.34), 0.9)
	for side in range(4):
		var along_x := side < 2
		var span := size.x if along_x else size.z
		var wall_x := center.x
		var wall_z := center.y
		if along_x:
			wall_z = center.y + (-1.0 if side == 0 else 1.0) * (size.z * 0.5 - wall * 0.5)
		else:
			wall_x = center.x + (-1.0 if side == 2 else 1.0) * (size.x * 0.5 - wall * 0.5)
		var is_door := side == door_side
		if not is_door:
			if along_x:
				_wall_static(Vector3(span, wall_h, wall), Vector3(wall_x, base_y + wall_h * 0.5, wall_z), color)
			else:
				_wall_static(Vector3(wall, wall_h, span), Vector3(wall_x, base_y + wall_h * 0.5, wall_z), color)
			continue
		var seg_len := (span - door_w) * 0.5
		if seg_len > 0.5:
			if along_x:
				_wall_static(Vector3(seg_len, wall_h, wall), Vector3(center.x - span * 0.5 + seg_len * 0.5, base_y + wall_h * 0.5, wall_z), color)
				_wall_static(Vector3(seg_len, wall_h, wall), Vector3(center.x + span * 0.5 - seg_len * 0.5, base_y + wall_h * 0.5, wall_z), color)
			else:
				_wall_static(Vector3(wall, wall_h, seg_len), Vector3(wall_x, base_y + wall_h * 0.5, center.y - span * 0.5 + seg_len * 0.5), color)
				_wall_static(Vector3(wall, wall_h, seg_len), Vector3(wall_x, base_y + wall_h * 0.5, center.y + span * 0.5 - seg_len * 0.5), color)
		var lintel_h := wall_h - door_h
		if lintel_h > 0.1:
			if along_x:
				_wall_static(Vector3(door_w, lintel_h, wall), Vector3(center.x, base_y + door_h + lintel_h * 0.5, wall_z), color.darkened(0.12))
			else:
				_wall_static(Vector3(wall, lintel_h, door_w), Vector3(wall_x, base_y + door_h + lintel_h * 0.5, center.y), color.darkened(0.12))
	var door_pos := Vector3(center.x, base_y, center.y)
	var door_yaw := 0.0
	match door_side:
		0:
			door_pos.z -= size.z * 0.5 + 0.05
		1:
			door_pos.z += size.z * 0.5 + 0.05
		2:
			door_pos.x -= size.x * 0.5 + 0.05
			door_yaw = PI * 0.5
		3:
			door_pos.x += size.x * 0.5 + 0.05
			door_yaw = PI * 0.5
	var sign := _add_box(self, Vector3(1.8, 0.34, 0.1), door_pos + Vector3(0.0, door_h + 0.35, 0.0), Color("#8fd8dc"), 0.4, 0.0, 1.4)
	sign.rotation.y = door_yaw
	var frame_l := _add_box(self, Vector3(0.12, door_h, 0.12), door_pos + Vector3(-door_w * 0.5 - 0.08 if door_yaw == 0.0 else 0.0, door_h * 0.5, door_w * 0.5 + 0.08 if door_yaw != 0.0 else 0.0), Color("#31474d"), 0.8)
	frame_l.rotation.y = door_yaw
	var frame_r := _add_box(self, Vector3(0.12, door_h, 0.12), door_pos + Vector3(door_w * 0.5 + 0.08 if door_yaw == 0.0 else 0.0, door_h * 0.5, -door_w * 0.5 - 0.08 if door_yaw != 0.0 else 0.0), Color("#31474d"), 0.8)
	frame_r.rotation.y = door_yaw
	_add_windows(center, size, base_y, int(building["floors"]))
	_add_rooftop(center, size, base_y, color, int(building.get("roof_variant", 0)))
	var light := OmniLight3D.new()
	light.position = Vector3(center.x, base_y + minf(wall_h - 1.0, 3.2), center.y)
	light.light_color = Color("#ffd9a0")
	light.light_energy = 1.5
	light.omni_range = minf(11.0, maxf(5.5, size.x * 0.9))
	light.shadow_enabled = false
	add_child(light)
	var crate_size := Vector3(1.1, 0.95, 1.1)
	var crate_pos := Vector3(center.x + size.x * 0.22, base_y + crate_size.y * 0.5 + 0.1, center.y - size.z * 0.18)
	_static_box(crate_size, crate_pos, Color("#3a4648"), 0.9)
	_add_box(self, Vector3(1.16, 0.08, 1.16), crate_pos + Vector3(0.0, crate_size.y * 0.5, 0.0), Color("#8fd8dc"), 0.5, 0.0, 1.1)


func _wall_static(size: Vector3, pos: Vector3, color: Color) -> void:
	_static_box(size, pos, color, 0.94)


func _build_terrain() -> void:
	var terrain: Array = _layout.get("terrain", [])
	var colors := [Color("#59656b"), Color("#4e5a52"), Color("#665c50")]
	for feature in terrain:
		var center: Vector2 = feature["center"]
		var feature_size: Vector2 = feature["size"]
		var height := float(feature["height"])
		var color: Color = colors[int(feature["color_index"]) % colors.size()]
		var top := 0.16 + height
		_static_box(Vector3(feature_size.x, height, feature_size.y), Vector3(center.x, 0.16 + height * 0.5, center.y), color, 0.93)
		_add_box(self, Vector3(feature_size.x + 0.3, 0.14, feature_size.y + 0.3), Vector3(center.x, top + 0.04, center.y), color.lightened(0.08), 0.9)
		_add_box(self, Vector3(feature_size.x, 0.12, 0.12), Vector3(center.x, top + 0.6, center.y - feature_size.y * 0.5 + 0.3), Color("#2f3c41"), 0.7, 0.4)
		var ramp_side := int(feature.get("ramp_side", 0))
		var ramp_len := 3.8
		var angle := atan2(height, ramp_len)
		var direction := -1.0 if ramp_side == 0 else 1.0
		var ramp := StaticBody3D.new()
		ramp.position = Vector3(center.x, 0.16 + height * 0.5, center.y + direction * (feature_size.y * 0.5 + ramp_len * 0.5))
		ramp.rotation.x = angle if direction > 0.0 else -angle
		ramp.collision_layer = 1
		ramp.collision_mask = 0
		var mesh := MeshInstance3D.new()
		mesh.mesh = _unit_box
		mesh.scale = Vector3(2.9, 0.4, sqrt(ramp_len * ramp_len + height * height))
		mesh.material_override = _mat(color.darkened(0.08), 0.0, 0.93)
		ramp.add_child(mesh)
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = mesh.scale
		shape.shape = box
		ramp.add_child(shape)
		add_child(ramp)
		_add_box(self, Vector3(2.9, 0.06, 0.25), Vector3(center.x, top + 0.06, center.y + direction * (feature_size.y * 0.5 - 0.1)), Color("#c9b87a"), 0.6, 0.0, 0.8)
		for i in range(3):
			_add_box(self, Vector3(0.55, 0.55, 0.55), Vector3(center.x - 1.6 + i * 1.7, top + 0.3, center.y + 1.0), Color("#3a4648"), 0.9)


func _build_cover() -> void:
	var covers: Array = _layout.get("cover", [])
	var colors := [Color("#5a6268"), Color("#6b5a49"), Color("#3d4a50")]
	for cover in covers:
		var pos: Vector3 = cover["pos"]
		var size: Vector3 = cover["size"]
		var color: Color = colors[int(cover["color_index"]) % colors.size()]
		var body := StaticBody3D.new()
		body.position = pos + Vector3(0.0, size.y * 0.5, 0.0)
		body.rotation.y = float(cover["rot"])
		body.collision_layer = 1
		body.collision_mask = 0
		var mesh := MeshInstance3D.new()
		mesh.mesh = _unit_box
		mesh.scale = size
		mesh.material_override = _mat(color, 0.0, 0.9)
		body.add_child(mesh)
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = size
		shape.shape = box
		body.add_child(shape)
		add_child(body)
		_add_box(body, Vector3(size.x, 0.1, size.z * 1.04), Vector3(0.0, size.y * 0.5 - 0.05, 0.0), Color("#d8c37a"), 0.8, 0.0, 0.5)


func _add_windows(center: Vector2, size: Vector3, base_y: float, floors: int) -> void:
	for floor in range(floors):
		var wy := base_y + floor * 3.2 + 1.85
		if wy > base_y + size.y - 0.6:
			break
		var count_x := maxi(1, int((size.x - 2.4) / 2.8))
		var start_x := center.x - (count_x - 1) * 1.4
		for i in range(count_x):
			var wx := start_x + i * 2.8
			for side in [-1.0, 1.0]:
				if _rng.randf() < 0.24:
					continue
				var wz: float = center.y + side * (size.z * 0.5 + 0.045)
				_add_window_transform(Vector3(wx, wy, wz), Vector3(1.35, 0.98, 0.07))
		var count_z := maxi(1, int((size.z - 2.4) / 2.8))
		var start_z := center.y - (count_z - 1) * 1.4
		for i in range(count_z):
			var wz := start_z + i * 2.8
			for side in [-1.0, 1.0]:
				if _rng.randf() < 0.24:
					continue
				var wx: float = center.x + side * (size.x * 0.5 + 0.045)
				_add_window_transform(Vector3(wx, wy, wz), Vector3(0.07, 0.98, 1.35))
	if _rng.randf() < 0.55 and size.y > 4.5:
		var band_width := maxf(2.0, size.x - 3.2)
		_add_window_transform(
			Vector3(center.x, base_y + 1.25, center.y + size.z * 0.5 + 0.06),
			Vector3(band_width, 0.85, 0.08)
		)


func _add_window_transform(pos: Vector3, scale: Vector3) -> void:
	var t := Transform3D(Basis.IDENTITY.scaled(scale), pos)
	if _rng.randf() < 0.58:
		_warm_windows.append(t)
	else:
		_cool_windows.append(t)


func _add_rooftop(center: Vector2, size: Vector3, base_y: float, color: Color, variant: int) -> void:
	var roof_y := base_y + size.y + 0.34
	var count := _rng.randi_range(0, 2) if variant > 0 else _rng.randi_range(0, 1)
	for i in range(count):
		var box_size := Vector3(_rng.randf_range(0.7, 1.7), _rng.randf_range(0.4, 0.9), _rng.randf_range(0.7, 1.7))
		var pos := Vector3(
			center.x + _rng.randf_range(-size.x * 0.3, size.x * 0.3),
			roof_y + box_size.y * 0.5,
			center.y + _rng.randf_range(-size.z * 0.3, size.z * 0.3)
		)
		_add_box(self, box_size, pos, color.darkened(0.42), 0.9)
	if variant == 2 and size.y > 12.0:
		var tank := _cylinder(1.0, 2.0, 8)
		var mesh := MeshInstance3D.new()
		mesh.mesh = tank
		mesh.position = Vector3(center.x + size.x * 0.22, roof_y + 1.0, center.y - size.z * 0.2)
		mesh.material_override = _mat(Color("#87949a"), 0.0, 0.65, 0.3)
		add_child(mesh)


func _build_props() -> void:
	var terrain_rects: Array[Rect2] = []
	for feature in _layout.get("terrain", []):
		var feature_center: Vector2 = feature["center"]
		var fsize: Vector2 = feature["size"]
		var rect := Rect2(feature_center - fsize * 0.5, fsize).grow(0.8)
		if int(feature.get("ramp_side", 0)) == 0:
			rect = rect.merge(Rect2(rect.position.x, rect.position.y - 3.8, rect.size.x, 3.8))
		else:
			rect = rect.merge(Rect2(rect.position.x, rect.end.y, rect.size.x, 3.8))
		terrain_rects.append(rect)
	var blocks: Array = _layout["blocks"]
	for block in blocks:
		var trees: Array = block.get("trees", [])
		for tree in trees:
			var pos: Vector3 = tree["pos"]
			if bool(block.get("central", false)) and VAULT_HOLE_RECT.grow(1.6).has_point(Vector2(pos.x, pos.z)):
				continue
			var on_terrain := false
			for terrain_rect in terrain_rects:
				if terrain_rect.has_point(Vector2(pos.x, pos.z)):
					on_terrain = true
					break
			if on_terrain:
				continue
			var tree_scale := float(tree["scale"])
			var foliage_color: Color = CityLayout.TREE_COLORS[int(tree["color_index"])]
			var trunk := _cylinder(0.18 * tree_scale, 2.1 * tree_scale, 6)
			var trunk_node := MeshInstance3D.new()
			trunk_node.mesh = trunk
			trunk_node.position = Vector3(pos.x, 0.16 + 1.05 * tree_scale, pos.z)
			trunk_node.material_override = _mat(TRUNK_COLOR, 0.0, 1.0)
			trunk_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			add_child(trunk_node)
			for layer in range(2):
				var cone := _cylinder((1.55 - layer * 0.35) * tree_scale, (2.8 - layer * 0.5) * tree_scale, 7, 0.0)
				var leaves := MeshInstance3D.new()
				leaves.mesh = cone
				leaves.position = Vector3(pos.x, 0.16 + (2.6 + layer * 1.35) * tree_scale, pos.z)
				leaves.material_override = _mat(foliage_color.lightened(layer * 0.06), 0.0, 1.0)
				add_child(leaves)
		if bool(block.get("fountain", false)) and not bool(block.get("central", false)):
			_build_fountain(block["center"])

	_build_cover()

	var lights: Array = _layout["streetlights"]
	var pole := _cylinder(0.075, 5.8, 6)
	var pole_material := _mat(POLE_COLOR, 0.0, 0.6, 0.5)
	var lamp_material := _mat(Color("#ffd493"), 2.4, 0.4)
	for light_pos in lights:
		var pole_node := MeshInstance3D.new()
		pole_node.mesh = pole
		pole_node.position = Vector3(light_pos.x, 0.16 + 2.9, light_pos.z)
		pole_node.material_override = pole_material
		add_child(pole_node)
		var head := MeshInstance3D.new()
		head.mesh = _unit_box
		head.scale = Vector3(0.62, 0.16, 0.36)
		head.position = Vector3(light_pos.x, 0.16 + 5.82, light_pos.z)
		head.material_override = lamp_material
		head.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(head)

	var cars: Array = _layout["cars"]
	var wheel := _cylinder(0.32, 0.26, 8)
	for car in cars:
		_build_car(car, wheel)


func _build_car(car: Dictionary, wheel_mesh: CylinderMesh) -> void:
	var body := StaticBody3D.new()
	body.position = car["pos"]
	body.rotation.y = float(car["rot"])
	body.collision_layer = 1
	body.collision_mask = 0
	var color: Color = CityLayout.CAR_COLORS[int(car["color_index"])]
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.0, 1.4, 4.2)
	shape.shape = box
	shape.position.y = 0.7
	body.add_child(shape)
	add_child(body)
	_add_box(body, Vector3(1.86, 0.58, 4.15), Vector3(0.0, 0.62, 0.0), color, 0.55, 0.25)
	_add_box(body, Vector3(1.62, 0.55, 2.05), Vector3(0.0, 1.14, -0.2), Color("#263541"), 0.3, 0.45)
	_add_box(body, Vector3(1.7, 0.08, 2.2), Vector3(0.0, 1.44, -0.2), color.darkened(0.25), 0.6)
	for x in [-0.92, 0.92]:
		for z in [-1.32, 1.32]:
			var wheel_node := MeshInstance3D.new()
			wheel_node.mesh = wheel_mesh
			wheel_node.position = Vector3(x, 0.34, z)
			wheel_node.rotation.z = PI * 0.5
			wheel_node.material_override = _mat(Color("#15181a"), 0.0, 0.9)
			body.add_child(wheel_node)
	for x in [-0.6, 0.6]:
		_add_box(body, Vector3(0.36, 0.16, 0.08), Vector3(x, 0.66, 2.08), Color("#ffe0a0"), 0.3, 0.0, 2.2)
		_add_box(body, Vector3(0.36, 0.16, 0.08), Vector3(x, 0.66, -2.08), Color("#d94f4f"), 0.3, 0.0, 1.2)


func _build_fountain(center: Vector2) -> void:
	var stone := _mat(Color("#8e9088"), 0.0, 0.9)
	var basin := _cylinder(3.2, 0.7, 12)
	var basin_node := MeshInstance3D.new()
	basin_node.mesh = basin
	basin_node.position = Vector3(center.x, 0.5, center.y)
	basin_node.material_override = stone
	add_child(basin_node)
	var water := _cylinder(2.72, 0.12, 12)
	var water_node := MeshInstance3D.new()
	water_node.mesh = water
	water_node.position = Vector3(center.x, 0.84, center.y)
	water_node.material_override = _mat(Color("#4b9aa2"), 0.7, 0.25, 0.1)
	add_child(water_node)
	var column := _cylinder(0.34, 1.7, 8)
	var column_node := MeshInstance3D.new()
	column_node.mesh = column
	column_node.position = Vector3(center.x, 1.55, center.y)
	column_node.material_override = stone
	add_child(column_node)
	var top := _cylinder(1.1, 0.18, 10)
	var top_node := MeshInstance3D.new()
	top_node.mesh = top
	top_node.position = Vector3(center.x, 2.4, center.y)
	top_node.material_override = _mat(Color("#5da9ae"), 0.5, 0.3)
	add_child(top_node)


func _build_boundaries() -> void:
	var total := float(_layout["total_size"])
	var half := total * 0.5
	var wall_height := 5.2
	var thickness := 1.4
	var body_color := WALL_COLOR
	_static_box(Vector3(total + thickness * 2.0, wall_height, thickness), Vector3(0.0, wall_height * 0.5, half + thickness * 0.5), body_color, 0.95)
	_static_box(Vector3(total + thickness * 2.0, wall_height, thickness), Vector3(0.0, wall_height * 0.5, -half - thickness * 0.5), body_color, 0.95)
	_static_box(Vector3(thickness, wall_height, total), Vector3(half + thickness * 0.5, wall_height * 0.5, 0.0), body_color, 0.95)
	_static_box(Vector3(thickness, wall_height, total), Vector3(-half - thickness * 0.5, wall_height * 0.5, 0.0), body_color, 0.95)
	for side in [-1.0, 1.0]:
		_add_box(self, Vector3(total + thickness * 2.0, 0.16, 0.3), Vector3(0.0, wall_height + 0.08, side * (half + thickness * 0.5)), WALL_STRIPE, 0.5, 0.0, 1.8)
		_add_box(self, Vector3(0.3, 0.16, total), Vector3(side * (half + thickness * 0.5), wall_height + 0.08, 0.0), WALL_STRIPE, 0.5, 0.0, 1.8)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_add_box(self, Vector3(2.2, 7.4, 2.2), Vector3(sx * (half + 0.7), 3.7, sz * (half + 0.7)), Color("#4a5258"), 0.9)
			_add_box(self, Vector3(1.4, 0.4, 1.4), Vector3(sx * (half + 0.7), 7.6, sz * (half + 0.7)), WALL_STRIPE, 0.5, 0.0, 2.0)


func _flush_windows() -> void:
	_add_multimesh(_warm_windows, Color("#ffd18a"), 1.9)
	_add_multimesh(_cool_windows, Color("#8fd3de"), 1.3)


func _add_multimesh(transforms: Array[Transform3D], color: Color, emission: float) -> void:
	if transforms.is_empty():
		return
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = _unit_box
	multimesh.instance_count = transforms.size()
	for i in range(transforms.size()):
		multimesh.set_instance_transform(i, transforms[i])
	var node := MultiMeshInstance3D.new()
	node.multimesh = multimesh
	node.material_override = _mat(color, emission, 0.6)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)


func _add_box(parent: Node3D, size: Vector3, pos: Vector3, color: Color, roughness: float = 0.95, metallic: float = 0.0, emission: float = 0.0) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = _unit_box
	node.scale = size
	node.position = pos
	node.material_override = _mat(color, emission, roughness, metallic)
	parent.add_child(node)
	return node


func _static_box(size: Vector3, pos: Vector3, color: Color, roughness: float = 0.95) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = pos
	body.collision_layer = 1
	body.collision_mask = 0
	var mesh := MeshInstance3D.new()
	mesh.mesh = _unit_box
	mesh.scale = size
	mesh.material_override = _mat(color, 0.0, roughness)
	body.add_child(mesh)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	add_child(body)
	return body


func _cylinder(radius: float, height: float, segments: int, top_radius: float = -1.0) -> CylinderMesh:
	var key := "%s|%s|%s" % [radius, height, segments]
	if top_radius >= 0.0:
		key += "|%s" % top_radius
	if _cylinders.has(key):
		return _cylinders[key]
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = radius
	mesh.top_radius = top_radius if top_radius >= 0.0 else radius
	mesh.height = height
	mesh.radial_segments = segments
	mesh.rings = 1
	_cylinders[key] = mesh
	return mesh


func _mat(color: Color, emission: float = 0.0, roughness: float = 0.95, metallic: float = 0.0) -> StandardMaterial3D:
	var key := "%s|%.2f|%.2f|%.2f" % [color.to_html(), emission, roughness, metallic]
	if _materials.has(key):
		return _materials[key]
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	if emission > 0.0:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = emission
	_materials[key] = material
	return material
