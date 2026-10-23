class_name CityLayout
extends RefCounted

const BUILDING_COLORS := [
	Color("#5f7183"), Color("#7d6b5d"), Color("#596b64"), Color("#726a80"),
	Color("#8a735f"), Color("#53687b"), Color("#6f7b62"), Color("#846a72"),
]
const CAR_COLORS := [
	Color("#b5483f"), Color("#d7a541"), Color("#4e7d9c"), Color("#c9d0d4"),
	Color("#6a6f78"), Color("#7b5a8f"),
]
const TREE_COLORS := [
	Color("#40694d"), Color("#4e7a55"), Color("#38604a"), Color("#5c8158"),
]
const ROAD_MARK_COLOR := Color("#d8c37a")


static func generate(seed_value: int, grid_size: int = 5, block_size: float = 28.0, road_width: float = 12.0) -> Dictionary:
	grid_size = maxi(3, grid_size)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var pitch := block_size + road_width
	var total_size := grid_size * pitch + road_width
	var origin := -total_size * 0.5
	var center_cell := int(grid_size * 0.5)

	var road_centers: Array[float] = []
	for k in range(grid_size + 1):
		road_centers.append(origin + road_width * 0.5 + k * pitch)

	var blocks: Array = []
	var streetlights: Array[Vector3] = []
	var cars: Array = []
	var buildings_flat: Array = []

	for gx in range(grid_size):
		for gz in range(grid_size):
			var center := Vector2(
				origin + road_width + gx * pitch + block_size * 0.5,
				origin + road_width + gz * pitch + block_size * 0.5
			)
			var central := gx == center_cell and gz == center_cell
			var is_park := central or rng.randf() < 0.2
			var block := {
				"center": center,
				"kind": "park" if is_park else "building",
				"central": central,
				"buildings": [],
				"trees": [],
			}
			if is_park:
				block["trees"] = _make_trees(rng, center, block_size, central)
				block["fountain"] = central
			else:
				var made: Array = _make_buildings(rng, center, block_size)
				block["buildings"] = made
				for building in made:
					buildings_flat.append(building)
			blocks.append(block)

			var inset := block_size * 0.5 - 1.4
			streetlights.append(Vector3(center.x - inset, 0.0, center.y - inset))
			streetlights.append(Vector3(center.x + inset, 0.0, center.y + inset))

			if rng.randf() < 0.46:
				var side := rng.randi_range(0, 3)
				var reach := block_size * 0.5 + road_width * 0.28
				var along := rng.randf_range(-block_size * 0.28, block_size * 0.28)
				var car_pos := center
				var car_rot := 0.0
				match side:
					0:
						car_pos += Vector2(along, -reach)
						car_rot = PI * 0.5
					1:
						car_pos += Vector2(along, reach)
						car_rot = PI * 0.5
					2:
						car_pos += Vector2(-reach, along)
					3:
						car_pos += Vector2(reach, along)
				cars.append({
					"pos": Vector3(car_pos.x, 0.0, car_pos.y),
					"rot": car_rot,
					"color_index": rng.randi_range(0, CAR_COLORS.size() - 1),
				})

	var spawn_points: Array[Vector3] = []
	for ix in range(1, grid_size):
		for iz in range(1, grid_size):
			spawn_points.append(Vector3(road_centers[ix], 0.06, road_centers[iz]))
	spawn_points.sort_custom(func(a: Vector3, b: Vector3) -> bool:
		return a.length_squared() < b.length_squared()
	)

	var zombie_spawns: Array[Vector3] = []
	var edge_near := road_centers[0]
	var edge_far := road_centers[grid_size]
	for k in range(grid_size + 1):
		_append_unique(zombie_spawns, Vector3(road_centers[k], 0.06, edge_near))
		_append_unique(zombie_spawns, Vector3(road_centers[k], 0.06, edge_far))
		_append_unique(zombie_spawns, Vector3(edge_near, 0.06, road_centers[k]))
		_append_unique(zombie_spawns, Vector3(edge_far, 0.06, road_centers[k]))
	for k in range(grid_size):
		var mid := origin + road_width * 0.5 + (k + 0.5) * pitch
		_append_unique(zombie_spawns, Vector3(mid, 0.06, edge_near))
		_append_unique(zombie_spawns, Vector3(mid, 0.06, edge_far))
		_append_unique(zombie_spawns, Vector3(edge_near, 0.06, mid))
		_append_unique(zombie_spawns, Vector3(edge_far, 0.06, mid))
		for street in road_centers:
			_append_unique(zombie_spawns, Vector3(street, 0.06, mid))
			_append_unique(zombie_spawns, Vector3(mid, 0.06, street))

	return {
		"seed": seed_value,
		"grid": grid_size,
		"block_size": block_size,
		"road_width": road_width,
		"pitch": pitch,
		"total_size": total_size,
		"road_centers": road_centers,
		"blocks": blocks,
		"buildings": buildings_flat,
		"spawn_points": spawn_points,
		"zombie_spawns": zombie_spawns,
		"streetlights": streetlights,
		"cars": cars,
	}


static func _make_buildings(rng: RandomNumberGenerator, block_center: Vector2, block_size: float) -> Array:
	var usable := block_size - 8.0
	var wanted := rng.randi_range(1, 3)
	var rects: Array[Rect2] = []
	var result: Array = []
	for i in range(wanted):
		for attempt in range(18):
			var w := rng.randf_range(6.4, minf(13.0, usable * 0.68))
			var d := rng.randf_range(6.4, minf(13.0, usable * 0.68))
			var min_x := block_center.x - usable * 0.5 + w * 0.5
			var max_x := block_center.x + usable * 0.5 - w * 0.5
			var min_z := block_center.y - usable * 0.5 + d * 0.5
			var max_z := block_center.y + usable * 0.5 - d * 0.5
			var cx := rng.randf_range(min_x, max_x)
			var cz := rng.randf_range(min_z, max_z)
			var rect := Rect2(cx - w * 0.5, cz - d * 0.5, w, d)
			var blocked := false
			for other in rects:
				if rect.grow(1.4).intersects(other):
					blocked = true
					break
			if blocked:
				continue
			var floors := rng.randi_range(2, 6)
			result.append({
				"center": Vector2(cx, cz),
				"size": Vector3(w, floors * 3.2 + rng.randf_range(0.1, 1.1), d),
				"floors": floors,
				"color_index": rng.randi_range(0, BUILDING_COLORS.size() - 1),
				"roof_variant": rng.randi_range(0, 2),
			})
			rects.append(rect)
			break
	if result.is_empty():
		var size := Vector3(10.0, 9.8, 10.0)
		result.append({
			"center": block_center,
			"size": size,
			"floors": 3,
			"color_index": rng.randi_range(0, BUILDING_COLORS.size() - 1),
			"roof_variant": 0,
		})
	return result


static func _make_trees(rng: RandomNumberGenerator, block_center: Vector2, block_size: float, central: bool) -> Array:
	var trees: Array = []
	var count := rng.randi_range(5, 9)
	var spread := block_size * 0.33
	for i in range(count):
		var offset := Vector2(
			rng.randf_range(-spread, spread),
			rng.randf_range(-spread, spread)
		)
		if central and offset.length() < 6.0:
			offset = offset.normalized() * 6.5
		trees.append({
			"pos": Vector3(block_center.x + offset.x, 0.0, block_center.y + offset.y),
			"scale": rng.randf_range(0.8, 1.35),
			"color_index": rng.randi_range(0, TREE_COLORS.size() - 1),
		})
	return trees


static func _append_unique(list: Array[Vector3], point: Vector3) -> void:
	for existing in list:
		if existing.distance_squared_to(point) < 0.01:
			return
	list.append(point)


static func validate(layout: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var grid: int = int(layout.get("grid", 0))
	var total: float = float(layout.get("total_size", 0.0))
	var half := total * 0.5
	var blocks: Array = layout.get("blocks", [])
	if blocks.size() != grid * grid:
		errors.append("block count %d != %d" % [blocks.size(), grid * grid])
	if layout.get("spawn_points", []).size() < 4:
		errors.append("too few player spawn points")
	if layout.get("zombie_spawns", []).size() < 8:
		errors.append("too few zombie spawn points")

	var all_rects: Array[Rect2] = []
	for block in blocks:
		var block_center: Vector2 = block["center"]
		var block_buildings: Array = block["buildings"]
		if block["kind"] == "park" and block_buildings.size() > 0:
			errors.append("park block contains buildings")
		var local_rects: Array[Rect2] = []
		for building in block_buildings:
			var size: Vector3 = building["size"]
			var center: Vector2 = building["center"]
			if size.x <= 1.0 or size.y <= 1.0 or size.z <= 1.0:
				errors.append("building has invalid size")
			var rect := Rect2(center - Vector2(size.x, size.z) * 0.5, Vector2(size.x, size.z))
			if rect.position.x < -half or rect.position.y < -half or rect.end.x > half or rect.end.y > half:
				errors.append("building outside world bounds")
			if absf(center.x - block_center.x) + size.x * 0.5 > float(layout["block_size"]) * 0.5:
				errors.append("building exceeds block width")
			if absf(center.y - block_center.y) + size.z * 0.5 > float(layout["block_size"]) * 0.5:
				errors.append("building exceeds block depth")
			for other in local_rects:
				if rect.intersects(other):
					errors.append("buildings overlap inside a block")
			local_rects.append(rect)
			all_rects.append(rect)

	for point in layout.get("spawn_points", []):
		var p := Vector2(point.x, point.z)
		if absf(p.x) > half - 1.0 or absf(p.y) > half - 1.0:
			errors.append("player spawn outside bounds")
		for rect in all_rects:
			if rect.grow(0.4).has_point(p):
				errors.append("player spawn inside a building")
	for point in layout.get("zombie_spawns", []):
		var p := Vector2(point.x, point.z)
		if absf(p.x) > half - 1.0 or absf(p.y) > half - 1.0:
			errors.append("zombie spawn outside bounds")
		for rect in all_rects:
			if rect.grow(0.2).has_point(p):
				errors.append("zombie spawn inside a building")

	return errors
