extends SceneTree

const MissionSiteScript = preload("res://scripts/mission_site.gd")
const ServerZombieScript = preload("res://scripts/server_zombie.gd")
const PlayerScript = preload("res://scripts/player.gd")
const ZombieDirectorScript = preload("res://scripts/zombie_director.gd")

var checks := 0
var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	print("== DeadCity mission tests ==")
	_test_site_queries()
	_test_site_visuals()
	_test_zombie_targeting()
	_test_player_reload_and_carry()
	_test_escalation()
	_test_meta_profile()
	print("== %d checks, %d failures ==" % [checks, failures])
	quit(1 if failures > 0 else 0)


func _check(condition: bool, label: String) -> void:
	checks += 1
	if condition:
		print("  [v] ", label)
	else:
		failures += 1
		print("  [x] ", label)
		push_error("FAIL: " + label)


func _test_site_queries() -> void:
	var site = MissionSiteScript.new()
	root.add_child(site)
	_check(MissionSiteScript.SAFE_SPAWNS.size() == 4, "four dedicated safe spawn points")
	var spawn_ok := true
	for i in range(MissionSiteScript.SAFE_SPAWNS.size()):
		if not site.is_in_safe_zone(site.spawn_point(i)):
			spawn_ok = false
	_check(spawn_ok, "all spawn points sit inside the safe zone")
	_check(site.is_in_safe_zone(MissionSiteScript.BASE_CENTER + Vector3(0.0, 0.0, 6.9)), "safe zone reaches its 7m radius")
	_check(not site.is_in_safe_zone(MissionSiteScript.BASE_CENTER + Vector3(0.0, 0.0, 7.4)), "safe zone rejects targets outside 7m")
	_check(not site.is_in_safe_zone(Vector3(0.0, -14.0, -98.0)), "basement is not treated as surface safe zone")
	_check(site.is_in_basement(site.BASEMENT_ARRIVAL), "basement arrival counts as vault interior")
	_check(not site.is_in_basement(Vector3(0.0, 0.2, 0.0)), "surface street is not basement")
	_check(not site.is_zombie_target(site.spawn_point(0)), "zombies ignore players in the safe zone")
	_check(not site.is_zombie_target(site.BASEMENT_ARRIVAL), "zombies ignore players in the vault")
	_check(site.is_zombie_target(Vector3(14.0, 0.06, 8.0)), "zombies still chase players in the streets")
	_check(site.core_distance(site.CORE_SITES[1] + Vector3(1.2, 0.0, 0.0), 1) < 1.5, "core distance resolves on the flat plane")
	_check(site.fountain_distance(site.FOUNTAIN_POINT + Vector3(0.0, 0.0, 2.5)) < 2.6, "gateway proximity measured from the fountain")
	_check(site.exit_distance(site.BASEMENT_EXIT) < 0.1, "basement exit distance resolves")
	_check(site.console_distance(site.CONSOLE_POINT) < 0.1, "delivery console distance resolves")
	_check(site.ammo_distance(MissionSiteScript.AMMO_POINT) < 0.1, "ammo station distance resolves")
	_check(site.is_in_safe_zone(MissionSiteScript.AMMO_POINT), "ammo station sits inside the safe zone")
	var core_y_ok := true
	for core_pos in site.CORE_SITES:
		if not site.is_in_basement(core_pos):
			core_y_ok = false
	_check(core_y_ok, "all three cores are stashed inside the basement")
	site.free()


func _test_site_visuals() -> void:
	var site = MissionSiteScript.new()
	root.add_child(site)
	site.build()
	_check(site.get_node_or_null("SafeZone") != null, "base builds a SafeZone group")
	_check(site.get_node_or_null("SafeZone/AmmoStation") != null, "base builds the ammo resupply table")
	_check(site.get_node_or_null("FountainGateway") != null, "gateway builds at the fountain")
	_check(site.get_node_or_null("CoreVault") != null, "basement vault is built")
	var core_nodes: Array = site.get("_core_nodes")
	var secured_nodes: Array = site.get("_secured_nodes")
	_check(core_nodes.size() == MissionSiteScript.CORE_COUNT, "vault contains three core orbs")
	_check(secured_nodes.size() == MissionSiteScript.CORE_COUNT, "console tracks three secured indicators")
	var initial_visible := true
	for orb in core_nodes:
		if not orb.visible:
			initial_visible = false
	_check(initial_visible, "cores start visible on their pedestals")
	site.set_core_state(1, "carried", Vector3.ZERO)
	_check(not core_nodes[1].visible, "carried core disappears from its pedestal")
	site.set_core_state(1, "dropped", Vector3(-2.0, -14.0, 2.0))
	_check(core_nodes[1].visible, "dropped core reappears in the world")
	_check(absf(float(site.get("_core_anchors")[1].y) - (-13.05)) < 0.01, "dropped core hovers above the vault floor")
	site.set_secured_count(2)
	var secured_visible := 0
	for orb in secured_nodes:
		if orb.visible:
			secured_visible += 1
	_check(secured_visible == 2, "secure indicators match the delivered count")
	site.reset_visuals()
	var restored := 0
	for i in range(core_nodes.size()):
		if core_nodes[i].visible:
			restored += 1
	_check(restored == 3, "reset restores all core orbs")
	site.free()


func _test_zombie_targeting() -> void:
	var zombie = ServerZombieScript.new()
	root.add_child(zombie)
	zombie.setup(9, "crawler", 3)
	_check(zombie.kind == "crawler", "crawler kind assigned")
	_check(zombie.max_hp < 60.0, "crawler is fragile")
	_check(zombie.speed > 5.4, "crawler is faster than a walker")
	zombie.step(0.12, Vector3(4.0, 0.06, 4.0), 1, false)
	_check(zombie.velocity.length() < 0.001, "zombie stops steering without a target")
	_check(int(zombie.state) == 0, "zombie returns to idle without a target")
	var hits: Array = []
	zombie.attacked_player.connect(func(player_id: int, damage: float) -> void:
		hits.append([player_id, damage])
	)
	zombie.step(0.12, Vector3(0.0, 0.06, 0.8), 7, true)
	_check(hits.size() == 1 and int(hits[0][0]) == 7, "zombie attacks an exposed target")
	_check(float(hits[0][1]) > 0.0, "attack carries damage")
	zombie.step(0.12, Vector3(0.0, 0.06, 0.8), 7, true)
	_check(hits.size() == 1, "attack interval gates repeated hits")
	zombie.free()


func _test_player_reload_and_carry() -> void:
	var player = PlayerScript.new()
	root.add_child(player)
	player.mag = 5
	player.start_reload()
	_check(player.reloading, "empty magazine starts a reload")
	player.set("_reload_left", player.reload_time * 0.5)
	_check(absf(player.reload_progress() - 0.5) < 0.02, "reload progress drives the viewmodel animation")
	player._finish_reload()
	_check(player.mag == player.mag_size and player.reserve == 65, "reload refills the magazine from reserve")
	player.mag = 5
	player.set_carrying(true)
	_check(player.carrying_core and not player.reloading, "picking up a core cancels the reload")
	player.start_reload()
	_check(not player.reloading, "carrying a core blocks reloading")
	player.set_carrying(false)
	player.start_reload()
	_check(player.reloading, "dropping the core restores reloading")
	player.apply_team_upgrades({"mag": 2, "reload": 2, "speed": 2, "armor": 2})
	_check(player.mag_size == 42, "magazine upgrade widens the mag")
	_check(player.reload_time < 1.2, "reload upgrade shortens reload time")
	_check(player.walk_speed > PlayerScript.WALK_SPEED, "speed upgrade raises movement speed")
	_check(absf(player.damage_reduction - 0.16) < 0.001, "armor upgrade adds damage reduction")
	player.face_yaw(3.5)
	_check(absf(player.rotation.y - wrapf(3.5, -PI, PI)) < 0.001, "face_yaw normalizes large angles")
	player.teleport_to(MissionSiteScript.BASEMENT_ARRIVAL)
	_check(player.global_position.y < -13.0, "teleport preserves basement depth")
	_check(PlayerScript.GRAVITY > 15.0 and PlayerScript.JUMP_VELOCITY > 6.0, "jump uses a snappy impulse and gravity")
	_check(PlayerScript.COYOTE_TIME > 0.0 and PlayerScript.JUMP_BUFFER > 0.0, "jump keeps coyote time and input buffering")
	player.set_meta_bonus(8, 0.9)
	_check(player.reserve >= 98, "legacy bonus raises starting reserve")
	player.mag = 0
	player.reserve = 0
	player.refill_ammo()
	_check(player.mag == player.mag_size and player.reserve == PlayerScript.MAX_RESERVE, "ammo station refills the magazine and reserve")
	player.apply_team_upgrades({"reload": 2})
	_check(absf(player.reload_time - maxf(0.55, PlayerScript.RELOAD_TIME * 0.76 * 0.9)) < 0.001, "legacy reload bonus stacks with team upgrades")
	player.free()


func _test_escalation() -> void:
	var director = ZombieDirectorScript.new()
	root.add_child(director)
	director.setup({"seed": 7, "zombie_spawns": [Vector3(20.0, 0.0, 20.0), Vector3(-20.0, 0.0, 20.0)]}, 0)
	director.start(0.0)
	director.tick(0.1, [])
	var base_quota := int(director.get("_to_spawn"))
	director.start(0.0)
	director.set_escalation(3)
	director.tick(0.1, [])
	var threat_quota := int(director.get("_to_spawn"))
	_check(threat_quota > base_quota, "threat escalation multiplies the spawn quota")
	var summary: Dictionary = director.summary()
	_check(int(summary.get("threat", 0)) == 3, "summary reports the current threat")
	_check(absf(float(summary.get("threat_mult", 0.0)) - 1.66) < 0.001, "summary reports the quota multiplier")
	director.tick(0.3, [])
	_check(director.zombie_count() == 1, "escalated director still spawns zombies")
	var escalated_delay := float(director.get("_spawn_interval")) * pow(0.8, 3)
	_check(absf(float(director.get("_spawn_delay")) - escalated_delay) < 0.001, "threat shortens the spawn interval")
	director.free()


func _test_meta_profile() -> void:
	var profile: Dictionary = MetaProfile.empty_profile()
	_check(MetaProfile.power_of({"mag": 1, "reload": 1, "damage": 1, "speed": 1, "armor": 1}) == 46, "power weights all five upgrade tracks")
	MetaProfile.start_run(profile, 4321, ["ALPHA", "BRAVO"])
	var current: Dictionary = profile.get("current_run", {})
	_check(int(current.get("seed", 0)) == 4321, "starting a run records the seed")
	_check(int(current.get("power", -1)) == 0, "starting a run resets power")
	MetaProfile.sync_run(profile, {"mag": 2, "damage": 1}, 2, 780, 14, 3, ["ALPHA", "BRAVO"])
	current = profile.get("current_run", {})
	_check(int(current.get("power", 0)) == 28, "run sync stores the current power")
	_check(int(profile.get("total_cores", 0)) == 2, "secured cores enter the lifetime archive")
	MetaProfile.sync_run(profile, {"mag": 2, "damage": 1}, 2, 780, 14, 3, ["ALPHA", "BRAVO"])
	_check(int(profile.get("total_cores", 0)) == 2, "repeated syncs do not double count cores")
	MetaProfile.finish_run(profile, true, "done")
	_check(int(profile.get("runs", 0)) == 1 and int(profile.get("victories", 0)) == 1, "finishing a run updates lifetime stats")
	_check(bool(profile.get("last_run", {}).get("victory", false)), "victory is archived in the last run")
	_check(profile.get("current_run", {}).is_empty(), "finishing clears the active run")
	_check(MetaProfile.legacy_level(profile) == 0, "legacy level starts from lifetime cores")
	profile["total_cores"] = 30
	_check(MetaProfile.legacy_level(profile) == 10, "legacy level grows every three lifetime cores")
	var bonus: Dictionary = MetaProfile.legacy_bonus(profile)
	_check(int(bonus.get("reserve", 0)) == 20 and float(bonus.get("reload_mult", 1.0)) < 1.0, "legacy grants reserve and reload bonuses")
	var path := "user://deadcity_test_profile.json"
	_check(MetaProfile.save_profile(profile, path), "meta profile saves to disk")
	var loaded: Dictionary = MetaProfile.load_profile(path)
	_check(int(loaded.get("runs", 0)) == 1 and bool(loaded.get("last_run", {}).get("victory", false)), "meta profile round-trips through JSON")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
