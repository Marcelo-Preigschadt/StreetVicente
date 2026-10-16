extends SceneTree
## Native OpenGL visual review. Run under an X server, not --headless (dummy GPU).
var game: Node


func _initialize() -> void:
	call_deferred("capture")


func capture() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.views[0].use_3d = true  # Explicit archival fixture, never the published default.
	game.choose_menu(0)
	game.paused = true
	for i in 8:
		await process_frame
	await shot("01-idle")
	var f: FighterModel = game.sim.fighters[0]
	for name in ["punch", "kick", "sweep", "airKick", "uppercut", "special"]:
		var move_id := "%s:1" % name
		if not f.character.moves.has(move_id):
			move_id = "%s:0" % name
		f.move_id = move_id
		f.state = FighterState.Id.ATTACK
		f.move_tick = f.current_move().startup * 2 + 1
		f.move_motion_started = true
		if name in ["airKick", "uppercut"]:
			f.y = f.ground_y - 120 * 256
			f.vy = -600
		else:
			f.y = f.ground_y
			f.vy = 0
		game.views[0].sync(true)
		await shot(name)
	f.state = FighterState.Id.IDLE
	f.y = f.ground_y
	f.facing = -1
	game.views[0].sync(true)
	await shot("02-left")
	f.facing = 1
	f.state = FighterState.Id.KNOCKDOWN
	f.state_tick = 35
	await shot("03-knockdown")
	print("3D_VISUAL_CAPTURE_COMPLETE")
	quit()


func shot(label: String) -> void:
	for i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-results/3d/%s.png" % label)
