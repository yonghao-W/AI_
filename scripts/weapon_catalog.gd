class_name WeaponCatalog
extends RefCounted

const ORDER := ["pistol", "smg", "rifle", "shotgun", "lmg", "machete", "sledge"]
const DEFAULT_OWNED := ["pistol", "smg", "machete"]
const DEFAULT_LOADOUT := ["smg", "machete"]
const DEFAULT_SELECTED := "smg"
const MAX_CARRY := 2

const MELEE_COMBO_STAGES := 3
const MELEE_COMBO_WINDOW := 0.45
const MELEE_STAGE_DAMAGE := [0.62, 0.72, 1.32]
const MELEE_STAGE_DURATION := [1.0, 0.94, 1.26]
const MELEE_STAGE_HIT := [0.38, 0.36, 0.48]
const MELEE_STAGE_RANGE := [1.0, 1.0, 1.08]
const MELEE_STAGE_ARC := [1.0, 1.12, 0.9]
const MELEE_STAGE_TARGETS := [2, 2, 3]
const MELEE_STAGE_LUNGE := [2.6, 2.4, 4.2]

const WEAPONS := {
	"pistol": {
		"name": "P-19 手枪", "short": "P-19", "tag": "半自动", "price": 0, "auto": false, "kind": "gun",
		"damage": 32.0, "headshot": 2.9, "interval": 0.19, "mag": 12, "reserve": 72,
		"reload": 1.2, "spread": 0.009, "ads_spread": 0.0032, "pellets": 1,
		"range": 90.0, "kick": 0.8, "accent": "#a9c3d2",
	},
	"smg": {
		"name": "VX-9 冲锋枪", "short": "VX-9", "tag": "全自动", "price": 0, "auto": true, "kind": "gun",
		"damage": 19.0, "headshot": 2.4, "interval": 0.068, "mag": 36, "reserve": 144,
		"reload": 1.3, "spread": 0.018, "ads_spread": 0.010, "pellets": 1,
		"range": 85.0, "kick": 0.65, "accent": "#59d8c8",
	},
	"rifle": {
		"name": "MK-3 突击步枪", "short": "MK-3", "tag": "全自动", "price": 180, "auto": true, "kind": "gun",
		"damage": 33.0, "headshot": 3.0, "interval": 0.104, "mag": 30, "reserve": 150,
		"reload": 1.5, "spread": 0.010, "ads_spread": 0.0035, "pellets": 1,
		"range": 120.0, "kick": 0.9, "accent": "#ffcb66",
	},
	"shotgun": {
		"name": "SG-12 战术霰弹", "short": "SG-12", "tag": "泵动", "price": 320, "auto": false, "kind": "gun",
		"damage": 13.0, "headshot": 2.0, "interval": 0.72, "mag": 7, "reserve": 42,
		"reload": 1.95, "spread": 0.055, "ads_spread": 0.046, "pellets": 9,
		"range": 48.0, "kick": 1.8, "accent": "#ff8d6b",
	},
	"lmg": {
		"name": "MG-7 轻机枪", "short": "MG-7", "tag": "全自动", "price": 560, "auto": true, "kind": "gun",
		"damage": 27.0, "headshot": 2.5, "interval": 0.06, "mag": 80, "reserve": 240,
		"reload": 3.0, "spread": 0.022, "ads_spread": 0.012, "pellets": 1,
		"range": 120.0, "kick": 1.1, "accent": "#b997ff",
	},
	"machete": {
		"name": "M-2 开山砍刀", "short": "砍刀", "tag": "近战 · 横扫", "price": 0, "auto": false, "kind": "melee",
		"damage": 74.0, "headshot": 1.35, "interval": 0.54, "mag": 0, "reserve": 0,
		"reload": 0.0, "range": 2.9, "arc": 0.72, "kick": 1.2, "accent": "#e0b46a",
	},
	"sledge": {
		"name": "S-6 破拆大锤", "short": "大锤", "tag": "近战 · 重击", "price": 240, "auto": false, "kind": "melee",
		"damage": 168.0, "headshot": 1.2, "interval": 0.92, "mag": 0, "reserve": 0,
		"reload": 0.0, "range": 3.15, "arc": 0.52, "kick": 1.9, "accent": "#d8895f",
	},
}


static func has_weapon(id: String) -> bool:
	return WEAPONS.has(id)


static func data(id: String) -> Dictionary:
	if not WEAPONS.has(id):
		id = DEFAULT_SELECTED
	var copy: Dictionary = (WEAPONS[id] as Dictionary).duplicate(true)
	copy["id"] = id
	return copy


static func display_name(id: String) -> String:
	return String(data(id).get("name", "未知武器"))


static func short_name(id: String) -> String:
	return String(data(id).get("short", "--"))


static func price_of(id: String) -> int:
	return maxi(0, int(data(id).get("price", 0)))


static func rpm(id: String) -> int:
	return roundi(60.0 / maxf(0.01, float(data(id).get("interval", 0.1))))


static func is_melee(id: String) -> bool:
	return String(data(id).get("kind", "gun")) == "melee"


static func melee_stage_index(stage: int) -> int:
	return clampi(stage, 1, MELEE_COMBO_STAGES) - 1


static func is_valid_melee_stage(stage: int) -> bool:
	return stage >= 1 and stage <= MELEE_COMBO_STAGES


static func melee_stage_damage(stage: int) -> float:
	return float(MELEE_STAGE_DAMAGE[melee_stage_index(stage)])


static func melee_stage_duration(id: String, stage: int) -> float:
	var weapon := data(id)
	return maxf(0.3, float(weapon.get("interval", 0.6)) * float(MELEE_STAGE_DURATION[melee_stage_index(stage)]))


static func melee_stage_hit(stage: int) -> float:
	return float(MELEE_STAGE_HIT[melee_stage_index(stage)])


static func melee_stage_range(id: String, stage: int) -> float:
	var weapon := data(id)
	return float(weapon.get("range", 2.9)) * float(MELEE_STAGE_RANGE[melee_stage_index(stage)])


static func melee_stage_arc(id: String, stage: int) -> float:
	var weapon := data(id)
	return float(weapon.get("arc", 0.65)) * float(MELEE_STAGE_ARC[melee_stage_index(stage)])


static func melee_stage_targets(stage: int) -> int:
	return int(MELEE_STAGE_TARGETS[melee_stage_index(stage)])


static func melee_stage_lunge(stage: int) -> float:
	return float(MELEE_STAGE_LUNGE[melee_stage_index(stage)])


static func stat_line(id: String) -> String:
	var weapon := data(id)
	if is_melee(id):
		return "伤害 %d · 挥速 %d/分 · 范围 %.1f m · %s" % [
			roundi(float(weapon.get("damage", 0.0))),
			rpm(id),
			float(weapon.get("range", 2.4)),
			String(weapon.get("tag", "")),
		]
	return "伤害 %d · 射速 %d RPM · 弹匣 %d · 备弹 %d · %s" % [
		roundi(float(weapon.get("damage", 0.0))),
		rpm(id),
		int(weapon.get("mag", 0)),
		int(weapon.get("reserve", 0)),
		String(weapon.get("tag", "")),
	]


static func accent(id: String) -> Color:
	return Color.from_string(String(data(id).get("accent", "#59d8c8")), Color("#59d8c8"))


static func default_owned() -> Array:
	return DEFAULT_OWNED.duplicate()


static func default_loadout() -> Array:
	return DEFAULT_LOADOUT.duplicate()


static func max_carry() -> int:
	return MAX_CARRY


static func ordered_ids() -> Array:
	return ORDER.duplicate()
