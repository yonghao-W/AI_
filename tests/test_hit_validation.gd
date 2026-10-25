extends SceneTree
## 服务器近战阶段校验：非法阶段不得进入目标查询或伤害结算。

class MockDirector:
	extends ZombieDirector
	var position_calls := 0
	var damage_calls := 0

	func zombie_position(_zid: int) -> Vector3:
		position_calls += 1
		return Vector3.ZERO

	func damage_zombie(_zid: int, _damage: float) -> Dictionary:
		damage_calls += 1
		return {"ok": false}

var checks := 0
var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("[hit-validation] " + message)


func _run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.is_server = true
	game.game_started = false
	game.game_over = false
	game.players = {1: {"alive": true, "pos": Vector3.ZERO}}
	var director := MockDirector.new()
	root.add_child(director)
	game.director = director

	game.call("_server_apply_hit", 1, 7, false, "machete", 1)
	_check(director.position_calls == 1, "valid melee stage reaches the server target query")
	_check(director.damage_calls == 1, "valid melee stage reaches damage resolution")
	director.position_calls = 0
	director.damage_calls = 0

	game.call("_server_apply_hit", 1, 7, false, "machete", 0)
	game.call("_server_apply_hit", 1, 7, false, "machete", 4)
	_check(director.position_calls == 0, "invalid melee stages are rejected before target query")
	_check(director.damage_calls == 0, "invalid melee stages are rejected before damage resolution")

	director.queue_free()
	game.queue_free()
	await process_frame
	print("Hit validation: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
