class_name ZombieDirector
extends Node3D

signal attacked_player(player_id: int, damage: float)

var _layout: Dictionary = {}
var _zombies: Dictionary = {}
var _next_id := 1
var _wave := 1
var _phase := "break"
var _break_left := 4.0
var _to_spawn := 0
var _spawn_delay := 0.0
var _spawn_interval := 1.2
var _escalation := 0
var _active := false
var _rng := RandomNumberGenerator.new()


func setup(layout: Dictionary, seed_offset: int = 0) -> void:
	clear_zombies()
	_layout = layout
	_rng.seed = int(layout.get("seed", 0)) * 6803 + 991 + seed_offset


func start(delay: float = 4.0) -> void:
	clear_zombies()
	_next_id = 1
	_wave = 1
	_phase = "break"
	_break_left = delay
	_to_spawn = 0
	_spawn_delay = 0.0
	_escalation = 0
	_active = true


func set_escalation(value: int) -> void:
	_escalation = clampi(value, 0, 3)


func escalation() -> int:
	return _escalation


func stop() -> void:
	_active = false


func clear_zombies() -> void:
	for zombie in _zombies.values():
		if is_instance_valid(zombie):
			zombie.queue_free()
	_zombies.clear()
	_to_spawn = 0


func tick(delta: float, players: Array) -> void:
	if not _active:
		return
	if _phase == "break":
		_break_left -= delta
		if _break_left <= 0.0:
			_begin_wave()
		return
	if _phase == "fight":
		_tick_spawning(delta, players)
		_tick_zombies(delta, players)
		if _to_spawn == 0 and _zombies.is_empty():
			_phase = "break"
			_break_left = maxf(3.5, 6.0 - _escalation * 0.7)
			_wave += 1


func _begin_wave() -> void:
	_phase = "fight"
	var quota := roundi((5 + _wave * 2) * (1.0 + 0.22 * _escalation))
	_to_spawn = mini(34, quota)
	_spawn_delay = 0.2
	_spawn_interval = maxf(0.45, 1.25 - _wave * 0.07)


func _tick_spawning(delta: float, players: Array) -> void:
	var alive_cap := mini(32, int(floor((9 + _wave * 2) * (1.0 + 0.15 * _escalation))))
	if _to_spawn <= 0 or _zombies.size() >= alive_cap:
		return
	_spawn_delay -= delta
	if _spawn_delay > 0.0:
		return
	var pos := _choose_spawn(players)
	var kind := _choose_kind()
	var zombie := ServerZombie.new()
	zombie.zombie_id = _next_id
	zombie.name = "Zombie_%d" % _next_id
	add_child(zombie)
	zombie.global_position = Vector3(pos.x, 0.06, pos.z)
	zombie.setup(_next_id, kind, _wave)
	zombie.attacked_player.connect(_on_zombie_attack)
	_zombies[_next_id] = zombie
	_next_id += 1
	_to_spawn -= 1
	_spawn_delay = _spawn_interval * pow(0.8, _escalation)


func _choose_kind() -> String:
	var roll := _rng.randf()
	if _wave >= 3 and roll < 0.15:
		return "brute"
	if _wave >= 2 and roll < 0.3:
		return "crawler"
	if _wave >= 2 and roll < 0.56:
		return "runner"
	return "walker"


func _choose_spawn(players: Array) -> Vector3:
	var spawns: Array = _layout.get("zombie_spawns", [])
	if spawns.is_empty():
		return Vector3(0.0, 0.06, 0.0)
	var alive_positions: Array[Vector3] = []
	for player in players:
		if bool(player.get("alive", false)):
			alive_positions.append(player["pos"])
	var best := Vector3(spawns[0].x, 0.06, spawns[0].z)
	var best_score := -1e20
	var fallback := best
	var fallback_distance := -1.0
	var start := _rng.randi_range(0, spawns.size() - 1)
	for i in range(spawns.size()):
		var candidate: Vector3 = spawns[(start + i) % spawns.size()]
		var nearest := 9999.0
		for pos in alive_positions:
			nearest = minf(nearest, Vector2(candidate.x - pos.x, candidate.z - pos.z).length())
		if nearest > fallback_distance:
			fallback_distance = nearest
			fallback = Vector3(candidate.x, 0.06, candidate.z)
		if nearest < 22.0:
			continue
		var score := -absf(nearest - 34.0) + _rng.randf_range(0.0, 6.0)
		if score > best_score:
			best_score = score
			best = Vector3(candidate.x, 0.06, candidate.z)
	if best_score < -1e19:
		return fallback
	return best


func _tick_zombies(delta: float, players: Array) -> void:
	for zombie in _zombies.values():
		if not is_instance_valid(zombie):
			continue
		var best_id := -1
		var best_pos := Vector3.ZERO
		var best_distance := 1e20
		for player in players:
			if not bool(player.get("alive", false)):
				continue
			var pos: Vector3 = player["pos"]
			var distance := pos.distance_squared_to(zombie.global_position)
			if distance < best_distance:
				best_distance = distance
				best_pos = pos
				best_id = int(player["id"])
		zombie.step(delta, best_pos, best_id, best_id >= 0)


func _on_zombie_attack(player_id: int, damage: float) -> void:
	attacked_player.emit(player_id, damage)


func damage_zombie(id: int, amount: float) -> Dictionary:
	if not _zombies.has(id):
		return {"ok": false}
	var zombie: ServerZombie = _zombies[id]
	var pos := zombie.global_position
	var kind := zombie.kind
	var killed := zombie.take_damage(amount)
	var remaining := maxf(0.0, zombie.hp)
	if killed:
		_zombies.erase(id)
		zombie.queue_free()
	return {
		"ok": true,
		"killed": killed,
		"kind": kind,
		"pos": pos,
		"remaining": remaining,
	}


func snapshots() -> Array:
	var result: Array = []
	for zombie in _zombies.values():
		if is_instance_valid(zombie):
			result.append(zombie.snapshot())
	return result


func summary() -> Dictionary:
	return {
		"wave": _wave,
		"phase": _phase,
		"remaining": _zombies.size() + _to_spawn,
		"alive": _zombies.size(),
		"to_spawn": _to_spawn,
		"break_left": maxf(0.0, _break_left),
		"active": _active,
		"threat": _escalation,
		"threat_mult": 1.0 + 0.22 * _escalation,
	}


func pick_safe_spawn(candidates: Array, fallback: Vector3) -> Vector3:
	if candidates.is_empty():
		return fallback
	var best := fallback
	var best_distance := -1.0
	for candidate in candidates:
		var nearest := 9999.0
		for zombie in _zombies.values():
			if is_instance_valid(zombie):
				nearest = minf(nearest, Vector2(candidate.x - zombie.global_position.x, candidate.z - zombie.global_position.z).length())
		if nearest > best_distance:
			best_distance = nearest
			best = candidate
	return best


func zombie_count() -> int:
	return _zombies.size()


func is_active() -> bool:
	return _active
