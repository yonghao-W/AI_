extends SceneTree

const MissionSiteScript = preload("res://scripts/mission_site.gd")
const ServerZombieScript = preload("res://scripts/server_zombie.gd")
const PlayerScript = preload("res://scripts/player.gd")
const ZombieDirectorScript = preload("res://scripts/zombie_director.gd")
const CityLayoutScript = preload("res://scripts/city_layout.gd")
const CityBuilderScript = preload("res://scripts/city_builder.gd")
const HudScript = preload("res://scripts/game_hud.gd")
const AudioScript = preload("res://scripts/dead_city_audio.gd")

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
	_test_zombie_abilities()
	_test_player_reload_and_carry()
	_test_weapon_system()
	_test_hud_overlays()
	_test_audio()
	_test_escalation()
	_test_basement_spawning()
	_test_map_variety()
	_test_meta_profile()
	_test_weapon_economy()
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
	_check(site.fountain_distance(site.FOUNTAIN_POINT + Vector3(0.0, 0.0, 2.5)) < 2.6, "entrance plaza proximity measured from the park")
	_check(site.exit_distance(site.BASEMENT_EXIT) < 0.1, "basement exit distance resolves")
	_check(site.console_distance(site.CONSOLE_POINT) < 0.1, "delivery console distance resolves")
	_check(site.ammo_distance(MissionSiteScript.AMMO_POINT) < 0.1, "ammo station distance resolves")
	_check(site.is_in_safe_zone(MissionSiteScript.AMMO_POINT), "ammo station sits inside the safe zone")
	var core_y_ok := true
	for core_pos in site.CORE_SITES:
		if not site.is_in_basement(core_pos):
			core_y_ok = false
	_check(core_y_ok, "all three cores are stashed inside the basement")
	var ramp_drop: float = MissionSiteScript.RAMP_TOP.y - MissionSiteScript.RAMP_BOTTOM.y
	var ramp_length: float = MissionSiteScript.RAMP_TOP.distance_to(MissionSiteScript.RAMP_BOTTOM)
	_check(MissionSiteScript.RAMP_TOP.z > MissionSiteScript.RAMP_BOTTOM.z, "ramp runs from the park down toward the vault")
	_check(ramp_drop > 13.0, "ramp drops a full storey without teleporting")
	_check(absf(sin(MissionSiteScript.RAMP_ANGLE) - ramp_drop / ramp_length) < 0.01, "ramp angle matches its run and rise")
	var vault_spawns: Array = site.basement_spawn_points()
	var vault_spawn_ok := vault_spawns.size() == 8
	for point in vault_spawns:
		if not site.is_in_basement(point):
			vault_spawn_ok = false
	_check(vault_spawn_ok, "vault spawn points sit on the basement floor")
	site.free()


func _test_site_visuals() -> void:
	var site = MissionSiteScript.new()
	root.add_child(site)
	site.build()
	_check(site.get_node_or_null("SafeZone") != null, "base builds a SafeZone group")
	_check(site.get_node_or_null("SafeZone/AmmoStation") != null, "base builds the ammo resupply table")
	_check(site.get_node_or_null("VaultEntrance") != null, "vault entrance is built as a walkable structure")
	_check(site.get("_gateway_ring") != null, "entrance plaza keeps its beacon ring")
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
	zombie.set_frenzy(true)
	_check(absf(zombie.speed_now() - zombie.speed * 1.35) < 0.001, "frenzied zombie sprints at 135 percent speed")
	zombie.set_frenzy(false)
	_check(absf(zombie.speed_now() - zombie.speed) < 0.001, "calmed zombie returns to its base speed")
	zombie.free()


func _test_zombie_abilities() -> void:
	var armored = ServerZombieScript.new()
	root.add_child(armored)
	armored.setup(11, "walker", 3)
	armored.apply_ability("armored")
	var armored_hp: float = armored.max_hp
	armored.take_damage(100.0)
	_check(absf(armored.hp - (armored_hp - 68.0)) < 0.01, "armored zombies absorb 32 percent of incoming damage")
	_check(armored.ability_index() == 2, "armored ability maps to its snapshot index")
	armored.free()

	var climber = ServerZombieScript.new()
	root.add_child(climber)
	climber.setup(12, "walker", 3)
	var walker_speed: float = climber.speed
	climber.apply_ability("climber")
	_check(climber.speed > walker_speed, "climbers gain climbing speed")
	climber.global_position = Vector3.ZERO
	climber.floor_y = 0.06
	climber._start_climb(5.0)
	climber.step(0.2, Vector3(0.0, 0.06, -10.0), 3, true)
	_check(int(climber.state) == 2 and climber.global_position.y > 0.5, "climber ascends walls into a leap state")
	_check(climber.ability_index() == 1, "climber ability maps to its snapshot index")
	climber.free()

	var host = ServerZombieScript.new()
	root.add_child(host)
	host.setup(21, "walker", 2)
	var prey = ServerZombieScript.new()
	root.add_child(prey)
	prey.setup(22, "brute", 2)
	var host_hp: float = host.max_hp
	var host_scale: float = host.visual_scale
	var host_tint: Color = host.tint
	host.fuse_with(prey)
	_check(host.mass == 1, "fusion consumes prey mass into the host")
	_check(host.max_hp > host_hp and host.visual_scale > host_scale, "fused host grows tankier and larger")
	_check(host.tint != host_tint, "fusion blends the prey tint into the host")
	_check(host.snapshot().size() == 11, "snapshots carry position, traits and ability data")
	var second = ServerZombieScript.new()
	root.add_child(second)
	second.setup(23, "walker", 2)
	host.fuse_with(second)
	_check(host.mass == 2 and host.ability == "armored", "second fusion awakens a mutation ability")
	prey.free()
	second.free()
	host.free()


func _test_player_reload_and_carry() -> void:
	var player = PlayerScript.new()
	root.add_child(player)
	player.set_loadout(WeaponCatalog.default_loadout(), "smg")
	player.mag = 5
	player.start_reload()
	_check(player.reloading, "empty magazine starts a reload")
	player.set("_reload_left", player.reload_time * 0.5)
	_check(absf(player.reload_progress() - 0.5) < 0.02, "reload progress drives the viewmodel animation")
	player._finish_reload()
	_check(player.mag == player.mag_size and player.reserve == 113, "reload refills the magazine from reserve")
	player.mag = 5
	player.set_carrying(true)
	_check(player.carrying_core and not player.reloading, "picking up a core cancels the reload")
	player.start_reload()
	_check(not player.reloading, "carrying a core blocks reloading")
	player.set_carrying(false)
	player.start_reload()
	_check(player.reloading, "dropping the core restores reloading")
	player.apply_team_upgrades({"mag": 2, "reload": 2, "speed": 2, "armor": 2})
	_check(player.mag_size == 48, "magazine upgrade widens the mag")
	_check(absf(player.reload_time - 1.04) < 0.001, "reload upgrade shortens reload time")
	_check(player.walk_speed > PlayerScript.WALK_SPEED, "speed upgrade raises movement speed")
	_check(absf(player.damage_reduction - 0.16) < 0.001, "armor upgrade adds damage reduction")
	player.face_yaw(3.5)
	_check(absf(player.rotation.y - wrapf(3.5, -PI, PI)) < 0.001, "face_yaw normalizes large angles")
	player.teleport_to(MissionSiteScript.BASEMENT_ARRIVAL)
	_check(player.global_position.y < -13.0, "teleport preserves basement depth")
	_check(PlayerScript.GRAVITY > 15.0 and PlayerScript.JUMP_VELOCITY > 6.0, "jump uses a snappy impulse and gravity")
	_check(PlayerScript.COYOTE_TIME > 0.0 and PlayerScript.JUMP_BUFFER > 0.0, "jump keeps coyote time and input buffering")
	player.set_meta_bonus(8, 0.9)
	_check(player.reserve_cap == 152 and player.reserve == 121, "legacy bonus raises starting reserve")
	player.mag = 0
	player.reserve = 0
	player.refill_ammo()
	_check(player.mag == 48 and player.reserve == 152, "ammo station refills the magazine and reserve")
	player.apply_team_upgrades({"reload": 2})
	_check(absf(player.reload_time - 0.936) < 0.001, "legacy reload bonus stacks with team upgrades")
	player.free()


func _test_weapon_system() -> void:
	_check(WeaponCatalog.ordered_ids().size() == 7, "catalog ships seven weapons including melee")
	_check(WeaponCatalog.MAX_CARRY == 2, "only two weapons can be carried into a run")
	_check(not bool(WeaponCatalog.data("pistol").get("auto", true)), "pistol stays semi-automatic")
	_check(bool(WeaponCatalog.data("smg").get("auto", false)), "smg fires full auto")
	_check(WeaponCatalog.is_melee("machete") and WeaponCatalog.is_melee("sledge"), "melee weapons are catalogued as melee")
	var player = PlayerScript.new()
	root.add_child(player)
	player.set_loadout(WeaponCatalog.default_loadout(), "smg")
	_check(player.weapons_owned.size() == 2 and player.current_weapon_id() == "smg", "default loadout carries an smg and a machete")
	_check(player.mag_size == 36 and player.reserve == 144, "smg starts with catalog ammo")
	_check(not player.switch_weapon_slot(1), "cannot switch to the active weapon")
	_check(not player.switch_weapon_slot(3), "cannot switch beyond the two carried slots")
	player.mag = 9
	player.reserve = 40
	_check(player.switch_weapon_slot(2), "slot key equips the machete")
	_check(player.current_weapon_id() == "machete" and player.is_melee_equipped(), "melee weapon drives the melee profile")
	_check(player.mag_size == 0 and player.mag == 0, "melee weapons carry no magazine")
	_check(bool(player.get("_third_person")), "melee swaps the viewmodel to third person")
	player.set("_switch_lock", 0.0)
	_check(player.switch_weapon_slot(1), "slot key returns to the smg")
	_check(player.mag == 9 and player.reserve == 40, "smg ammo state survives a weapon swap")
	player.set_carrying(true)
	player.set("_switch_lock", 0.0)
	_check(not player.switch_weapon_slot(2), "carrying a core blocks weapon switching")
	player.set_carrying(false)
	player.apply_team_upgrades({"rate": 3})
	_check(absf(player.fire_interval - 0.068 * 0.79) < 0.0001, "rate upgrade tightens the fire interval")
	player.set_loadout(["pistol", "smg", "rifle"], "rifle")
	_check(player.weapons_owned.size() == 2 and player.current_weapon_id() == "rifle" and player.mag_size == 30, "set_loadout caps the loadout and equips the selection")
	var summary: Array = player.loadout_summary()
	_check(summary.size() == 2 and bool(summary[1]["active"]), "loadout summary marks the active slot")
	player.free()


func _test_hud_overlays() -> void:
	var hud = HudScript.new()
	root.add_child(hud)
	_check(not hud.overlay_open(), "hud overlays start closed")
	var loadout: Array = [
		{"slot": 1, "id": "smg", "name": "VX-9", "full_name": "VX-9 冲锋枪", "accent": Color.WHITE, "active": true, "mag": 30, "reserve": 120, "mag_size": 36},
		{"slot": 2, "id": "machete", "name": "砍刀", "full_name": "M-2 开山砍刀", "accent": Color.WHITE, "active": false, "mag": 0, "reserve": 0, "mag_size": 0},
	]
	hud.set_weapon_strip(loadout, {"id": "smg", "name": "VX-9 冲锋枪", "tag": "全自动"})
	var slots: Dictionary = hud.get("_weapon_slots")
	_check(slots.size() == 2, "weapon strip renders exactly two carry slots")
	hud.open_intel({
		"mission": {
			"cores": 2, "required": 3, "zone": "基地安全区", "hint": "护送核心返回基地",
			"wave": 4, "score": 900, "frenzy": true, "tokens": 1,
			"upgrades": {"mag": 1, "reload": 1, "damage": 1, "rate": 2, "speed": 0, "armor": 1}, "power": 58,
		},
		"roster": [{"name": "ALPHA", "health": 64.0, "kills": 9, "alive": true, "color": Color.CYAN}],
		"player": {
			"name": "ALPHA", "health": 88.0, "kills": 22,
			"weapon": {"id": "smg", "name": "VX-9 冲锋枪"},
			"loadout": loadout, "reserve_bonus": 4,
		},
	})
	_check(hud.intel_open() and not hud.backpack_open(), "TAB opens the intel overlay")
	var intel_body: Node = hud.get("_intel_body")
	_check(intel_body.get_child_count() == 3, "intel overlay renders mission, squad and survivor columns")
	hud.open_backpack(loadout, {"id": "smg", "name": "VX-9 冲锋枪"}, {"mag": 1, "rate": 2})
	_check(hud.backpack_open() and not hud.intel_open(), "B opens the backpack overlay")
	var backpack_body: Node = hud.get("_backpack_body")
	_check(backpack_body.get_child_count() == 2, "backpack lists both carry slots")
	hud.close_overlays()
	_check(not hud.overlay_open(), "closing overlays clears both panels")
	hud.free()


func _test_audio() -> void:
	var audio = AudioScript.new()
	root.add_child(audio)
	var streams: Dictionary = audio.get("_streams")
	_check(streams.size() == 19, "audio bakes seven weapons, nine UI cues and three zombie cues")
	_check(streams.has("ui_melee") and streams.has("ui_fuse"), "melee and fusion cues are baked")
	var shot: AudioStreamWAV = streams.get("shot_shotgun")
	_check(shot != null and shot.data.size() > 4000, "gunshot cue carries baked PCM samples")
	audio.play_weapon_shot("smg", false)
	audio.play_ui("switch", -6.0)
	_check(int(audio.get("_next_2d")) == 2, "2D voice pool rotates between shots and UI")
	audio.play_zombie("growl", Vector3(3.0, 0.0, 3.0))
	audio.play_zombie("growl", Vector3(3.0, 0.0, 3.0))
	_check(int(audio.get("_next_3d")) == 1, "zombie growls are rate limited per cue")
	audio.free()


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
	_check(threat_quota > base_quota * 1.8, "threat escalation multiplies the spawn quota")
	var summary: Dictionary = director.summary()
	_check(int(summary.get("threat", 0)) == 3, "summary reports the current threat")
	_check(absf(float(summary.get("threat_mult", 0.0)) - 1.66) < 0.001, "summary reports the quota multiplier")
	director.tick(0.3, [])
	_check(director.zombie_count() == 2, "escalated director spawns a two-zombie burst")
	var escalated_delay := float(director.get("_spawn_interval")) * pow(0.8, 3)
	_check(absf(float(director.get("_spawn_delay")) - escalated_delay) < 0.001, "threat shortens the spawn interval")
	director.start(0.0)
	director.tick(0.1, [])
	var calm_quota := int(director.get("_to_spawn"))
	director.set_frenzy(true)
	_check(director.is_frenzy() and bool(director.summary().get("frenzy", false)), "frenzy flag reaches the director summary")
	_check(int(director.get("_to_spawn")) == calm_quota + 14, "frenzy injects a large spawn burst")
	_check(float(director.get("_spawn_delay")) <= 0.1, "frenzy front-loads the next spawn")
	director.tick(0.1, [])
	_check(director.zombie_count() == 3, "frenzy spawns three zombies per pulse")
	var zombies: Dictionary = director.get("_zombies")
	var first: ServerZombie = zombies.values()[0]
	_check(first.speed_now() > first.speed, "frenzied zombies move faster")
	director.set_frenzy(false)
	var calm_speed := first.speed * (1.0 - clampf((first.visual_scale - 1.0) * 0.12, 0.0, 0.3))
	_check(absf(first.speed_now() - calm_speed) < 0.001, "calming the horde restores zombie speed")
	director.free()


func _test_basement_spawning() -> void:
	var director = ZombieDirectorScript.new()
	root.add_child(director)
	director.setup({
		"seed": 11,
		"zombie_spawns": [Vector3(30.0, 0.0, 30.0), Vector3(-30.0, 0.0, 30.0)],
		"basement_spawns": [Vector3(2.0, -13.84, 2.0), Vector3(-2.0, -13.84, 2.0), Vector3(0.0, -13.84, -2.0)],
	}, 0)
	var players: Array = [{"id": 1, "alive": true, "pos": Vector3(0.0, -13.84, 0.0)}]
	director.start(0.0)
	director.tick(0.1, players)
	director.tick(0.3, players)
	var basement_ok := director.zombie_count() > 0
	for zombie in (director.get("_zombies") as Dictionary).values():
		if zombie.global_position.y > -13.0:
			basement_ok = false
	_check(basement_ok, "vault incursion spawns zombies on the basement floor")
	director.free()


func _test_map_variety() -> void:
	var districts := {}
	var terrain_total := 0
	var cover_total := 0
	var enterable_total := 0
	var validation_ok := true
	for i in range(10):
		var layout: Dictionary = CityLayoutScript.generate(7000 + i * 17)
		districts[String(layout["district"])] = true
		terrain_total += (layout["terrain"] as Array).size()
		cover_total += (layout["cover"] as Array).size()
		for raw in (layout["buildings"] as Array):
			var building: Dictionary = raw
			if bool(building.get("enterable", false)):
				enterable_total += 1
		if not CityLayoutScript.validate(layout).is_empty():
			validation_ok = false
	_check(districts.size() >= 2, "seeds rotate through multiple city districts")
	_check(terrain_total >= 6, "seeds scatter raised terrain onto park blocks")
	_check(cover_total >= 20, "building blocks receive street cover")
	_check(enterable_total >= 3, "some buildings generate enterable interiors")
	_check(validation_ok, "generated layouts pass structural validation")
	var first: Dictionary = CityLayoutScript.generate(4242)
	var second: Dictionary = CityLayoutScript.generate(4242)
	_check(String(first["district"]) == String(second["district"]) and (first["terrain"] as Array).size() == (second["terrain"] as Array).size(),
		"the same seed reproduces district and terrain")
	var builder = CityBuilderScript.new()
	root.add_child(builder)
	builder.build(first)
	var direct_statics := 0
	for child in builder.get_children():
		if child is StaticBody3D:
			direct_statics += 1
	_check(builder.get_child_count() > 80, "city builder instantiates the generated map")
	_check(direct_statics >= (first["cover"] as Array).size(), "street cover colliders are built into the world")
	builder.free()


func _test_meta_profile() -> void:
	var profile: Dictionary = MetaProfile.empty_profile()
	_check(MetaProfile.power_of({"mag": 1, "reload": 1, "damage": 1, "speed": 1, "armor": 1}) == 46, "power weights all five upgrade tracks")
	_check(MetaProfile.power_of({"rate": 1}) == 10, "rate upgrades contribute to power")
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
	_check(int(profile.get("credits", 0)) == 298 and int(profile.get("total_credits", 0)) == 298, "extraction pays credits into the archive")
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


func _test_weapon_economy() -> void:
	var profile: Dictionary = MetaProfile.empty_profile()
	var owned: Array = profile.get("owned_weapons", [])
	_check(owned.has("pistol") and owned.has("smg") and owned.has("machete"), "new profiles start with pistol, smg and machete")
	_check(MetaProfile.equipped_weapons(profile).size() == 2, "default combat loadout carries two weapons")
	_check(WeaponCatalog.price_of("rifle") == 180 and WeaponCatalog.price_of("lmg") == 560, "armory prices ladder up")
	var broke := MetaProfile.buy_weapon(profile, "rifle")
	_check(not bool(broke.get("ok", true)), "armory rejects purchases without credits")
	profile["credits"] = 200
	var bought := MetaProfile.buy_weapon(profile, "rifle")
	_check(bool(bought.get("ok", false)) and int(profile.get("credits", -1)) == 20, "buying a weapon spends credits")
	_check(MetaProfile.owns_weapon(profile, "rifle"), "purchased weapon enters the armory")
	_check(not bool(MetaProfile.buy_weapon(profile, "rifle").get("ok", true)), "armory blocks duplicate purchases")
	var equipped := MetaProfile.select_weapon(profile, "rifle")
	var carried: Array = MetaProfile.equipped_weapons(profile)
	_check(bool(equipped.get("ok", false)) and String(profile.get("selected_weapon", "")) == "rifle", "owned weapons can be equipped")
	_check(carried.size() == 2 and carried.has("rifle"), "equipping swaps into the two-slot loadout")
	_check(not bool(MetaProfile.select_weapon(profile, "shotgun").get("ok", true)), "unowned weapons cannot be equipped")
	_check(MetaProfile.run_reward({"kills": 10, "secured": 2}, true) == 290, "extraction rewards kills and secured cores")
	_check(MetaProfile.run_reward({"kills": 10, "secured": 2}, false, true) == 0, "abandoned runs pay nothing")
