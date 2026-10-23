extends SceneTree

const CityLayoutScript = preload("res://scripts/city_layout.gd")
const CityBuilderScript = preload("res://scripts/city_builder.gd")

var checks := 0
var failures := 0


func _initialize() -> void:
	print("== DeadCity city tests ==")
	_test_determinism()
	_test_variation()
	_test_bounds_and_content()
	_test_many_seeds()
	_test_builder_geometry()
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


func _test_determinism() -> void:
	var a: Dictionary = CityLayoutScript.generate(424242)
	var b: Dictionary = CityLayoutScript.generate(424242)
	_check(var_to_str(a) == var_to_str(b), "same seed produces identical layout")
	_check(int(a["seed"]) == 424242, "seed stored in layout")
	_check(a["spawn_points"].size() == 16, "5x5 grid exposes 16 interior intersections")
	_check(a["zombie_spawns"].size() >= 20, "enough perimeter zombie spawn points")


func _test_variation() -> void:
	var signatures: Dictionary = {}
	for s in range(12):
		var layout: Dictionary = CityLayoutScript.generate(1000 + s)
		var parts: Array[String] = []
		for building in layout["buildings"]:
			parts.append("%.1f,%.1f,%.1f" % [building["center"].x, building["center"].y, building["size"].y])
		signatures[",".join(parts)] = true
	_check(signatures.size() >= 10, "different seeds generate different cities")


func _test_bounds_and_content() -> void:
	var layout: Dictionary = CityLayoutScript.generate(7)
	var errors: Array[String] = CityLayoutScript.validate(layout)
	_check(errors.is_empty(), "layout validates: %s" % [str(errors)])
	_check(layout["blocks"].size() == 25, "grid has 25 blocks")
	_check(layout["buildings"].size() >= 25, "city has a dense set of buildings")
	var central: Dictionary = layout["blocks"][12]
	_check(bool(central["central"]) and central["kind"] == "park", "central block is a park")
	_check(bool(central["fountain"]), "central park has a fountain")
	_check(layout["cars"].size() >= 5, "cars scattered through streets")
	_check(layout["streetlights"].size() == 50, "two streetlights per block")


func _test_many_seeds() -> void:
	var bad := 0
	var parks := 0
	for s in range(1, 41):
		var layout: Dictionary = CityLayoutScript.generate(s)
		if not CityLayoutScript.validate(layout).is_empty():
			bad += 1
		for block in layout["blocks"]:
			if block["kind"] == "park":
				parks += 1
	_check(bad == 0, "40 random cities validate without errors")
	_check(parks >= 40, "random cities contain parks")


func _test_builder_geometry() -> void:
	var layout: Dictionary = CityLayoutScript.generate(2026)
	var builder := CityBuilderScript.new()
	root.add_child(builder)
	builder.build(layout)
	var counts := _walk_counts(builder)
	_check(counts["nodes"] > 400, "builder creates a populated city (%d nodes)" % counts["nodes"])
	var required_statics: int = layout["buildings"].size() + 5
	_check(counts["statics"] >= required_statics, "buildings and walls have collision (%d static bodies)" % counts["statics"])
	_check(counts["multimesh"] >= 3, "windows and road marks batched in multimeshes")
	builder.queue_free()


func _walk_counts(node: Node) -> Dictionary:
	var nodes := 1
	var statics := 1 if node is StaticBody3D else 0
	var multimesh := 1 if node is MultiMeshInstance3D else 0
	for child in node.get_children():
		var sub := _walk_counts(child)
		nodes += sub["nodes"]
		statics += sub["statics"]
		multimesh += sub["multimesh"]
	return {"nodes": nodes, "statics": statics, "multimesh": multimesh}
