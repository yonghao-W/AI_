class_name ServerZombie
extends CharacterBody3D

signal attacked_player(player_id: int, damage: float)

var zombie_id := 0
var kind := "walker"
var hp := 100.0
var max_hp := 100.0
var speed := 2.2
var attack_damage := 9.0
var attack_interval := 1.2
var state := 0
var _cooldown := 0.0
var _steer_side := 1.0
var _stuck_time := 0.0


func setup(id: int, kind_id: String, wave: int) -> void:
	zombie_id = id
	kind = kind_id
	collision_layer = 0
	collision_mask = 1
	var scale := 1.0
	match kind:
		"crawler":
			scale = 0.64
			max_hp = 42.0
			speed = 5.4 + minf(1.6, wave * 0.1)
			attack_damage = 4.5 + wave * 0.35
			attack_interval = 0.7
		"runner":
			scale = 0.9
			max_hp = 62.0
			speed = 4.5 + minf(1.2, wave * 0.08)
			attack_damage = 6.0 + wave * 0.6
			attack_interval = 0.85
		"brute":
			scale = 1.32
			max_hp = 275.0
			speed = 1.55 + minf(0.8, wave * 0.04)
			attack_damage = 19.0 + wave * 1.3
			attack_interval = 1.55
		_:
			max_hp = 96.0
			speed = 2.15 + minf(1.1, wave * 0.06)
			attack_damage = 9.0 + wave * 0.7
			attack_interval = 1.15
	max_hp *= 1.0 + (wave - 1) * 0.14
	hp = max_hp
	attack_damage *= 1.0 + (wave - 1) * 0.08
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.4 * scale
	capsule.height = 1.95 * scale
	var shape := CollisionShape3D.new()
	shape.shape = capsule
	shape.position.y = 0.98 * scale
	add_child(shape)


func step(delta: float, target_pos: Vector3, target_id: int, has_target: bool) -> void:
	_cooldown = maxf(0.0, _cooldown - delta)
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
	rotation.y = lerp_angle(rotation.y, atan2(-direction.x, -direction.z), clampf(delta * 8.0, 0.0, 1.0))
	if distance <= 1.9:
		state = 1
		velocity.x = 0.0
		velocity.z = 0.0
		if _cooldown <= 0.0:
			_cooldown = attack_interval
			attacked_player.emit(target_id, attack_damage)
		return
	state = 0
	var step_motion := direction * speed * delta
	if test_move(global_transform, direction * speed * 0.18):
		direction = direction.rotated(Vector3.UP, 1.0 * _steer_side)
		if test_move(global_transform, direction * speed * 0.18):
			_steer_side *= -1.0
			direction = direction.rotated(Vector3.UP, -1.6 * _steer_side)
		_stuck_time += delta
	else:
		_stuck_time = maxf(0.0, _stuck_time - delta * 2.0)
	step_motion = direction * speed * delta
	velocity.x = step_motion.x / maxf(delta, 0.0001)
	velocity.z = step_motion.z / maxf(delta, 0.0001)
	velocity.y = 0.0
	var before := global_position
	move_and_slide()
	global_position.y = 0.06
	if global_position.distance_to(before) < speed * delta * 0.15:
		_stuck_time += delta * 0.5
		if _stuck_time > 0.45:
			_steer_side *= -1.0
			_stuck_time = 0.0


func take_damage(amount: float) -> bool:
	hp -= amount
	return hp <= 0.0


func snapshot() -> Array:
	return [
		zombie_id,
		global_position.x, global_position.y, global_position.z,
		rotation.y, kind, state,
	]
