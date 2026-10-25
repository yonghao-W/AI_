class_name MeleeRigView
extends Node3D
## 近战第三人称视觉：骨架、武器挂点、姿态、拔刀与镜头冲击。
## 不决定伤害、命中合法性和网络状态。

const WALK_SPEED := 5.2
const DRAW_TIME := 0.24
const IDLE_PIVOT := Vector3(0.12, 0.5, -0.2)
const BASE_PIVOT_POS := Vector3(0.46, 1.18, -0.2)

var draw_left := 0.0
var camera_punch := 0.0
var weapon_id := ""

var _body: Node3D
var _weapon_pivot: Node3D
var _weapon: Node3D
var _left_leg: Node3D
var _right_leg: Node3D
var _arm_left: Node3D
var _arm_right: Node3D
var _materials: Dictionary = {}
var _unit_box: BoxMesh
var _unit_cylinder: CylinderMesh


func build() -> void:
	_unit_box = BoxMesh.new()
	_unit_box.size = Vector3.ONE
	_unit_cylinder = CylinderMesh.new()
	_unit_cylinder.top_radius = 1.0
	_unit_cylinder.bottom_radius = 1.0
	_unit_cylinder.height = 1.0
	_unit_cylinder.radial_segments = 10
	_body = Node3D.new()
	add_child(_body)
	var jacket := _mat(Color("#2d4a43"), 0.95)
	var jacket_dark := _mat(Color("#20352f"), 0.98)
	var pants := _mat(Color("#26343a"), 0.98)
	var skin := _mat(Color("#b98d68"), 0.9)
	var hair := _mat(Color("#2a2521"), 1.0)
	var strap := _mat(Color("#b08743"), 0.7, 0.15)
	var glove := _mat(Color("#1b2624"), 0.9)
	var boots := _mat(Color("#171d20"), 0.95)
	_part(_body, Vector3(0.52, 0.58, 0.34), Vector3(0.0, 1.24, 0.0), jacket)
	_part(_body, Vector3(0.42, 0.34, 0.38), Vector3(0.0, 1.3, 0.0), jacket_dark)
	_part(_body, Vector3(0.54, 0.1, 0.36), Vector3(0.0, 0.94, 0.0), strap)
	_part(_body, Vector3(0.36, 0.44, 0.2), Vector3(0.0, 1.27, 0.27), strap)
	_part(_body, Vector3(0.3, 0.32, 0.3), Vector3(0.0, 1.64, 0.0), skin)
	_part(_body, Vector3(0.32, 0.1, 0.31), Vector3(0.0, 1.81, 0.0), hair)
	for side in [-1.0, 1.0]:
		var arm := Node3D.new()
		arm.position = Vector3(0.34 * side, 1.46, 0.0)
		_body.add_child(arm)
		_part(arm, Vector3(0.15, 0.42, 0.19), Vector3(0.0, -0.18, 0.0), jacket)
		_part(arm, Vector3(0.13, 0.13, 0.15), Vector3(0.0, -0.42, 0.0), glove)
		if side < 0.0:
			_arm_left = arm
		else:
			_arm_right = arm
	_left_leg = Node3D.new()
	_left_leg.position = Vector3(-0.16, 0.88, 0.0)
	_body.add_child(_left_leg)
	_part(_left_leg, Vector3(0.21, 0.76, 0.25), Vector3(0.0, -0.38, 0.0), pants)
	_part(_left_leg, Vector3(0.23, 0.16, 0.32), Vector3(0.0, -0.8, -0.04), boots)
	_right_leg = Node3D.new()
	_right_leg.position = Vector3(0.16, 0.88, 0.0)
	_body.add_child(_right_leg)
	_part(_right_leg, Vector3(0.21, 0.76, 0.25), Vector3(0.0, -0.38, 0.0), pants)
	_part(_right_leg, Vector3(0.23, 0.16, 0.32), Vector3(0.0, -0.8, -0.04), boots)
	_weapon_pivot = Node3D.new()
	_weapon_pivot.position = BASE_PIVOT_POS
	_body.add_child(_weapon_pivot)
	visible = false


func equip(id: String) -> void:
	if _weapon != null:
		_weapon.queue_free()
	_weapon = Node3D.new()
	_weapon_pivot.add_child(_weapon)
	weapon_id = id
	var accent := _mat(WeaponCatalog.accent(id), 0.45, 0.25, 0.8)
	var steel := _mat(Color("#c3ccd0"), 0.35, 0.7)
	var dark := _mat(Color("#1b2226"), 0.8, 0.25)
	var wood := _mat(Color("#5a3d27"), 0.9)
	_part(_weapon, Vector3(0.09, 0.1, 0.32), Vector3(0.0, 0.0, 0.08), wood)
	_part(_weapon, Vector3(0.13, 0.13, 0.12), Vector3(0.0, -0.02, -0.08), dark)
	if id == "sledge":
		_add_barrel(_weapon, 0.0, -0.64, 0.16, 0.038, wood)
		_part(_weapon, Vector3(0.18, 0.46, 0.24), Vector3(0.0, 0.0, -0.82), steel)
		_part(_weapon, Vector3(0.2, 0.12, 0.26), Vector3(0.0, 0.26, -0.82), accent)
	else:
		_part(_weapon, Vector3(0.055, 0.16, 0.9), Vector3(0.0, 0.03, -0.48), steel).rotation.x = -0.06
		_part(_weapon, Vector3(0.07, 0.1, 0.2), Vector3(0.0, 0.02, -0.93), accent)
		_part(_weapon, Vector3(0.035, 0.05, 0.5), Vector3(0.0, 0.1, -0.5), accent)
	_weapon.rotation = Vector3(0.2, -0.2, -0.12)
	draw_left = DRAW_TIME
	camera_punch = 0.0


func refresh_visibility(alive: bool, carrying_core: bool, third_person: bool) -> void:
	visible = alive and third_person and not carrying_core


func cancel_draw() -> void:
	draw_left = 0.0


func cancel_attack() -> void:
	draw_left = 0.0
	camera_punch = 0.0


func trigger_hit(stage: int) -> void:
	camera_punch = 0.012 + 0.008 * clampi(stage, 1, 3)


func camera_offset() -> Vector2:
	return Vector2(camera_punch * 0.55, -camera_punch)


func update_pose(
	delta: float,
	stage: int,
	swinging: bool,
	progress: float,
	hit_at: float,
	move_ratio: float,
	bob: float,
	bob_time: float,
	alive: bool,
	carrying_core: bool,
	third_person: bool
) -> void:
	draw_left = maxf(0.0, draw_left - delta)
	camera_punch = move_toward(camera_punch, 0.0, delta * 0.42)
	refresh_visibility(alive, carrying_core, third_person)
	if not visible:
		return
	var ratio := clampf(move_ratio, 0.0, 1.2)
	var stride := sin(bob_time * 2.2) * ratio
	_left_leg.rotation.x = stride * 0.6
	_right_leg.rotation.x = -stride * 0.6
	var pivot_target := IDLE_PIVOT + Vector3(sin(bob_time * 0.7) * 0.008, sin(bob_time * 0.55) * 0.012, 0.0)
	var body_target := Vector3.ZERO
	var arm_left_target := Vector3.ZERO
	var arm_right_target := Vector3.ZERO
	var pivot_pos := BASE_PIVOT_POS + Vector3(0.0, -bob * 0.35, 0.0)
	if swinging:
		var pose := _stage_pose(progress, stage, hit_at)
		pivot_target = pose
		var contact_reach := sin(clampf(progress / maxf(0.01, hit_at), 0.0, 1.0) * PI * 0.5)
		body_target = Vector3(
			clampf(-pose.x * 0.1, -0.045, 0.14),
			pose.y * 0.22,
			pose.z * 0.05
		)
		arm_right_target = Vector3(-0.2 - pose.x * 0.45, 0.04, -0.38 + pose.z * 0.3)
		arm_left_target = Vector3(-0.55 * contact_reach, 0.0, 0.32 * contact_reach)
		pivot_pos.x -= 0.12 * contact_reach
		pivot_pos.z -= 0.11 * contact_reach
	elif ratio > 0.1:
		arm_left_target.x = -stride * 0.45
		arm_right_target.x = stride * 0.45
	if draw_left > 0.0:
		var draw_t := _smooth01(1.0 - draw_left / DRAW_TIME)
		pivot_target = Vector3(-0.55, 0.95, -0.5).lerp(pivot_target, draw_t)
		arm_right_target = Vector3(-0.5, 0.0, -0.2).lerp(arm_right_target, draw_t)
		arm_left_target = Vector3(-0.15, 0.0, 0.1).lerp(arm_left_target, draw_t)
	var pose_speed := 48.0 if swinging else 9.0
	var body_speed := 24.0 if swinging else 10.0
	_weapon_pivot.rotation = _weapon_pivot.rotation.lerp(pivot_target, minf(1.0, delta * pose_speed))
	_weapon_pivot.position = _weapon_pivot.position.lerp(pivot_pos, minf(1.0, delta * (18.0 if swinging else 12.0)))
	_body.rotation = _body.rotation.lerp(body_target, minf(1.0, delta * body_speed))
	if _arm_left != null:
		_arm_left.rotation = _arm_left.rotation.lerp(arm_left_target, minf(1.0, delta * body_speed))
	if _arm_right != null:
		_arm_right.rotation = _arm_right.rotation.lerp(arm_right_target, minf(1.0, delta * body_speed))


func _stage_pose(t: float, stage: int, hit_at: float) -> Vector3:
	var idle := IDLE_PIVOT
	var windup: Vector3
	var contact: Vector3
	var follow: Vector3
	var windup_at := 0.26
	match stage:
		1:
			windup = Vector3(-0.35, -0.85, -0.5)
			contact = Vector3(0.75, -0.55, -0.3)
			follow = Vector3(0.9, -0.65, -0.2)
		2:
			windup = Vector3(0.32, 1.15, 0.65)
			contact = Vector3(0.42, -1.25, -0.65)
			follow = Vector3(0.22, -1.45, -0.8)
		_:
			windup = Vector3(1.35, 0.1, -0.25)
			contact = Vector3(-1.1, -0.7, 0.12)
			follow = Vector3(-0.85, -0.85, 0.22)
			if weapon_id == "sledge":
				windup = Vector3(1.55, 0.05, -0.2)
				contact = Vector3(-0.95, -0.7, 0.18)
				follow = Vector3(-0.65, -0.85, 0.28)
			windup_at = 0.32
	windup_at = minf(windup_at, hit_at * 0.8)
	var contact_at := hit_at
	var follow_at := minf(0.94, contact_at + 0.2)
	if t <= windup_at:
		return idle.lerp(windup, _smooth01(t / maxf(0.01, windup_at)))
	if t < contact_at:
		return windup.lerp(contact, _smooth01((t - windup_at) / maxf(0.01, contact_at - windup_at)))
	if t < follow_at:
		return contact.lerp(follow, (t - contact_at) / maxf(0.01, follow_at - contact_at))
	return follow.lerp(idle, _smooth01((t - follow_at) / maxf(0.01, 1.0 - follow_at)))


func _smooth01(value: float) -> float:
	var t := clampf(value, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


func _part(parent: Node3D, size: Vector3, pos: Vector3, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = _unit_box
	instance.scale = size
	instance.position = pos
	instance.material_override = material
	parent.add_child(instance)
	return instance


func _add_barrel(root: Node3D, y: float, z_from: float, z_to: float, radius: float, material: Material) -> void:
	var barrel := MeshInstance3D.new()
	barrel.mesh = _unit_cylinder
	barrel.scale = Vector3(radius, absf(z_to - z_from), radius)
	barrel.rotation.x = PI * 0.5
	barrel.position = Vector3(0.0, y, (z_from + z_to) * 0.5)
	barrel.material_override = material
	root.add_child(barrel)


func _mat(color: Color, roughness: float = 0.9, metallic: float = 0.0, emission: float = 0.0, unshaded: bool = false) -> StandardMaterial3D:
	var key := "%s|%.2f|%.2f|%.2f|%s" % [color.to_html(), roughness, metallic, emission, str(unshaded)]
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
	if unshaded:
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_materials[key] = material
	return material
