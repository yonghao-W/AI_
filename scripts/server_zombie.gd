class_name ServerZombie
extends CharacterBody3D

signal attacked_player(player_id: int, damage: float)

const ABILITY_ORDER := ["none", "climber", "armored", "volatile"]

var zombie_id := 0
var kind := "walker"
var ability := "none"
var mass := 0
var tint := Color("#759b50")
var visual_scale := 1.0
var hp := 100.0
var max_hp := 100.0
var speed := 2.2
var attack_damage := 9.0
var attack_interval := 1.2
var state := 0
var floor_y := 0.06
var _cooldown := 0.0
var _steer_side := 1.0
var _stuck_time := 0.0
var _frenzy := false
var _climb_left := 0.0
var _climb_height := 0.0
var _climb_cooldown := 0.0
var _leap_left := 0.0
var _leap_velocity := Vector3.ZERO
var _screeched := false
var _shape: CollisionShape3D


func set_frenzy(value: bool) -> void:
	_frenzy = value
	if value and not _screeched:
		_screeched = true


func speed_now() -> float:
	var scale_speed := 1.0 - clampf((visual_scale - 1.0) * 0.12, 0.0, 0.3)
	return speed * (1.35 if _frenzy else 1.0) * scale_speed


func setup(id: int, kind_id: String, wave: int) -> void:
	zombie_id = id
	kind = kind_id
	collision_layer = 0
	collision_mask = 1
	floor_y = 0.06
	match kind:
		"crawler":
			visual_scale = 0.64
			max_hp = 42.0
			speed = 5.4 + minf(1.6, wave * 0.1)
			attack_damage = 4.5 + wave * 0.35
			attack_interval = 0.7
			tint = Color("#c2b26a")
		"runner":
			visual_scale = 0.9
			max_hp = 62.0
			speed = 4.5 + minf(1.2, wave * 0.08)
			attack_damage = 6.0 + wave * 0.6
			attack_interval = 0.85
			tint = Color("#b1bf52")
		"brute":
			visual_scale = 1.32
			max_hp = 275.0
			speed = 1.55 + minf(0.8, wave * 0.04)
			attack_damage = 19.0 + wave * 1.3
			attack_interval = 1.55
			tint = Color("#bb6b48")
		_:
			max_hp = 96.0
			speed = 2.15 + minf(1.1, wave * 0.06)
			attack_damage = 9.0 + wave * 0.7
			attack_interval = 1.15
			tint = Color("#759b50")
	max_hp *= 1.0 + (wave - 1) * 0.14
	hp = max_hp
	attack_damage *= 1.0 + (wave - 1) * 0.08
	_refresh_shape()


func apply_ability(value: String) -> void:
	if value == "none" or not ABILITY_ORDER.has(value):
		return
	ability = value
	match ability:
		"climber":
			speed += 0.55
			tint = tint.lerp(Color("#7fd4c8"), 0.4)
		"armored":
			max_hp *= 1.4
			attack_damage *= 1.1
			speed *= 0.88
			visual_scale = minf(2.5, visual_scale * 1.14)
			tint = tint.lerp(Color("#4f5a63"), 0.55)
		"volatile":
			max_hp *= 0.82
			speed *= 1.12
			attack_damage *= 0.92
			tint = tint.lerp(Color("#d84a3d"), 0.62)
	hp = max_hp
	_refresh_shape()


func fuse_with(prey: ServerZombie) -> void:
	mass += prey.mass + 1
	max_hp += prey.max_hp * (0.45 + 0.2 * prey.mass)
	hp = minf(max_hp, hp + max_hp * 0.32 + prey.hp * 0.35)
	attack_damage = attack_damage * 1.16 + prey.attack_damage * 0.28
	speed = minf(7.6, speed * 1.05 + 0.08)
	visual_scale = minf(2.5, visual_scale + 0.2 + 0.14 * prey.visual_scale)
	tint = tint.lerp(prey.tint, 0.45)
	if ability == "none" and prey.ability != "none":
		ability = prey.ability
	elif mass >= 2 and ability == "none":
		ability = "armored" if mass % 2 == 0 else "volatile"
	_cooldown = 0.0
	_refresh_shape()


func _refresh_shape() -> void:
	if _shape != null and is_instance_valid(_shape):
		_shape.queue_free()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.4 * visual_scale
	capsule.height = 1.95 * visual_scale
	_shape = CollisionShape3D.new()
	_shape.shape = capsule
	_shape.position.y = 0.98 * visual_scale
	add_child(_shape)


func step(delta: float, target_pos: Vector3, target_id: int, has_target: bool) -> void:
	_cooldown = maxf(0.0, _cooldown - delta)
	_climb_cooldown = maxf(0.0, _climb_cooldown - delta)
	if not has_target:
		state = 0
		velocity = Vector3.ZERO
		return
	var flat := Vector3(target_pos.x, global_position.y, target_pos.z)
	var to_target := flat - global_position
	var distance := to_target.length()
	if distance < 0.01:
		velocity = Vector3.ZERO
		return
	var direction := to_target / distance
	var move_speed := speed_now()
	rotation.y = lerp_angle(rotation.y, atan2(-direction.x, -direction.z), clampf(delta * 8.0, 0.0, 1.0))
	if _leap_left > 0.0:
		_tick_leap(delta, distance, target_id)
		return
	if _climb_left > 0.0:
		_climb_left -= delta
		state = 2
		global_position.y = minf(global_position.y + (3.4 + 0.35 * mass) * delta, floor_y + _climb_height)
		velocity = Vector3.ZERO
		if _climb_left <= 0.0:
			_leap_left = 0.65
			var leap_dir := Vector3(target_pos.x - global_position.x, 0.0, target_pos.z - global_position.z).normalized()
			_leap_velocity = leap_dir * (7.5 + mass * 0.6) + Vector3(0.0, 3.4, 0.0)
		return
	if distance <= 1.9 + 0.25 * mass:
		state = 1
		velocity = Vector3.ZERO
		_apply_gravity(delta)
		if _cooldown <= 0.0:
			_cooldown = attack_interval * (0.62 if _frenzy else 1.0)
			attacked_player.emit(target_id, attack_damage * (1.2 if _frenzy else 1.0))
		return
	state = 0
	var step_motion := direction * move_speed * delta
	if test_move(global_transform, direction * move_speed * 0.18):
		if ability == "climber" and _climb_cooldown <= 0.0 and global_position.y <= floor_y + 0.4 and target_pos.y > floor_y - 1.5:
			_start_climb(distance)
			return
		direction = direction.rotated(Vector3.UP, 1.0 * _steer_side)
		if test_move(global_transform, direction * move_speed * 0.18):
			_steer_side *= -1.0
			direction = direction.rotated(Vector3.UP, -1.6 * _steer_side)
		_stuck_time += delta
	else:
		_stuck_time = maxf(0.0, _stuck_time - delta * 2.0)
	step_motion = direction * move_speed * delta
	velocity.x = step_motion.x / maxf(delta, 0.0001)
	velocity.z = step_motion.z / maxf(delta, 0.0001)
	_apply_gravity(delta)
	var before := global_position
	move_and_slide()
	if global_position.y < floor_y:
		global_position.y = floor_y
	if global_position.distance_to(before) < move_speed * delta * 0.15:
		_stuck_time += delta * 0.5
		if _stuck_time > 0.45:
			_steer_side *= -1.0
			_stuck_time = 0.0


func _start_climb(distance: float) -> void:
	state = 2
	_climb_left = 0.7 + minf(0.5, distance * 0.04)
	_climb_height = 3.0 + mass * 0.5
	_climb_cooldown = 2.6
	_stuck_time = 0.0
	velocity = Vector3.ZERO


func _tick_leap(delta: float, distance: float, target_id: int) -> void:
	state = 3
	_leap_left -= delta
	_leap_velocity.y -= 19.0 * delta
	velocity = _leap_velocity
	move_and_slide()
	if distance <= 2.2 and _cooldown <= 0.0:
		_cooldown = attack_interval
		attacked_player.emit(target_id, attack_damage * (1.1 if _frenzy else 1.0))
	if _leap_left <= 0.0 or global_position.y <= floor_y + 0.02:
		global_position.y = floor_y
		_leap_left = 0.0
		velocity = Vector3.ZERO


func _apply_gravity(delta: float) -> void:
	if global_position.y > floor_y + 0.02:
		velocity.y -= 22.0 * delta
	else:
		velocity.y = 0.0


func take_damage(amount: float) -> bool:
	var mitigation := 0.32 if ability == "armored" else 0.0
	hp -= amount * (1.0 - mitigation)
	return hp <= 0.0


func snapshot() -> Array:
	return [
		zombie_id,
		global_position.x, global_position.y, global_position.z,
		rotation.y, kind, state, visual_scale, tint.to_rgba32(), ability_index(), mass,
	]


func ability_index() -> int:
	return ABILITY_ORDER.find(ability)
