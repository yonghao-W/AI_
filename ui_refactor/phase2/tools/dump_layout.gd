extends SceneTree

func _initialize() -> void:
	var seed_value := 4242
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seed="):
			seed_value = int(arg.trim_prefix("--seed="))
	var layout := CityLayout.generate(seed_value)
	var out := {
		"seed": seed_value,
		"district": layout.get("district"),
		"grid": layout.get("grid"),
		"block_size": layout.get("block_size"),
		"road_width": layout.get("road_width"),
		"pitch": layout.get("pitch"),
		"total_size": layout.get("total_size"),
		"road_centers": layout.get("road_centers"),
		"blocks": [],
		"buildings": [],
		"cars": layout.get("cars"),
		"spawn_points": layout.get("spawn_points"),
	}
	for b in layout.get("blocks", []):
		out["blocks"].append({
			"center": [b["center"].x, b["center"].y],
			"kind": b["kind"],
			"central": b["central"],
			"buildings": [],
		})
		for building in b.get("buildings", []):
			var rec := {
				"center": [building["center"].x, building["center"].y],
				"size": [building["size"].x, building["size"].y, building["size"].z],
				"floors": building["floors"],
				"enterable": building.get("enterable", false),
			}
			out["blocks"][out["blocks"].size() - 1]["buildings"].append(rec)
			out["buildings"].append(rec)
	var f := FileAccess.open("res://ui_refactor/phase2/tools/layout_%d.json" % seed_value, FileAccess.WRITE)
	f.store_string(JSON.stringify(out, "  "))
	f.close()
	print("wrote layout_%d.json district=%s total=%.1f" % [seed_value, out["district"], out["total_size"]])
	quit()
