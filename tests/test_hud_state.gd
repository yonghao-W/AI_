extends SceneTree
## HUD 快照与兼容层回归：生命、武器、弹药、连击、搬运、倒地与旧 setter。

const StateScript := preload("res://scripts/combat_hud_state.gd")
const HudScript := preload("res://scripts/game_hud.gd")
const PlayerScript := preload("res://scripts/player.gd")

var checks := 0
var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("[hud-state] " + message)


func _run() -> void:
	var hud = HudScript.new()
	root.add_child(hud)
	var state: Variant = StateScript.new()
	state.health = 37.0
	state.max_health = 100.0
	state.weapon_id = "machete"
	state.weapon_name = "M-2 开山砍刀"
	state.weapon_tag = "近战 · 横扫"
	state.mag = 0
	state.reserve = 0
	state.reloading = false
	state.reload_progress = 0.0
	state.melee = true
	state.combo_stage = 2
	state.carrying_core = false
	state.downed = false

	hud.apply_combat_state(state)
	_check(hud.get("_health_label").text == "37", "snapshot applies health")
	_check(hud.get("_ammo_state").text.contains("连击 2"), "snapshot applies melee combo stage")
	_check(hud.get("_weapon_title").text == "M-2 开山砍刀", "snapshot applies current weapon name")
	_check(hud.get("_weapon_mode").text == "近战 · 横扫", "snapshot applies weapon mode tag")

	state.health = 52.0
	hud.apply_combat_state(state)
	_check(hud.get("_health_label").text == "52", "snapshot updates changed health")

	state.carrying_core = true
	hud.apply_combat_state(state)
	_check(bool(hud.get("_carrying_core")), "snapshot applies carrying restriction")
	_check(hud.get("_carry_panel").visible, "snapshot shows the carry panel")
	_check(hud.get("_ammo_state").text.contains("核心搬运"), "snapshot blocks weapon status while carrying")

	state.carrying_core = false
	hud.apply_combat_state(state)
	_check(not bool(hud.get("_carrying_core")), "snapshot clears carrying restriction")
	_check(not hud.get("_carry_panel").visible, "snapshot hides the carry panel")

	state.downed = true
	hud.apply_combat_state(state)
	_check(bool(hud.get("_down_active")), "snapshot applies downed state")
	hud.set_down(true, 7.0)
	hud.apply_combat_state(state)
	_check(is_equal_approx(float(hud.get("_down_left")), 7.0), "repeated downed snapshot preserves the countdown")
	state.downed = false
	hud.apply_combat_state(state)
	_check(not bool(hud.get("_down_active")), "snapshot clears downed state")

	var old_loadout := [{"slot": 1, "id": "smg", "name": "VX-9", "full_name": "VX-9 冲锋枪", "accent": Color.WHITE, "active": true, "mag": 3, "reserve": 9, "mag_size": 36}]
	hud.set_health(88.0, 100.0)
	hud.set_ammo(3, 9, false, 0.0, false, 0)
	hud.set_weapon_strip(old_loadout, {"id": "smg", "name": "VX-9 冲锋枪", "tag": "全自动"})
	_check(hud.get("_health_label").text == "88", "legacy set_health still works")
	_check(hud.get("_ammo_mag").text == "3" and hud.get("_ammo_reserve").text == "9", "legacy set_ammo still works")
	_check(hud.get("_weapon_title").text == "VX-9 冲锋枪", "legacy set_weapon_strip still works")

	var player: LocalPlayer = PlayerScript.new()
	root.add_child(player)
	player.set_loadout(["smg", "machete"], "machete")
	player.health = 64.0
	player.carrying_core = true
	var snapshot: Variant = StateScript.new()
	player.write_hud_state(snapshot)
	_check(snapshot.weapon_id == "machete" and snapshot.melee, "player snapshot exposes the real current weapon")
	_check(is_equal_approx(snapshot.health, 64.0) and snapshot.carrying_core, "player snapshot exposes health and carry state")
	player.carrying_core = false
	player.set_down()
	player.write_hud_state(snapshot)
	_check(snapshot.downed, "player snapshot exposes downed state")

	player.respawn_at(Vector3.ZERO)
	player.set("_switch_lock", 0.0)
	player.switch_weapon_slot(2)
	player.call("_start_melee_stage")
	player.write_hud_state(snapshot)
	_check(snapshot.combo_stage == 1 and snapshot.melee, "player snapshot exposes the live combo stage")

	player.free()
	hud.free()
	print("HUD state: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
