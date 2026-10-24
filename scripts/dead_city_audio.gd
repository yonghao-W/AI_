class_name DeadCityAudio
extends Node

const RATE := 22050

const GUN_PROFILES := {
	"pistol": {"dur": 0.22, "decay": 24.0, "thump": 168.0, "thump_decay": 17.0, "noise": 0.52, "gain": 0.82},
	"smg": {"dur": 0.16, "decay": 30.0, "thump": 138.0, "thump_decay": 22.0, "noise": 0.58, "gain": 0.72},
	"rifle": {"dur": 0.26, "decay": 20.0, "thump": 112.0, "thump_decay": 14.0, "noise": 0.6, "gain": 0.9},
	"shotgun": {"dur": 0.55, "decay": 9.0, "thump": 72.0, "thump_decay": 7.5, "noise": 0.72, "gain": 0.95},
	"lmg": {"dur": 0.2, "decay": 22.0, "thump": 96.0, "thump_decay": 13.0, "noise": 0.66, "gain": 0.86},
}

var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _players_3d: Array[AudioStreamPlayer3D] = []
var _next_2d := 0
var _next_3d := 0
var _zombie_cooldown: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_build_streams()
	_build_pools()


func _build_pools() -> void:
	for i in range(10):
		var voice := AudioStreamPlayer.new()
		voice.bus = "Master"
		voice.volume_db = 0.0
		add_child(voice)
		_players.append(voice)
	for i in range(8):
		var voice := AudioStreamPlayer3D.new()
		voice.bus = "Master"
		voice.unit_size = 18.0
		voice.max_distance = 95.0
		voice.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		add_child(voice)
		_players_3d.append(voice)


func _build_streams() -> void:
	for id in WeaponCatalog.ordered_ids():
		_streams["shot_" + String(id)] = _gun_stream(String(id))
	for kind in ["switch", "empty", "reload", "reload_done", "supply", "core", "frenzy"]:
		_streams["ui_" + kind] = _ui_stream(kind)
	for kind in ["growl", "attack", "death"]:
		_streams["z_" + kind] = _zombie_stream(kind)


func play_weapon_shot(weapon_id: String, aiming: bool = false) -> void:
	var key := "shot_" + weapon_id
	if not _streams.has(key):
		key = "shot_smg"
	var volume := -6.0 if aiming else -3.0
	_play_2d(key, volume, randf_range(0.965, 1.035))


func play_ui(kind: String, volume: float = 0.0, pitch: float = 1.0) -> void:
	var key := "ui_" + kind
	if _streams.has(key):
		_play_2d(key, volume, pitch)


func play_zombie(kind: String, world_pos: Vector3) -> void:
	var key := "z_" + kind
	if not _streams.has(key):
		return
	var now := Time.get_ticks_msec() * 0.001
	if kind != "death":
		var last := float(_zombie_cooldown.get(kind, -10.0))
		if now - last < 0.16:
			return
		_zombie_cooldown[kind] = now
	var volume := -13.0
	if kind == "attack":
		volume = -8.0
	elif kind == "death":
		volume = -5.0
	_play_3d(key, world_pos, volume, randf_range(0.88, 1.12))


func _play_2d(key: String, volume: float, pitch: float) -> void:
	if _players.is_empty():
		return
	var voice := _players[_next_2d]
	_next_2d = (_next_2d + 1) % _players.size()
	voice.stream = _streams.get(key, null)
	voice.volume_db = volume
	voice.pitch_scale = maxf(0.05, pitch)
	voice.play()


func _play_3d(key: String, world_pos: Vector3, volume: float, pitch: float) -> void:
	if _players_3d.is_empty():
		return
	var voice := _players_3d[_next_3d]
	_next_3d = (_next_3d + 1) % _players_3d.size()
	voice.global_position = world_pos
	voice.stream = _streams.get(key, null)
	voice.volume_db = volume
	voice.pitch_scale = maxf(0.05, pitch)
	voice.play()


func _gun_stream(id: String) -> AudioStreamWAV:
	var profile: Dictionary = GUN_PROFILES.get(id, GUN_PROFILES["smg"])
	var duration := float(profile["dur"])
	var count := int(RATE * duration)
	var samples := PackedFloat32Array()
	samples.resize(count)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(id)
	var smoothed := 0.0
	for i in range(count):
		var t := float(i) / float(RATE)
		var attack := clampf(t / 0.0015, 0.0, 1.0)
		var env := exp(-t * float(profile["decay"]))
		smoothed = smoothed * 0.55 + rng.randf_range(-1.0, 1.0) * 0.45
		var crack := smoothed * float(profile["noise"]) * env
		var thump := sin(TAU * float(profile["thump"]) * t * (1.0 + t * 0.7)) * exp(-t * float(profile["thump_decay"]))
		var click := 0.0
		if t < 0.007:
			click = rng.randf_range(-1.0, 1.0) * (1.0 - t / 0.007)
		samples[i] = clampf((crack + thump * 0.9 + click * 0.32) * attack * float(profile["gain"]), -1.0, 1.0)
	return _to_wav(samples)


func _ui_stream(kind: String) -> AudioStreamWAV:
	match kind:
		"switch":
			return _sweep(0.075, 950.0, 1440.0, 34.0, 0.25, 0.55)
		"empty":
			return _sweep(0.1, 210.0, 160.0, 26.0, 0.5, 0.7)
		"reload":
			return _sweep(0.22, 520.0, 330.0, 15.0, 0.42, 0.6)
		"reload_done":
			return _sweep(0.14, 760.0, 1180.0, 20.0, 0.2, 0.55)
		"supply":
			return _bell(0.42, [660.0, 990.0, 1320.0], 9.0, 0.5)
		"core":
			return _bell(0.62, [440.0, 660.0, 880.0, 1100.0], 7.0, 0.55)
		"frenzy":
			return _sweep(0.95, 150.0, 52.0, 2.6, 0.55, 0.85)
	return _sweep(0.08, 800.0, 800.0, 30.0, 0.2, 0.5)


func _zombie_stream(kind: String) -> AudioStreamWAV:
	match kind:
		"growl":
			return _growl(0.55, 76.0, 64.0, 4.2, 0.05, 0.5)
		"attack":
			return _growl(0.34, 128.0, 74.0, 7.0, 0.55, 0.62)
		"death":
			return _growl(0.95, 158.0, 48.0, 3.2, 0.7, 0.6)
	return _growl(0.4, 90.0, 70.0, 5.0, 0.2, 0.5)


func _growl(duration: float, start_freq: float, end_freq: float, decay: float, rasp: float, gain: float) -> AudioStreamWAV:
	var count := int(RATE * duration)
	var samples := PackedFloat32Array()
	samples.resize(count)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s_%s" % [start_freq, end_freq])
	var phase := 0.0
	var noise := 0.0
	for i in range(count):
		var t := float(i) / float(RATE)
		var ratio := clampf(t / duration, 0.0, 1.0)
		var freq := lerpf(start_freq, end_freq, ratio)
		freq *= 1.0 + sin(t * 23.0) * 0.06
		phase += TAU * freq / float(RATE)
		var body := sin(phase) + 0.45 * sin(phase * 2.0) + 0.22 * sin(phase * 3.0)
		noise = noise * 0.7 + rng.randf_range(-1.0, 1.0) * 0.3
		var env := clampf(t / 0.03, 0.0, 1.0) * exp(-t * decay)
		samples[i] = clampf((body * 0.55 + noise * rasp) * env * gain, -1.0, 1.0)
	return _to_wav(samples)


func _sweep(duration: float, start_freq: float, end_freq: float, decay: float, noise_amount: float, gain: float) -> AudioStreamWAV:
	var count := int(RATE * duration)
	var samples := PackedFloat32Array()
	samples.resize(count)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s_%s" % [start_freq, end_freq])
	var phase := 0.0
	for i in range(count):
		var t := float(i) / float(RATE)
		var ratio := clampf(t / duration, 0.0, 1.0)
		var freq := lerpf(start_freq, end_freq, ratio)
		phase += TAU * freq / float(RATE)
		var env := clampf(t / 0.002, 0.0, 1.0) * exp(-t * decay)
		var sample := sin(phase) * 0.8
		sample += rng.randf_range(-1.0, 1.0) * noise_amount * 0.35
		samples[i] = clampf(sample * env * gain, -1.0, 1.0)
	return _to_wav(samples)


func _bell(duration: float, partials: Array, decay: float, gain: float) -> AudioStreamWAV:
	var count := int(RATE * duration)
	var samples := PackedFloat32Array()
	samples.resize(count)
	var phases := PackedFloat32Array()
	phases.resize(partials.size())
	for i in range(count):
		var t := float(i) / float(RATE)
		var env := clampf(t / 0.004, 0.0, 1.0) * exp(-t * decay)
		var sample := 0.0
		for p in range(partials.size()):
			var freq := float(partials[p])
			phases[p] += TAU * freq / float(RATE)
			sample += sin(phases[p]) / float(p + 1)
		samples[i] = clampf(sample * env * gain, -1.0, 1.0)
	return _to_wav(samples)


func _to_wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in range(samples.size()):
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = bytes
	return wav
