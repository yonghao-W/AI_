extends SceneTree
## Abandoned_House 资产回归：资源可加载、网格/材质/贴图规模符合记录、包围盒非空。

const ASSET_PATH := "res://assets/models/abandoned_house/abandoned_house.glb"

var checks := 0
var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)


func _run() -> void:
	var packed: PackedScene = load(ASSET_PATH)
	_check(packed != null, "Failed to load %s" % ASSET_PATH)
	if packed == null:
		print("Abandoned house asset: %d checks, %d failures" % [checks, failures])
		quit(1)
		return

	var scene := packed.instantiate()
	root.add_child(scene)
	await process_frame

	var aabb := AABB()
	var has_bounds := false
	var mesh_count := 0
	var surface_count := 0
	var vertex_count := 0
	var materials: Dictionary = {}
	var textures: Dictionary = {}
	var stack: Array[Node] = [scene]

	while not stack.is_empty():
		var node: Node = stack.pop_back()
		var mesh_instance := node as MeshInstance3D
		if mesh_instance != null and mesh_instance.mesh != null:
			mesh_count += 1
			var bounds: AABB = mesh_instance.global_transform * mesh_instance.get_aabb()
			aabb = bounds if not has_bounds else aabb.merge(bounds)
			has_bounds = true
			var mesh := mesh_instance.mesh
			for surface in range(mesh.get_surface_count()):
				surface_count += 1
				var arrays := mesh.surface_get_arrays(surface)
				var vertices = arrays[Mesh.ARRAY_VERTEX]
				if vertices != null:
					vertex_count += vertices.size()
				var material := mesh.surface_get_material(surface)
				if material != null:
					materials[material.get_instance_id()] = true
					var albedo = material.get("albedo_texture")
					if albedo != null:
						textures[albedo.get_instance_id()] = true
		for child in node.get_children():
			stack.append(child)

	print("[asset] meshes=%d surfaces=%d vertices=%d materials=%d textures=%d" % [
		mesh_count, surface_count, vertex_count, materials.size(), textures.size()
	])
	print("[asset] aabb.position=%s aabb.size=%s" % [aabb.position, aabb.size])

	_check(mesh_count >= 500, "Unexpected mesh count: %d" % mesh_count)
	_check(materials.size() >= 50, "Unexpected material count: %d" % materials.size())
	_check(textures.size() >= 50, "Unexpected texture count: %d" % textures.size())
	_check(vertex_count >= 100000, "Unexpected vertex count: %d" % vertex_count)
	_check(has_bounds, "No mesh bounds found")
	_check(aabb.size.x > 1.0 and aabb.size.y > 1.0 and aabb.size.z > 1.0, "Unreasonable asset size: %s" % aabb.size)

	scene.queue_free()
	await process_frame
	print("Abandoned house asset: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)
