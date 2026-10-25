extends Node

const MAX_PLAYERS := 4
const RESPAWN_TIME := 8.0
const SNAPSHOT_INTERVAL := 1.0 / 15.0
const SUMMARY_INTERVAL := 0.25
const STATE_INTERVAL := 1.0 / 12.0
const ZOMBIE_SCORE := {"walker": 10, "crawler": 14, "runner": 16, "brute": 30}
const ZOMBIE_NAMES := {"walker": "普通丧尸", "crawler": "爬行丧尸", "runner": "疾行丧尸", "brute": "重装丧尸"}
const CORES_REQUIRED := 3
const CORE_SECURE_SCORE := 120
const MISSION_BONUS := 300
const CARD_MAX_LEVEL := 3
const DRAW_TIMEOUT := 25.0
const CARD_POOL := [
	{"key": "mag", "title": "扩容弹匣", "desc": "全队弹匣容量 +6 发（霰弹 +2）", "accent": "#7fc3ba"},
	{"key": "reload", "title": "快速装填", "desc": "全队换弹时间 -10%", "accent": "#e6c07a"},
	{"key": "damage", "title": "膛压强化", "desc": "全队枪械伤害 +14%", "accent": "#e08a6f"},
	{"key": "rate", "title": "枪机抛光", "desc": "全队射速 +7%", "accent": "#8fb9cc"},
	{"key": "speed", "title": "轻装疾行", "desc": "全队移动速度 +5%", "accent": "#9bc284"},
	{"key": "armor", "title": "防弹插板", "desc": "全队受到伤害 -8%", "accent": "#b9a6d9"},
]

var menu: MainMenu
var hud: GameHUD
var player: LocalPlayer
var audio: DeadCityAudio

var _world: Node3D
var city: CityBuilder
var effects: CombatEffects
var director: ZombieDirector
var mission: MissionSite
var station: ChapterOneStation
var layout: Dictionary = {}
var players: Dictionary = {}
var remote_avatars: Dictionary = {}
var zombie_proxies: Dictionary = {}
var _zombie_states: Dictionary = {}

var local_id := 1
var local_name := "幸存者"
var seed_value := 2026
var team_score := 0
var game_started := false
var game_over := false
var is_server := false
var is_hosting := false
var solo_mode := false
var cores_secured := 0
var core_states: Array = []
var draw_tokens := 0
var mission_complete := false
var team_upgrades := {"mag": 0, "reload": 0, "damage": 0, "rate": 0, "speed": 0, "armor": 0}
var _mission_hint_text := "沿市中心公园坡道下到核心储藏层 B1"
var _mission_zone_text := "基地安全区"
var _pending_draw: Dictionary = {}
var _draw_open := false
var _draw_options: Array = []
var _draw_rng := RandomNumberGenerator.new()
var _interact_action := ""
var _interact_target := -1
var _teleport_grace := 0.0
var _paused := false
var _settings_panel: SettingsPanel
var _settings_from_game := false
var _starting_match := false
var _networked := false
var _leaving := false
var _connecting := false
var _connect_timer := 0.0
var _join_address := ""
var _host_port := 7777
var _lobby_active := false
var _lobby_ready: Dictionary = {}
var _run_active := false
var _run_wave := 1
var _meta: Dictionary = {}

var _snapshot_accum := 0.0
var _summary_accum := 0.0
var _state_accum := 0.0

var _cli_host := false
var _cli_solo := false
var _cli_join := ""
var _cli_port := 7777
var _cli_seed := 4242
var _cli_pilot := false
var _cli_capture := ""
var _cli_menu_shot := ""
var _cli_menu_view := ""
var _cli_menu_view_shot := ""
var _cli_hud_demo := ""
var _cli_result := ""
var _cli_lobby_shot := ""
var _demo_active := false
var _demo_health := -1.0
var _demo_roster: Array = []
var _demo_empty := false
var _cli_quit_after := 0.0
var _cli_capture_after := 7.0
var _cli_pause_after := 0.0
var _cli_mission := false
var _cli_mission_delay := 2.8
var _cli_mission_shots := ""
var _cli_reload_shot := ""
var _cli_armory_shot := ""
var _cli_intel_shot := ""
var _cli_backpack_shot := ""
var _cli_ui_scale := -1.0
var _cli_ui_contrast := false
var _cli_ui_reduced := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	multiplayer.connected_to_server.connect(_on_net_connected)
	multiplayer.connection_failed.connect(_on_net_connection_failed)
	multiplayer.server_disconnected.connect(_on_net_server_disconnected)
	multiplayer.peer_disconnected.connect(_on_net_peer_disconnected)
	multiplayer.peer_connected.connect(_on_net_peer_connected)
	audio = DeadCityAudio.new()
	audio.name = "Audio"
	add_child(audio)
	_build_ui()
	_meta = MetaProfile.load_profile()
	menu.set_profile(_meta)
	_parse_cli()
	if _cli_active():
		_run_cli()


func _build_ui() -> void:
	var ui := CanvasLayer.new()
	ui.name = "UI"
	ui.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(ui)
	menu = MainMenu.new()
	menu.name = "MainMenu"
	ui.add_child(menu)
	menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud = GameHUD.new()
	hud.name = "GameHUD"
	ui.add_child(hud)
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.visible = false
	_settings_panel = SettingsPanel.new()
	_settings_panel.name = "SettingsPanel"
	ui.add_child(_settings_panel)
	_settings_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_settings_panel.visible = false
	_settings_panel.closed.connect(_on_settings_closed)
	menu.settings_requested.connect(_open_settings_center.bind(false))
	hud.settings_requested.connect(_open_settings_center.bind(true))
	menu.host_requested.connect(_on_host_requested)
	menu.join_requested.connect(_on_join_requested)
	menu.solo_requested.connect(_on_solo_requested)
	menu.quit_requested.connect(_on_quit_requested)
	menu.lobby_ready_requested.connect(_on_lobby_ready_requested)
	menu.lobby_start_requested.connect(_on_lobby_start_requested)
	menu.lobby_leave_requested.connect(_on_lobby_leave_requested)
	menu.buy_weapon_requested.connect(_on_buy_weapon_requested)
	menu.equip_weapon_requested.connect(_on_equip_weapon_requested)
	hud.resume_requested.connect(_resume_game)
	hud.lobby_requested.connect(_on_lobby_requested)
	hud.card_picked.connect(_on_card_picked)
	hud.draw_cancelled.connect(_on_draw_cancelled)
	hud.weapon_selected.connect(_on_backpack_weapon_selected)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _parse_cli() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg == "--auto-host":
			_cli_host = true
		elif arg == "--auto-solo":
			_cli_solo = true
		elif arg == "--auto-pilot":
			_cli_pilot = true
		elif arg.begins_with("--auto-join="):
			_cli_join = arg.trim_prefix("--auto-join=")
		elif arg.begins_with("--auto-port="):
			_cli_port = clampi(int(arg.trim_prefix("--auto-port=")), 1024, 65535)
		elif arg.begins_with("--auto-seed="):
			_cli_seed = int(arg.trim_prefix("--auto-seed="))
		elif arg.begins_with("--capture="):
			_cli_capture = arg.trim_prefix("--capture=")
		elif arg.begins_with("--capture-after="):
			_cli_capture_after = maxf(1.0, float(arg.trim_prefix("--capture-after=")))
		elif arg.begins_with("--menu-shot="):
			_cli_menu_shot = arg.trim_prefix("--menu-shot=")
		elif arg.begins_with("--menu-view="):
			_cli_menu_view = arg.trim_prefix("--menu-view=")
		elif arg.begins_with("--menu-view-shot="):
			_cli_menu_view_shot = arg.trim_prefix("--menu-view-shot=")
		elif arg.begins_with("--hud-demo="):
			_cli_hud_demo = arg.trim_prefix("--hud-demo=")
		elif arg.begins_with("--result="):
			_cli_result = arg.trim_prefix("--result=")
		elif arg.begins_with("--lobby-shot="):
			_cli_lobby_shot = arg.trim_prefix("--lobby-shot=")
		elif arg.begins_with("--quit-after="):
			_cli_quit_after = maxf(1.0, float(arg.trim_prefix("--quit-after=")))
		elif arg.begins_with("--auto-pause-after="):
			_cli_pause_after = maxf(1.0, float(arg.trim_prefix("--auto-pause-after=")))
		elif arg == "--auto-mission":
			_cli_mission = true
		elif arg.begins_with("--mission-delay="):
			_cli_mission_delay = maxf(0.5, float(arg.trim_prefix("--mission-delay=")))
		elif arg.begins_with("--mission-shots="):
			_cli_mission_shots = arg.trim_prefix("--mission-shots=")
		elif arg.begins_with("--reload-shot="):
			_cli_reload_shot = arg.trim_prefix("--reload-shot=")
		elif arg.begins_with("--armory-shot="):
			_cli_armory_shot = arg.trim_prefix("--armory-shot=")
		elif arg.begins_with("--intel-shot="):
			_cli_intel_shot = arg.trim_prefix("--intel-shot=")
		elif arg.begins_with("--backpack-shot="):
			_cli_backpack_shot = arg.trim_prefix("--backpack-shot=")
		elif arg.begins_with("--ui-scale="):
			_cli_ui_scale = clampf(float(arg.trim_prefix("--ui-scale=")), 0.85, 1.2)
		elif arg == "--ui-contrast":
			_cli_ui_contrast = true
		elif arg == "--ui-reduced":
			_cli_ui_reduced = true


func _cli_active() -> bool:
	return _cli_host or _cli_solo or not _cli_join.is_empty() or not _cli_capture.is_empty() or not _cli_menu_shot.is_empty() or not _cli_menu_view.is_empty() or not _cli_hud_demo.is_empty() or not _cli_result.is_empty() or not _cli_lobby_shot.is_empty() or _cli_mission or not _cli_reload_shot.is_empty() or not _cli_armory_shot.is_empty() or not _cli_intel_shot.is_empty() or not _cli_backpack_shot.is_empty()


func _apply_ui_cli() -> void:
	## 截图/回归用：把无障碍设置应用到当前运行实例，不写入 user:// 配置。
	if _cli_ui_scale < 0.0 and not _cli_ui_contrast and not _cli_ui_reduced:
		return
	var settings := get_node_or_null("/root/UISettings")
	if settings == null:
		return
	if _cli_ui_scale >= 0.0:
		settings.set("hud_scale", _cli_ui_scale)
	if _cli_ui_contrast:
		settings.set("high_contrast", true)
	if _cli_ui_reduced:
		settings.set("reduced_motion", true)
	if settings.has_signal("changed"):
		settings.changed.emit("all")
	print("[DeadCity] ui cli: scale=%.2f contrast=%s reduced=%s" % [float(settings.get("hud_scale")), str(_cli_ui_contrast), str(_cli_ui_reduced)])


func _run_cli() -> void:
	_apply_ui_cli()
	if _cli_quit_after > 0.0:
		_quit_later(_cli_quit_after)
	if _cli_pause_after > 0.0:
		_pause_later(_cli_pause_after)
	if not _cli_menu_shot.is_empty():
		await get_tree().create_timer(0.8).timeout
		_capture(_cli_menu_shot)
	if not _cli_menu_view.is_empty():
		menu.open_view(_cli_menu_view)
		await get_tree().create_timer(0.45).timeout
		if not _cli_menu_view_shot.is_empty():
			await _capture(_cli_menu_view_shot)
	if not _cli_armory_shot.is_empty():
		await get_tree().create_timer(0.9).timeout
		menu.open_armory()
		await get_tree().create_timer(0.45).timeout
		await _capture(_cli_armory_shot)
		menu.close_armory()
	var delay := 0.6
	if not _cli_join.is_empty():
		delay = 2.2
	await get_tree().create_timer(delay).timeout
	if _cli_host:
		_on_host_requested("HOST", _cli_port, _cli_seed)
	elif not _cli_join.is_empty():
		_on_join_requested("CLIENT", _cli_join, _cli_port)
	elif _cli_solo:
		_on_solo_requested("SOLO", _cli_seed)
	if not _cli_lobby_shot.is_empty():
		await get_tree().create_timer(1.1).timeout
		await _capture(_cli_lobby_shot)
	if _cli_pilot:
		await get_tree().create_timer(3.0).timeout
		if player != null:
			player.auto_pilot = true
	if not _cli_hud_demo.is_empty():
		await _wait_for_game()
		await get_tree().create_timer(1.4).timeout
		_apply_hud_demo(_cli_hud_demo)
	elif not _cli_result.is_empty():
		await _wait_for_game()
		await get_tree().create_timer(1.0).timeout
		if _cli_result == "win":
			cores_secured = CORES_REQUIRED
		_server_game_over(_cli_result == "win")
	elif not _cli_capture.is_empty():
		await _wait_for_game()
		if player != null:
			player.set_input_enabled(false)
			player.set_view_direction(ChapterOneStation.SPAWN_YAW, -0.08)
	if _cli_mission:
		_run_mission_auto()
	if not _cli_reload_shot.is_empty():
		_run_reload_auto()
	if not _cli_intel_shot.is_empty():
		await _wait_for_game()
		await get_tree().create_timer(1.2).timeout
		_open_intel()
		await get_tree().create_timer(0.4).timeout
		await _capture(_cli_intel_shot)
		_close_overlays()
	if not _cli_backpack_shot.is_empty():
		await _wait_for_game()
		await get_tree().create_timer(1.4).timeout
		_open_backpack()
		await get_tree().create_timer(0.4).timeout
		await _capture(_cli_backpack_shot)
		_close_overlays()
	if not _cli_capture.is_empty():
		if _cli_hud_demo in ["reload", "strip"] and _cli_capture_after > 0.8:
			# 换弹与切枪提示是瞬态，截图前重新触发，避免等待期间已经结束。
			await get_tree().create_timer(_cli_capture_after - 0.5).timeout
			_apply_hud_demo(_cli_hud_demo)
			await get_tree().create_timer(0.35).timeout
		else:
			await get_tree().create_timer(_cli_capture_after).timeout
		_capture(_cli_capture)


func _apply_hud_demo(state: String) -> void:
	## 仅用于截图/回归的状态预览；不写入任何存档，也不改变服务器状态。
	## 真实状态每帧仍会刷新 HUD，因此这里记录演示值并在 _process 末尾回写。
	if hud == null or not game_started:
		return
	_demo_active = true
	_demo_health = -1.0
	_demo_roster = []
	_demo_empty = false
	if player != null:
		# 截图时锁定视角并关闭输入，避免窗口鼠标移动让相机转向随机物体。
		player.set_input_enabled(false)
		player.set_view_direction(ChapterOneStation.SPAWN_YAW, -0.08)
	print("[DeadCity] hud-demo applied: %s" % state)
	match state:
		"lowhealth":
			_demo_health = 21.0
			hud.set_health(21.0)
		"hurt":
			_demo_health = 52.0
			hud.set_health(52.0)
		"squad":
			_demo_roster = [
				{"id": 1, "name": "SOLO", "color": DeadCityUI.CYAN, "alive": true, "health": 100.0, "kills": 4, "is_local": true},
				{"id": 2, "name": "林昭", "color": DeadCityUI.AMBER, "alive": true, "health": 46.0, "kills": 7, "is_local": false, "distance": 9.0},
				{"id": 3, "name": "周野", "color": DeadCityUI.VIOLET, "alive": false, "health": 0.0, "kills": 2, "is_local": false, "distance": 12.0},
				{"id": 4, "name": "陈默", "color": DeadCityUI.CORAL, "alive": true, "health": 88.0, "kills": 3, "is_local": false, "distance": 6.0},
			]
			hud.set_roster(_demo_roster)
		"squad_low":
			_demo_roster = [
				{"id": 1, "name": "SOLO", "color": DeadCityUI.CYAN, "alive": true, "health": 22.0, "kills": 4, "is_local": true},
				{"id": 2, "name": "林昭", "color": DeadCityUI.AMBER, "alive": true, "health": 46.0, "kills": 7, "is_local": false, "distance": 9.0},
				{"id": 3, "name": "周野", "color": DeadCityUI.VIOLET, "alive": false, "health": 0.0, "kills": 2, "is_local": false, "distance": 12.0},
				{"id": 4, "name": "陈默", "color": DeadCityUI.CORAL, "alive": true, "health": 88.0, "kills": 3, "is_local": false, "distance": 6.0},
			]
			_demo_health = 22.0
			hud.set_roster(_demo_roster)
			hud.set_health(22.0)
		"carry":
			hud.set_carry_preview(true)
		"downed":
			_demo_health = 0.0
			hud.set_health(0.0)
			hud.set_down(true, 8.0)
		"reload":
			if player != null and player.alive:
				player.mag = maxi(0, player.mag_size - 9)
				player.start_reload()
		"empty":
			_demo_empty = true
			if player != null:
				player.mag = 0
				player.reloading = false
			hud.set_ammo(0, player.reserve if player != null else 0, false, 0.0, false)
		"strip":
			if player != null:
				hud.set_weapon_strip(player.loadout_summary(), player.weapon_profile())


func _wait_for_game() -> void:
	var waited := 0.0
	while not game_started and waited < 25.0:
		await get_tree().process_frame
		waited += get_process_delta_time()


func _run_reload_auto() -> void:
	await _wait_for_game()
	await get_tree().create_timer(1.2).timeout
	if player != null and player.alive:
		player.mag = maxi(0, player.mag_size - 9)
		player.start_reload()
		await get_tree().create_timer(0.48).timeout
		await _capture(_cli_reload_shot)


func _run_mission_auto() -> void:
	await _wait_for_game()
	if not is_server or mission == null:
		return
	await get_tree().create_timer(_cli_mission_delay).timeout
	_server_teleport_player(local_id, Vector3(-4.6, 0.18, -92.9), 0.0)
	await get_tree().create_timer(0.6).timeout
	if player != null:
		player.mag = 3
		player.reserve = 10
		player.ammo_changed.emit(player.mag, player.reserve, false)
	await get_tree().create_timer(0.2).timeout
	await _mission_shot("mission_ammo")
	_server_mission_interact(local_id)
	await get_tree().create_timer(0.35).timeout
	await _mission_shot("mission_base")
	_server_teleport_player(local_id, Vector3(0.0, 0.4, 18.6), 0.0)
	await get_tree().create_timer(0.4).timeout
	if player != null:
		player.aim_at(Vector3(0.0, 1.4, 13.2))
	await get_tree().create_timer(0.4).timeout
	await _mission_shot("mission_gateway")
	_server_teleport_player(local_id, Vector3(0.0, 16.0, 24.0), 0.0)
	await get_tree().create_timer(0.12).timeout
	if player != null:
		player.aim_at(Vector3(0.0, -2.0, 5.0))
	await get_tree().create_timer(0.12).timeout
	await _mission_shot("mission_overview")
	_server_teleport_player(local_id, Vector3(0.0, 0.4, 14.2), 0.0)
	await get_tree().create_timer(0.5).timeout
	if player != null:
		player.aim_at(Vector3(0.0, -11.5, -5.5))
	await get_tree().create_timer(0.4).timeout
	await _mission_shot("mission_ramp")
	_server_teleport_player(local_id, MissionSite.BASEMENT_ARRIVAL, PI)
	await get_tree().create_timer(0.6).timeout
	if player != null:
		player.aim_at(Vector3(0.0, -6.0, 1.0))
	await get_tree().create_timer(0.4).timeout
	await _mission_shot("mission_basement")
	for i in range(MissionSite.CORE_COUNT):
		var site: Vector3 = mission.core_site_pos(i)
		_server_teleport_player(local_id, site + Vector3(0.0, 0.16, 2.0), 0.0)
		await get_tree().create_timer(0.35).timeout
		_server_mission_interact(local_id)
		await get_tree().create_timer(0.35).timeout
		if i == 0:
			await _mission_shot("mission_carry")
		_server_teleport_player(local_id, Vector3(0.0, 0.18, -100.2), 0.0)
		await get_tree().create_timer(0.3).timeout
		_server_mission_interact(local_id)
		await get_tree().create_timer(0.7).timeout
		if i == 0:
			await _mission_shot("mission_draw")
		_server_pick_card(local_id, 0)
		await get_tree().create_timer(0.7).timeout
	await get_tree().create_timer(1.0).timeout
	await _mission_shot("mission_victory")


func _mission_shot(shot_name: String) -> void:
	if _cli_mission_shots.is_empty():
		return
	var folder := _cli_mission_shots.replace("\\", "/").trim_suffix("/")
	await _capture("%s/%s.png" % [folder, shot_name])


func _quit_later(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
	get_tree().quit()


func _pause_later(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
	if game_started and not game_over and not _paused:
		_pause_game()


func _capture(path: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	if image == null:
		return
	var folder := path.get_base_dir()
	if not folder.is_empty():
		DirAccess.make_dir_recursive_absolute(folder)
	var result := image.save_png(path)
	print("[DeadCity] capture %s (err=%d)" % [path, result])


func _on_host_requested(requested_name: String, port: int, world_seed: int) -> void:
	if game_started or _starting_match or _connecting:
		return
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, MAX_PLAYERS - 1)
	if err != OK:
		menu.present("无法创建房间：端口 %d 可能被占用。" % port, true)
		return
	multiplayer.multiplayer_peer = peer
	_networked = true
	_leaving = false
	is_server = true
	is_hosting = true
	solo_mode = false
	local_id = 1
	local_name = requested_name
	seed_value = world_seed
	_host_port = port
	menu.set_busy(false)
	_open_host_lobby()


func _on_solo_requested(requested_name: String, world_seed: int) -> void:
	if game_started or _starting_match or _connecting:
		return
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	_networked = false
	_leaving = false
	is_server = true
	is_hosting = false
	solo_mode = true
	local_id = 1
	local_name = requested_name
	seed_value = world_seed
	menu.set_busy(true, "正在准备单人演练…")
	_start_solo_match()


func _on_buy_weapon_requested(weapon_id: String) -> void:
	if game_started:
		return
	var result := MetaProfile.buy_weapon(_meta, weapon_id)
	var ok := bool(result.get("ok", false))
	if menu != null:
		menu.set_armory_status(String(result.get("message", "")), not ok)
	if ok:
		_persist_meta()
		if audio != null:
			audio.play_ui("supply", -4.0)


func _on_equip_weapon_requested(weapon_id: String) -> void:
	if game_started:
		return
	var result := MetaProfile.select_weapon(_meta, weapon_id)
	var ok := bool(result.get("ok", false))
	if menu != null:
		menu.set_armory_status(String(result.get("message", "")), not ok)
	if ok:
		_persist_meta()
		if audio != null:
			audio.play_ui("switch", -6.0)


func _on_join_requested(requested_name: String, address: String, port: int) -> void:
	if game_started or _starting_match or _connecting:
		return
	local_name = requested_name
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(address, port)
	if err != OK:
		menu.present("无法连接 %s:%d，请检查地址与端口。" % [address, port], true)
		return
	multiplayer.multiplayer_peer = peer
	_networked = true
	_leaving = false
	is_server = false
	is_hosting = false
	solo_mode = false
	_join_address = address
	_connecting = true
	_connect_timer = 10.0
	menu.set_busy(true, "正在连接 %s:%d…" % [address, port])


func _on_quit_requested() -> void:
	get_tree().quit()


func _on_lobby_requested() -> void:
	_return_to_menu("已结束本次行动。")


func _start_host_match() -> void:
	_open_host_lobby()


func _open_host_lobby() -> void:
	_lobby_active = true
	_lobby_ready.clear()
	players.clear()
	_lobby_ready[1] = true
	_server_add_player(1, local_name)
	menu.visible = true
	menu.show_lobby(true, 1, _lobby_payload())
	_update_connection_info()
	if _cli_host:
		_cli_lobby_autostart()


func _lobby_payload() -> Dictionary:
	return {
		"seed": seed_value,
		"port": _host_port,
		"host_id": 1,
		"players": _roster_payload(),
		"ready": _lobby_ready.duplicate(),
		"all_ready": _lobby_all_ready(),
	}


func _lobby_all_ready() -> bool:
	if players.is_empty():
		return false
	for id in players.keys():
		if not bool(_lobby_ready.get(int(id), _lobby_ready.get(str(id), false))):
			return false
	return true


func _refresh_lobby() -> void:
	if not _lobby_active or menu == null:
		return
	menu.update_lobby(_lobby_payload(), local_id)


func _broadcast_lobby() -> void:
	_refresh_lobby()
	if multiplayer.get_peers().size() > 0:
		rpc("_net_lobby_state", _lobby_payload())


func _on_lobby_ready_requested(value: bool) -> void:
	if not _lobby_active or game_started:
		return
	if is_server:
		_lobby_ready[local_id] = value
		_broadcast_lobby()
	elif multiplayer.multiplayer_peer != null:
		rpc_id(1, "_net_lobby_ready", value)


func _on_lobby_start_requested() -> void:
	if not is_server or not is_hosting or not _lobby_active or game_started or _starting_match:
		return
	if not _lobby_all_ready():
		menu.set_lobby_status("还有队员没有准备，无法开始行动。", true)
		return
	_host_begin_match()


func _on_lobby_leave_requested() -> void:
	if _lobby_active and not game_started:
		_return_to_menu("已离开准备房间。")


func _cli_lobby_autostart() -> void:
	var waited := 0.0
	while waited < 20.0 and _lobby_active:
		if multiplayer.get_peers().size() > 0 and _lobby_all_ready():
			break
		if multiplayer.get_peers().size() == 0 and waited >= 8.0:
			break
		await get_tree().create_timer(0.2).timeout
		waited += 0.2
	if not _lobby_active:
		return
	await get_tree().create_timer(0.6).timeout
	if _lobby_active and _lobby_all_ready():
		_on_lobby_start_requested()


func _host_begin_match() -> void:
	_starting_match = true
	_lobby_active = false
	menu.hide_lobby()
	var ready_ok: bool = await _prepare_world(seed_value)
	if not ready_ok:
		_starting_match = false
		return
	if not players.has(1):
		_server_add_player(1, local_name)
	var info: Dictionary = players.get(1, {})
	var spawn: Vector3 = info.get("pos", MissionSite.SAFE_SPAWNS[0])
	_place_local_player(spawn, float(info.get("yaw", PI)))
	director.start(6.0)
	game_started = true
	_starting_match = false
	_begin_run_record()
	_sync_run_record()
	_update_connection_info()
	_capture_mouse()
	if multiplayer.get_peers().size() > 0:
		rpc("_net_lobby_start", seed_value, _roster_payload(), _mission_payload(), team_score, director.summary())
	hud.announce("第一章 · 失联信号", "E-07 维护站 · 经西侧楼梯下楼，前往基地补给", DeadCityUI.CYAN, 5.0)


func _start_solo_match() -> void:
	_starting_match = true
	_lobby_active = false
	var ready_ok: bool = await _prepare_world(seed_value)
	if not ready_ok:
		return
	_server_add_player(1, local_name)
	var info: Dictionary = players.get(1, {})
	var spawn: Vector3 = info.get("pos", MissionSite.SAFE_SPAWNS[0])
	_place_local_player(spawn, float(info.get("yaw", PI)))
	director.start(5.0)
	game_started = true
	_starting_match = false
	_begin_run_record()
	_sync_run_record()
	menu.set_busy(false)
	_update_connection_info()
	_capture_mouse()
	hud.announce("第一章 · 失联信号", "E-07 维护站 · 经西侧楼梯下楼，前往基地补给", DeadCityUI.CYAN, 5.0)


func _start_client_match(world_seed: int, roster: Array, summary: Dictionary, score: int, mission_data: Dictionary) -> void:
	_starting_match = true
	_lobby_active = false
	menu.hide_lobby()
	var ready_ok: bool = await _prepare_world(world_seed)
	if not ready_ok:
		return
	if game_over:
		_return_to_menu("本轮行动已经结束，请加入新的房间。")
		return
	_apply_roster(roster)
	if not players.has(local_id):
		_return_to_menu("同步失败：服务器未登记本地玩家。")
		return
	_apply_mission_state(mission_data)
	var info: Dictionary = players[local_id]
	_place_local_player(info.get("pos", MissionSite.SAFE_SPAWNS[0]), float(info.get("yaw", PI)))
	hud.set_wave(summary)
	hud.set_score(score)
	game_started = true
	_starting_match = false
	_begin_run_record()
	_sync_run_record()
	menu.set_busy(false)
	_update_connection_info()
	_capture_mouse()
	hud.announce("投入行动", "地图 #%d · 与队友会合" % seed_value, DeadCityUI.CYAN, 2.6)


func _prepare_world(world_seed: int) -> bool:
	menu.visible = false
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.visible = true
	hud.reset_for_match()
	hud.show_loading("正在生成街区 #%d…" % world_seed)
	await get_tree().process_frame
	if not _starting_match:
		hud.hide_loading()
		hud.visible = false
		menu.visible = true
		return false
	_teardown_world()
	seed_value = world_seed
	_world = Node3D.new()
	_world.name = "World"
	_world.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(_world)
	_build_environment()
	layout = CityLayout.generate(seed_value)
	ChapterOneStation.prepare_layout(layout)
	city = CityBuilder.new()
	city.name = "City"
	_world.add_child(city)
	city.build(layout)
	station = ChapterOneStation.new()
	station.name = "ChapterOneStation"
	_world.add_child(station)
	station.build()
	mission = MissionSite.new()
	mission.name = "MissionSite"
	_world.add_child(mission)
	mission.build()
	effects = CombatEffects.new()
	effects.name = "CombatEffects"
	_world.add_child(effects)
	director = ZombieDirector.new()
	director.name = "ZombieDirector"
	_world.add_child(director)
	director.setup(_director_layout(), 0)
	director.attacked_player.connect(_on_zombie_attacked)
	director.fused.connect(_on_zombie_fused)
	_spawn_local_player_node()
	_draw_rng.seed = seed_value * 3413 + 77
	if is_server:
		_server_reset_mission()
	hud.setup_world(layout)
	hud.set_health(100.0)
	hud.set_ammo(player.mag, player.reserve, false, 0.0, player.is_melee_equipped())
	hud.set_weapon_strip(player.loadout_summary(), player.weapon_profile())
	hud.set_mission(cores_secured, CORES_REQUIRED, draw_tokens,
		"经西侧楼梯下楼，前往基地补给，再到公园 B1 回收核心", "第一章 · E-07 维护站", DeadCityUI.CYAN, team_upgrades, false, MetaProfile.power_of(team_upgrades))
	hud.hide_loading()
	return true


func _build_environment() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("#070d18")
	sky_material.sky_horizon_color = Color("#27313c")
	sky_material.ground_bottom_color = Color("#070a0e")
	sky_material.ground_horizon_color = Color("#1a222b")
	sky_material.sky_curve = 0.16
	sky_material.ground_curve = 0.05
	sky_material.sun_angle_max = 22.0
	sky.sky_material = sky_material
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_sky_contribution = 0.85
	environment.ambient_light_energy = 0.55
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_exposure = 1.05
	environment.glow_enabled = true
	environment.glow_intensity = 0.45
	environment.glow_bloom = 0.08
	environment.fog_enabled = true
	environment.fog_light_color = Color("#1b2833")
	environment.fog_light_energy = 0.7
	environment.fog_density = 0.006
	environment.fog_sky_affect = 0.35
	environment.background_energy_multiplier = 0.9
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	_world.add_child(world_environment)
	var moon := DirectionalLight3D.new()
	moon.name = "Moonlight"
	moon.rotation_degrees = Vector3(-52.0, 38.0, 0.0)
	moon.light_color = Color("#b9cfe8")
	moon.light_energy = 1.15
	moon.shadow_enabled = true
	moon.directional_shadow_max_distance = 140.0
	moon.shadow_blur = 1.2
	_world.add_child(moon)


func _spawn_local_player_node() -> void:
	player = LocalPlayer.new()
	player.name = "Player"
	_world.add_child(player)
	player.effects = effects
	player.main_ref = self
	player.audio = audio
	var bonus := MetaProfile.legacy_bonus(_meta)
	player.set_meta_bonus(int(bonus["reserve"]), float(bonus["reload_mult"]))
	player.set_loadout(MetaProfile.equipped_weapons(_meta), String(_meta.get("selected_weapon", WeaponCatalog.DEFAULT_SELECTED)))
	player.set_game_active(false)
	player.health_changed.connect(_on_local_health_changed)
	player.damaged.connect(_on_local_damaged)
	player.hit_marker.connect(_on_local_hit_marker)
	player.weapon_changed.connect(_on_weapon_changed)


func _place_local_player(spawn: Vector3, face_yaw_value: float = PI) -> void:
	if player == null:
		return
	player.respawn_at(spawn, face_yaw_value)
	player.set_game_active(true)
	player.set_input_enabled(true)
	player.auto_pilot = _cli_pilot
	hud.set_down(false)
	hud.set_health(100.0)
	hud.set_ammo(player.mag, player.reserve, false, 0.0, player.is_melee_equipped())
	hud.set_weapon_strip(player.loadout_summary(), player.weapon_profile())


func _process(delta: float) -> void:
	if get_tree().paused:
		return
	_teleport_grace = maxf(0.0, _teleport_grace - delta)
	if _connecting:
		_connect_timer -= delta
		if _connect_timer <= 0.0:
			_fail_connection("连接超时，请确认主机地址与端口。")
	if not game_started:
		return
	if is_server and not game_over:
		_server_step(delta)
	elif not is_server:
		_client_step(delta)
	if player != null and hud != null:
		hud.set_ammo(player.mag, player.reserve, player.is_reloading(), player.reload_progress(), player.is_melee_equipped())
		hud.set_spread(player.get_spread_normalized())
		hud.set_minimap_entities(player.global_position, player.rotation.y, _minimap_remotes(), _minimap_zombies(), _minimap_markers())
		hud.set_compass_heading(player.rotation.y)
		_update_mission_hud()
	if _demo_active and hud != null:
		# 截图演示值必须压过真实状态同步，否则低血量/小队截图会退回默认值。
		if _demo_health >= 0.0:
			hud.set_health(_demo_health)
		if not _demo_roster.is_empty():
			hud.set_roster(_demo_roster)
		if _demo_empty and player != null:
			hud.set_ammo(0, player.reserve, false, 0.0, player.is_melee_equipped())


func _unhandled_input(event: InputEvent) -> void:
	if _settings_panel != null and _settings_panel.visible:
		return
	if not game_started or game_over:
		return
	if _draw_open:
		if event is InputEventKey:
			var draw_key := event as InputEventKey
			if draw_key.pressed and not draw_key.echo:
				if draw_key.physical_keycode == KEY_ESCAPE:
					_on_draw_cancelled()
				elif draw_key.physical_keycode == KEY_1 or draw_key.physical_keycode == KEY_KP_1:
					_on_card_picked(0)
				elif draw_key.physical_keycode == KEY_2 or draw_key.physical_keycode == KEY_KP_2:
					_on_card_picked(1)
				elif draw_key.physical_keycode == KEY_3 or draw_key.physical_keycode == KEY_KP_3:
					_on_card_picked(2)
				get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		if _overlay_open():
			_close_overlays()
		elif _paused:
			_resume_game()
		else:
			_pause_game()
		get_viewport().set_input_as_handled()
		return
	if _overlay_open():
		if event is InputEventKey:
			var overlay_key := event as InputEventKey
			if overlay_key.pressed and not overlay_key.echo:
				if event.is_action_pressed("intel") or event.is_action_pressed("backpack"):
					_close_overlays()
					get_viewport().set_input_as_handled()
		return
	if _paused or player == null or not player.alive:
		return
	if event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and not key.echo:
			if event.is_action_pressed("intel"):
				_open_intel()
				get_viewport().set_input_as_handled()
			elif event.is_action_pressed("backpack"):
				_open_backpack()
				get_viewport().set_input_as_handled()
			elif event.is_action_pressed("interact"):
				_request_interact()
				get_viewport().set_input_as_handled()
			elif event.is_action_pressed("drop_core"):
				_request_drop()
				get_viewport().set_input_as_handled()


func _open_settings_center(from_game: bool) -> void:
	if _settings_panel == null:
		return
	if _settings_panel.visible:
		return
	_settings_from_game = from_game and game_started and not game_over
	if _settings_from_game and not _paused:
		_pause_game()
	_release_mouse()
	_settings_panel.open(_settings_from_game)


func _on_settings_closed() -> void:
	if _settings_from_game:
		if _paused and hud != null:
			hud.set_pause_visible(true)
			var resume_button := hud.get("_pause_resume") as Button
			if resume_button != null:
				resume_button.grab_focus.call_deferred()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		if menu != null:
			menu.visible = true
			menu.call("_select", 4, true)
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_settings_from_game = false


func _pause_game() -> void:
	if not game_started or game_over:
		return
	if _overlay_open():
		hud.call("close_overlays")
	_paused = true
	if solo_mode:
		get_tree().paused = true
	if player != null:
		player.set_input_enabled(false)
	hud.set_pause_note("已释放鼠标 · 单人演练已暂停" if solo_mode else "已释放鼠标 · 战斗仍在服务器上继续")
	hud.set_pause_visible(true)
	_release_mouse()


func _resume_game() -> void:
	if not game_started or game_over:
		return
	_paused = false
	get_tree().paused = false
	hud.set_pause_visible(false)
	if player != null:
		player.set_input_enabled(player.alive)
		if player.alive:
			_capture_mouse()


func _capture_mouse() -> void:
	if not game_started or game_over or _paused:
		return
	if player == null or not player.alive:
		return
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _release_mouse() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _overlay_open() -> bool:
	return hud != null and hud.has_method("overlay_open") and bool(hud.call("overlay_open"))


func _open_intel() -> void:
	if hud == null or player == null:
		return
	hud.call("open_intel", _intel_payload())
	_set_overlay_input(false)


func _open_backpack() -> void:
	if hud == null or player == null:
		return
	hud.call("open_backpack", player.loadout_summary(), player.weapon_profile(), team_upgrades)
	_set_overlay_input(false)


func _close_overlays() -> void:
	if hud != null:
		hud.call("close_overlays")
	_set_overlay_input(true)


func _set_overlay_input(active: bool) -> void:
	if player != null and not _paused and not game_over:
		player.set_input_enabled(active and player.alive)
	if active and not _paused and not game_over:
		_capture_mouse()
	else:
		_release_mouse()


func _intel_payload() -> Dictionary:
	var local_info: Dictionary = players.get(local_id, {})
	return {
		"mission": {
			"cores": cores_secured,
			"required": CORES_REQUIRED,
			"tokens": draw_tokens,
			"hint": _mission_hint_text,
			"zone": _mission_zone_text,
			"upgrades": team_upgrades.duplicate(),
			"power": MetaProfile.power_of(team_upgrades),
			"frenzy": director != null and director.is_frenzy(),
			"wave": _run_wave,
			"score": team_score,
		},
		"roster": _roster_payload(),
		"player": {
			"name": String(local_info.get("name", local_name)),
			"health": player.health if player != null else 100.0,
			"weapon": player.weapon_profile() if player != null else {},
			"loadout": player.loadout_summary() if player != null else [],
			"kills": int(local_info.get("kills", 0)),
			"reserve_bonus": int(MetaProfile.legacy_bonus(_meta).get("reserve", 0)),
		},
	}


func _on_backpack_weapon_selected(weapon_id: String) -> void:
	if player == null:
		return
	var index := player.weapons_owned.find(weapon_id)
	if index < 0:
		if hud != null:
			hud.announce("尚未解锁", "%s 可在主菜单军械库购买" % WeaponCatalog.display_name(weapon_id), DeadCityUI.AMBER, 1.6)
		return
	if player.switch_weapon_slot(index + 1):
		_close_overlays()
	elif hud != null:
		hud.announce("无法切换", "搬运核心或换弹时无法切换武器", DeadCityUI.AMBER, 1.4)


func _server_step(delta: float) -> void:
	director.tick(delta, _director_targets())
	_server_update_players(delta)
	_tick_pending_draw(delta)
	if game_over:
		return
	if player != null and player.alive:
		_state_accum += delta
		if _state_accum >= STATE_INTERVAL:
			_state_accum = 0.0
			_store_local_state()
	_snapshot_accum += delta
	if _snapshot_accum >= SNAPSHOT_INTERVAL:
		_snapshot_accum = 0.0
		_broadcast_snapshot()
	_summary_accum += delta
	if _summary_accum >= SUMMARY_INTERVAL:
		_summary_accum = 0.0
		_broadcast_summary()


func _client_step(delta: float) -> void:
	if player == null or not player.alive:
		return
	_state_accum += delta
	if _state_accum >= STATE_INTERVAL:
		_state_accum = 0.0
		_store_local_state()


func _store_local_state() -> void:
	if player == null or not player.alive:
		return
	var pos := _sanitize_position(player.global_position)
	if is_server:
		var info: Dictionary = players.get(local_id, {})
		if info.is_empty():
			return
		info["pos"] = pos
		info["yaw"] = player.rotation.y
	else:
		rpc_id(1, "_net_submit_state", pos, player.rotation.y)


func _sanitize_position(pos: Vector3) -> Vector3:
	var half := float(layout.get("total_size", 200.0)) * 0.5 - 0.7
	return Vector3(clampf(pos.x, -half, half), clampf(pos.y, -18.0, 26.0), clampf(pos.z, -half, half))


func _server_update_players(delta: float) -> void:
	for id in players.keys():
		var info: Dictionary = players[id]
		var cool := float(info.get("teleport_cool", 0.0))
		if cool > 0.0:
			info["teleport_cool"] = maxf(0.0, cool - delta)
		if bool(info["alive"]):
			var hurt := float(info.get("hurt_cool", 0.0))
			if hurt > 0.0:
				info["hurt_cool"] = maxf(0.0, hurt - delta)
			elif float(info["health"]) < 100.0:
				info["health"] = minf(100.0, float(info["health"]) + 2.2 * delta)
		else:
			var left := maxf(0.0, float(info.get("respawn_left", 0.0)) - delta)
			info["respawn_left"] = left
			if left <= 0.0:
				var respawn_pos := _server_pick_spawn()
				info["pos"] = respawn_pos
				info["health"] = 100.0
				info["alive"] = true
				info["hurt_cool"] = 0.0
				_notify_player_respawn(int(id), respawn_pos)
				if multiplayer.get_peers().size() > 0:
					rpc("_net_player_respawn", int(id), respawn_pos)


func _on_zombie_attacked(player_id: int, damage: float) -> void:
	if game_over:
		return
	var info: Dictionary = players.get(player_id, {})
	if info.is_empty() or not bool(info["alive"]):
		return
	var reduction := clampf(0.08 * int(team_upgrades.get("armor", 0)), 0.0, 0.4)
	info["health"] = maxf(0.0, float(info["health"]) - damage * (1.0 - reduction))
	info["hurt_cool"] = 6.0
	if float(info["health"]) <= 0.0:
		_down_player(player_id)


func _down_player(player_id: int) -> void:
	var info: Dictionary = players.get(player_id, {})
	if info.is_empty():
		return
	_server_release_core(player_id, true)
	_abort_pending_draw(player_id, true)
	info["health"] = 0.0
	info["alive"] = false
	info["respawn_left"] = RESPAWN_TIME
	info["hurt_cool"] = 0.0
	var wiped := _server_all_down()
	_notify_player_down(player_id, String(info["name"]), not wiped)
	if multiplayer.get_peers().size() > 0:
		rpc("_net_player_down", player_id, String(info["name"]))
	if wiped:
		_server_game_over(false)


func _server_all_down() -> bool:
	if players.is_empty():
		return false
	for info in players.values():
		if bool(info["alive"]):
			return false
	return true


func _server_game_over(victory: bool = false) -> void:
	if game_over:
		return
	game_over = true
	director.stop()
	_abort_pending_draw(0, true)
	var total_kills := 0
	for info in players.values():
		total_kills += int(info["kills"])
	var wave := int(director.summary().get("wave", 1))
	var stats := ""
	if victory:
		mission_complete = true
		team_score += MISSION_BONUS
		stats = "核心回收完成    ·    全队击杀 %d    ·    行动得分 %d" % [total_kills, team_score]
	else:
		stats = "抵达第 %d 波    ·    全队击杀 %d    ·    核心 %d / %d    ·    行动得分 %d" % [wave, total_kills, cores_secured, CORES_REQUIRED, team_score]
	_broadcast_mission_state()
	_handle_game_over(stats, victory)
	if multiplayer.get_peers().size() > 0:
		rpc("_net_game_over", stats, victory)


func _handle_game_over(stats: String, victory: bool = false) -> void:
	_finish_run_record(victory, stats)
	game_over = true
	mission_complete = mission_complete or victory
	_paused = false
	_draw_open = false
	get_tree().paused = false
	if hud != null:
		hud.call("close_overlays")
	hud.set_pause_visible(false)
	hud.set_down(false)
	if not victory:
		hud.set_health(0.0, 100.0)
		if player != null:
			player.apply_health(0.0)
	hud.show_game_over(stats + "\n" + MetaProfile.archive_line(_meta), victory)
	if player != null:
		player.set_input_enabled(false)
	_release_mouse()


func _run_player_names() -> Array:
	var ids: Array = players.keys()
	ids.sort()
	var names: Array = []
	for id in ids:
		var info: Dictionary = players[id]
		names.append(String(info.get("name", "幸存者")))
	return names


func _team_kills() -> int:
	var total := 0
	for info in players.values():
		total += int(info.get("kills", 0))
	return total


func _begin_run_record() -> void:
	MetaProfile.start_run(_meta, seed_value, _run_player_names())
	_run_wave = 1
	_run_active = true
	_persist_meta()


func _sync_run_record() -> void:
	if not _run_active:
		return
	MetaProfile.sync_run(_meta, team_upgrades, cores_secured, team_score, _team_kills(), _run_wave, _run_player_names())
	_persist_meta()


func _finish_run_record(victory: bool, stats: String) -> void:
	if not _run_active:
		return
	MetaProfile.sync_run(_meta, team_upgrades, cores_secured, team_score, _team_kills(), _run_wave, _run_player_names())
	MetaProfile.finish_run(_meta, victory, stats)
	_run_active = false
	_persist_meta()


func _persist_meta() -> void:
	MetaProfile.save_profile(_meta)
	if menu != null:
		menu.set_profile(_meta)


func _broadcast_snapshot() -> void:
	var entries: Array = []
	for id in players.keys():
		var info: Dictionary = players[id]
		var pos: Vector3 = info["pos"]
		entries.append([
			int(id), pos.x, pos.y, pos.z, float(info["yaw"]),
			float(info["health"]), bool(info["alive"]), int(info["kills"]),
			float(info.get("respawn_left", 0.0)),
		])
	var zombie_data: Array = director.snapshots()
	if multiplayer.get_peers().size() > 0:
		rpc("_net_snapshot", entries, zombie_data)
	_apply_world(entries, zombie_data)


func _broadcast_summary() -> void:
	var summary := director.summary()
	_run_wave = int(summary.get("wave", _run_wave))
	if multiplayer.get_peers().size() > 0:
		rpc("_net_summary", summary, team_score)
	hud.set_wave(summary)
	hud.set_score(team_score)
	_refresh_roster_ui()


func _director_targets() -> Array:
	var targets: Array = []
	for id in players.keys():
		var info: Dictionary = players[id]
		if not bool(info["alive"]):
			continue
		var pos: Vector3 = info["pos"]
		if mission != null and not mission.is_zombie_target(pos):
			continue
		targets.append({"id": int(id), "pos": pos, "alive": true})
	return targets


func _on_net_connected() -> void:
	if is_server:
		return
	menu.set_status("已连接，正在同步行动数据…")
	rpc_id(1, "_net_join_request", local_name)


func _on_net_connection_failed() -> void:
	if _leaving:
		return
	_fail_connection("无法连接主机，请检查地址与端口。")


func _on_net_server_disconnected() -> void:
	if _leaving:
		return
	if game_started or _starting_match or _lobby_active:
		_return_to_menu("与主机的连接已断开。")
	else:
		_fail_connection("主机已关闭连接。")


func _on_net_peer_connected(peer_id: int) -> void:
	print("[DeadCity] peer connected: %d" % peer_id)


func _on_net_peer_disconnected(peer_id: int) -> void:
	if not is_server:
		return
	if game_started or _lobby_active:
		_remove_player(peer_id)


func _fail_connection(message: String) -> void:
	_connecting = false
	_networked = false
	_lobby_active = false
	_lobby_ready.clear()
	var peer := multiplayer.multiplayer_peer
	if peer is ENetMultiplayerPeer:
		peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	menu.present(message, true)


func request_zombie_hit(zid: int, headshot: bool, weapon_id: String = "smg") -> void:
	if not game_started or game_over or player == null or not player.alive:
		return
	if is_server:
		_server_apply_hit(local_id, zid, headshot, weapon_id)
	else:
		rpc_id(1, "_net_request_hit", zid, headshot, weapon_id)


func _server_apply_hit(shooter_id: int, zid: int, headshot: bool, weapon_id: String = "smg") -> void:
	if not is_server or game_over:
		return
	var info: Dictionary = players.get(shooter_id, {})
	if info.is_empty() or not bool(info["alive"]):
		return
	var weapon := WeaponCatalog.data(weapon_id)
	if WeaponCatalog.is_melee(weapon_id):
		var shooter_pos: Vector3 = info.get("pos", Vector3.ZERO)
		var target_pos := director.zombie_position(zid)
		if target_pos.y > 1.0e8:
			return
		var reach := float(weapon.get("range", 2.9)) + 1.8
		if _flat_distance(shooter_pos, target_pos) > reach or absf(shooter_pos.y - target_pos.y) > 2.4:
			return
	var damage := float(weapon.get("damage", 19.0))
	if headshot:
		damage *= float(weapon.get("headshot", 2.4))
	damage *= 1.0 + 0.14 * int(team_upgrades.get("damage", 0))
	var result: Dictionary = director.damage_zombie(zid, damage)
	if not bool(result.get("ok", false)):
		return
	if not bool(result.get("killed", false)):
		return
	var kind := String(result.get("kind", "walker"))
	var death_pos: Vector3 = result.get("pos", Vector3.ZERO)
	var mass := int(result.get("mass", 0))
	var ability := String(result.get("ability", "none"))
	var points := int(ZOMBIE_SCORE.get(kind, 10)) * (1 + mass)
	if ability != "none":
		points += 6
	if ability == "volatile":
		var blast := 24.0 + 10.0 * mass
		for pid in players.keys():
			var target: Dictionary = players[pid]
			if not bool(target.get("alive", false)):
				continue
			var target_pos: Vector3 = target.get("pos", Vector3.ZERO)
			if target_pos.distance_to(death_pos) <= 4.8:
				_on_zombie_attacked(int(pid), blast)
	info["kills"] = int(info["kills"]) + 1
	team_score += points
	var killer_name := String(info["name"])
	var killer_color: Color = info["color"]
	_handle_zombie_killed(zid, kind, death_pos, headshot, shooter_id, killer_name, killer_color, points)
	if multiplayer.get_peers().size() > 0:
		rpc("_net_zombie_killed", zid, kind, death_pos, headshot, shooter_id, killer_name, killer_color, points)


@rpc("any_peer", "call_remote", "reliable")
func _net_join_request(requested_name: String) -> void:
	if not is_server or not is_hosting:
		return
	var sender := multiplayer.get_remote_sender_id()
	if sender <= 0:
		return
	if game_started or _starting_match:
		rpc_id(sender, "_net_join_denied", "行动已经开始，中途无法加入。")
		return
	if not _lobby_active:
		rpc_id(sender, "_net_join_denied", "房间正在部署，请稍后重试。")
		return
	if not players.has(sender) and players.size() >= MAX_PLAYERS:
		rpc_id(sender, "_net_join_denied", "房间已满（最多 4 人）。")
		return
	if not players.has(sender):
		var clean := requested_name.replace("\n", " ").replace("\t", " ").strip_edges()
		if clean.is_empty():
			clean = "幸存者"
		_lobby_ready[sender] = false
		_server_add_player(sender, clean.left(12))
	rpc_id(sender, "_net_lobby_welcome", seed_value, sender, _lobby_payload())
	_broadcast_lobby()


@rpc("authority", "call_remote", "reliable")
func _net_lobby_welcome(world_seed: int, assigned_id: int, payload: Dictionary) -> void:
	if is_server or game_started or _starting_match:
		return
	_connecting = false
	local_id = assigned_id
	seed_value = world_seed
	players.clear()
	_lobby_ready = payload.get("ready", {}).duplicate()
	_apply_roster(payload.get("players", []))
	_lobby_active = true
	menu.set_busy(false)
	menu.visible = true
	menu.show_lobby(false, local_id, payload)
	if not _cli_join.is_empty():
		await get_tree().create_timer(0.45).timeout
		if _lobby_active and not game_started:
			_on_lobby_ready_requested(true)


@rpc("authority", "call_remote", "reliable")
func _net_lobby_state(payload: Dictionary) -> void:
	if is_server or game_started:
		return
	_lobby_ready = payload.get("ready", {}).duplicate()
	_apply_roster(payload.get("players", []))
	if _lobby_active:
		menu.update_lobby(payload, local_id)


@rpc("any_peer", "call_remote", "reliable")
func _net_lobby_ready(value: bool) -> void:
	if not is_server or not _lobby_active:
		return
	var sender := multiplayer.get_remote_sender_id()
	if not players.has(sender):
		return
	_lobby_ready[sender] = value
	_broadcast_lobby()


@rpc("authority", "call_remote", "reliable")
func _net_lobby_start(world_seed: int, roster: Array, mission_data: Dictionary, score: int, summary: Dictionary) -> void:
	if is_server or game_started or _starting_match:
		return
	_starting_match = true
	_lobby_active = false
	menu.hide_lobby()
	players.clear()
	_apply_roster(roster)
	_start_client_match(world_seed, roster, summary, score, mission_data)


@rpc("authority", "call_remote", "reliable")
func _net_join_denied(reason: String) -> void:
	_fail_connection(reason)


@rpc("authority", "call_remote", "reliable")
func _net_roster(roster: Array) -> void:
	if is_server:
		return
	_apply_roster(roster)


@rpc("any_peer", "call_remote", "unreliable_ordered")
func _net_submit_state(pos: Vector3, yaw: float) -> void:
	if not is_server or not game_started or game_over:
		return
	var sender := multiplayer.get_remote_sender_id()
	var info: Dictionary = players.get(sender, {})
	if info.is_empty() or not bool(info["alive"]):
		return
	if float(info.get("teleport_cool", 0.0)) > 0.0:
		return
	info["pos"] = _sanitize_position(pos)
	info["yaw"] = yaw


@rpc("any_peer", "call_remote", "reliable")
func _net_request_hit(zid: int, headshot: bool, weapon_id: String) -> void:
	if not is_server:
		return
	var sender := multiplayer.get_remote_sender_id()
	_server_apply_hit(sender, zid, headshot, weapon_id)


@rpc("authority", "call_remote", "unreliable_ordered")
func _net_snapshot(entries: Array, zombie_data: Array) -> void:
	if not game_started or game_over:
		return
	_apply_world(entries, zombie_data)


@rpc("authority", "call_remote", "unreliable_ordered")
func _net_summary(summary: Dictionary, score: int) -> void:
	if not game_started:
		return
	_run_wave = int(summary.get("wave", _run_wave))
	hud.set_wave(summary)
	hud.set_score(score)
	_refresh_roster_ui()


@rpc("authority", "call_remote", "reliable")
func _net_zombie_killed(zid: int, kind: String, death_pos: Vector3, headshot: bool, killer_id: int, killer_name: String, killer_color: Color, points: int) -> void:
	_handle_zombie_killed(zid, kind, death_pos, headshot, killer_id, killer_name, killer_color, points)


@rpc("authority", "call_remote", "reliable")
func _net_player_down(player_id: int, player_name_text: String) -> void:
	_notify_player_down(player_id, player_name_text)


@rpc("authority", "call_remote", "reliable")
func _net_player_respawn(player_id: int, spawn: Vector3) -> void:
	_notify_player_respawn(player_id, spawn)


@rpc("authority", "call_remote", "reliable")
func _net_game_over(stats: String, victory: bool) -> void:
	if game_over:
		return
	_handle_game_over(stats, victory)


func _apply_world(entries: Array, zombie_data: Array) -> void:
	for raw in entries:
		if not raw is Array or (raw as Array).size() < 9:
			continue
		var entry: Array = raw
		var id := int(entry[0])
		var info: Dictionary = players.get(id, {})
		if info.is_empty():
			continue
		var pos := Vector3(float(entry[1]), float(entry[2]), float(entry[3]))
		var yaw := float(entry[4])
		var health := float(entry[5])
		var alive := bool(entry[6])
		var kills := int(entry[7])
		var respawn_left := float(entry[8])
		var was_alive := bool(info.get("alive", true))
		info["pos"] = pos
		info["yaw"] = yaw
		info["health"] = health
		info["alive"] = alive
		info["kills"] = kills
		info["respawn_left"] = respawn_left
		if id == local_id:
			_apply_local_snapshot(pos, health, alive, was_alive, respawn_left)
		else:
			if not remote_avatars.has(id):
				_ensure_remote_avatar(id)
			var avatar: RemoteAvatar = remote_avatars.get(id, null)
			if avatar != null and is_instance_valid(avatar):
				avatar.set_network_state(pos, yaw, alive)
	_update_zombies(zombie_data)


func _apply_local_snapshot(pos: Vector3, health: float, alive: bool, was_alive: bool, respawn_left: float) -> void:
	if player == null:
		return
	if not alive:
		if was_alive or player.alive:
			player.apply_health(0.0)
			player.set_down()
			player.set_input_enabled(false)
			_release_mouse()
		hud.set_down(true, respawn_left)
		return
	if not was_alive or not player.alive:
		player.respawn_at(pos, PI)
		player.set_input_enabled(not _paused and not game_over)
		hud.set_down(false)
		_apply_carry_visuals()
		if not _paused and not game_over:
			_capture_mouse()
	player.apply_health(health)
	if player.global_position.distance_to(pos) > 6.0 and _teleport_grace <= 0.0:
		player.global_position = pos


func _update_zombies(zombie_data: Array) -> void:
	if _world == null:
		return
	var present: Dictionary = {}
	for raw in zombie_data:
		if not raw is Array or (raw as Array).size() < 7:
			continue
		var data: Array = raw
		var id := int(data[0])
		present[id] = true
		var proxy: ZombieProxy = zombie_proxies.get(id, null)
		if proxy == null or not is_instance_valid(proxy):
			proxy = ZombieProxy.new()
			proxy.setup(id, String(data[5]))
			_world.add_child(proxy)
			zombie_proxies[id] = proxy
			if _zombie_audio_hear(Vector3(float(data[1]), float(data[2]), float(data[3])), 55.0):
				audio.play_zombie("growl", Vector3(float(data[1]), float(data[2]), float(data[3])))
		var state := int(data[6])
		if state == 1 and int(_zombie_states.get(id, 0)) != 1:
			audio.play_zombie("attack", Vector3(float(data[1]), float(data[2]), float(data[3])))
		_zombie_states[id] = state
		var pos := Vector3(float(data[1]), float(data[2]), float(data[3]))
		if data.size() > 10:
			var packed := int(data[8])
			var tint := Color8((packed >> 24) & 0xFF, (packed >> 16) & 0xFF, (packed >> 8) & 0xFF)
			var ability_index := clampi(int(data[9]), 0, ServerZombie.ABILITY_ORDER.size() - 1)
			proxy.set_network_state(pos, float(data[4]), state, float(data[7]), tint, String(ServerZombie.ABILITY_ORDER[ability_index]), int(data[10]))
		else:
			proxy.set_network_state(pos, float(data[4]), state)
	for id in zombie_proxies.keys():
		if present.has(id):
			continue
		var proxy: ZombieProxy = zombie_proxies[id]
		if proxy != null and is_instance_valid(proxy):
			if _zombie_audio_hear(proxy.global_position, 70.0):
				audio.play_zombie("death", proxy.global_position)
			proxy.play_death()
		zombie_proxies.erase(id)
		_zombie_states.erase(id)


func _zombie_audio_hear(world_pos: Vector3, radius: float) -> bool:
	if player == null or audio == null:
		return false
	return player.global_position.distance_to(world_pos) <= radius


func _handle_zombie_killed(zid: int, kind: String, death_pos: Vector3, headshot: bool, killer_id: int, killer_name: String, killer_color: Color, points: int) -> void:
	var kind_name := String(ZOMBIE_NAMES.get(kind, "丧尸"))
	var proxy: ZombieProxy = zombie_proxies.get(zid, null)
	if proxy != null and is_instance_valid(proxy):
		if effects != null:
			effects.zombie_death(death_pos, kind)
		proxy.play_death()
	if _zombie_audio_hear(death_pos, 70.0):
		audio.play_zombie("death", death_pos)
	zombie_proxies.erase(zid)
	_zombie_states.erase(zid)
	if killer_id == local_id:
		hud.show_hit(headshot, true)
		hud.push_kill("你 击杀 %s  +%d" % [kind_name, points], killer_color)
		if is_server:
			hud.set_score(team_score)
	else:
		hud.push_kill("%s 击杀 %s  +%d" % [killer_name, kind_name, points], killer_color)


func _notify_player_down(player_id: int, player_name_text: String, will_respawn: bool = true) -> void:
	if hud == null:
		return
	hud.push_kill("%s 被感染者击倒" % player_name_text, DeadCityUI.RED)
	if player_id == local_id:
		if will_respawn:
			hud.announce("你已倒下", "正在重新部署，请稍候…", DeadCityUI.RED, 2.2)
		_release_mouse()


func _notify_player_respawn(player_id: int, spawn: Vector3) -> void:
	if player_id != local_id or player == null:
		return
	player.respawn_at(spawn, PI)
	player.set_input_enabled(not _paused and not game_over)
	_apply_carry_visuals()
	hud.set_down(false)
	if not _paused and not game_over:
		_capture_mouse()
	hud.announce("重新投入战场", "保持队形，任务还在继续", DeadCityUI.GREEN, 1.8)


func _on_local_health_changed(health: float) -> void:
	hud.set_health(health, 100.0)


func _on_weapon_changed(weapon_id: String, slot: int) -> void:
	if hud == null or player == null:
		return
	hud.set_weapon_strip(player.loadout_summary(), player.weapon_profile())
	hud.announce(WeaponCatalog.display_name(weapon_id), "%s · 槽位 %d · %s" % [
		WeaponCatalog.short_name(weapon_id), slot, String(player.weapon_profile().get("tag", ""))],
		WeaponCatalog.accent(weapon_id), 1.1)


func _on_local_damaged(amount: float) -> void:
	hud.trigger_damage_flash(clampf(amount / 25.0, 0.3, 1.0))


func _on_local_hit_marker(headshot: bool) -> void:
	hud.show_hit(headshot, false)


func _roster_payload() -> Array:
	var payload: Array = []
	for id in players.keys():
		var info: Dictionary = players[id]
		var pos: Vector3 = info["pos"]
		payload.append({
			"id": int(id),
			"name": String(info["name"]),
			"color": info["color"],
			"health": float(info["health"]),
			"alive": bool(info["alive"]),
			"kills": int(info["kills"]),
			"pos": pos,
			"yaw": float(info["yaw"]),
			"respawn_left": float(info.get("respawn_left", 0.0)),
		})
	return payload


func _apply_roster(roster: Array) -> void:
	var seen: Dictionary = {}
	for raw in roster:
		if not raw is Dictionary:
			continue
		var entry: Dictionary = raw
		var id := int(entry.get("id", 0))
		if id <= 0:
			continue
		seen[id] = true
		var info: Dictionary = players.get(id, {})
		info["name"] = String(entry.get("name", "幸存者"))
		info["color"] = entry.get("color", DeadCityUI.CYAN)
		info["health"] = float(entry.get("health", 100.0))
		info["alive"] = bool(entry.get("alive", true))
		info["kills"] = int(entry.get("kills", 0))
		info["pos"] = entry.get("pos", Vector3.ZERO)
		info["yaw"] = float(entry.get("yaw", 0.0))
		info["respawn_left"] = float(entry.get("respawn_left", 0.0))
		if not info.has("hurt_cool"):
			info["hurt_cool"] = 0.0
		players[id] = info
	for id in players.keys():
		if not seen.has(id):
			players.erase(id)
	if game_started and _world != null:
		for id in players.keys():
			if int(id) != local_id:
				_ensure_remote_avatar(int(id))
		for id in remote_avatars.keys():
			if not players.has(id):
				var avatar: RemoteAvatar = remote_avatars[id]
				if avatar != null and is_instance_valid(avatar):
					avatar.queue_free()
				remote_avatars.erase(id)
	_refresh_roster_ui()
	_update_connection_info()


func _refresh_roster_ui() -> void:
	if hud == null:
		return
	var ids := players.keys()
	ids.sort()
	var roster_ui: Array = []
	for id in ids:
		var info: Dictionary = players[id]
		var distance := 0.0
		var pos_value: Variant = info.get("pos", null)
		if player != null and int(id) != local_id and typeof(pos_value) == TYPE_VECTOR3:
			distance = player.global_position.distance_to(pos_value)
		roster_ui.append({
			"id": int(id),
			"name": String(info.get("name", "幸存者")),
			"color": info.get("color", DeadCityUI.CYAN),
			"alive": bool(info.get("alive", false)),
			"health": float(info.get("health", 0.0)),
			"kills": int(info.get("kills", 0)),
			"is_local": int(id) == local_id,
			"distance": distance,
		})
	hud.set_roster(roster_ui)


func _update_connection_info() -> void:
	if hud == null:
		return
	if solo_mode:
		hud.set_connection_info("单人演练 · 本地权威")
	elif is_hosting:
		hud.set_connection_info("房主 · 端口 %d · %d/%d 玩家" % [_host_port, players.size(), MAX_PLAYERS])
	elif not is_server:
		hud.set_connection_info("已连接 %s · %d/%d 玩家" % [_join_address, players.size(), MAX_PLAYERS])
	else:
		hud.set_connection_info("服务端 · %d/%d 玩家" % [players.size(), MAX_PLAYERS])


func _ensure_remote_avatar(player_id: int) -> void:
	if _world == null or player_id == local_id or remote_avatars.has(player_id):
		return
	var info: Dictionary = players.get(player_id, {})
	if info.is_empty():
		return
	var avatar := RemoteAvatar.new()
	avatar.setup(String(info.get("name", "幸存者")), info.get("color", DeadCityUI.CYAN))
	_world.add_child(avatar)
	var pos: Vector3 = info.get("pos", Vector3.ZERO)
	avatar.global_position = pos
	avatar.set_network_state(pos, float(info.get("yaw", 0.0)), bool(info.get("alive", true)))
	avatar.set_carrying(_core_carried_by(player_id) >= 0)
	remote_avatars[player_id] = avatar


func _minimap_remotes() -> Array:
	var result: Array = []
	for id in remote_avatars.keys():
		var avatar: RemoteAvatar = remote_avatars[id]
		if avatar == null or not is_instance_valid(avatar):
			continue
		var info: Dictionary = players.get(id, {})
		result.append({
			"pos": avatar.global_position,
			"color": info.get("color", Color.WHITE),
			"alive": bool(info.get("alive", true)),
		})
	return result


func _minimap_zombies() -> Array:
	var result: Array = []
	for id in zombie_proxies.keys():
		var proxy: ZombieProxy = zombie_proxies[id]
		if proxy == null or not is_instance_valid(proxy) or not proxy.is_targetable():
			continue
		result.append({"pos": proxy.global_position, "kind": proxy.kind})
	return result


func _server_add_player(player_id: int, player_name_text: String) -> void:
	if players.has(player_id):
		return
	var color: Color = DeadCityUI.PLAYER_COLORS[0]
	var used: Dictionary = {}
	for info in players.values():
		used[info["color"]] = true
	for candidate in DeadCityUI.PLAYER_COLORS:
		if not used.has(candidate):
			color = candidate
			break
	var spawn := _server_pick_spawn(true)
	players[player_id] = {
		"name": player_name_text,
		"color": color,
		"health": 100.0,
		"alive": true,
		"kills": 0,
		"pos": spawn,
		"yaw": ChapterOneStation.SPAWN_YAW,
		"hurt_cool": 0.0,
		"respawn_left": 0.0,
		"teleport_cool": 0.0,
	}
	_refresh_roster_ui()
	_update_connection_info()
	if multiplayer.get_peers().size() > 0:
		rpc("_net_roster", _roster_payload())


func _remove_player(player_id: int) -> void:
	if not players.has(player_id):
		return
	_lobby_ready.erase(player_id)
	_server_release_core(player_id, true)
	_abort_pending_draw(player_id, true)
	players.erase(player_id)
	var avatar: RemoteAvatar = remote_avatars.get(player_id, null)
	if avatar != null and is_instance_valid(avatar):
		avatar.queue_free()
	remote_avatars.erase(player_id)
	_refresh_roster_ui()
	_update_connection_info()
	if game_started and multiplayer.get_peers().size() > 0:
		rpc("_net_roster", _roster_payload())
	if _lobby_active:
		_broadcast_lobby()
	if game_started and not game_over and _server_all_down():
		_server_game_over()


func _server_pick_spawn(in_station: bool = false) -> Vector3:
	var spawns: Array = MissionSite.SAFE_SPAWNS
	if in_station:
		spawns = ChapterOneStation.SPAWNS
	var best: Vector3 = spawns[players.size() % spawns.size()]
	var best_score := -1.0
	for candidate in spawns:
		var point: Vector3 = candidate
		var nearest := 9999.0
		for info in players.values():
			if not bool(info["alive"]):
				continue
			var pos: Vector3 = info["pos"]
			nearest = minf(nearest, Vector2(point.x - pos.x, point.z - pos.z).length())
		if nearest > best_score:
			best_score = nearest
			best = point
	return best


func _director_layout() -> Dictionary:
	var filtered := layout.duplicate(true)
	var spawns: Array = []
	for raw in layout.get("zombie_spawns", []):
		var point: Vector3 = raw
		if Vector2(point.x - MissionSite.BASE_CENTER.x, point.z - MissionSite.BASE_CENTER.z).length() > 26.0:
			spawns.append(point)
	filtered["zombie_spawns"] = spawns
	if mission != null:
		filtered["basement_spawns"] = mission.basement_spawn_points()
	return filtered


func _on_zombie_fused(pos: Vector3, mass: int) -> void:
	if mass != 2:
		return
	if _zombie_audio_hear(pos, 45.0) and audio != null:
		audio.play_zombie("growl", pos)
	if is_server:
		_broadcast_announce("感染者融合", "融合体会获得护甲或自爆能力 · 优先集火", Color("#d8895f"))


func _server_reset_mission() -> void:
	cores_secured = 0
	mission_complete = false
	draw_tokens = 0
	team_upgrades = {"mag": 0, "reload": 0, "damage": 0, "rate": 0, "speed": 0, "armor": 0}
	core_states.clear()
	for i in range(MissionSite.CORE_COUNT):
		core_states.append({"state": "site", "carrier": 0, "pos": mission.core_site_pos(i)})
	_pending_draw.clear()
	_draw_options.clear()
	_close_draw_local()
	if mission != null:
		mission.reset_visuals()
	_apply_mission_visuals()
	if director != null:
		director.set_frenzy(false)
	if player != null:
		player.set_carrying(false)
		player.apply_team_upgrades(team_upgrades)


func _mission_payload() -> Dictionary:
	return {
		"cores": cores_secured,
		"complete": mission_complete,
		"tokens": draw_tokens,
		"upgrades": team_upgrades.duplicate(),
		"states": core_states.duplicate(true),
	}


func _apply_mission_state(data: Dictionary) -> void:
	if data.is_empty():
		return
	cores_secured = int(data.get("cores", cores_secured))
	mission_complete = bool(data.get("complete", mission_complete))
	draw_tokens = int(data.get("tokens", draw_tokens))
	var upgrades: Dictionary = data.get("upgrades", {})
	for key in team_upgrades.keys():
		team_upgrades[key] = int(upgrades.get(key, team_upgrades[key]))
	var states: Array = data.get("states", [])
	if states.size() == MissionSite.CORE_COUNT:
		core_states = states.duplicate(true)
	_apply_mission_visuals()
	if player != null:
		player.apply_team_upgrades(team_upgrades)
	_apply_carry_visuals()
	if _run_active:
		_sync_run_record()


func _apply_mission_visuals() -> void:
	if mission == null or core_states.is_empty():
		return
	for i in range(core_states.size()):
		var entry: Dictionary = core_states[i]
		mission.set_core_state(i, String(entry.get("state", "site")), entry.get("pos", mission.core_site_pos(i)))
	mission.set_secured_count(cores_secured)


func _core_carried_by(player_id: int) -> int:
	for i in range(core_states.size()):
		var entry: Dictionary = core_states[i]
		if String(entry.get("state", "")) == "carried" and int(entry.get("carrier", 0)) == player_id:
			return i
	return -1


func _apply_carry_visuals() -> void:
	if player != null:
		player.set_carrying(_core_carried_by(local_id) >= 0 and player.alive)
	for id in remote_avatars.keys():
		var avatar: RemoteAvatar = remote_avatars[id]
		if avatar != null and is_instance_valid(avatar):
			avatar.set_carrying(_core_carried_by(int(id)) >= 0)


func _sync_mission_after_change() -> void:
	_apply_mission_visuals()
	if player != null:
		player.apply_team_upgrades(team_upgrades)
	_apply_carry_visuals()
	_broadcast_mission_state()
	if _run_active:
		_sync_run_record()


func _broadcast_mission_state() -> void:
	if multiplayer.get_peers().size() > 0:
		rpc("_net_mission_state", _mission_payload())


func _broadcast_announce(title: String, sub: String = "", color: Color = DeadCityUI.TEXT) -> void:
	if hud != null:
		hud.announce(title, sub, color, 2.4)
	if multiplayer.get_peers().size() > 0:
		rpc("_net_announce", title, sub, color)


func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _nearest_collectable_core(pos: Vector3, radius: float) -> int:
	var best := -1
	var best_distance := radius
	for i in range(core_states.size()):
		var entry: Dictionary = core_states[i]
		var state := String(entry.get("state", "site"))
		if state == "site":
			if not mission.is_in_basement(pos):
				continue
			var distance: float = mission.core_distance(pos, i)
			if distance <= best_distance:
				best_distance = distance
				best = i
		elif state == "dropped":
			var dropped_pos: Vector3 = entry.get("pos", Vector3.ZERO)
			var distance := _flat_distance(pos, dropped_pos)
			if absf(pos.y - dropped_pos.y) < 2.5 and distance <= best_distance:
				best_distance = distance
				best = i
	return best


func _server_mission_interact(player_id: int, requested: String = "auto") -> void:
	if not is_server or game_over or mission == null:
		return
	var info: Dictionary = players.get(player_id, {})
	if info.is_empty() or not bool(info.get("alive", false)):
		return
	var pos: Vector3 = info["pos"]
	var carrying_index := _core_carried_by(player_id)
	if requested == "drop":
		if carrying_index >= 0:
			_server_release_core(player_id, false)
		return
	if station != null and station.can_use_radio(pos) and carrying_index < 0:
		_broadcast_announce("无线电 · 基地呼叫", "下楼前往青色基地补给 → 公园坡道进入 B1 → 运回三枚核心", DeadCityUI.CYAN)
		return
	if carrying_index >= 0:
		if mission.is_in_safe_zone(pos):
			if mission.console_distance(pos) <= 3.2:
				_server_secure_core(player_id)
			else:
				_server_release_core(player_id, false)
			return
		_server_release_core(player_id, false)
		return
	var core_index := _nearest_collectable_core(pos, 2.9)
	if core_index >= 0:
		_server_pick_core(player_id, core_index)
		return
	if mission.is_in_safe_zone(pos) and mission.ammo_distance(pos) <= 3.0:
		_server_resupply_ammo(player_id)
		return
	if mission.is_in_safe_zone(pos) and mission.console_distance(pos) <= 3.2:
		_server_open_draw(player_id)


func _server_pick_core(player_id: int, index: int) -> void:
	if index < 0 or index >= core_states.size() or mission == null:
		return
	if _core_carried_by(player_id) >= 0:
		return
	var info: Dictionary = players.get(player_id, {})
	if info.is_empty() or not bool(info.get("alive", false)):
		return
	var entry: Dictionary = core_states[index]
	var state := String(entry.get("state", "site"))
	var pos: Vector3 = info["pos"]
	var within := 0.0
	if state == "site":
		within = mission.core_distance(pos, index)
	elif state == "dropped":
		var dropped_pos: Vector3 = entry.get("pos", Vector3.ZERO)
		within = _flat_distance(pos, dropped_pos)
		if absf(pos.y - dropped_pos.y) > 2.5:
			return
	else:
		return
	if within > 3.2:
		return
	entry["state"] = "carried"
	entry["carrier"] = player_id
	entry["pos"] = pos
	_sync_mission_after_change()
	if player_id == local_id and audio != null:
		audio.play_ui("core", -4.0)
	_broadcast_announce("已获取核心", "搬运核心时无法射击或换弹 · 返回基地交付台", MissionSite.CORE_COLOR)
	if cores_secured >= CORES_REQUIRED - 1 and director != null and not director.is_frenzy():
		director.set_frenzy(true)
		_broadcast_announce("最后的核心 · 尸潮狂暴", "感染者进入暴走状态 · 拼死护送核心返回基地", DeadCityUI.RED)
		_broadcast_sound("frenzy")


func _broadcast_sound(kind: String, volume: float = -1.0) -> void:
	if audio != null:
		audio.play_ui(kind, volume)
	if multiplayer.get_peers().size() > 0:
		rpc("_net_sound", kind)


@rpc("authority", "call_remote", "reliable")
func _net_sound(kind: String) -> void:
	if audio != null:
		audio.play_ui(kind, -1.0)


func _server_release_core(player_id: int, silent: bool = false) -> bool:
	var index := _core_carried_by(player_id)
	if index < 0:
		return false
	var info: Dictionary = players.get(player_id, {})
	if info.is_empty():
		return false
	var entry: Dictionary = core_states[index]
	entry["state"] = "dropped"
	entry["carrier"] = 0
	entry["pos"] = _sanitize_position(info["pos"])
	_sync_mission_after_change()
	if not silent:
		_broadcast_announce("核心已落地", "靠近后按 E 可重新拾取", MissionSite.CORE_COLOR)
	return true


func _server_secure_core(player_id: int) -> void:
	var index := _core_carried_by(player_id)
	if index < 0 or mission == null:
		return
	var info: Dictionary = players.get(player_id, {})
	if info.is_empty():
		return
	var pos: Vector3 = info["pos"]
	if not mission.is_in_safe_zone(pos) or mission.console_distance(pos) > 3.4:
		return
	var entry: Dictionary = core_states[index]
	entry["state"] = "secured"
	entry["carrier"] = 0
	entry["pos"] = MissionSite.CONSOLE_POINT
	cores_secured += 1
	draw_tokens += 1
	team_score += CORE_SECURE_SCORE
	if director != null:
		director.set_escalation(cores_secured)
	_sync_mission_after_change()
	if player_id == local_id and audio != null:
		audio.play_ui("supply", -3.0)
	if cores_secured >= CORES_REQUIRED:
		_broadcast_announce("核心全部回收", "B1 核心已全部运回基地", DeadCityUI.GREEN)
		_server_game_over(true)
	else:
		_broadcast_announce("核心已交付 · %d / %d" % [cores_secured, CORES_REQUIRED],
			"尸潮威胁 +1 · 立即选择全队强化", MissionSite.CORE_COLOR)
		_server_open_draw(player_id)


func _server_resupply_ammo(player_id: int) -> void:
	if not is_server or game_over or mission == null:
		return
	var info: Dictionary = players.get(player_id, {})
	if info.is_empty() or not bool(info.get("alive", false)):
		return
	var pos: Vector3 = info["pos"]
	if not mission.is_in_safe_zone(pos) or mission.ammo_distance(pos) > 3.0:
		return
	if player_id == local_id:
		if player != null:
			player.refill_ammo()
			hud.set_weapon_strip(player.loadout_summary(), player.weapon_profile())
		hud.announce("弹药已补给", "所有枪械弹匣与备弹已补满", DeadCityUI.CYAN, 1.8)
	elif multiplayer.get_peers().size() > 0:
		rpc_id(player_id, "_net_resupply")


func _server_teleport_player(player_id: int, pos: Vector3, yaw: float) -> void:
	if not is_server:
		return
	var info: Dictionary = players.get(player_id, {})
	if info.is_empty() or not bool(info.get("alive", false)):
		return
	var destination := _sanitize_position(pos)
	info["pos"] = destination
	info["yaw"] = yaw
	info["teleport_cool"] = 1.0
	_apply_teleport(player_id, destination, yaw)
	if multiplayer.get_peers().size() > 0:
		rpc("_net_teleport", player_id, destination, yaw)


func _apply_teleport(player_id: int, pos: Vector3, yaw: float) -> void:
	if player_id == local_id:
		if player != null:
			player.teleport_to(pos)
			player.face_yaw(yaw)
			_teleport_grace = 1.1
	else:
		var avatar: RemoteAvatar = remote_avatars.get(player_id, null)
		if avatar != null and is_instance_valid(avatar):
			var info: Dictionary = players.get(player_id, {})
			avatar.snap_to(pos, yaw, bool(info.get("alive", true)))


func _server_open_draw(player_id: int) -> void:
	if not is_server or game_over or mission == null:
		return
	var info: Dictionary = players.get(player_id, {})
	if info.is_empty() or not bool(info.get("alive", false)):
		return
	if _core_carried_by(player_id) >= 0:
		return
	if not _pending_draw.is_empty():
		return
	var pos: Vector3 = info["pos"]
	if not mission.is_in_safe_zone(pos) or mission.console_distance(pos) > 3.4:
		return
	if draw_tokens <= 0:
		if player_id == local_id:
			hud.announce("核心券不足", "回收核心并交付后可获得抽卡券", DeadCityUI.AMBER, 2.0)
		return
	var eligible: Array = []
	for card in CARD_POOL:
		if int(team_upgrades.get(String(card["key"]), 0)) < CARD_MAX_LEVEL:
			eligible.append(card)
	if eligible.is_empty():
		if player_id == local_id:
			hud.announce("强化已满", "全队战术强化已达到上限", DeadCityUI.MUTED, 2.0)
		return
	draw_tokens -= 1
	var options := _roll_draw_options(eligible)
	_pending_draw = {"player": player_id, "options": options, "timer": DRAW_TIMEOUT}
	_sync_mission_after_change()
	if player_id == local_id:
		_open_draw(options)
	elif multiplayer.get_peers().size() > 0:
		rpc_id(player_id, "_net_draw_options", options)


func _roll_draw_options(eligible: Array) -> Array:
	var pool := eligible.duplicate()
	var options: Array = []
	while options.size() < mini(3, pool.size()):
		var pick := _draw_rng.randi_range(0, pool.size() - 1)
		var card: Dictionary = pool[pick]
		pool.remove_at(pick)
		var copy := card.duplicate(true)
		copy["level"] = int(team_upgrades.get(String(copy["key"]), 0))
		options.append(copy)
	return options


func _server_pick_card(player_id: int, index: int) -> void:
	if _pending_draw.is_empty():
		return
	if int(_pending_draw.get("player", 0)) != player_id:
		return
	var options: Array = _pending_draw.get("options", [])
	if index < 0 or index >= options.size():
		return
	var card: Dictionary = options[index]
	var key := String(card.get("key", ""))
	if not team_upgrades.has(key):
		return
	if int(team_upgrades[key]) >= CARD_MAX_LEVEL:
		return
	team_upgrades[key] = int(team_upgrades[key]) + 1
	_pending_draw.clear()
	_sync_mission_after_change()
	_send_draw_close(player_id)
	var accent := Color.from_string(String(card.get("accent", "#59d8c8")), DeadCityUI.CYAN)
	_broadcast_announce("全队强化 · %s" % String(card.get("title", "战术强化")),
		String(card.get("desc", "")), accent)


func _server_cancel_draw(player_id: int) -> void:
	if _pending_draw.is_empty():
		return
	if int(_pending_draw.get("player", 0)) != player_id:
		return
	_abort_pending_draw(player_id, true)
	_broadcast_announce("抽卡已取消", "核心券已返还", DeadCityUI.MUTED)


func _abort_pending_draw(player_id: int, refund: bool) -> void:
	if _pending_draw.is_empty():
		return
	var owner_id := int(_pending_draw.get("player", 0))
	if player_id > 0 and owner_id != player_id:
		return
	_pending_draw.clear()
	if refund:
		draw_tokens += 1
		_sync_mission_after_change()
	_send_draw_close(owner_id)


func _tick_pending_draw(delta: float) -> void:
	if _pending_draw.is_empty():
		return
	_pending_draw["timer"] = float(_pending_draw.get("timer", 0.0)) - delta
	if float(_pending_draw["timer"]) > 0.0:
		return
	var owner_id := int(_pending_draw.get("player", 0))
	_abort_pending_draw(owner_id, true)
	_broadcast_announce("抽卡超时", "核心券已返还", DeadCityUI.MUTED)


func _open_draw(options: Array) -> void:
	if options.is_empty():
		return
	_draw_open = true
	_draw_options = options.duplicate(true)
	if hud != null:
		hud.show_draw(options)
	if player != null:
		player.set_input_enabled(false)
	_release_mouse()


func _close_draw_local() -> void:
	_draw_open = false
	_draw_options.clear()
	if hud != null:
		hud.hide_draw()
	if game_started and not game_over and not _paused and player != null and player.alive:
		player.set_input_enabled(true)
		_capture_mouse()


func _send_draw_close(target_id: int) -> void:
	if target_id <= 0 or target_id == local_id:
		_close_draw_local()
	if target_id > 0 and target_id != local_id and multiplayer.get_peers().size() > 0:
		rpc_id(target_id, "_net_draw_close")
	elif target_id <= 0 and multiplayer.get_peers().size() > 0:
		rpc("_net_draw_close")


func _request_interact() -> void:
	if not game_started or game_over or _draw_open or _paused or player == null or not player.alive:
		return
	if is_server:
		_server_mission_interact(local_id)
	else:
		rpc_id(1, "_net_mission_interact")


func _request_drop() -> void:
	if not game_started or game_over or _draw_open or _paused or player == null or not player.alive:
		return
	if not player.carrying_core:
		return
	if is_server:
		_server_mission_interact(local_id, "drop")
	else:
		rpc_id(1, "_net_request_drop")


func _compute_interaction() -> String:
	if mission == null or player == null or not player.alive:
		return ""
	var pos := player.global_position
	if station != null and station.can_use_radio(pos) and not player.carrying_core:
		return "radio"
	if player.carrying_core:
		if mission.is_in_safe_zone(pos) and mission.console_distance(pos) <= 3.2:
			return "secure"
		return "drop"
	if _nearest_collectable_core(pos, 2.9) >= 0:
		return "pick"
	if mission.is_in_safe_zone(pos) and mission.ammo_distance(pos) <= 2.8:
		return "ammo"
	if mission.is_in_safe_zone(pos) and mission.console_distance(pos) <= 3.2:
		return "draw" if draw_tokens > 0 else "no_tokens"
	return ""


func _interaction_prompt() -> String:
	var action := _compute_interaction()
	_interact_action = action
	match action:
		"radio":
			return "E   收听基地无线电"
		"secure":
			return "E   交付核心 · 立即抽卡"
		"drop":
			return "E / G   放下核心"
		"pick":
			return "E   回收核心"
		"ammo":
			return "E   补充弹药"
		"draw":
			return "E   核心抽卡 · 消耗 1 张券"
		"no_tokens":
			return "E   核心交付台 · 回收核心可兑换抽卡券"
		_:
			return ""


func _update_mission_hud() -> void:
	if hud == null:
		return
	var zone := "城市区域"
	var zone_color := DeadCityUI.MUTED
	var hint := "沿市中心公园坡道下到核心储藏层 B1"
	var pos := Vector3.ZERO
	if mission != null and player != null:
		pos = player.global_position
		if mission.is_in_safe_zone(pos):
			zone = "基地安全区"
			zone_color = DeadCityUI.CYAN
		elif mission.is_in_basement(pos):
			zone = "核心储藏层 B1"
			zone_color = DeadCityUI.AMBER
		elif station != null and station.contains_point(pos):
			zone = station.zone_name(pos)
			zone_color = DeadCityUI.CYAN
	if mission_complete:
		zone = "任务完成"
		zone_color = DeadCityUI.GREEN
		hint = "全部核心已回收 · 行动完成"
	elif player != null and player.carrying_core:
		hint = "搬运核心 · 无法射击、换弹或冲刺，返回基地交付台"
	elif station != null and player != null and station.contains_point(pos):
		hint = "经西侧楼梯下楼 → 青色基地补给 → 公园 B1 回收核心"
	elif mission != null and player != null and mission.is_in_safe_zone(pos) and mission.ammo_distance(pos) <= 3.0:
		hint = "弹药补给台 · 按 E 补满弹匣与备弹"
	elif cores_secured >= CORES_REQUIRED:
		hint = "核心已全部回收"
	elif mission != null and player != null and mission.is_in_basement(pos):
		hint = "回收核心，然后从绿色出口返回地表"
	elif cores_secured > 0:
		hint = "已回收 %d / %d · 继续搜索地下储藏层" % [cores_secured, CORES_REQUIRED]
	var prompt := ""
	if game_started and not game_over and not _paused and not _draw_open and player != null and player.alive:
		prompt = _interaction_prompt()
	else:
		_interact_action = ""
	_mission_hint_text = hint
	_mission_zone_text = zone
	hud.set_mission(cores_secured, CORES_REQUIRED, draw_tokens, hint, zone, zone_color, team_upgrades,
		player != null and player.carrying_core, MetaProfile.power_of(team_upgrades))
	hud.set_interaction(prompt)


func _minimap_markers() -> Array:
	var result: Array = []
	if mission == null:
		return result
	result.append({"pos": MissionSite.BASE_CENTER, "color": DeadCityUI.CYAN, "kind": "safe", "radius": MissionSite.SAFE_RADIUS})
	result.append({"pos": ChapterOneStation.CENTER, "color": DeadCityUI.CYAN, "kind": "point"})
	result.append({"pos": Vector3(0.0, 0.16, 12.8), "color": MissionSite.CORE_COLOR, "kind": "gateway"})
	var in_basement: bool = player != null and mission.is_in_basement(player.global_position)
	for i in range(core_states.size()):
		var entry: Dictionary = core_states[i]
		var state := String(entry.get("state", "site"))
		if state == "site" and in_basement:
			result.append({"pos": mission.core_site_pos(i), "color": MissionSite.CORE_COLOR, "kind": "core"})
		elif state == "dropped":
			result.append({"pos": entry.get("pos", Vector3.ZERO), "color": MissionSite.CORE_COLOR, "kind": "core"})
	return result


@rpc("any_peer", "call_remote", "reliable")
func _net_mission_interact() -> void:
	if not is_server:
		return
	_server_mission_interact(multiplayer.get_remote_sender_id())


@rpc("authority", "call_remote", "reliable")
func _net_resupply() -> void:
	if player != null:
		player.refill_ammo()
	if hud != null:
		hud.announce("弹药已补给", "弹匣与备弹已补满", DeadCityUI.CYAN, 1.8)


@rpc("any_peer", "call_remote", "reliable")
func _net_request_drop() -> void:
	if not is_server:
		return
	_server_mission_interact(multiplayer.get_remote_sender_id(), "drop")


@rpc("any_peer", "call_remote", "reliable")
func _net_pick_card(index: int) -> void:
	if not is_server:
		return
	_server_pick_card(multiplayer.get_remote_sender_id(), index)


@rpc("any_peer", "call_remote", "reliable")
func _net_cancel_draw() -> void:
	if not is_server:
		return
	_server_cancel_draw(multiplayer.get_remote_sender_id())


@rpc("authority", "call_remote", "reliable")
func _net_mission_state(data: Dictionary) -> void:
	if is_server:
		return
	_apply_mission_state(data)


@rpc("authority", "call_remote", "reliable")
func _net_draw_options(options: Array) -> void:
	if is_server:
		return
	_open_draw(options)


@rpc("authority", "call_remote", "reliable")
func _net_draw_close() -> void:
	if is_server:
		return
	_close_draw_local()


@rpc("authority", "call_remote", "reliable")
func _net_teleport(player_id: int, pos: Vector3, yaw: float) -> void:
	if is_server:
		return
	_apply_teleport(player_id, pos, yaw)


@rpc("authority", "call_remote", "reliable")
func _net_announce(title: String, sub: String, color: Color) -> void:
	if hud != null:
		hud.announce(title, sub, color, 2.4)


func _on_card_picked(index: int) -> void:
	if not _draw_open:
		return
	if index < 0 or index >= _draw_options.size():
		return
	if is_server:
		_server_pick_card(local_id, index)
	else:
		rpc_id(1, "_net_pick_card", index)


func _on_draw_cancelled() -> void:
	if not _draw_open:
		return
	if is_server:
		_server_cancel_draw(local_id)
	else:
		rpc_id(1, "_net_cancel_draw")


func _return_to_menu(message: String) -> void:
	_leaving = true
	if _run_active:
		MetaProfile.abandon_run(_meta)
		_run_active = false
		_persist_meta()
	_run_wave = 1
	_lobby_active = false
	_lobby_ready.clear()
	if menu != null:
		menu.hide_lobby()
	game_started = false
	game_over = false
	_paused = false
	get_tree().paused = false
	_starting_match = false
	_connecting = false
	_snapshot_accum = 0.0
	_summary_accum = 0.0
	_state_accum = 0.0
	team_score = 0
	cores_secured = 0
	core_states.clear()
	draw_tokens = 0
	mission_complete = false
	team_upgrades = {"mag": 0, "reload": 0, "damage": 0, "rate": 0, "speed": 0, "armor": 0}
	_pending_draw.clear()
	_draw_open = false
	_draw_options.clear()
	_interact_action = ""
	_teleport_grace = 0.0
	if _networked:
		_networked = false
		var peer := multiplayer.multiplayer_peer
		if peer is ENetMultiplayerPeer:
			peer.close()
		multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	_teardown_world()
	players.clear()
	local_id = 1
	is_server = false
	is_hosting = false
	solo_mode = false
	_release_mouse()
	hud.visible = false
	hud.hide_loading()
	hud.reset_for_match()
	menu.visible = true
	menu.present(message)


func _teardown_world() -> void:
	if player != null:
		player.set_game_active(false)
		player.set_input_enabled(false)
	if director != null:
		director.stop()
		director.clear_zombies()
	if _world != null and is_instance_valid(_world):
		_world.queue_free()
	_world = null
	city = null
	mission = null
	station = null
	effects = null
	director = null
	player = null
	remote_avatars.clear()
	zombie_proxies.clear()
