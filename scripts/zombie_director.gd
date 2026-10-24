class_name ZombieDirector
extends Node3D

signal attacked_player(player_id: int, damage: float)
signal fused(pos: Vector3, mass: int)

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
var _frenzy := false
var _fusion_timer := 5.0
var _basement_active := false
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
	_frenzy = false
	_fusion_timer = 5.0
	_basement_active = false
	_active = true


func set_escalation(value: int) -> void:
	_escalation = clampi(value, 0, 3)


func escalation() -> int:
	return _escalation


func set_frenzy(value: bool) -> void:
	if _frenzy == value:
		return
	_frenzy = value
	for zombie in _zombies.values():
		if is_instance_valid(zombie):
			zombie.set_frenzy(value)
	if value:
		_spawn_delay = minf(_spawn_delay, 0.1)
		_to_spawn += 14 + _escalation * 3


func is_frenzy() -> bool:
	return _frenzy


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
		_update_basement(players)
		_tick_spawning(delta, players)
		_tick_zombies(delta, players)
		_tick_fusion(delta)
		if _to_spawn == 0 and _zombies.is_empty():
			_phase = "break"
			_break_left = maxf(3.5, 6.0 - _escalation * 0.7)
			_wave += 1


func _begin_wave() -> void:
	_phase = "fight"
	var quota := roundi((10 + _wave * 4) * (1.0 + 0.34 * _escalation))
	if _frenzy:
		quota = roundi(quota * 1.4)
	_to_spawn = mini(80, quota)
	_spawn_delay = 0.15
	_spawn_interval = maxf(0.16, 0.62 - _wave * 0.04)


func _tick_spawning(delta: float, players: Array) -> void:
	var alive_cap := int(floor((16 + _wave * 4) * (1.0 + 0.28 * _escalation))) + 12
	if _frenzy:
		alive_cap += 14
	alive_cap = mini(64, alive_cap)
	if _to_spawn <= 0 or _zombies.size() >= alive_cap:
		return
	_spawn_delay -= delta
	if _spawn_delay > 0.0:
		return
	var burst := 3 if _frenzy else 2
	for i in range(burst):
		if _to_spawn <= 0 or _zombies.size() >= alive_cap:
			break
		_spawn_one(players)
	_spawn_delay = _spawn_interval * pow(0.8, _escalation)
	if _frenzy:
		_spawn_delay *= 0.55
	elif _wave >= 4:
		_spawn_delay *= 0.9


func _spawn_one(players: Array) -> void:
	var pos := _choose_spawn(players)
	var kind := _choose_kind()
	var zombie := ServerZombie.new()
	zombie.zombie_id = _next_id
	zombie.name = "Zombie_%d" % _next_id
	add_child(zombie)
	zombie.global_position = Vector3(pos.x, pos.y, pos.z)
	zombie.setup(_next_id, kind, _wave)
	zombie.floor_y = pos.y
	zombie.apply_ability(_choose_ability(kind))
	zombie.set_frenzy(_frenzy)
	zombie.attacked_player.connect(_on_zombie_attack)
	_zombies[_next_id] = zombie
	_next_id += 1
	_to_spawn -= 1


func _choose_kind() -> String:
	var roll := _rng.randf()
	var brute_chance := 0.14 if _wave >= 3 else (0.08 if _wave >= 2 else 0.0)
	if _frenzy:
		brute_chance += 0.06
	if roll < brute_chance:
		return "brute"
	roll = _rng.randf()
	if roll < 0.3:
		return "crawler"
	if roll < 0.58:
		return "runner"
	if _frenzy and roll < 0.72:
		return "crawler"
	return "walker"


func _choose_ability(kind_id: String) -> String:
	var climb := 0.1 if _wave >= 2 else 0.0
	var armor := 0.1 if _wave >= 3 else 0.0
	var volatile := 0.09 if _wave >= 4 else 0.0
	if _frenzy:
		climb += 0.04
		armor += 0.04
		volatile += 0.05
	if kind_id == "crawler":
		climb += 0.06
	var roll := _rng.randf()
	if roll < climb:
		return "climber"
	if roll < climb + armor:
		return "armored"
	if roll < climb + armor + volatile:
		return "volatile"
	return "none"


func _choose_spawn(players: Array) -> Vector3:
	var surface_spawns: Array = _layout.get("zombie_spawns", [])
	var basement_spawns: Array = _layout.get("basement_spawns", [])
	var spawns: Array = surface_spawns
	if _basement_active and not basement_spawns.is_empty():
		spawns = basement_spawns
	if spawns.is_empty():
		return Vector3(0.0, 0.06, 0.0)
	var alive_positions: Array[Vector3] = []
	for player in players:
		if bool(player.get("alive", false)):
			alive_positions.append(player["pos"])
	var best: Vector3 = spawns[0]
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
			fallback = candidate
		if nearest < 22.0:
			continue
		var score := -absf(nearest - 34.0) + _rng.randf_range(0.0, 6.0)
		if score > best_score:
			best_score = score
			best = candidate
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


func _update_basement(players: Array) -> void:
	var wants := false
	for player in players:
		if bool(player.get("alive", false)) and (player["pos"] as Vector3).y < -9.0:
			wants = true
			break
	if wants == _basement_active:
		return
	_basement_active = wants
	if wants:
		return
	var spawns: Array = _layout.get("zombie_spawns", [])
	for zombie in _zombies.values():
		if not is_instance_valid(zombie) or zombie.floor_y > -9.0:
			continue
		zombie.floor_y = 0.06
		var spot: Vector3 = spawns[_rng.randi_range(0, maxi(0, spawns.size() - 1))] if not spawns.is_empty() else Vector3(0.0, 0.06, -20.0)
		zombie.global_position = Vector3(spot.x, 0.06, spot.z)


func _tick_fusion(delta: float) -> void:
	if _wave < 2 and not _frenzy:
		return
	_fusion_timer -= delta
	if _fusion_timer > 0.0:
		return
	_fusion_timer = maxf(2.2, 5.4 - _wave * 0.3) * (0.6 if _frenzy else 1.0)
	_try_fusion()


func _try_fusion() -> void:
	var list: Array = []
	for zombie in _zombies.values():
		if is_instance_valid(zombie) and zombie.mass < 3:
			list.append(zombie)
	for i in range(list.size()):
		var host: ServerZombie = list[i]
		if not is_instance_valid(host):
			continue
		for j in range(i + 1, list.size()):
			var prey: ServerZombie = list[j]
			if not is_instance_valid(prey) or not is_instance_valid(host):
				continue
			if host.mass + prey.mass > 3:
				continue
			if absf(host.global_position.y - prey.global_position.y) > 2.5:
				continue
			if host.global_position.distance_to(prey.global_position) > 6.5:
				continue
			host.fuse_with(prey)
			_zombies.erase(prey.zombie_id)
			prey.queue_free()
			fused.emit(host.global_position, host.mass)
			return


func damage_zombie(id: int, amount: float) -> Dictionary:
	if not _zombies.has(id):
		return {"ok": false}
	var zombie: ServerZombie = _zombies[id]
	var pos := zombie.global_position
	var kind := zombie.kind
	var ability := zombie.ability
	var mass := zombie.mass
	var killed := zombie.take_damage(amount)
	var remaining := maxf(0.0, zombie.hp)
	if killed:
		_zombies.erase(id)
		zombie.queue_free()
	return {
		"ok": true,
		"killed": killed,
		"kind": kind,
		"ability": ability,
		"mass": mass,
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
		"frenzy": _frenzy,
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


func zombie_position(id: int) -> Vector3:
	if _zombies.has(id) and is_instance_valid(_zombies[id]):
		return _zombies[id].global_position
	return Vector3(1.0e9, 1.0e9, 1.0e9)


func is_active() -> bool:
	return _active
