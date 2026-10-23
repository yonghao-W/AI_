extends SceneTree

const ZombieProxyScript = preload("res://scripts/zombie_proxy.gd")
const OUTPUT := "D:/Aprojects/DeadCity/shots/zombie_lineup.png"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#0b141c")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#6f8794")
	env.ambient_light_energy = 0.8
	var world := WorldEnvironment.new()
	world.environment = env
	root.add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52.0, 36.0, 0.0)
	sun.light_energy = 1.25
	sun.light_color = Color("#d8e6e2")
	root.add_child(sun)
	var fill := OmniLight3D.new()
	fill.position = Vector3(0.0, 2.6, 4.2)
	fill.light_color = Color("#7fd8cf")
	fill.light_energy = 1.2
	fill.omni_range = 9.0
	root.add_child(fill)
	var floor := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(26.0, 18.0)
	floor.mesh = plane
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color("#29333a")
	floor_mat.roughness = 0.92
	floor.material_override = floor_mat
	root.add_child(floor)
	var camera := Camera3D.new()
	camera.fov = 52.0
	root.add_child(camera)
	camera.look_at_from_position(Vector3(0.0, 2.35, 8.4), Vector3(0.0, 0.9, 0.0), Vector3.UP)
	camera.current = true
	var kinds := ["walker", "crawler", "runner", "brute"]
	var names := ["普通 · WALKER", "爬行 · CRAWLER", "疾行 · RUNNER", "重装 · BRUTE"]
	var colors := [Color("#93b563"), Color("#d2c583"), Color("#c6ce6c"), Color("#cd8058")]
	var label_heights := [2.25, 1.2, 2.25, 2.95]
	for i in range(kinds.size()):
		var slot := Vector3((i - 1.5) * 2.1, 0.0, 0.0)
		var proxy = ZombieProxyScript.new()
		root.add_child(proxy)
		proxy.position = slot
		proxy.setup(i + 1, kinds[i])
		proxy.set_network_state(slot, PI, 0)
		var label := Label3D.new()
		label.text = names[i]
		label.font = DeadCityUI.display_font()
		label.font_size = 34
		label.pixel_size = 0.004
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.modulate = colors[i]
		label.outline_size = 10
		label.outline_modulate = Color(0.02, 0.03, 0.04, 0.9)
		label.position = slot + Vector3(0.0, label_heights[i], 0.0)
		root.add_child(label)
	await create_timer(1.1).timeout
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(OUTPUT.get_base_dir())
	var result := image.save_png(OUTPUT)
	print("[DeadCity] zombie lineup capture %s (err=%d)" % [OUTPUT, result])
	quit()
