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
var _third_person := false
var _tp_root: Node3D
var _tp_weapon_pivot: Node3D
var _tp_weapon: Node3D
var _tp_left_leg: Node3D
var _tp_right_leg: Node3D
var _tp_body: Node3D
var _tp_arm_left: Node3D
var _tp_arm_right: Node3D
var _melee_swing_left := 0.0
var _melee_swing_total := 0.5
var _melee_stage := 0
var _melee_combo_left := 0.0
var _melee_buffered := false
var _melee_hit_pending := false
var _melee_hit_at := 0.38
var _melee_forward := Vector3.FORWARD
var _melee_draw_left := 0.0
var _melee_camera_punch := 0.0
var _settings: Node
var _aim_held := false
var _aim_toggle := false


func _ready() -> void:
	_settings = get_node_or_null("/root/UISettings")
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
	_build_third_person()
	_build_carry_visual()
	set_loadout(WeaponCatalog.default_loadout(), WeaponCatalog.DEFAULT_SELECTED)


func _build_camera() -> void:
	_head = Node3D.new()
	_head.position = Vector3(0.0, 1.55, 0.0)
	add_child(_head)
	_camera = Camera3D.new()
	_camera.fov = _setting_float("fov", 78.0)
	_camera.near = 0.045
	_camera.far = 320.0
	_camera.current = true
	_head.add_child(_camera)
	var flashlight := SpotLight3D.new()
	flashlight.position = Vector3(0.12, -0.1, 0.0)
	flashlight.spot_range = 28.0
	flashlight.spot_angle = 34.0
	flashlight.spot_angle_attenuation = 2.2
	flashlight.light_energy = 1.35
	flashlight.light_color = Color("#ffe9c7")
	flashlight.shadow_enabled = false
	flashlight.light_cull_mask = 0xFFFFFFFF ^ 2
	_camera.add_child(flashlight)
	var viewmodel_light := OmniLight3D.new()
	viewmodel_light.position = Vector3(0.0, 0.05, -0.15)
	viewmodel_light.light_color = Color("#dfe8ef")
	viewmodel_light.light_energy = 0.65
	viewmodel_light.omni_range = 2.4
	viewmodel_light.shadow_enabled = false
	_camera.add_child(viewmodel_light)


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


func _build_third_person() -> void:
	_tp_root = Node3D.new()
	_tp_root.visible = false
	add_child(_tp_root)
	_tp_body = Node3D.new()
	_tp_root.add_child(_tp_body)
	var jacket := _mat(Color("#2d4a43"), 0.95)
	var jacket_dark := _mat(Color("#20352f"), 0.98)
	var pants := _mat(Color("#26343a"), 0.98)
	var skin := _mat(Color("#b98d68"), 0.9)
	var hair := _mat(Color("#2a2521"), 1.0)
	var strap := _mat(Color("#b08743"), 0.7, 0.15)
	var glove := _mat(Color("#1b2624"), 0.9)
	var boots := _mat(Color("#171d20"), 0.95)
	_part(_tp_body, Vector3(0.52, 0.58, 0.34), Vector3(0.0, 1.24, 0.0), jacket)
	_part(_tp_body, Vector3(0.42, 0.34, 0.38), Vector3(0.0, 1.3, 0.0), jacket_dark)
	_part(_tp_body, Vector3(0.54, 0.1, 0.36), Vector3(0.0, 0.94, 0.0), strap)
	_part(_tp_body, Vector3(0.36, 0.44, 0.2), Vector3(0.0, 1.27, 0.27), strap)
	_part(_tp_body, Vector3(0.3, 0.32, 0.3), Vector3(0.0, 1.64, 0.0), skin)
	_part(_tp_body, Vector3(0.32, 0.1, 0.31), Vector3(0.0, 1.81, 0.0), hair)
	for side in [-1.0, 1.0]:
		var arm := Node3D.new()
		arm.position = Vector3(0.34 * side, 1.46, 0.0)
		_tp_body.add_child(arm)
		_part(arm, Vector3(0.15, 0.42, 0.19), Vector3(0.0, -0.18, 0.0), jacket)
		_part(arm, Vector3(0.13, 0.13, 0.15), Vector3(0.0, -0.42, 0.0), glove)
		if side < 0.0:
			_tp_arm_left = arm
		else:
			_tp_arm_right = arm
	_tp_left_leg = Node3D.new()
	_tp_left_leg.position = Vector3(-0.16, 0.88, 0.0)
	_tp_body.add_child(_tp_left_leg)
	_part(_tp_left_leg, Vector3(0.21, 0.76, 0.25), Vector3(0.0, -0.38, 0.0), pants)
	_part(_tp_left_leg, Vector3(0.23, 0.16, 0.32), Vector3(0.0, -0.8, -0.04), boots)
	_tp_right_leg = Node3D.new()
	_tp_right_leg.position = Vector3(0.16, 0.88, 0.0)
	_tp_body.add_child(_tp_right_leg)
	_part(_tp_right_leg, Vector3(0.21, 0.76, 0.25), Vector3(0.0, -0.38, 0.0), pants)
	_part(_tp_right_leg, Vector3(0.23, 0.16, 0.32), Vector3(0.0, -0.8, -0.04), boots)
	_tp_weapon_pivot = Node3D.new()
	_tp_weapon_pivot.position = Vector3(0.46, 1.18, -0.2)
	_tp_body.add_child(_tp_weapon_pivot)


func _build_tp_weapon(id: String) -> void:
	if _tp_weapon != null:
		_tp_weapon.queue_free()
	_tp_weapon = Node3D.new()
	_tp_weapon_pivot.add_child(_tp_weapon)
	var accent := _mat(WeaponCatalog.accent(id), 0.45, 0.25, 0.8)
	var steel := _mat(Color("#c3ccd0"), 0.35, 0.7)
	var dark := _mat(Color("#1b2226"), 0.8, 0.25)
	var wood := _mat(Color("#5a3d27"), 0.9)
	_part(_tp_weapon, Vector3(0.09, 0.1, 0.32), Vector3(0.0, 0.0, 0.08), wood)
	_part(_tp_weapon, Vector3(0.13, 0.13, 0.12), Vector3(0.0, -0.02, -0.08), dark)
	if id == "sledge":
		_add_barrel(_tp_weapon, 0.0, -0.64, 0.16, 0.038, wood)
		_part(_tp_weapon, Vector3(0.18, 0.46, 0.24), Vector3(0.0, 0.0, -0.82), steel)
		_part(_tp_weapon, Vector3(0.2, 0.12, 0.26), Vector3(0.0, 0.26, -0.82), accent)
	else:
		_part(_tp_weapon, Vector3(0.055, 0.16, 0.9), Vector3(0.0, 0.03, -0.48), steel).rotation.x = -0.06
		_part(_tp_weapon, Vector3(0.07, 0.1, 0.2), Vector3(0.0, 0.02, -0.93), accent)
		_part(_tp_weapon, Vector3(0.035, 0.05, 0.5), Vector3(0.0, 0.1, -0.5), accent)
	_tp_weapon.rotation = Vector3(0.2, -0.2, -0.12)


func set_loadout(owned: Array, selected: String) -> void:
	var cleaned: Array[String] = []
	for raw in owned:
		var id := String(raw)
		if WeaponCatalog.has_weapon(id) and not cleaned.has(id):
			cleaned.append(id)
		if cleaned.size() >= WeaponCatalog.MAX_CARRY:
			break
	if not cleaned.has(selected) and WeaponCatalog.has_weapon(selected):
		if cleaned.size() >= WeaponCatalog.MAX_CARRY:
			cleaned[cleaned.size() - 1] = selected
		else:
			cleaned.append(selected)
	if cleaned.is_empty():
		cleaned.assign(WeaponCatalog.default_loadout())
	weapons_owned = cleaned
	for id in weapons_owned:
		if not _ammo_states.has(id):
			_ammo_states[id] = {
				"mag": _mag_size_for(id),
				"reserve": _reserve_cap_for(id),
			}
	var index := weapons_owned.find(selected)
	_equip_index(maxi(index, 0), false)


func is_melee_equipped() -> bool:
	return not _weapon.is_empty() and String(_weapon.get("kind", "gun")) == "melee"


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
			"kind": String(WeaponCatalog.data(id).get("kind", "gun")),
			"melee": WeaponCatalog.is_melee(id),
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
	_third_person = WeaponCatalog.is_melee(id)
	_melee_stage = 0
	_melee_combo_left = 0.0
	_melee_buffered = false
	_melee_hit_pending = false
	_melee_swing_left = 0.0
	_melee_draw_left = 0.24 if _third_person else 0.0
	_melee_camera_punch = 0.0
	_melee_forward = -global_transform.basis.z
	if _third_person:
		_viewmodel = null
		_muzzle = null
		_flash_mesh = null
		_flash_light = null
		_magazine = null
		_build_tp_weapon(id)
		if _tp_root != null:
			_tp_root.visible = alive and not carrying_core
	else:
		if _tp_root != null:
			_tp_root.visible = false
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
	if WeaponCatalog.is_melee(id):
		mag_size = 0
		reserve_cap = 0
		reload_time = 0.0
		fire_interval = _melee_interval_for(id)
		mag = 0
		reserve = 0
		return
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


func _melee_interval_for(id: String) -> float:
	var data := WeaponCatalog.data(id)
	var level := int(_upgrades.get("rate", 0))
	return maxf(0.32, float(data.get("interval", 0.6)) * (1.0 - 0.06 * level))


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
		_aim_held = false
		_aim_toggle = false


func _unhandled_input(event: InputEvent) -> void:
	if not game_active or not input_enabled or not alive:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_apply_mouse_look((event as InputEventMouseMotion).relative)
	elif event.is_action_pressed("aim"):
		if _setting_string("aim_mode", "hold") == "toggle":
			_aim_toggle = not _aim_toggle
		else:
			_aim_held = true
		get_viewport().set_input_as_handled()
	elif event.is_action_released("aim"):
		_aim_held = false
	elif event.is_action_pressed("reload"):
		start_reload()
	elif event.is_action_pressed("jump"):
		_jump_queued = true
	elif event.is_action_pressed("weapon_prev"):
		_cycle_weapon(-1)
	elif event.is_action_pressed("weapon_next"):
		_cycle_weapon(1)
	elif event.is_action_pressed("weapon_1"):
		switch_weapon_slot(1)
	elif event.is_action_pressed("weapon_2"):
		switch_weapon_slot(2)
	elif event.is_action_pressed("weapon_3"):
		switch_weapon_slot(3)
	elif event.is_action_pressed("weapon_4"):
		switch_weapon_slot(4)
	elif event.is_action_pressed("weapon_5"):
		switch_weapon_slot(5)


func _apply_mouse_look(relative: Vector2) -> void:
	var sens_x := SENSITIVITY * _setting_float("mouse_x", 1.0)
	var sens_y := SENSITIVITY * _setting_float("mouse_y", 1.0)
	if aiming:
		var ads := _setting_float("ads_sens", 0.8)
		sens_x *= ads
		sens_y *= ads
	if _setting_bool("invert_y", false):
		sens_y = -sens_y
	_yaw = wrapf(_yaw - relative.x * sens_x, -PI, PI)
	_pitch = clampf(_pitch - relative.y * sens_y, -1.47, 1.47)
	rotation.y = _yaw
	_head.rotation.x = _pitch


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
		if velocity.y > 0.0 and not Input.is_action_pressed("jump"):
			velocity.y -= _gravity * JUMP_CUT * delta
	if _jump_queued:
		_jump_buffer = JUMP_BUFFER
		_jump_queued = false
	else:
		_jump_buffer = maxf(0.0, _jump_buffer - delta)
	var can_move := alive and input_enabled
	var wish := Vector3.ZERO
	var aim_requested := _aim_held if _setting_string("aim_mode", "hold") == "hold" else _aim_toggle
	aiming = can_move and aim_requested and not carrying_core
	if carrying_core or not alive:
		_aim_toggle = false
	if can_move:
		var input_dir := Input.get_vector("move_left", "move_right", "move_back", "move_forward")
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
		var sprinting := Input.is_action_pressed("sprint") and input_dir.y > 0.2 and not aiming and not carrying_core
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
	if _flash_mesh != null:
		_flash_mesh.visible = _flash_time > 0.0
	if _flash_light != null:
		_flash_light.light_energy = 3.2 if _flash_time > 0.0 else 0.0
	if reloading:
		_reload_left -= delta
		if _reload_left <= 0.0:
			_finish_reload()
	_switch_lock = maxf(0.0, _switch_lock - delta)
	_update_melee_state(delta)
	_update_visuals(delta)
	var trigger_down := false
	if auto_pilot and alive and not carrying_core:
		_auto_pilot_step(delta)
	elif alive and input_enabled and not carrying_core and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		trigger_down = Input.is_action_pressed("fire")
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
	var ads_pose := aiming and not reloading and not carrying_core and not _third_person
	var base_fov := _setting_float("fov", 78.0)
	var ads_fov := _setting_float("ads_fov", 58.0)
	var target_fov := ads_fov if ads_pose else (base_fov - 6.0 if _third_person else base_fov)
	_camera.fov = clampf(lerpf(_camera.fov, target_fov, minf(1.0, delta * 11.0)), 20.0, 140.0)
	var camera_target := Vector3.ZERO
	if _third_person and alive and not carrying_core:
		camera_target = Vector3(0.82, 0.55, 3.05)
		var desired := _head.global_transform * camera_target
		var query := PhysicsRayQueryParameters3D.create(_head.global_position, desired, 1, [get_rid()])
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty():
			var safe: Vector3 = hit["position"] + Vector3(hit["normal"]) * 0.22
			camera_target = _head.global_transform.affine_inverse() * safe
			camera_target.z = maxf(0.4, camera_target.z)
	_camera.position = _camera.position.lerp(camera_target, delta * (9.0 if _third_person else 13.0))

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
		_viewmodel.visible = alive and not carrying_core and not _third_person
	if _magazine != null:
		_magazine.visible = alive and mag_visible
		_magazine.position = _magazine_base + Vector3(0.015 * mag_off, -0.42 * mag_off, 0.02 * mag_off)
		_magazine.rotation.x = _magazine_rot_base + 0.55 * mag_off
		_magazine.rotation.z = 0.35 * mag_off

	if _tp_root != null:
		var show_body := alive and _third_person and not carrying_core
		_tp_root.visible = show_body
		if show_body:
			var stride := sin(_bob_time * 2.2) * clampf(horizontal_speed / WALK_SPEED, 0.0, 1.2)
			_tp_left_leg.rotation.x = stride * 0.6
			_tp_right_leg.rotation.x = -stride * 0.6
			var idle_pivot := Vector3(0.12, 0.5, -0.2)
			var pivot_target := idle_pivot + Vector3(sin(_bob_time * 0.7) * 0.008, sin(_bob_time * 0.55) * 0.012, 0.0)
			var body_target := Vector3.ZERO
			var arm_left_target := Vector3.ZERO
			var arm_right_target := Vector3.ZERO
			var pivot_pos := Vector3(0.46, 1.18 - bob * 0.35, -0.2)
			var swing_t := melee_combo_progress()
			if _melee_swing_left > 0.0 and _melee_stage > 0:
				var pose := _melee_stage_pose(swing_t, _melee_stage)
				pivot_target = pose
				var contact_reach := sin(clampf(swing_t / maxf(0.01, _melee_hit_at), 0.0, 1.0) * PI * 0.5)
				body_target = Vector3(
					clampf(-pose.x * 0.1, -0.045, 0.14),
					pose.y * 0.22,
					pose.z * 0.05
				)
				arm_right_target = Vector3(-0.2 - pose.x * 0.45, 0.04, -0.38 + pose.z * 0.3)
				arm_left_target = Vector3(-0.55 * contact_reach, 0.0, 0.32 * contact_reach)
				pivot_pos.x -= 0.12 * contact_reach
				pivot_pos.z -= 0.11 * contact_reach
			elif moving:
				arm_left_target.x = -stride * 0.45
				arm_right_target.x = stride * 0.45
			if _melee_draw_left > 0.0:
				var draw_t := _smooth01(1.0 - _melee_draw_left / 0.24)
				pivot_target = Vector3(-0.55, 0.95, -0.5).lerp(pivot_target, draw_t)
				arm_right_target = Vector3(-0.5, 0.0, -0.2).lerp(arm_right_target, draw_t)
				arm_left_target = Vector3(-0.15, 0.0, 0.1).lerp(arm_left_target, draw_t)
			var swinging := _melee_swing_left > 0.0
			var pose_speed := 48.0 if swinging else 9.0
			var body_speed := 24.0 if swinging else 10.0
			_tp_weapon_pivot.rotation = _tp_weapon_pivot.rotation.lerp(pivot_target, minf(1.0, delta * pose_speed))
			_tp_weapon_pivot.position = _tp_weapon_pivot.position.lerp(pivot_pos, minf(1.0, delta * (18.0 if swinging else 12.0)))
			_tp_body.rotation = _tp_body.rotation.lerp(body_target, minf(1.0, delta * body_speed))
			if _tp_arm_left != null:
				_tp_arm_left.rotation = _tp_arm_left.rotation.lerp(arm_left_target, minf(1.0, delta * body_speed))
			if _tp_arm_right != null:
				_tp_arm_right.rotation = _tp_arm_right.rotation.lerp(arm_right_target, minf(1.0, delta * body_speed))
		_camera.h_offset = _melee_camera_punch * 0.55
		_camera.v_offset = -_melee_camera_punch

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


func _melee_stage_pose(t: float, stage: int) -> Vector3:
	var idle := Vector3(0.12, 0.5, -0.2)
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
			if current_weapon_id() == "sledge":
				windup = Vector3(1.55, 0.05, -0.2)
				contact = Vector3(-0.95, -0.7, 0.18)
				follow = Vector3(-0.65, -0.85, 0.28)
			windup_at = 0.32
	windup_at = minf(windup_at, _melee_hit_at * 0.8)
	var contact_at := _melee_hit_at
	var follow_at := minf(0.94, contact_at + 0.2)
	if t <= windup_at:
		return idle.lerp(windup, _smooth01(t / maxf(0.01, windup_at)))
	if t < contact_at:
		return windup.lerp(contact, _smooth01((t - windup_at) / maxf(0.01, contact_at - windup_at)))
	if t < follow_at:
		return contact.lerp(follow, (t - contact_at) / maxf(0.01, follow_at - contact_at))
	return follow.lerp(idle, _smooth01((t - follow_at) / maxf(0.01, 1.0 - follow_at)))


func _fire() -> void:
	if not alive or reloading or carrying_core or not game_active or _switch_lock > 0.0:
		return
	if is_melee_equipped():
		_fire_melee()
		return
	if _fire_cooldown > 0.0:
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
	if _weapon.is_empty() or is_melee_equipped():
		return
	_ammo_states[current_weapon_id()] = {"mag": mag, "reserve": reserve}


func melee_combo_stage() -> int:
	if _melee_stage > 0 and (_melee_swing_left > 0.0 or _melee_combo_left > 0.0):
		return _melee_stage
	return 0


func melee_combo_progress() -> float:
	if _melee_swing_left <= 0.0 or _melee_swing_total <= 0.0:
		return 0.0
	return clampf(1.0 - _melee_swing_left / _melee_swing_total, 0.0, 1.0)


func _fire_melee() -> void:
	if _melee_swing_left > 0.0:
		if _melee_swing_left <= 0.2 and _melee_stage < WeaponCatalog.MELEE_COMBO_STAGES:
			_melee_buffered = true
		return
	_start_melee_stage()


func _start_melee_stage() -> void:
	var weapon_id := current_weapon_id()
	if not WeaponCatalog.is_melee(weapon_id):
		return
	var next_stage := 1
	if _melee_stage > 0 and _melee_stage < WeaponCatalog.MELEE_COMBO_STAGES and _melee_combo_left > 0.0:
		next_stage = _melee_stage + 1
	_melee_stage = next_stage
	_melee_swing_total = WeaponCatalog.melee_stage_duration(weapon_id, _melee_stage)
	_melee_swing_left = _melee_swing_total
	_fire_cooldown = _melee_swing_total
	_melee_hit_at = WeaponCatalog.melee_stage_hit(_melee_stage)
	_melee_hit_pending = true
	_melee_buffered = false
	_melee_combo_left = 0.0
	_melee_draw_left = 0.0
	_melee_forward = -global_transform.basis.z
	_melee_forward.y = 0.0
	if _melee_forward.length_squared() < 0.01:
		_melee_forward = Vector3.FORWARD
	_melee_forward = _melee_forward.normalized()
	_play_ui("melee", -1.0, [0.94, 1.04, 0.82][_melee_stage - 1])


func _update_melee_state(delta: float) -> void:
	_melee_draw_left = maxf(0.0, _melee_draw_left - delta)
	_melee_camera_punch = move_toward(_melee_camera_punch, 0.0, delta * 0.42)
	if not is_melee_equipped():
		_melee_stage = 0
		_melee_combo_left = 0.0
		_melee_buffered = false
		_melee_hit_pending = false
		_melee_swing_left = 0.0
		return
	if _melee_swing_left > 0.0:
		var before := 1.0 - _melee_swing_left / maxf(0.01, _melee_swing_total)
		_melee_swing_left = maxf(0.0, _melee_swing_left - delta)
		var after := 1.0 - _melee_swing_left / maxf(0.01, _melee_swing_total)
		if _melee_hit_pending and before < _melee_hit_at and after >= _melee_hit_at:
			_melee_hit_pending = false
			_resolve_melee_hit()
		if _melee_swing_left <= 0.0:
			_melee_hit_pending = false
			if _melee_stage < WeaponCatalog.MELEE_COMBO_STAGES:
				_melee_combo_left = WeaponCatalog.MELEE_COMBO_WINDOW
				if _melee_buffered:
					_melee_buffered = false
					_start_melee_stage()
			else:
				_melee_stage = 0
				_melee_combo_left = 0.0
	elif _melee_stage > 0:
		_melee_combo_left = maxf(0.0, _melee_combo_left - delta)
		if _melee_combo_left <= 0.0:
			_melee_stage = 0


func _resolve_melee_hit() -> void:
	var weapon_id := current_weapon_id()
	if not WeaponCatalog.is_melee(weapon_id):
		return
	var stage := clampi(_melee_stage, 1, WeaponCatalog.MELEE_COMBO_STAGES)
	var weapon_range := WeaponCatalog.melee_stage_range(weapon_id, stage)
	var half_arc := WeaponCatalog.melee_stage_arc(weapon_id, stage)
	var max_targets := WeaponCatalog.melee_stage_targets(stage)
	var forward := _melee_forward
	forward.y = 0.0
	if forward.length_squared() < 0.01:
		forward = Vector3.FORWARD
	forward = forward.normalized()
	var origin := global_position + Vector3.UP
	var candidates: Array = []
	for node in get_tree().get_nodes_in_group("zombie_proxies"):
		if not is_instance_valid(node) or not node is Node3D:
			continue
		if node.has_method("is_targetable") and not bool(node.call("is_targetable")):
			continue
		var target := node as Node3D
		var offset := target.global_position - origin
		offset.y = 0.0
		var distance := offset.length()
		if distance > weapon_range + 0.35 or distance < 0.01:
			continue
		if forward.dot(offset / distance) < cos(half_arc):
			continue
		candidates.append({"id": int(target.get("zombie_id")), "pos": target.global_position, "distance": distance})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["distance"]) < float(b["distance"])
	)
	var strikes := mini(max_targets, candidates.size())
	var hit_any := false
	for i in range(strikes):
		var entry: Dictionary = candidates[i]
		hit_any = true
		if effects != null:
			effects.impact(Vector3(entry["pos"]) + Vector3.UP * 1.1, Vector3.UP, true)
		if main_ref != null and main_ref.has_method("request_zombie_hit"):
			main_ref.call("request_zombie_hit", int(entry["id"]), false, weapon_id, stage)
	if hit_any:
		hit_marker.emit(false)
		_play_ui("melee_hit", -1.0 + stage * 0.7, [1.02, 1.08, 0.92][stage - 1])
	if is_on_floor():
		var mass_scale := 0.72 if weapon_id == "sledge" else 1.0
		velocity += forward * WeaponCatalog.melee_stage_lunge(stage) * mass_scale
	_melee_camera_punch = 0.012 + 0.008 * stage
	ammo_changed.emit(mag, reserve, false)


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
	var fire_range := 90.0
	if is_melee_equipped():
		fire_range = float(_weapon.get("range", 2.6))
	if _auto_fire_timer <= 0.0 and nearest_distance < fire_range * fire_range:
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
	if is_melee_equipped() or reloading or carrying_core or mag >= mag_size or reserve <= 0 or not alive:
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
		if WeaponCatalog.is_melee(id):
			continue
		_ammo_states[id] = {
			"mag": _mag_size_for(id),
			"reserve": _reserve_cap_for(id),
		}
	_apply_weapon_stats()
	if is_melee_equipped():
		mag = 0
		reserve = 0
	else:
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
	_aim_held = false
	_aim_toggle = false
	if _viewmodel != null:
		_viewmodel.visible = false
	if _carry_rig != null:
		_carry_rig.visible = false
	if _tp_root != null:
		_tp_root.visible = false
	died.emit()


func _setting_float(key: String, fallback: float) -> float:
	if _settings == null:
		return fallback
	return float(_settings.get_value(key))


func _setting_bool(key: String, fallback: bool) -> bool:
	if _settings == null:
		return fallback
	return bool(_settings.get_value(key))


func _setting_string(key: String, fallback: String) -> String:
	if _settings == null:
		return fallback
	return String(_settings.get_value(key))


func set_view_direction(yaw_value: float, pitch_value: float = 0.0) -> void:
	_yaw = wrapf(yaw_value, -PI, PI)
	_pitch = clampf(pitch_value, -1.47, 1.47)
	rotation.y = _yaw
	if _head != null:
		_head.rotation.x = _pitch


func respawn_at(pos: Vector3, face_yaw: float = 0.0) -> void:
	global_position = Vector3(pos.x, maxf(pos.y, 0.12), pos.z)
	velocity = Vector3.ZERO
	health = 100.0
	alive = true
	reloading = false
	carrying_core = false
	_aim_held = false
	_aim_toggle = false
	_yaw = face_yaw
	_pitch = 0.0
	rotation.y = _yaw
	_head.rotation.x = 0.0
	_head.position.y = 1.55
	if _viewmodel != null:
		_viewmodel.visible = not _third_person
	if _tp_root != null:
		_tp_root.visible = _third_person
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
		_aim_held = false
		_aim_toggle = false
		_flash_time = 0.0
		if _flash_mesh != null:
			_flash_mesh.visible = false
	if _viewmodel != null:
		_viewmodel.visible = alive and not value
	if _tp_root != null:
		_tp_root.visible = alive and not value and _third_person
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
	if is_melee_equipped():
		return 0.0
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
