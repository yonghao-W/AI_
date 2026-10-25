extends SceneTree
## 原创近战三连击回归：阶段推进、输入缓冲、窗口过期、收招重置、HUD 读数。

var checks := 0
var failures := 0


class HitRecorder:
	extends Node
	var hits: Array = []

	func record_hit(zid: int, headshot: bool, weapon_id: String, combo_stage: int) -> void:
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
	var view: Variant = player.get("_melee_view")
	_check(view != null and view.draw_left > 0.0, "equipping melee starts the draw blend")
	_check(view.visible, "melee rig is visible in third person")
	_check(player.melee_combo_stage() == 0, "combo starts at zero")

	var melee: Variant = player.get("_melee")
	player.call("_start_melee_stage")
	_check(player.melee_combo_stage() == 1, "first attack starts stage 1")
	_check(melee.is_swinging(), "stage 1 has a live swing timer")
	_check(not melee.buffered, "a fresh swing starts without a buffered follow-up")

	melee.swing_left = 0.0001
	player.call("_update_melee_state", 0.01)
	_check(melee.combo_left > 0.0, "finishing stage 1 opens the combo window")
	player.call("_start_melee_stage")
	_check(player.melee_combo_stage() == 2, "clicking inside the window advances to stage 2")

	melee.swing_left = 0.15
	player.call("_fire_melee")
	_check(melee.buffered, "a late click is buffered instead of dropped")
	_check(player.melee_combo_stage() == 2, "buffering does not start stage 3 before stage 2 ends")
	melee.swing_left = 0.0001
	player.call("_update_melee_state", 0.01)
	_check(player.melee_combo_stage() == 3, "buffered input chains into the finisher")

	melee.swing_left = 0.0001
	player.call("_update_melee_state", 0.01)
	_check(player.melee_combo_stage() == 0, "finisher resets the chain")

	player.call("_start_melee_stage")
	melee.swing_left = 0.0001
	player.call("_update_melee_state", 0.01)
	player.call("_update_melee_state", WeaponCatalog.MELEE_COMBO_WINDOW + 0.1)
	_check(player.melee_combo_stage() == 0, "expired combo window returns to idle")
	player.call("_start_melee_stage")
	_check(player.melee_combo_stage() == 1, "expired chain restarts at stage 1")

	player.set("_switch_lock", 0.0)
	player.switch_weapon_slot(1)
	_check(player.current_weapon_id() == "smg", "switching back to the smg succeeds")
	_check(not view.visible, "switching to a gun hides the melee rig")
	_check(player.melee_combo_stage() == 0 and melee.swing_left == 0.0, "switching away clears the melee chain")

	_check(is_equal_approx(WeaponCatalog.melee_stage_damage(0), WeaponCatalog.melee_stage_damage(1)), "stage index clamps below one")
	_check(is_equal_approx(WeaponCatalog.melee_stage_damage(99), WeaponCatalog.melee_stage_damage(3)), "stage index clamps above three")
	_check(WeaponCatalog.melee_stage_duration("sledge", 3) > WeaponCatalog.melee_stage_duration("machete", 3), "sledge finisher stays heavier than the machete")
	_check(WeaponCatalog.is_valid_melee_stage(1) and WeaponCatalog.is_valid_melee_stage(3), "valid melee stages are accepted")
	_check(not WeaponCatalog.is_valid_melee_stage(0) and not WeaponCatalog.is_valid_melee_stage(4), "server-side stage validation rejects invalid values")

	player.set("_switch_lock", 0.0)
	player.switch_weapon_slot(2)
	var target := TargetProxy.new()
	target.position = Vector3(0.0, 0.0, -1.2)
	target.add_to_group("zombie_proxies")
	root.add_child(target)
	var recorder := HitRecorder.new()
	root.add_child(recorder)
	player.zombie_hit_requested.connect(recorder.record_hit)
	player.call("_start_melee_stage")
	var duration: float = melee.swing_total
	var hit_at: float = melee.hit_at
	player.call("_update_melee_state", duration * maxf(0.0, hit_at - 0.05))
	_check(recorder.hits.is_empty(), "melee does not damage before the contact frame")
	player.call("_update_melee_state", duration * 0.1)
	_check(recorder.hits.size() == 1, "contact frame damages one target in range")
	if recorder.hits.size() == 1:
		var hit: Dictionary = recorder.hits[0]
		_check(int(hit["stage"]) == 1 and String(hit["weapon"]) == "machete", "hit request carries weapon and combo stage")
	player.zombie_hit_requested.disconnect(recorder.record_hit)
	target.free()
	recorder.free()
	melee.cancel()

	player.set("_switch_lock", 0.0)
	player.switch_weapon_slot(2)
	player.call("_start_melee_stage")
	player.set_carrying(true)
	_check(player.melee_combo_stage() == 0 and melee.swing_left == 0.0, "picking up a core cancels the melee chain")
	_check(not view.visible, "carrying a core hides the melee rig")
	player.set_carrying(false)
	_check(view.visible, "dropping the core restores the melee rig")

	player.respawn_at(Vector3.ZERO)
	player.set_game_active(true)
	player.set("_switch_lock", 0.0)
	player.switch_weapon_slot(2)
	player.call("_start_melee_stage")
	player.set_down()
	_check(player.melee_combo_stage() == 0, "going down cancels the melee chain")
	_check(not view.visible, "going down hides the melee rig")
	player.respawn_at(Vector3.ZERO)
	_check(player.alive and player.melee_combo_stage() == 0, "respawn starts with a cleared melee chain")
	_check(view.visible, "respawn restores the melee rig")

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
