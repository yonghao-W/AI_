extends SceneTree
## 分辨率取证工具：在离屏 SubViewport 中按目标分辨率渲染真实主菜单与单人 HUD。
## 用法：--script res://ui_refactor/phase3/tools/capture_resolution.gd -- --size=1920x1080 --out=ui_refactor/phase3/shots/resolution

var _w := 1920
var _h := 1080
var _out := "ui_refactor/phase3/shots/resolution"


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--size="):
			var parts := arg.trim_prefix("--size=").split("x")
			_w = int(parts[0])
			_h = int(parts[1])
		elif arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
	_run.call_deferred()


func _shot(vp: SubViewport, name: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = vp.get_texture().get_image()
	if img == null:
		print("[res] capture failed: ", name)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://" + _out))
	var path := "%s/%s_%dx%d.png" % [_out, name, _w, _h]
	print("[res] %s -> %s (%dx%d)" % [name, path, img.get_width(), img.get_height()])
	print("[res] save err=", img.save_png(ProjectSettings.globalize_path("res://" + path)))


func _run() -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(_w, _h)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var game = load("res://scenes/main.tscn").instantiate()
	vp.add_child(game)
	await create_timer(1.6).timeout
	await _shot(vp, "menu")
	game.menu.solo_requested.emit("RES", 4242)
	var deadline := Time.get_ticks_msec() + 20000
	while not game.game_started and Time.get_ticks_msec() < deadline:
		await process_frame
	if not game.game_started:
		print("[res] solo failed")
		quit(1)
		return
	await create_timer(2.5).timeout
	await _shot(vp, "hud")
	quit(0)
