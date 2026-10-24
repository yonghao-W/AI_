extends SceneTree

var checks := 0
var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)


func _run() -> void:
	# 新开一局应从 E-07 三楼开始，并能步行进入原有城市任务。
	_check(FileAccess.file_exists("res://scripts/chapter_one_station.gd"), "Chapter one has no playable E-07 station")
	if failures > 0:
		quit(1)
		return
	for seed_value in [1, 7, 42, 4242, 731993, 2026]:
		var layout := CityLayout.generate(seed_value)
		ChapterOneStation.prepare_layout(layout)
		_check(CityLayout.validate(layout).is_empty(), "Chapter layout invalid for seed %d" % seed_value)
		for building in layout["buildings"]:
			var size: Vector3 = building["size"]
			_check(not Rect2(building["center"] - Vector2(size.x, size.z) * 0.5, Vector2(size.x, size.z)).intersects(ChapterOneStation.FOOTPRINT), "Random building blocks station")
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.menu.solo_requested.emit("E07 TEST", 4242)
	for i in range(120):
		await process_frame
		if game.game_started:
			break
	_check(game.game_started, "Main menu cannot start chapter one")
	if not game.game_started:
		quit(1)
		return
	game.set_process(false)
	game.director.stop()
	game.player.set_game_active(false)
	game.player.set_physics_process(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var player: CharacterBody3D = game.player
	_check(game.station.contains_point(player.global_position), "New game does not start inside E-07")
	_check(absf(player.global_position.y - 7.58) < 0.05, "New game does not start on third floor")
	_check(game.station.can_use_radio(ChapterOneStation.RADIO_POINT), "Radio interaction unavailable on third floor")
	_check(not game.station.can_use_radio(ChapterOneStation.RADIO_POINT - Vector3(0, 3.4, 0)), "Radio can be activated through a floor")
	_check(not game.mission.is_in_basement(ChapterOneStation.CENTER + Vector3(0, -3, 0)), "Station basement confused with park vault")
	for point in ChapterOneStation.SPAWNS:
		player.global_position = point
		await _settle(player, 25)
		_check(absf(player.global_position.y - 7.52) < 0.15, "Station spawn falls through floor")
	player.global_position = ChapterOneStation.SPAWNS[0]
	await _walk_path(player, [Vector3(3.85, 7.52, 1.8), Vector3(3.85, 7.52, 3.65), Vector3(-4, 7.52, 3.65), Vector3(-4, 7.52, 6.45), Vector3(-8.25, 7.52, 6.45)])
	for lower in [4.0, 0.0, -3.2]:
		var middle: float = (player.global_position.y - 0.12 + lower) * 0.5
		await _walk_path(player, [Vector3(-8.25, middle + 0.1, 1.3), Vector3(-10.75, middle + 0.1, 1.3), Vector3(-10.75, lower + 0.12, 6.45), Vector3(-8.25, lower + 0.12, 6.45)])
		_check(absf(player.global_position.y - (lower + 0.12)) < 0.3, "Interior stairs cannot descend to %.1f: %s" % [lower, player.global_position])
	for upper in [0.0, 4.0, 7.4]:
		var bottom: float = player.global_position.y - 0.12
		var middle: float = (bottom + upper) * 0.5
		await _walk_path(player, [Vector3(-10.75, bottom + 0.12, 6.45), Vector3(-10.75, middle + 0.1, 1.3), Vector3(-8.25, middle + 0.1, 1.3), Vector3(-8.25, upper + 0.12, 6.45)])
		_check(absf(player.global_position.y - (upper + 0.12)) < 0.3, "Interior stairs cannot ascend to %.1f: %s" % [upper, player.global_position])
	await _walk_path(player, [Vector3(-11.25, 7.52, 6.45), Vector3(-11.25, 7.52, 3.8), Vector3(-16.1, 7.56, 3.8)])
	for lower in [4.0, 0.0]:
		var middle: float = (player.global_position.y - 0.16 + lower) * 0.5
		await _walk_path(player, [Vector3(-16.1, middle + 0.09, -0.55), Vector3(-14.2, middle + 0.09, -0.55), Vector3(-14.2, lower + 0.16, 4.5)])
		_check(absf(player.global_position.y - (lower + 0.16)) < 0.35, "Exterior stairs cannot descend to %.1f: %s" % [lower, player.global_position])
		if lower > 0:
			await _walk_path(player, [Vector3(-16.1, lower + 0.16, 4.5)])
	for upper in [4.0, 7.4]:
		var bottom: float = player.global_position.y - 0.16
		var middle: float = (bottom + upper) * 0.5
		await _walk_path(player, [Vector3(-14.2, bottom + 0.16, 4.5), Vector3(-14.2, middle + 0.09, -0.55), Vector3(-16.1, middle + 0.09, -0.55), Vector3(-16.1, upper + 0.16, 4.5), Vector3(-14.2, upper + 0.16, 4.5)])
		_check(absf(player.global_position.y - (upper + 0.16)) < 0.35, "Exterior stairs cannot ascend to %.1f: %s" % [upper, player.global_position])
	await _walk_path(player, [Vector3(-14.2, 7.56, 3.8), Vector3(-11.25, 7.52, 3.8)])
	_check(absf(player.global_position.y - 7.52) < 0.2, "Cannot reenter station from fire escape")
	await _walk_path(player, [Vector3(-16.1, 7.56, 3.8)])
	for lower in [4.0, 0.0]:
		var middle: float = (player.global_position.y - 0.16 + lower) * 0.5
		await _walk_path(player, [Vector3(-16.1, middle + 0.09, -0.55), Vector3(-14.2, middle + 0.09, -0.55), Vector3(-14.2, lower + 0.16, 4.5)])
		if lower > 0:
			await _walk_path(player, [Vector3(-16.1, lower + 0.16, 4.5)])
	await _walk_path(player, [Vector3(-14.2, 0, 5.8), Vector3(-18.5, 0, 5.8), Vector3(-20, 0, 12)])
	_check(not game.station.contains_point(player.global_position) and player.global_position.y > -0.1, "Cannot walk out of station onto city street")
	game.queue_free()
	await process_frame
	print("Chapter one: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


func _settle(player: CharacterBody3D, ticks: int) -> void:
	player.velocity = Vector3.ZERO
	for i in range(ticks):
		await physics_frame
		player.velocity.y -= 22.0 / 60.0
		player.move_and_slide()


func _walk_path(player: CharacterBody3D, points: Array) -> void:
	for local_point: Vector3 in points:
		var target := ChapterOneStation.CENTER + local_point
		var arrived := false
		for i in range(240):
			await physics_frame
			var offset := Vector3(target.x - player.global_position.x, 0, target.z - player.global_position.z)
			if offset.length() < 0.12:
				arrived = true
				break
			var direction := offset.normalized()
			player.velocity.x = direction.x * minf(3.5, offset.length() * 30.0)
			player.velocity.z = direction.z * minf(3.5, offset.length() * 30.0)
			player.velocity.y -= 22.0 / 60.0
			player.move_and_slide()
		_check(arrived, "Walk blocked toward %s at %s" % [local_point, player.global_position - ChapterOneStation.CENTER])
		if not arrived:
			for i in range(player.get_slide_collision_count()):
				var collision := player.get_slide_collision(i)
				print("BLOCKER: ", collision.get_collider().get_path(), " ", collision.get_position() - ChapterOneStation.CENTER, " normal=", collision.get_normal(), " velocity=", player.velocity, " floor=", player.is_on_floor())
			quit(1)
			await process_frame
			return
		await _settle(player, 4)
