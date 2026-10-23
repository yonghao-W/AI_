class_name MetaProfile
extends RefCounted

const SAVE_VERSION := 1
const SAVE_PATH := "user://deadcity_profile.json"
const HISTORY_LIMIT := 6
const CORES_PER_LEGACY := 3
const LEGACY_MAX := 20
const UPGRADE_KEYS := ["mag", "reload", "damage", "speed", "armor"]


static func empty_profile() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"runs": 0,
		"victories": 0,
		"best_score": 0,
		"best_cores": 0,
		"best_power": 0,
		"total_cores": 0,
		"total_kills": 0,
		"last_run": {},
		"current_run": {},
		"history": [],
	}


static func load_profile(path: String = SAVE_PATH) -> Dictionary:
	var profile := empty_profile()
	if not FileAccess.file_exists(path):
		return profile
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return profile
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return profile
	var data: Dictionary = parsed
	profile["version"] = SAVE_VERSION
	for key in ["runs", "victories", "best_score", "best_cores", "best_power", "total_cores", "total_kills"]:
		profile[key] = maxi(0, int(data.get(key, 0)))
	if data.get("last_run") is Dictionary:
		profile["last_run"] = _sanitize_run(data["last_run"])
	if data.get("current_run") is Dictionary:
		profile["current_run"] = _sanitize_run(data["current_run"])
	if data.get("history") is Array:
		var history: Array = []
		for raw in data["history"]:
			if raw is Dictionary:
				history.append(_sanitize_run(raw))
				if history.size() >= HISTORY_LIMIT:
					break
		profile["history"] = history
	return profile


static func save_profile(profile: Dictionary, path: String = SAVE_PATH) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(profile, "\t"))
	file.close()
	return true


static func _sanitize_run(raw: Dictionary) -> Dictionary:
	var upgrades: Dictionary = {}
	var raw_upgrades: Dictionary = raw.get("upgrades", {})
	for key in UPGRADE_KEYS:
		upgrades[key] = clampi(int(raw_upgrades.get(key, 0)), 0, 3)
	var player_list: Array = []
	if raw.get("players") is Array:
		player_list = raw["players"].duplicate()
	return {
		"seed": int(raw.get("seed", 0)),
		"started_at": String(raw.get("started_at", "")),
		"ended_at": String(raw.get("ended_at", "")),
		"upgrades": upgrades,
		"power": maxi(0, int(raw.get("power", power_of(upgrades)))),
		"cores": maxi(0, int(raw.get("cores", 0))),
		"secured": maxi(0, int(raw.get("secured", raw.get("cores", 0)))),
		"score": maxi(0, int(raw.get("score", 0))),
		"kills": maxi(0, int(raw.get("kills", 0))),
		"wave": maxi(1, int(raw.get("wave", 1))),
		"players": player_list,
		"victory": bool(raw.get("victory", false)),
		"abandoned": bool(raw.get("abandoned", false)),
	}


static func power_of(upgrades: Dictionary) -> int:
	return 8 * int(upgrades.get("mag", 0)) \
		+ 8 * int(upgrades.get("reload", 0)) \
		+ 12 * int(upgrades.get("damage", 0)) \
		+ 8 * int(upgrades.get("speed", 0)) \
		+ 10 * int(upgrades.get("armor", 0))


static func start_run(profile: Dictionary, seed_value: int, player_names: Array) -> void:
	var previous: Dictionary = profile.get("current_run", {})
	if not previous.is_empty():
		_archive(profile, _finish_snapshot(previous, false, true))
	profile["current_run"] = {
		"seed": seed_value,
		"started_at": Time.get_datetime_string_from_system(false, true),
		"ended_at": "",
		"upgrades": {"mag": 0, "reload": 0, "damage": 0, "speed": 0, "armor": 0},
		"power": 0,
		"cores": 0,
		"secured": 0,
		"score": 0,
		"kills": 0,
		"wave": 1,
		"players": player_names.duplicate(),
		"victory": false,
		"abandoned": false,
	}


static func sync_run(profile: Dictionary, upgrades: Dictionary, cores: int, score: int, kills: int, wave: int, player_names: Array) -> void:
	if not (profile.get("current_run") is Dictionary):
		return
	if profile["current_run"].is_empty():
		return
	var run: Dictionary = profile["current_run"]
	var previous_cores := int(run.get("secured", 0))
	var clean := {}
	for key in UPGRADE_KEYS:
		clean[key] = clampi(int(upgrades.get(key, 0)), 0, 3)
	run["upgrades"] = clean
	run["power"] = power_of(clean)
	run["cores"] = mini(3, maxi(0, cores))
	run["secured"] = maxi(previous_cores, mini(3, maxi(0, cores)))
	run["score"] = maxi(0, score)
	run["kills"] = maxi(0, kills)
	run["wave"] = maxi(1, wave)
	run["players"] = player_names.duplicate()
	if int(run["secured"]) > previous_cores:
		profile["total_cores"] = int(profile.get("total_cores", 0)) + int(run["secured"]) - previous_cores
	profile["best_power"] = maxi(int(profile.get("best_power", 0)), int(run["power"]))
	profile["best_score"] = maxi(int(profile.get("best_score", 0)), int(run["score"]))
	profile["best_cores"] = maxi(int(profile.get("best_cores", 0)), int(run["secured"]))


static func finish_run(profile: Dictionary, victory: bool, stats_text: String = "") -> Dictionary:
	var run: Dictionary = profile.get("current_run", {})
	if run.is_empty():
		return {}
	var finished := _finish_snapshot(run, victory, false)
	finished["stats"] = stats_text
	profile["last_run"] = finished.duplicate(true)
	profile["runs"] = int(profile.get("runs", 0)) + 1
	if victory:
		profile["victories"] = int(profile.get("victories", 0)) + 1
	profile["total_kills"] = int(profile.get("total_kills", 0)) + int(finished.get("kills", 0))
	_archive(profile, finished)
	profile["current_run"] = {}
	return finished


static func abandon_run(profile: Dictionary) -> void:
	var run: Dictionary = profile.get("current_run", {})
	if run.is_empty():
		return
	_archive(profile, _finish_snapshot(run, false, true))
	profile["current_run"] = {}


static func _finish_snapshot(run: Dictionary, victory: bool, abandoned: bool) -> Dictionary:
	var copy := _sanitize_run(run)
	copy["victory"] = victory
	copy["abandoned"] = abandoned
	copy["ended_at"] = Time.get_datetime_string_from_system(false, true)
	return copy


static func _archive(profile: Dictionary, run: Dictionary) -> void:
	var history: Array = profile.get("history", [])
	history.push_front(run.duplicate(true))
	while history.size() > HISTORY_LIMIT:
		history.pop_back()
	profile["history"] = history


static func legacy_level(profile: Dictionary) -> int:
	return clampi(int(profile.get("total_cores", 0)) / CORES_PER_LEGACY, 0, LEGACY_MAX)


static func legacy_bonus(profile: Dictionary) -> Dictionary:
	var level := legacy_level(profile)
	return {
		"level": level,
		"reserve": level * 2,
		"reload_mult": 1.0 - 0.005 * level,
	}


static func archive_line(profile: Dictionary) -> String:
	var level := legacy_level(profile)
	return "局外档案 · 行动 %d 次 · 完成 %d 次 · 最佳战力 %d · 血脉 Lv.%d" % [
		int(profile.get("runs", 0)),
		int(profile.get("victories", 0)),
		int(profile.get("best_power", 0)),
		level,
	]


static func last_run_line(profile: Dictionary) -> String:
	var last: Dictionary = profile.get("last_run", {})
	if last.is_empty():
		return "尚无局外行动记录 · 每次回收核心都会写入档案"
	var result := "撤离成功" if bool(last.get("victory", false)) else ("行动中断" if bool(last.get("abandoned", false)) else "行动失败")
	return "上次行动 · %s · 核心 %d/3 · 战力 %d · 得分 %d · 第 %d 波" % [
		result,
		int(last.get("secured", last.get("cores", 0))),
		int(last.get("power", 0)),
		int(last.get("score", 0)),
		int(last.get("wave", 1)),
	]
