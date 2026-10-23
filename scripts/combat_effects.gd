class_name CombatEffects
extends Node3D

var _spark_particles: BoxMesh
var _blood_particles: BoxMesh
var _death_particles: BoxMesh
var _materials: Dictionary = {}


func _ready() -> void:
	_spark_particles = _make_particle_mesh(Vector3(0.055, 0.055, 0.055))
	_blood_particles = _make_particle_mesh(Vector3(0.09, 0.09, 0.09))
	_death_particles = _make_particle_mesh(Vector3(0.16, 0.16, 0.16))


func tracer(from: Vector3, to: Vector3, color: Color = Color("#ffd68a")) -> void:
	var distance := from.distance_to(to)
	if distance < 0.2:
		return
	var direction := (to - from).normalized()
	var mesh := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.012
	cylinder.bottom_radius = 0.028
	cylinder.height = distance
	cylinder.radial_segments = 4
	cylinder.rings = 1
	mesh.mesh = cylinder
	mesh.material_override = _emissive_material(color, 2.4)
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mesh)
	mesh.global_position = from.lerp(to, 0.5)
	mesh.basis = Basis(Quaternion(Vector3.UP, direction))
	var tween := create_tween()
	tween.tween_interval(0.055)
	tween.tween_callback(mesh.queue_free)


func impact(pos: Vector3, normal: Vector3, flesh: bool = false) -> void:
	if normal.length_squared() < 0.01:
		normal = Vector3.UP
	var color := Color("#8fbf58") if flesh else Color("#ffd27e")
	_burst(pos, normal, color, 7 if flesh else 9, _blood_particles if flesh else _spark_particles, 3.6, 0.35)
	if not flesh:
		var flash := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		mesh.radius = 0.09
		mesh.height = 0.18
		mesh.radial_segments = 5
		mesh.rings = 2
		flash.mesh = mesh
		flash.material_override = _emissive_material(Color("#ffd27e"), 3.5)
		flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(flash)
		flash.global_position = pos
		var tween := create_tween()
		tween.tween_interval(0.05)
		tween.tween_callback(flash.queue_free)


func zombie_hit(pos: Vector3, normal: Vector3, headshot: bool) -> void:
	impact(pos, normal, true)
	if headshot:
		_burst(pos, Vector3.UP, Color("#c6f06d"), 9, _blood_particles, 4.5, 0.4)


func zombie_death(pos: Vector3, kind: String) -> void:
	var color := Color("#8dbb58")
	var count := 24
	if kind == "runner":
		color = Color("#c8cf66")
	elif kind == "brute":
		color = Color("#cf7250")
		count = 36
	_burst(pos + Vector3.UP * 1.1, Vector3.UP, color, count, _death_particles, 5.2, 0.7)
	_burst(pos + Vector3.UP * 1.2, Vector3.UP, Color("#55733c"), maxi(8, count / 2), _blood_particles, 3.6, 0.55)


func _burst(pos: Vector3, normal: Vector3, color: Color, amount: int, mesh: Mesh, velocity: float, life: float) -> void:
	var particles := CPUParticles3D.new()
	particles.mesh = mesh
	particles.material_override = _particle_material(color)
	particles.amount = amount
	particles.lifetime = life
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.direction = normal
	particles.spread = 62.0
	particles.initial_velocity_min = velocity * 0.45
	particles.initial_velocity_max = velocity
	particles.gravity = Vector3(0.0, -7.5, 0.0)
	particles.scale_amount_min = 0.5
	particles.scale_amount_max = 1.4
	particles.damping_min = 1.0
	particles.damping_max = 3.0
	particles.emitting = true
	add_child(particles)
	particles.global_position = pos
	var tween := create_tween()
	tween.tween_interval(life + 0.35)
	tween.tween_callback(particles.queue_free)


func _make_particle_mesh(size: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	return mesh


func _emissive_material(color: Color, energy: float) -> StandardMaterial3D:
	var key := "e_%s_%.2f" % [color.to_html(), energy]
	if _materials.has(key):
		return _materials[key]
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_materials[key] = material
	return material


func _particle_material(color: Color) -> StandardMaterial3D:
	var key := "p_%s" % color.to_html()
	if _materials.has(key):
		return _materials[key]
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 0.8
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_materials[key] = material
	return material
