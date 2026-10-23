class_name LocalPlayer
extends CharacterBody3D

signal ammo_changed(mag: int, reserve: int, reloading: bool)
signal health_changed(health: float)
signal damaged(amount: float)
signal hit_marker(headshot: bool)
signal died

const MAG_SIZE := 30
const MAX_RESERVE := 150
const WALK_SPEED := 5.2
const SPRINT_SPEED := 7.3
const ADS_SPEED := 3.1
const JUMP_VELOCITY := 7.0
const GRAVITY := 22.0
const FALL_GRAVITY_MULT := 1.35
const JUMP_CUT := 1.8
const COYOTE_TIME := 0.11
const JUMP_BUFFER := 0.12
const GROUND_ACCEL := 48.0
const AIR_ACCEL := 18.0
const FIRE_INTERVAL := 0.102
const RELOAD_TIME := 1.55
const BODY_DAMAGE := 34.0
const RANGE := 140.0
const HIT_MASK := 1 | 4
const SENSITIVITY := 0.0022

var effects: CombatEffects
var main_ref: Node
var health := 100.0
var alive := true
var input_enabled := true
var game_active := false
var aiming := false
var auto_pilot := false
var carrying_core := false
var mag := MAG_SIZE
var reserve := 90
var reloading := false
var mag_size := MAG_SIZE
var reload_time := RELOAD_TIME
var walk_speed := WALK_SPEED
var sprint_speed := SPRINT_SPEED
var ads_speed := ADS_SPEED
var damage_reduction := 0.0
var reserve_bonus := 0
var meta_reload_mult := 1.0

var _yaw := 0.0
var _pitch := 0.0
var _fire_cooldown := 0.0
var _reload_left := 0.0
var _regen_timer := 0.0
var _flash_time := 0.0
var _gun_kick := 0.0
var _jump_queued := false
var _jump_buffer := 0.0
var _coyote_left := 0.0
var _bob_time := 0.0
var _auto_fire_timer := 0.0
var _gravity := 9.8
var _head: Node3D
var _camera: Camera3D
var _viewmodel: Node3D
var _muzzle: Node3D
var _flash_mesh: MeshInstance3D
var _flash_light: OmniLight3D
var _magazine: MeshInstance3D
var _magazine_base := Vector3.ZERO
var _carry_rig: Node3D
var _carry_orb: MeshInstance3D
var _carry_ring: MeshInstance3D
var _materials: Dictionary = {}
var _unit_box: BoxMesh
var _unit_cylinder: CylinderMesh


func _ready() -> void:
	_gravity = GRAVITY
	collision_layer = 2
	collision_mask = 1
	floor_snap_length = 0.35
	floor_max_angle = deg_to_rad(48.0)
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.8
	var shape := CollisionShape3D.new()
	shape.shape = capsule
	shape.position.y = 0.9
	add_child(shape)
	_unit_box = BoxMesh.new()
	_unit_box.size = Vector3.ONE
	_unit_cylinder = CylinderMesh.new()
	_unit_cylinder.top_radius = 1.0
	_unit_cylinder.bottom_radius = 1.0
	_unit_cylinder.height = 1.0
	_unit_cylinder.radial_segments = 10
	_build_camera()
	_build_weapon()
	_build_carry_visual()


func _build_camera() -> void:
	_head = Node3D.new()
	_head.position = Vector3(0.0, 1.55, 0.0)
	add_child(_head)
	_camera = Camera3D.new()
	_camera.fov = 78.0
	_camera.near = 0.045
	_camera.far = 320.0
	_camera.current = true
	_head.add_child(_camera)
	var flashlight := SpotLight3D.new()
	flashlight.position = Vector3(0.12, -0.1, 0.0)
	flashlight.spot_range = 28.0
	flashlight.spot_angle = 34.0
	flashlight.light_energy = 1.7
	flashlight.light_color = Color("#ffe9c7")
	flashlight.shadow_enabled = false
	flashlight.light_cull_mask = 0xFFFFFFFF ^ 2
	_camera.add_child(flashlight)


func _build_weapon() -> void:
	_viewmodel = Node3D.new()
	_viewmodel.position = Vector3(0.31, -0.29, -0.53)
	_viewmodel.rotation = Vector3(0.0, -0.04, 0.0)
	_viewmodel.scale = Vector3.ONE * 0.88
	_camera.add_child(_viewmodel)
	var steel := _mat(Color("#28323a"), 0.72, 0.32)
	var dark := _mat(Color("#12181d"), 0.82, 0.2)
	var accent := _mat(Color("#4bbdb4"), 0.45, 0.15, 1.1)
	var glove := _mat(Color("#283831"), 0.95, 0.0)
	var sleeve := _mat(Color("#1d2a25"), 0.95, 0.0)
	_part(_viewmodel, Vector3(0.16, 0.16, 0.5), Vector3(0.0, 0.0, -0.2), steel)
	_part(_viewmodel, Vector3(0.12, 0.12, 0.34), Vector3(0.0, 0.015, -0.45), dark)
	var barrel := MeshInstance3D.new()
	barrel.mesh = _unit_cylinder
	barrel.scale = Vector3(0.034, 0.38, 0.034)
	barrel.rotation.x = PI * 0.5
	barrel.position = Vector3(0.0, 0.025, -0.67)
	barrel.material_override = dark
	_viewmodel.add_child(barrel)
	_part(_viewmodel, Vector3(0.12, 0.13, 0.27), Vector3(0.0, -0.005, 0.16), steel)
	_magazine = _part(_viewmodel, Vector3(0.1, 0.24, 0.14), Vector3(0.0, -0.18, -0.06), dark)
	_magazine.rotation.x = -0.22
	_magazine_base = _magazine.position
	_part(_viewmodel, Vector3(0.09, 0.2, 0.11), Vector3(0.0, -0.17, 0.1), dark).rotation.x = 0.3
	_part(_viewmodel, Vector3(0.035, 0.09, 0.1), Vector3(0.0, 0.12, -0.14), accent)
	_part(_viewmodel, Vector3(0.09, 0.05, 0.06), Vector3(0.0, 0.11, 0.05), dark)
	_part(_viewmodel, Vector3(0.168, 0.028, 0.3), Vector3(0.0, 0.065, -0.24), accent)
	_part(_viewmodel, Vector3(0.12, 0.13, 0.22), Vector3(0.06, -0.16, -0.34), glove)
	_part(_viewmodel, Vector3(0.12, 0.12, 0.24), Vector3(-0.03, -0.22, 0.08), glove)
	_part(_viewmodel, Vector3(0.15, 0.16, 0.34), Vector3(0.1, -0.29, -0.42), sleeve).rotation.z = -0.25
	_part(_viewmodel, Vector3(0.14, 0.15, 0.3), Vector3(-0.06, -0.35, 0.1), sleeve).rotation.z = 0.15
	_muzzle = Node3D.new()
	_muzzle.position = Vector3(0.0, 0.025, -0.88)
	_viewmodel.add_child(_muzzle)
	_flash_mesh = MeshInstance3D.new()
	var flash_mesh := BoxMesh.new()
	flash_mesh.size = Vector3(0.13, 0.13, 0.26)
	_flash_mesh.mesh = flash_mesh
	_flash_mesh.material_override = _mat(Color("#ffd27a"), 0.0, 0.0, 4.0, true)
	_flash_mesh.visible = false
	_flash_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_muzzle.add_child(_flash_mesh)
	_flash_light = OmniLight3D.new()
	_flash_light.light_color = Color("#ffc16d")
	_flash_light.light_energy = 0.0
	_flash_light.omni_range = 7.0
	_flash_light.shadow_enabled = false
	_flash_light.light_cull_mask = 0xFFFFFFFF ^ 2
	_muzzle.add_child(_flash_light)
	_assign_viewmodel_layer(_viewmodel)


func _assign_viewmodel_layer(node: Node) -> void:
	if node is VisualInstance3D:
		(node as VisualInstance3D).layers = 2
	for child in node.get_children():
		_assign_viewmodel_layer(child)


func _build_carry_visual() -> void:
	_carry_rig = Node3D.new()
	_carry_rig.position = Vector3(0.0, -0.38, -0.9)
	_carry_rig.visible = false
	_camera.add_child(_carry_rig)
	var glow := _mat(Color("#ffc861"), 0.35, 0.1, 3.4, true)
	var cage := _mat(Color("#3a4a4f"), 0.7, 0.4)
	var glove := _mat(Color("#33443b"), 0.95, 0.0)
	var sleeve := _mat(Color("#22312b"), 0.95, 0.0)
	_carry_orb = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.17
	sphere.height = 0.34
	sphere.radial_segments = 12
	sphere.rings = 8
	_carry_orb.mesh = sphere
	_carry_orb.material_override = glow
	_carry_rig.add_child(_carry_orb)
	_carry_ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.2
	torus.outer_radius = 0.25
	torus.rings = 24
	torus.ring_segments = 6
	_carry_ring.mesh = torus
	_carry_ring.material_override = cage
	_carry_rig.add_child(_carry_ring)
	_part(_carry_rig, Vector3(0.11, 0.12, 0.18), Vector3(-0.24, -0.06, -0.01), glove)
	_part(_carry_rig, Vector3(0.11, 0.12, 0.18), Vector3(0.24, -0.06, -0.01), glove)
	_part(_carry_rig, Vector3(0.15, 0.15, 0.4), Vector3(-0.28, -0.16, 0.15), sleeve).rotation.z = -0.25
	_part(_carry_rig, Vector3(0.15, 0.15, 0.4), Vector3(0.28, -0.16, 0.15), sleeve).rotation.z = 0.25
	var light := OmniLight3D.new()
	light.light_color = Color("#ffd58a")
	light.light_energy = 0.9
	light.omni_range = 4.0
	light.shadow_enabled = false
	light.light_cull_mask = 0xFFFFFFFF ^ 2
	_carry_rig.add_child(light)
	_assign_viewmodel_layer(_carry_rig)


func _part(parent: Node3D, size: Vector3, pos: Vector3, material: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = _unit_box
	node.scale = size
	node.position = pos
	node.material_override = material
	parent.add_child(node)
	return node


func set_game_active(value: bool) -> void:
	game_active = value
	if not value:
		set_input_enabled(false)


func set_input_enabled(value: bool) -> void:
	input_enabled = value
	if not value:
		aiming = false


func _unhandled_input(event: InputEvent) -> void:
	if not game_active or not input_enabled or not alive:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var motion := event as InputEventMouseMotion
		_yaw = wrapf(_yaw - motion.relative.x * SENSITIVITY, -PI, PI)
		_pitch = clampf(_pitch - motion.relative.y * SENSITIVITY, -1.47, 1.47)
		rotation.y = _yaw
		_head.rotation.x = _pitch
	elif event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and not key.echo:
			if key.physical_keycode == KEY_R:
				start_reload()
			elif key.physical_keycode == KEY_SPACE:
				_jump_queued = true


func _physics_process(delta: float) -> void:
	if not game_active:
		return
	var grounded := is_on_floor()
	if grounded:
		_coyote_left = COYOTE_TIME
	else:
		_coyote_left = maxf(0.0, _coyote_left - delta)
		var gravity_scale := FALL_GRAVITY_MULT if velocity.y < 0.0 else 1.0
		velocity.y -= _gravity * gravity_scale * delta
		if velocity.y > 0.0 and not Input.is_physical_key_pressed(KEY_SPACE):
			velocity.y -= _gravity * JUMP_CUT * delta
	if _jump_queued:
		_jump_buffer = JUMP_BUFFER
		_jump_queued = false
	else:
		_jump_buffer = maxf(0.0, _jump_buffer - delta)
	var can_move := alive and input_enabled
	var wish := Vector3.ZERO
	if can_move:
		var input_dir := Vector2.ZERO
		if Input.is_physical_key_pressed(KEY_W):
			input_dir.y += 1.0
		if Input.is_physical_key_pressed(KEY_S):
			input_dir.y -= 1.0
		if Input.is_physical_key_pressed(KEY_A):
			input_dir.x -= 1.0
		if Input.is_physical_key_pressed(KEY_D):
			input_dir.x += 1.0
		input_dir = input_dir.normalized()
		var forward := -global_transform.basis.z
		forward.y = 0.0
		forward = forward.normalized()
		var right := global_transform.basis.x
		right.y = 0.0
		right = right.normalized()
		wish = (right * input_dir.x + forward * input_dir.y).normalized()
		if wish.length_squared() > 0.01:
			aiming = Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) and not carrying_core
		var sprinting := Input.is_physical_key_pressed(KEY_SHIFT) and input_dir.y > 0.2 and not aiming and not carrying_core
		var speed := ads_speed if aiming else (sprint_speed if sprinting else walk_speed)
		if carrying_core:
			aiming = false
			speed = walk_speed * 0.58
		var target := wish * speed
		var accel := GROUND_ACCEL if grounded else AIR_ACCEL
		velocity.x = move_toward(velocity.x, target.x, accel * delta)
		velocity.z = move_toward(velocity.z, target.z, accel * delta)
		if _jump_buffer > 0.0 and _coyote_left > 0.0 and not carrying_core:
			velocity.y = JUMP_VELOCITY
			_jump_buffer = 0.0
			_coyote_left = 0.0
	else:
		aiming = false
		_jump_buffer = 0.0
		_coyote_left = 0.0
		velocity.x = move_toward(velocity.x, 0.0, 32.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 32.0 * delta)
	move_and_slide()


func _process(delta: float) -> void:
	if not game_active:
		return
	_fire_cooldown = maxf(0.0, _fire_cooldown - delta)
	_flash_time = maxf(0.0, _flash_time - delta)
	_gun_kick = move_toward(_gun_kick, 0.0, delta * 7.0)
	_flash_mesh.visible = _flash_time > 0.0
	_flash_light.light_energy = 3.2 if _flash_time > 0.0 else 0.0
	if reloading:
		_reload_left -= delta
		if _reload_left <= 0.0:
			_finish_reload()
	_regen_timer += delta
	if not reloading and reserve < MAX_RESERVE and _regen_timer >= 2.2:
		_regen_timer = 0.0
		reserve += 1
		ammo_changed.emit(mag, reserve, false)
	_update_visuals(delta)
	if auto_pilot and alive and not carrying_core:
		_auto_pilot_step(delta)
	elif alive and input_enabled and not carrying_core and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_fire()


func _update_visuals(delta: float) -> void:
	var horizontal_speed := Vector2(velocity.x, velocity.z).length()
	var moving := horizontal_speed > 0.5 and is_on_floor()
	if moving:
		_bob_time += delta * horizontal_speed
	var bob := sin(_bob_time * 2.6) * 0.018 * clampf(horizontal_speed / WALK_SPEED, 0.0, 1.3)
	var sway := cos(_bob_time * 1.3) * 0.012 * clampf(horizontal_speed / WALK_SPEED, 0.0, 1.3)
	_head.position.y = lerpf(_head.position.y, 1.55 + bob - (0.05 if carrying_core else 0.0), delta * 12.0)
	var ads_pose := aiming and not reloading and not carrying_core
	var target_fov := 58.0 if ads_pose else 78.0
	_camera.fov = lerpf(_camera.fov, target_fov, delta * 11.0)

	var reload_t := 0.0
	if reloading:
		reload_t = clampf(1.0 - _reload_left / maxf(0.01, reload_time), 0.0, 1.0)
	var tilt := _smooth01(reload_t / 0.22) * (1.0 - _smooth01((reload_t - 0.78) / 0.22))
	var mag_off := 0.0
	if reload_t < 0.38:
		mag_off = _smooth01((reload_t - 0.2) / 0.18)
	elif reload_t >= 0.58:
		mag_off = 1.0 - _smooth01((reload_t - 0.58) / 0.18)
	var mag_visible := not (reload_t > 0.39 and reload_t < 0.57)

	var target_pos := Vector3(0.0, -0.155, -0.42) if ads_pose else Vector3(0.31, -0.29, -0.53)
	target_pos.x += sway + 0.055 * tilt
	target_pos.y += bob * 0.5 - _gun_kick * 0.02 - 0.085 * tilt
	target_pos.z += _gun_kick * 0.085
	_viewmodel.position = _viewmodel.position.lerp(target_pos, delta * (18.0 if reloading else 14.0))
	_viewmodel.rotation.x = _gun_kick * 0.075 + sin(_bob_time * 0.7) * 0.003 - 0.3 * tilt
	_viewmodel.rotation.z = 0.3 * tilt
	_viewmodel.visible = alive and not carrying_core
	_magazine.visible = alive and mag_visible
	_magazine.position = _magazine_base + Vector3(0.015 * mag_off, -0.42 * mag_off, 0.02 * mag_off)
	_magazine.rotation.x = -0.22 + 0.55 * mag_off
	_magazine.rotation.z = 0.35 * mag_off

	if _carry_rig != null:
		var carry_pose := carrying_core and alive
		_carry_rig.visible = carry_pose
		if carry_pose:
			var carry_target := Vector3(0.02, -0.4, -0.88)
			carry_target.x += sway * 1.6
			carry_target.y += bob * 0.7 + sin(_bob_time * 1.4 + 1.0) * 0.008
			_carry_rig.position = _carry_rig.position.lerp(carry_target, delta * 10.0)
			_carry_rig.rotation.y = lerp_angle(_carry_rig.rotation.y, sway * 0.45, delta * 6.0)
			_carry_orb.rotation.y += delta * 1.6
			_carry_ring.rotation.z += delta * 0.9
		else:
			_carry_rig.position = Vector3(0.0, -0.38, -0.9)


func _smooth01(value: float) -> float:
	var t := clampf(value, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


func _fire() -> void:
	if not alive or reloading or carrying_core or _fire_cooldown > 0.0 or not game_active:
		return
	if mag <= 0:
		start_reload()
		return
	mag -= 1
	_fire_cooldown = FIRE_INTERVAL
	_flash_time = 0.05
	_gun_kick = 1.0
	var from := _camera.global_position
	var spread := 0.0026 if aiming else 0.013
	if Vector2(velocity.x, velocity.z).length() > 1.0:
		spread += 0.006
	var offset := Vector3(randf_range(-spread, spread), randf_range(-spread, spread), 0.0)
	var direction := (_camera.global_transform.basis * (Vector3(0.0, 0.0, -1.0) + offset)).normalized()
	var to := from + direction * RANGE
	var query := PhysicsRayQueryParameters3D.create(from, to, HIT_MASK, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	var end := to
	var normal := -direction
	var flesh_hit := false
	var headshot := false
	var zombie_id := -1
	if not hit.is_empty():
		end = hit["position"]
		normal = hit["normal"]
		var collider: Object = hit["collider"]
		if collider != null and collider.has_meta("zombie_id"):
			zombie_id = int(collider.get_meta("zombie_id"))
			flesh_hit = true
			var proxy: Node = collider.get_meta("zombie_proxy", null)
			if is_instance_valid(proxy):
				headshot = end.y > proxy.global_position.y + float(proxy.call("head_height"))
				if proxy.has_method("receive_hit"):
					proxy.call("receive_hit", headshot)
	if effects != null:
		effects.tracer(_muzzle.global_position, end)
		effects.impact(end, normal, flesh_hit)
	if flesh_hit:
		hit_marker.emit(headshot)
		if main_ref != null and main_ref.has_method("request_zombie_hit"):
			main_ref.call("request_zombie_hit", zombie_id, headshot)
	ammo_changed.emit(mag, reserve, reloading)


func _auto_pilot_step(delta: float) -> void:
	if carrying_core:
		return
	_auto_fire_timer -= delta
	var nearest: Node3D = null
	var nearest_distance := 1e20
	for node in get_tree().get_nodes_in_group("zombie_proxies"):
		if not is_instance_valid(node) or not node is Node3D:
			continue
		if node.has_method("is_targetable") and not bool(node.call("is_targetable")):
			continue
		var distance := global_position.distance_squared_to((node as Node3D).global_position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = node
	if nearest == null:
		return
	aim_at(nearest.global_position + Vector3.UP * 1.1)
	if _auto_fire_timer <= 0.0 and nearest_distance < 90.0 * 90.0:
		_auto_fire_timer = 0.14
		_fire()


func aim_at(target: Vector3) -> void:
	var direction := target - _camera.global_position
	if direction.length_squared() < 0.001:
		return
	direction = direction.normalized()
	_yaw = atan2(-direction.x, -direction.z)
	_pitch = asin(clampf(direction.y, -1.0, 1.0))
	rotation.y = _yaw
	_head.rotation.x = _pitch


func start_reload() -> void:
	if reloading or carrying_core or mag >= mag_size or reserve <= 0 or not alive:
		return
	reloading = true
	_reload_left = reload_time
	ammo_changed.emit(mag, reserve, true)


func _finish_reload() -> void:
	var needed := mag_size - mag
	var taken := mini(needed, reserve)
	mag += taken
	reserve -= taken
	reloading = false
	ammo_changed.emit(mag, reserve, false)


func add_reserve(amount: int) -> void:
	reserve = mini(MAX_RESERVE, reserve + amount)
	ammo_changed.emit(mag, reserve, reloading)


func refill_ammo() -> void:
	if not alive:
		return
	reloading = false
	mag = mag_size
	reserve = MAX_RESERVE
	ammo_changed.emit(mag, reserve, false)


func set_meta_bonus(reserve_bonus_value: int, reload_multiplier: float) -> void:
	reserve_bonus = maxi(0, reserve_bonus_value)
	meta_reload_mult = clampf(reload_multiplier, 0.5, 1.0)
	reserve = maxi(reserve, 90 + reserve_bonus)


func apply_health(value: float) -> void:
	var previous := health
	health = clampf(value, 0.0, 100.0)
	if previous - health > 0.5:
		damaged.emit(previous - health)
	health_changed.emit(health)


func set_down() -> void:
	if not alive:
		return
	alive = false
	reloading = false
	aiming = false
	_viewmodel.visible = false
	if _carry_rig != null:
		_carry_rig.visible = false
	died.emit()


func respawn_at(pos: Vector3, face_yaw: float = 0.0) -> void:
	global_position = Vector3(pos.x, maxf(pos.y, 0.12), pos.z)
	velocity = Vector3.ZERO
	health = 100.0
	alive = true
	reloading = false
	carrying_core = false
	_yaw = face_yaw
	_pitch = 0.0
	rotation.y = _yaw
	_head.rotation.x = 0.0
	_head.position.y = 1.55
	_viewmodel.visible = true
	if _carry_rig != null:
		_carry_rig.visible = false
	mag = mag_size
	reserve = maxi(reserve, 90 + reserve_bonus)
	ammo_changed.emit(mag, reserve, false)
	health_changed.emit(health)


func set_carrying(value: bool) -> void:
	if carrying_core == value:
		return
	carrying_core = value
	if value:
		reloading = false
		aiming = false
		_flash_time = 0.0
		if _flash_mesh != null:
			_flash_mesh.visible = false
	if _viewmodel != null:
		_viewmodel.visible = alive and not value
	if _carry_rig != null:
		_carry_rig.visible = value and alive


func teleport_to(pos: Vector3) -> void:
	global_position = Vector3(pos.x, maxf(pos.y, -17.0), pos.z)
	velocity = Vector3.ZERO
	_jump_queued = false


func face_yaw(value: float) -> void:
	_yaw = wrapf(value, -PI, PI)
	rotation.y = _yaw


func apply_team_upgrades(upgrades: Dictionary) -> void:
	var mag_level := int(upgrades.get("mag", 0))
	var reload_level := int(upgrades.get("reload", 0))
	var speed_level := int(upgrades.get("speed", 0))
	mag_size = MAG_SIZE + 6 * mag_level
	reload_time = maxf(0.55, RELOAD_TIME * (1.0 - 0.12 * reload_level) * meta_reload_mult)
	var speed_mult := 1.0 + 0.05 * speed_level
	walk_speed = WALK_SPEED * speed_mult
	sprint_speed = SPRINT_SPEED * speed_mult
	ads_speed = ADS_SPEED * speed_mult
	damage_reduction = clampf(0.08 * int(upgrades.get("armor", 0)), 0.0, 0.4)
	mag = mini(mag, mag_size)
	if not reloading:
		ammo_changed.emit(mag, reserve, false)


func reload_progress() -> float:
	if not reloading:
		return 0.0
	return clampf(1.0 - _reload_left / maxf(0.01, reload_time), 0.0, 1.0)


func is_reloading() -> bool:
	return reloading


func get_spread_normalized() -> float:
	var value := 0.25
	if aiming:
		value = 0.05
	if Vector2(velocity.x, velocity.z).length() > 1.0:
		value += 0.3
	if _flash_time > 0.0:
		value += 0.2
	return value


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
