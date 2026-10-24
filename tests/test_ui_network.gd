extends SceneTree
## 联机 UI 回归：大厅准备/开始、HUD 小队、联机暂停不停止服务器模拟。
## 用法：进程 A `--host`，进程 B… 默认加入；可用 `--players=4` 做四人联机回归。
## 端口默认 17878，可用 `--port=` 覆盖，便于并行运行。

const DEFAULT_PORT := 17878

var checks := 0
var failures := 0
var expected_players := 2
var port := DEFAULT_PORT
var host_port := DEFAULT_PORT
var join_port := DEFAULT_PORT
var soak_seconds := 0
var shot_path := ""


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("[%s] %s" % ["HOST" if _hosting else "CLIENT", message])


var _hosting := false


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	_hosting = args.has("--host")
	for arg in args:
		if arg.begins_with("--players="):
			expected_players = clampi(int(arg.trim_prefix("--players=")), 2, 4)
		elif arg.begins_with("--port="):
			port = int(arg.trim_prefix("--port="))
			host_port = port
			join_port = port
		elif arg.begins_with("--host-port="):
			host_port = int(arg.trim_prefix("--host-port="))
		elif arg.begins_with("--join-port="):
			join_port = int(arg.trim_prefix("--join-port="))
		elif arg.begins_with("--soak="):
			soak_seconds = maxi(0, int(arg.trim_prefix("--soak=")))
		elif arg.begins_with("--shot="):
			shot_path = arg.trim_prefix("--shot=")
	print("[UI network] host=%s expected=%d host_port=%d join_port=%d soak=%d" % [str(_hosting), expected_players, host_port, join_port, soak_seconds])
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	var menu = game.menu
	var lobby_layer: Control = menu.get("_lobby_layer")
	var roster_box: VBoxContainer = menu.get("_lobby_roster_box")
	var start_button: Button = menu.get("_lobby_start_button")
	var ready_button: Button = menu.get("_lobby_ready_button")

	if _hosting:
		menu.host_requested.emit("HOST", host_port, 4242)
	else:
		menu.join_requested.emit("CLIENT", "127.0.0.1", join_port)

	var ready_sent := false
	var ready_checked := false
	var start_sent := false
	var lobby_checked := false
	var deadline := Time.get_ticks_msec() + 25000
	while not game.game_started and Time.get_ticks_msec() < deadline:
		await process_frame
		if _hosting:
			if not lobby_layer.visible:
				continue
			if not lobby_checked:
				lobby_checked = true
				_check(roster_box.get_child_count() == 4, "Lobby must keep four squad slots")
			if game.players.size() == expected_players and not start_sent:
				var ready_deadline := Time.get_ticks_msec() + 8000
				while start_button.disabled and Time.get_ticks_msec() < ready_deadline:
					await process_frame
				start_sent = true
				_check(not start_button.disabled, "Host start button stayed locked after the client readied")
				_check(start_button.text == "开始行动", "Host start button text is stale: %s" % start_button.text)
				_check(lobby_layer.visible, "Host lobby closed before the match started")
				menu.lobby_start_requested.emit()
		else:
			if not ready_sent and lobby_layer.visible and game.players.size() == expected_players:
				ready_sent = true
				menu.lobby_ready_requested.emit(true)
			if ready_sent and not ready_checked:
				# 准备状态以服务器回包为准；四人同房时回包可能晚于数个帧。
				var ready_deadline := Time.get_ticks_msec() + 3000
				while ready_button.text != "取消准备" and Time.get_ticks_msec() < ready_deadline:
					await process_frame
				ready_checked = true
				_check(ready_button.text == "取消准备", "Client ready button did not flip to 取消准备: %s" % ready_button.text)
				_check(lobby_layer.visible, "Client lobby closed before the match started")
	if not game.game_started:
		push_error("[%s] Match failed to start" % ("HOST" if _hosting else "CLIENT"))
		quit(1)
		return

	for i in range(30):
		await process_frame
	_check(game.players.size() == expected_players, "Roster did not reach the expected player count")
	var roster: VBoxContainer = game.hud.get("_roster_box")
	_check(roster.get_child_count() == expected_players, "HUD roster did not render the expected squad rows")
	_check(game.hud.get("_roster_panel").visible, "Squad HUD roster is hidden")
	_check(not lobby_layer.visible and not menu.visible, "Lobby/menu still visible after deployment")
	if _hosting and not shot_path.is_empty():
		await RenderingServer.frame_post_draw
		var image: Image = game.get_viewport().get_texture().get_image()
		if image != null:
			print("[UI network] shot %s (err=%d)" % [shot_path, image.save_png(shot_path)])

	# 联机暂停：只打开本地暂停层，不暂停 SceneTree，服务器继续模拟。
	var break_before := float(game.director.get("_break_left")) if game.director != null else 0.0
	game.call("_pause_game")
	await process_frame
	_check(not paused, "Co-op pause paused the SceneTree")
	_check(bool(game.get("_paused")), "Co-op pause did not open the pause state")
	_check(game.hud.get("_pause_overlay").visible, "Co-op pause overlay is hidden")
	_check(not game.player.input_enabled, "Co-op pause kept player input enabled")
	_check(String(game.hud.get("_pause_note").text).contains("服务器"), "Co-op pause note does not explain server simulation")
	await create_timer(1.2).timeout
	if _hosting and game.director != null:
		var break_after := float(game.director.get("_break_left"))
		_check(break_after < break_before - 0.4, "Host pause stopped the server director (break %.2f -> %.2f)" % [break_before, break_after])
	game.call("_resume_game")
	await process_frame
	_check(not bool(game.get("_paused")) and game.player != null and game.player.input_enabled, "Co-op resume did not restore input")
	_check(not game.hud.get("_pause_overlay").visible, "Co-op pause overlay did not close")

	if soak_seconds > 0:
		var soak_deadline := Time.get_ticks_msec() + soak_seconds * 1000
		var next_check := Time.get_ticks_msec() + 5000
		while Time.get_ticks_msec() < soak_deadline:
			await create_timer(1.0).timeout
			if Time.get_ticks_msec() >= next_check:
				next_check += 5000
				if Time.get_ticks_msec() < soak_deadline - 30000:
					_check(game.game_started and game.player != null, "Soak: match or player disappeared")
					_check(game.players.size() == expected_players, "Soak: player count drifted from %d" % expected_players)
					_check(game.hud.get("_roster_panel").visible, "Soak: squad HUD disappeared")
				print("[UI network] soak t=%ds players=%d break=%.2f" % [soak_seconds - int((soak_deadline - Time.get_ticks_msec()) / 1000.0), game.players.size(), float(game.director.get("_break_left")) if game.director != null else -1.0])
		print("UI network soak: %s, %d checks, %d failures" % ["HOST" if _hosting else "CLIENT", checks, failures])
		game.queue_free()
		await process_frame
		quit(1 if failures > 0 else 0)
		return

	if _hosting:
		# 让客户端先完成暂停/恢复断言，避免房主提前断开导致对端进入返回菜单流程。
		await create_timer(5.0).timeout

	# 退出清理：双端都回到菜单，不残留世界。
	game.hud.lobby_requested.emit()
	await process_frame
	await process_frame
	_check(not game.game_started and game.player == null and game.director == null, "Co-op return to menu left the world running")
	_check(game.menu.visible and not game.hud.visible, "Co-op return to menu did not restore the menu")
	_check(not paused, "Co-op return to menu left the tree paused")

	print("UI network: %s, %d checks, %d failures" % ["HOST" if _hosting else "CLIENT", checks, failures])
	game.queue_free()
	await process_frame
	quit(1 if failures > 0 else 0)
