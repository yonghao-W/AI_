extends SceneTree
## 原创近战三连击回归：阶段推进、输入缓冲、窗口过期、收招重置、HUD 读数。

var checks := 0
var failures := 0


class HitRecorder:
	extends Node
	var hits: Array = []

	func request_zombie_hit(zid: int, headshot: bool, weapon_id: String, combo_stage: int = 1) -> void:
		hits.append({"id": zid, "headshot": headshot, "weapon": weapon_id, "stage": combo_stage})


class TargetProxy:
	extends Node3D
	var zombie_id := 7

	func is_targetable() -> bool:
		return true


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("[melee] " + message)


func _run() -> void:
	var player: LocalPlayer = load("res://scripts/player.gd").new()
	root.add_child(player)
	player.set_loadout(["smg", "machete"], "machete")
	_check(player.is_melee_equipped(), "machete equips as melee")
	_check(player.get("_melee_draw_left") > 0.0, "equipping melee starts the draw blend")
	_check(player.melee_combo_stage() == 0, "combo starts at zero")

	player.call("_start_melee_stage")
	_check(player.melee_combo_stage() == 1, "first attack starts stage 1")
	_check(absf(player.get("_melee_stage_damage") - WeaponCatalog.melee_stage_damage(1)) < 0.001, "stage 1 uses the catalog multiplier")
	_check(player.get("_melee_swing_left") > 0.0, "stage 1 has a live swing timer")
	_check(not bool(player.get("_melee_buffered")), "a fresh swing starts without a buffered follow-up")

	player.set("_melee_swing_left", 0.0001)
	player.call("_update_melee_state", 0.01)
	_check(player.get("_melee_combo_left") > 0.0, "finishing stage 1 opens the combo window")
	player.call("_start_melee_stage")
	_check(player.melee_combo_stage() == 2, "clicking inside the window advances to stage 2")
	_check(absf(player.get("_melee_stage_damage") - WeaponCatalog.melee_stage_damage(2)) < 0.001, "stage 2 uses the catalog multiplier")

	player.set("_melee_swing_left", 0.15)
	player.call("_fire_melee")
	_check(bool(player.get("_melee_buffered")), "a late click is buffered instead of dropped")
	_check(player.melee_combo_stage() == 2, "buffering does not start stage 3 before stage 2 ends")
	player.set("_melee_swing_left", 0.0001)
	player.call("_update_melee_state", 0.01)
	_check(player.melee_combo_stage() == 3, "buffered input chains into the finisher")
	_check(absf(player.get("_melee_stage_damage") - WeaponCatalog.melee_stage_damage(3)) < 0.001, "finisher uses the catalog multiplier")

	player.set("_melee_swing_left", 0.0001)
	player.call("_update_melee_state", 0.01)
	_check(player.melee_combo_stage() == 0, "finisher resets the chain")

	player.call("_start_melee_stage")
	player.set("_melee_swing_left", 0.0001)
	player.call("_update_melee_state", 0.01)
	player.call("_update_melee_state", WeaponCatalog.MELEE_COMBO_WINDOW + 0.1)
	_check(player.melee_combo_stage() == 0, "expired combo window returns to idle")
	player.call("_start_melee_stage")
	_check(player.melee_combo_stage() == 1, "expired chain restarts at stage 1")

	player.set("_switch_lock", 0.0)
	player.switch_weapon_slot(1)
	_check(player.current_weapon_id() == "smg", "switching back to the smg succeeds")
	_check(player.melee_combo_stage() == 0 and float(player.get("_melee_swing_left")) == 0.0, "switching away clears the melee chain")

	_check(is_equal_approx(WeaponCatalog.melee_stage_damage(0), WeaponCatalog.melee_stage_damage(1)), "stage index clamps below one")
	_check(is_equal_approx(WeaponCatalog.melee_stage_damage(99), WeaponCatalog.melee_stage_damage(3)), "stage index clamps above three")
	_check(WeaponCatalog.melee_stage_duration("sledge", 3) > WeaponCatalog.melee_stage_duration("machete", 3), "sledge finisher stays heavier than the machete")

	player.set("_switch_lock", 0.0)
	player.switch_weapon_slot(2)
	var target := TargetProxy.new()
	target.position = Vector3(0.0, 0.0, -1.2)
	target.add_to_group("zombie_proxies")
	root.add_child(target)
	var recorder := HitRecorder.new()
	root.add_child(recorder)
	player.main_ref = recorder
	player.call("_start_melee_stage")
	var duration := float(player.get("_melee_swing_total"))
	var hit_at := float(player.get("_melee_hit_at"))
	player.call("_update_melee_state", duration * maxf(0.0, hit_at - 0.05))
	_check(recorder.hits.is_empty(), "melee does not damage before the contact frame")
	player.call("_update_melee_state", duration * 0.1)
	_check(recorder.hits.size() == 1, "contact frame damages one target in range")
	if recorder.hits.size() == 1:
		var hit: Dictionary = recorder.hits[0]
		_check(int(hit["stage"]) == 1 and String(hit["weapon"]) == "machete", "hit request carries weapon and combo stage")
	player.main_ref = null
	target.free()
	recorder.free()
	player.set("_melee_swing_left", 0.0)
	player.set("_melee_stage", 0)
	player.set("_melee_combo_left", 0.0)

	var hud: GameHUD = load("res://scripts/game_hud.gd").new()
	root.add_child(hud)
	hud.set_ammo(0, 0, false, 0.0, true, 2)
	_check(hud.get("_ammo_state").text.contains("连击 2"), "HUD shows the live combo stage")
	hud.set_ammo(0, 0, false, 0.0, true, 0)
	_check(hud.get("_ammo_state").text.contains("三连击"), "HUD returns to the idle melee label")

	hud.free()
	player.free()
	print("Melee combo: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
