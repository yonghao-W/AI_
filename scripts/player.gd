class_name LocalPlayer
extends CharacterBody3D

signal ammo_changed(mag: int, reserve: int, reloading: bool)
signal health_changed(health: float)
signal damaged(amount: float)
signal hit_marker(headshot: bool)
signal died
signal weapon_changed(weapon_id: String, slot: int)

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
const HIT_MASK := 1 | 4
const SENSITIVITY := 0.0022

var effects: CombatEffects
var main_ref: Node
var audio: Node
var health := 100.0
var alive := true
var input_enabled := true
var game_active := false
var aiming := false
var auto_pilot := false
var carrying_core := false
var mag := 12
var reserve := 72
var reloading := false
var mag_size := 12
var reload_time := 1.2
var fire_interval := 0.19
var reserve_cap := 72
var walk_speed := WALK_SPEED
var sprint_speed := SPRINT_SPEED
var ads_speed := ADS_SPEED
var damage_reduction := 0.0
var reserve_bonus := 0
var meta_reload_mult := 1.0
var weapons_owned: Array[String] = []
var weapon_index := 0

var _yaw := 0.0
var _pitch := 0.0
var _fire_cooldown := 0.0
var _reload_left := 0.0
var _flash_time := 0.0
var _gun_kick := 0.0
var _jump_queued := false
var _jump_buffer := 0.0
var _coyote_left := 0.0
var _bob_time := 0.0
var _auto_fire_timer := 0.0
var _switch_lock := 0.0
var _trigger_was_down := false
var _gravity := 9.8
var _head: Node3D
var _camera: Camera3D
var _viewmodel: Node3D
var _muzzle: Node3D
var _flash_mesh: MeshInstance3D
var _flash_light: OmniLight3D
var _magazine: MeshInstance3D
var _magazine_base := Vector3.ZERO
var _magazine_rot_base := -0.22
var _weapon: Dictionary = {}
var _upgrades: Dictionary = {"mag": 0, "reload": 0, "rate": 0}
var _ammo_states: Dictionary = {}
var _rig_data: Dictionary = {}
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
	_build_weapon_rigs()
	_build_carry_visual()
	set_loadout(WeaponCatalog.default_owned(), WeaponCatalog.DEFAULT_SELECTED)


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


func _build_weapon_rigs() -> void:
	for raw in WeaponCatalog.ordered_ids():
		_build_weapon_rig(String(raw))


func _build_weapon_rig(id: String) -> void:
	var data := WeaponCatalog.data(id)
	var accent_color := Color(data.get("accent", "#59d8c8"))
	var root := Node3D.new()
	root.position = Vector3(0.31, -0.29, -0.53)
	root.rotation = Vector3(0.0, -0.04, 0.0)
	root.scale = Vector3.ONE * 0.88
	root.visible = false
	_camera.add_child(root)
	var steel := _mat(Color("#28323a"), 0.72, 0.32)
	var dark := _mat(Color("#12181d"), 0.82, 0.2)
	var accent := _mat(accent_color, 0.45, 0.15, 1.1)
	var glove := _mat(Color("#283831"), 0.95, 0.0)
	var sleeve := _mat(Color("#1d2a25"), 0.95, 0.0)
	var muzzle_z := -0.88
	var magazine: MeshInstance3D = null
	var mag_base := Vector3.ZERO
	match id:
		"pistol":
			_part(root, Vector3(0.105, 0.105, 0.4), Vector3(0.0, 0.03, -0.17), steel)
			_part(root, Vector3(0.085, 0.07, 0.14), Vector3(0.0, 0.02, -0.42), dark)
			_part(root, Vector3(0.09, 0.22, 0.13), Vector3(0.0, -0.15, 0.03), dark).rotation.x = 0.2
			magazine = _part(root, Vector3(0.07, 0.18, 0.09), Vector3(0.0, -0.16, 0.04), steel)
			magazine.rotation.x = 0.2
			_part(root, Vector3(0.03, 0.035, 0.08), Vector3(0.0, 0.1, -0.34), accent)
			_part(root, Vector3(0.04, 0.06, 0.06), Vector3(0.0, 0.1, 0.04), dark)
			muzzle_z = -0.5
		"smg":
			_part(root, Vector3(0.14, 0.14, 0.42), Vector3(0.0, 0.0, -0.16), steel)
			_add_barrel(root, 0.02, -0.34, -0.55, 0.032, dark)
			_part(root, Vector3(0.1, 0.11, 0.22), Vector3(0.0, -0.01, 0.13), steel)
			_part(root, Vector3(0.05, 0.05, 0.16), Vector3(0.0, 0.01, 0.26), dark)
			magazine = _part(root, Vector3(0.085, 0.26, 0.11), Vector3(0.0, -0.19, -0.09), dark)
			magazine.rotation.x = -0.1
			_part(root, Vector3(0.145, 0.03, 0.24), Vector3(0.0, 0.08, -0.2), accent)
			_part(root, Vector3(0.035, 0.05, 0.09), Vector3(0.0, 0.11, -0.05), accent)
			muzzle_z = -0.62
		"rifle":
			_part(root, Vector3(0.145, 0.145, 0.6), Vector3(0.0, 0.0, -0.24), steel)
			_add_barrel(root, 0.02, -0.52, -0.82, 0.03, dark)
			_part(root, Vector3(0.095, 0.1, 0.26), Vector3(0.0, -0.01, 0.18), steel)
			_part(root, Vector3(0.05, 0.06, 0.16), Vector3(0.0, 0.015, 0.32), dark)
			magazine = _part(root, Vector3(0.09, 0.24, 0.12), Vector3(0.0, -0.17, -0.14), dark)
			magazine.rotation.x = -0.16
			_part(root, Vector3(0.15, 0.03, 0.34), Vector3(0.0, 0.085, -0.3), accent)
			_part(root, Vector3(0.05, 0.07, 0.14), Vector3(0.0, 0.115, -0.08), dark)
			_part(root, Vector3(0.03, 0.03, 0.06), Vector3(0.0, 0.13, 0.03), accent)
			muzzle_z = -0.9
		"shotgun":
			_part(root, Vector3(0.15, 0.14, 0.52), Vector3(0.0, 0.0, -0.2), steel)
			_add_barrel(root, 0.035, -0.44, -0.9, 0.045, dark)
			_add_barrel(root, -0.055, -0.44, -0.82, 0.035, dark)
			_part(root, Vector3(0.13, 0.1, 0.2), Vector3(0.0, -0.075, -0.48), accent)
			_part(root, Vector3(0.1, 0.11, 0.26), Vector3(0.0, -0.01, 0.18), steel)
			_part(root, Vector3(0.07, 0.1, 0.16), Vector3(0.0, -0.11, 0.05), dark)
			magazine = _part(root, Vector3(0.085, 0.12, 0.08), Vector3(0.0, -0.14, 0.06), dark)
			_part(root, Vector3(0.15, 0.03, 0.26), Vector3(0.0, 0.08, -0.24), accent)
			muzzle_z = -0.94
		"lmg":
			_part(root, Vector3(0.18, 0.17, 0.58), Vector3(0.0, 0.0, -0.22), steel)
			_add_barrel(root, 0.02, -0.5, -0.88, 0.036, dark)
			_part(root, Vector3(0.12, 0.11, 0.24), Vector3(0.0, -0.01, 0.18), steel)
			_part(root, Vector3(0.06, 0.06, 0.16), Vector3(0.0, 0.01, 0.32), dark)
			magazine = _part(root, Vector3(0.19, 0.2, 0.19), Vector3(0.0, -0.2, -0.1), dark)
			_part(root, Vector3(0.17, 0.035, 0.36), Vector3(0.0, 0.1, -0.28), accent)
			_part(root, Vector3(0.05, 0.06, 0.2), Vector3(0.0, 0.125, -0.05), dark)
			_part(root, Vector3(0.03, 0.05, 0.04), Vector3(-0.08, 0.11, -0.52), accent)
			_part(root, Vector3(0.09, 0.09, 0.1), Vector3(0.0, -0.02, -0.55), steel)
			muzzle_z = -0.94
	mag_base = magazine.position if magazine != null else Vector3.ZERO
	_part(root, Vector3(0.12, 0.13, 0.22), Vector3(0.06, -0.16, -0.34), glove)
	_part(root, Vector3(0.12, 0.12, 0.24), Vector3(-0.03, -0.22, 0.08), glove)
	_part(root, Vector3(0.15, 0.16, 0.34), Vector3(0.1, -0.29, -0.42), sleeve).rotation.z = -0.25
	_part(root, Vector3(0.14, 0.15, 0.3), Vector3(-0.06, -0.35, 0.1), sleeve).rotation.z = 0.15
	var muzzle := Node3D.new()
	muzzle.position = Vector3(0.0, 0.025, muzzle_z)
	root.add_child(muzzle)
	var flash := MeshInstance3D.new()
	var flash_mesh := BoxMesh.new()
	flash_mesh.size = Vector3(0.16, 0.16, 0.32) if id in ["shotgun", "lmg"] else Vector3(0.13, 0.13, 0.26)
	flash.mesh = flash_mesh
	flash.material_override = _mat(Color("#ffd27a"), 0.0, 0.0, 4.0, true)
	flash.visible = false
	flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	muzzle.add_child(flash)
	var light := OmniLight3D.new()
	light.light_color = Color("#ffc16d")
	light.light_energy = 0.0
	light.omni_range = 7.0
	light.shadow_enabled = false
	light.light_cull_mask = 0xFFFFFFFF ^ 2
	muzzle.add_child(light)
	_assign_viewmodel_layer(root)
	_rig_data[id] = {
		"root": root,
		"muzzle": muzzle,
		"flash": flash,
		"light": light,
		"magazine": magazine,
		"mag_base": mag_base,
	}


func _add_barrel(root: Node3D, y: float, z_from: float, z_to: float, radius: float, material: Material) -> void:
	var barrel := MeshInstance3D.new()
	barrel.mesh = _unit_cylinder
	barrel.scale = Vector3(radius, absf(z_to - z_from), radius)
	barrel.rotation.x = PI * 0.5
	barrel.position = Vector3(0.0, y, (z_from + z_to) * 0.5)
	barrel.material_override = material
	root.add_child(barrel)


func _assign_viewmodel_layer(node: Node) -> void:
	if node is VisualInstance3D:
		(node as VisualInstance3D).layers = 2
	for child in node.get_children():
		_assign_viewmodel_layer(child)


func set_loadout(owned: Array, selected: String) -> void:
	var cleaned: Array[String] = []
	for raw in owned:
		var id := String(raw)
		if WeaponCatalog.has_weapon(id) and not cleaned.has(id):
			cleaned.append(id)
	if cleaned.is_empty():
		cleaned = WeaponCatalog.default_owned()
	weapons_owned = cleaned
	for id in weapons_owned:
		if not _ammo_states.has(id):
			_ammo_states[id] = {
				"mag": _mag_size_for(id),
				"reserve": _reserve_cap_for(id),
			}
	var index := weapons_owned.find(selected)
	_equip_index(maxi(index, 0), false)


func current_weapon_id() -> String:
	return String(_weapon.get("id", "pistol"))


func weapon_profile() -> Dictionary:
	return _weapon.duplicate(true)


func loadout_summary() -> Array:
	var result: Array = []
	for i in range(weapons_owned.size()):
		var id := weapons_owned[i]
		var state: Dictionary = _ammo_states.get(id, {})
		result.append({
			"slot": i + 1,
			"id": id,
			"name": WeaponCatalog.short_name(id),
			"full_name": WeaponCatalog.display_name(id),
			"accent": WeaponCatalog.accent(id),
			"active": i == weapon_index,
			"mag": int(state.get("mag", 0)),
			"reserve": int(state.get("reserve", 0)),
			"mag_size": _mag_size_for(id),
		})
	return result


func switch_weapon_slot(slot: int) -> bool:
	var index := slot - 1
	if index < 0 or index >= weapons_owned.size() or index == weapon_index:
		return false
	if carrying_core or reloading or _switch_lock > 0.0 or not alive:
		return false
	_equip_index(index, true)
	return true


func _cycle_weapon(direction: int) -> void:
	if weapons_owned.size() < 2 or carrying_core or reloading or _switch_lock > 0.0 or not alive:
		return
	_equip_index(wrapi(weapon_index + direction, 0, weapons_owned.size()), true)


func _equip_index(index: int, announce: bool) -> void:
	if weapons_owned.is_empty():
		return
	index = clampi(index, 0, weapons_owned.size() - 1)
	if not _weapon.is_empty():
		_ammo_states[current_weapon_id()] = {"mag": mag, "reserve": reserve}
	weapon_index = index
	var id := weapons_owned[weapon_index]
	_weapon = WeaponCatalog.data(id)
	if not _ammo_states.has(id):
		_ammo_states[id] = {"mag": int(_weapon.get("mag", 0)), "reserve": int(_weapon.get("reserve", 0))}
	var state: Dictionary = _ammo_states[id]
	_apply_weapon_stats()
	mag = clampi(int(state.get("mag", mag_size)), 0, mag_size)
	reserve = clampi(int(state.get("reserve", reserve_cap)), 0, reserve_cap)
	reloading = false
	_reload_left = 0.0
	_trigger_was_down = false
	_switch_lock = 0.2 if announce else 0.0
	_fire_cooldown = maxf(_fire_cooldown, 0.12)
	for key in _rig_data.keys():
		var other: Dictionary = _rig_data[key]
		var other_root: Node3D = other.get("root") as Node3D
		if other_root != null:
			other_root.visible = false
	var rig: Dictionary = _rig_data.get(id, {})
	if not rig.is_empty():
		_viewmodel = rig.get("root") as Node3D
		_muzzle = rig.get("muzzle") as Node3D
		_flash_mesh = rig.get("flash") as MeshInstance3D
		_flash_light = rig.get("light") as OmniLight3D
		_magazine = rig.get("magazine") as MeshInstance3D
		_magazine_base = rig.get("mag_base", Vector3.ZERO)
		_magazine_rot_base = _magazine.rotation.x if _magazine != null else -0.22
		if _viewmodel != null:
			_viewmodel.visible = alive and not carrying_core
	ammo_changed.emit(mag, reserve, false)
	weapon_changed.emit(id, weapon_index + 1)
	if announce:
		_play_ui("switch", -6.0, randf_range(0.94, 1.06))


func _apply_weapon_stats() -> void:
	var id := current_weapon_id()
	mag_size = _mag_size_for(id)
	reserve_cap = _reserve_cap_for(id)
	reload_time = _reload_time_for(id)
	fire_interval = _fire_interval_for(id)


func _mag_size_for(id: String) -> int:
	var data := WeaponCatalog.data(id)
	var level := int(_upgrades.get("mag", 0))
	var per := 2 if id == "shotgun" else 6
	return int(data.get("mag", 12)) + per * level


func _reserve_cap_for(id: String) -> int:
	var data := WeaponCatalog.data(id)
	return int(data.get("reserve", 72)) + reserve_bonus


func _reload_time_for(id: String) -> float:
	var data := WeaponCatalog.data(id)
	var level := int(_upgrades.get("reload", 0))
	return maxf(0.5, float(data.get("reload", 1.2)) * (1.0 - 0.1 * level) * meta_reload_mult)


func _fire_interval_for(id: String) -> float:
	var data := WeaponCatalog.data(id)
	var level := int(_upgrades.get("rate", 0))
	return maxf(0.042, float(data.get("interval", 0.12)) * (1.0 - 0.07 * level))


func _play_ui(kind: String, volume: float = 0.0, pitch: float = 1.0) -> void:
	if audio != null and audio.has_method("play_ui"):
		audio.call("play_ui", kind, volume, pitch)


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
			elif key.physical_keycode >= KEY_1 and key.physical_keycode <= KEY_5:
				switch_weapon_slot(int(key.physical_keycode - KEY_1) + 1)
	elif event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.pressed and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			if button.button_index == MOUSE_BUTTON_WHEEL_UP:
				_cycle_weapon(-1)
			elif button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_cycle_weapon(1)


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
	aiming = can_move and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) and not carrying_core
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
			if carrying_core:
				aiming = false
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
	_switch_lock = maxf(0.0, _switch_lock - delta)
	_update_visuals(delta)
	var trigger_down := false
	if auto_pilot and alive and not carrying_core:
		_auto_pilot_step(delta)
	elif alive and input_enabled and not carrying_core and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		trigger_down = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	var automatic := bool(_weapon.get("auto", true))
	if trigger_down and (automatic or not _trigger_was_down):
		_fire()
	_trigger_was_down = trigger_down


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

	if _viewmodel != null:
		var target_pos := Vector3(0.0, -0.155, -0.42) if ads_pose else Vector3(0.31, -0.29, -0.53)
		target_pos.x += sway + 0.055 * tilt
		target_pos.y += bob * 0.5 - _gun_kick * 0.02 - 0.085 * tilt
		target_pos.z += _gun_kick * 0.085
		_viewmodel.position = _viewmodel.position.lerp(target_pos, delta * (18.0 if reloading else 14.0))
		_viewmodel.rotation.x = _gun_kick * 0.075 + sin(_bob_time * 0.7) * 0.003 - 0.3 * tilt
		_viewmodel.rotation.z = 0.3 * tilt
		_viewmodel.visible = alive and not carrying_core
	if _magazine != null:
		_magazine.visible = alive and mag_visible
		_magazine.position = _magazine_base + Vector3(0.015 * mag_off, -0.42 * mag_off, 0.02 * mag_off)
		_magazine.rotation.x = _magazine_rot_base + 0.55 * mag_off
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
	if not alive or reloading or carrying_core or _fire_cooldown > 0.0 or not game_active or _switch_lock > 0.0:
		return
	if mag <= 0:
		if not _trigger_was_down:
			_play_ui("empty", -8.0)
		start_reload()
		return
	mag -= 1
	_sync_ammo_state()
	_fire_cooldown = fire_interval
	_flash_time = 0.04 if aiming else 0.055
	_gun_kick = minf(1.6, float(_weapon.get("kick", 1.0)))
	var weapon_id := current_weapon_id()
	var pellets := maxi(1, int(_weapon.get("pellets", 1)))
	var spread := float(_weapon.get("ads_spread", 0.004)) if aiming else float(_weapon.get("spread", 0.01))
	if Vector2(velocity.x, velocity.z).length() > 1.0:
		spread += 0.006
	if not is_on_floor():
		spread += 0.01
	if auto_pilot:
		spread *= 0.4
	var weapon_range := float(_weapon.get("range", 100.0))
	var from := _camera.global_position
	var muzzle_pos := _muzzle.global_position if _muzzle != null else from
	var hit_any := false
	var head_any := false
	for pellet in range(pellets):
		var offset := Vector3(randf_range(-spread, spread), randf_range(-spread, spread), 0.0)
		var direction := (_camera.global_transform.basis * (Vector3(0.0, 0.0, -1.0) + offset)).normalized()
		var to := from + direction * weapon_range
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
			if pellet < 3:
				effects.tracer(muzzle_pos, end)
			effects.impact(end, normal, flesh_hit)
		if flesh_hit:
			hit_any = true
			head_any = head_any or headshot
			if main_ref != null and main_ref.has_method("request_zombie_hit"):
				main_ref.call("request_zombie_hit", zombie_id, headshot, weapon_id)
	if hit_any:
		hit_marker.emit(head_any)
	if audio != null and audio.has_method("play_weapon_shot"):
		audio.call("play_weapon_shot", weapon_id, aiming)
	ammo_changed.emit(mag, reserve, reloading)
	if mag <= 0:
		start_reload()


func _sync_ammo_state() -> void:
	if _weapon.is_empty():
		return
	_ammo_states[current_weapon_id()] = {"mag": mag, "reserve": reserve}


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
	_play_ui("reload", -4.0, randf_range(0.96, 1.05))
	ammo_changed.emit(mag, reserve, true)


func _finish_reload() -> void:
	var needed := mag_size - mag
	var taken := mini(needed, reserve)
	mag += taken
	reserve -= taken
	reloading = false
	_sync_ammo_state()
	_play_ui("reload_done", -6.0)
	ammo_changed.emit(mag, reserve, false)


func add_reserve(amount: int) -> void:
	reserve = mini(reserve_cap, reserve + amount)
	_sync_ammo_state()
	ammo_changed.emit(mag, reserve, reloading)


func refill_ammo() -> void:
	if not alive:
		return
	reloading = false
	for id in weapons_owned:
		_ammo_states[id] = {
			"mag": _mag_size_for(id),
			"reserve": _reserve_cap_for(id),
		}
	_apply_weapon_stats()
	mag = mag_size
	reserve = reserve_cap
	_sync_ammo_state()
	_play_ui("supply", -4.0)
	ammo_changed.emit(mag, reserve, false)


func set_meta_bonus(reserve_bonus_value: int, reload_multiplier: float) -> void:
	reserve_bonus = maxi(0, reserve_bonus_value)
	meta_reload_mult = clampf(reload_multiplier, 0.5, 1.0)
	for key in _ammo_states.keys():
		var id := String(key)
		var state: Dictionary = _ammo_states[key]
		var cap := _reserve_cap_for(id)
		state["reserve"] = mini(cap, int(state.get("reserve", 0)) + reserve_bonus)
	_apply_weapon_stats()
	if not _weapon.is_empty():
		reserve = mini(reserve_cap, reserve + reserve_bonus)
		_sync_ammo_state()
		ammo_changed.emit(mag, reserve, reloading)


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
	if _viewmodel != null:
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
	if _viewmodel != null:
		_viewmodel.visible = true
	if _carry_rig != null:
		_carry_rig.visible = false
	refill_ammo()
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
	_upgrades = {
		"mag": int(upgrades.get("mag", 0)),
		"reload": int(upgrades.get("reload", 0)),
		"rate": int(upgrades.get("rate", 0)),
		"speed": int(upgrades.get("speed", 0)),
		"armor": int(upgrades.get("armor", 0)),
	}
	_apply_weapon_stats()
	var speed_level := int(_upgrades["speed"])
	var speed_mult := 1.0 + 0.05 * speed_level
	walk_speed = WALK_SPEED * speed_mult
	sprint_speed = SPRINT_SPEED * speed_mult
	ads_speed = ADS_SPEED * speed_mult
	damage_reduction = clampf(0.08 * int(_upgrades["armor"]), 0.0, 0.4)
	mag = mini(mag, mag_size)
	reserve = mini(reserve, reserve_cap)
	if not reloading:
		_sync_ammo_state()
		ammo_changed.emit(mag, reserve, false)


func reload_progress() -> float:
	if not reloading:
		return 0.0
	return clampf(1.0 - _reload_left / maxf(0.01, reload_time), 0.0, 1.0)


func is_reloading() -> bool:
	return reloading


func get_spread_normalized() -> float:
	var value := clampf(float(_weapon.get("spread", 0.012)) / 0.03, 0.15, 1.0) * 0.6
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
