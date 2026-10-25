class_name CombatHudState
extends RefCounted
## 每帧复用的战斗 HUD 快照；不包含 UI 节点，也不计算伤害。

var health := 100.0
var max_health := 100.0
var weapon_id := "smg"
var weapon_name := ""
var weapon_tag := ""
var mag := 0
var reserve := 0
var reloading := false
var reload_progress := 0.0
var melee := false
var combo_stage := 0
var carrying_core := false
var downed := false


func reset() -> void:
	health = 100.0
	max_health = 100.0
	weapon_id = "smg"
	weapon_name = ""
	weapon_tag = ""
	mag = 0
	reserve = 0
	reloading = false
	reload_progress = 0.0
	melee = false
	combo_stage = 0
	carrying_core = false
	downed = false
