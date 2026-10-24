extends SceneTree
## 资产预览：自动按包围盒取景，输出实际 Godot 渲染的静帧。
## 用法：Godot --path . --resolution 1280x720 --script res://ui_refactor/phase3/tools/preview_asset.gd -- --asset=res://assets/models/abandoned_house/abandoned_house.glb --out=user://preview.png

const DEFAULT_ASSET := "res://assets/models/abandoned_house/abandoned_house.glb"
const DEFAULT_OUT := "user://asset_preview.png"
const WIDTH := 1280
const HEIGHT := 720

var _asset_path := DEFAULT_ASSET
var _out_path := DEFAULT_OUT
var _focus := ""
var _excludes: Array[String] = []
var _list_groups := false
var _distance := 0.0


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--asset="):
			_asset_path = arg.trim_prefix("--asset=")
		elif arg.begins_with("--out="):
			_out_path = arg.trim_prefix("--out=")
		elif arg.begins_with("--focus="):
			_focus = arg.trim_prefix("--focus=")
		elif arg.begins_with("--exclude="):
			_excludes.append(arg.trim_prefix("--exclude="))
		elif arg == "--list":
			_list_groups = true
		elif arg.begins_with("--distance="):
			_distance = maxf(float(arg.trim_prefix("--distance=")), 0.0)
	_run.call_deferred()


func _run() -> void:
	DisplayServer.window_set_size(Vector2i(WIDTH, HEIGHT))
	root.size = Vector2i(WIDTH, HEIGHT)

	var packed: PackedScene = load(_asset_path)
	if packed == null:
		push_error("Failed to load asset: %s" % _asset_path)
		quit(1)
		return

	var world := Node3D.new()
	world.name = "AssetPreview"
	root.add_child(world)

	var env := WorldEnvironment.new()
	var environment := Environment.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("#2b3b4b")
	sky_material.sky_horizon_color = Color("#938b7c")
	sky_material.ground_bottom_color = Color("#17191b")
	sky_material.ground_horizon_color = Color("#3b4043")
	var sky := Sky.new()
	sky.sky_material = sky_material
	environment.sky = sky
	environment.background_mode = Environment.BG_SKY
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.8
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = environment
	world.add_child(env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52.0, 38.0, 0.0)
	sun.light_energy = 2.2
	sun.shadow_enabled = true
	world.add_child(sun)

	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20.0, -140.0, 0.0)
	fill.light_energy = 0.5
	world.add_child(fill)

	var scene := packed.instantiate()
	world.add_child(scene)
	await process_frame

	for excluded in _excludes:
		var node := scene.find_child(excluded, true, false)
		if node != null:
			node.visible = false

	if _list_groups:
		for child in scene.get_children():
			var child_bounds := _scene_bounds(child)
			print("[group] %s visible=%s size=%s center=%s" % [
				child.name, str(child.is_visible_in_tree()), child_bounds.size, child_bounds.get_center()
			])

	var target: Node = scene
	if not _focus.is_empty():
		var focused := scene.find_child(_focus, true, false)
		if focused != null:
			target = focused
		else:
			push_error("Focus node not found: %s" % _focus)

	var bounds := _scene_bounds(target)
	var center := bounds.get_center()
	var radius := maxf(bounds.size.length() * 0.5, 0.1)

	var camera := Camera3D.new()
	camera.fov = 48.0
	camera.near = 0.05
	camera.far = maxf(radius * 20.0, 500.0)
	world.add_child(camera)
	var direction := Vector3(1.0, 0.55, 1.25).normalized()
	var camera_distance := radius / tan(deg_to_rad(camera.fov * 0.5)) * 1.15
	if _distance > 0.0:
		camera_distance = _distance
	camera.global_position = center + direction * camera_distance
	camera.look_at(center, Vector3.UP)
	camera.current = true

	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(radius * 8.0, radius * 8.0)
	ground.mesh = plane
	var ground_material := StandardMaterial3D.new()
	ground_material.albedo_color = Color("#20262b")
	ground_material.roughness = 1.0
	ground.material_override = ground_material
	ground.position.y = bounds.position.y - 0.02
	world.add_child(ground)

	for i in range(3):
		await process_frame
	await RenderingServer.frame_post_draw

	var image: Image = root.get_texture().get_image()
	var err := image.save_png(_out_path)
	print("[preview] asset=%s size=%dx%d bounds=%s center=%s" % [
		_asset_path, image.get_width(), image.get_height(), bounds.size, center
	])
	print("[preview] saved %s (err=%d)" % [_out_path, err])
	quit(0 if err == OK else 1)


func _scene_bounds(node: Node) -> AABB:
	var bounds := AABB()
	var found := false
	var stack: Array[Node] = [node]
	while not stack.is_empty():
		var current: Node = stack.pop_back()
		var mesh_instance := current as MeshInstance3D
		if mesh_instance != null and mesh_instance.mesh != null and mesh_instance.is_visible_in_tree():
			var box: AABB = mesh_instance.global_transform * mesh_instance.get_aabb()
			bounds = box if not found else bounds.merge(box)
			found = true
		for child in current.get_children():
			stack.append(child)
	return bounds
