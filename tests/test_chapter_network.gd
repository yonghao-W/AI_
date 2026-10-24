extends SceneTree


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var hosting := OS.get_cmdline_user_args().has("--host")
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	if hosting:
		game.menu.host_requested.emit("HOST", 17877, 4242)
	else:
		game.menu.join_requested.emit("CLIENT", "127.0.0.1", 17877)
	var ready_sent := false
	var deadline := Time.get_ticks_msec() + 20000
	var frame := 0
	while not game.game_started and Time.get_ticks_msec() < deadline:
		await process_frame
		frame += 1
		if not hosting and game.local_id != 1 and game.players.size() == 2 and not ready_sent:
			game.menu.lobby_ready_requested.emit(true)
			ready_sent = true
		if hosting and game.players.size() == 2 and frame % 30 == 0:
			game.menu.lobby_start_requested.emit()
	if not game.game_started:
		push_error("Network chapter failed to start: host=%s" % hosting)
		quit(1)
		return
	await create_timer(0.6).timeout
	var ok: bool = game.station != null and game.players.size() == 2 and game.station.contains_point(game.player.global_position)
	for info in game.players.values():
		var point: Vector3 = info["pos"]
		ok = ok and absf(point.y - 7.52) < 0.2 and game.station.contains_point(point)
	if not ok:
		push_error("Network station spawn mismatch: host=%s roster=%s" % [hosting, game.players])
	print("Chapter network: host=%s, players=%d, station_spawn=%s" % [hosting, game.players.size(), ok])
	if hosting:
		await create_timer(4.0).timeout
	game.hud.lobby_requested.emit()
	game.queue_free()
	await process_frame
	quit(0 if ok else 1)
