extends SceneTree


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await create_timer(0.5).timeout
	game.menu.solo_requested.emit("E-07", 4242)
	while not game.game_started:
		await process_frame
	game.director.stop()
	game.player.set_input_enabled(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await create_timer(5.5).timeout
	await _capture("chapter_one_observation")
	game.hud.visible = false
	var camera := Camera3D.new()
	game.get_node("World").add_child(camera)
	camera.position = ChapterOneStation.CENTER + Vector3(-35, 19, 28)
	camera.look_at(ChapterOneStation.CENTER + Vector3(-2, 5, 0))
	camera.current = true
	camera.fov = 58
	await create_timer(0.5).timeout
	await _capture("chapter_one_exterior")
	game.queue_free()
	await process_frame
	await process_frame
	quit()


func _capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	var path := "res://shots/%s.png" % label
	var error := root.get_texture().get_image().save_png(path)
	if error != OK:
		push_error("Cannot capture %s: %s" % [path, error_string(error)])
		quit(1)
