extends SceneTree
## Real Compatibility renderer fixture. No 3D, no headless dummy screenshots.
var game: Node


func _initialize() -> void:
	call_deferred("capture")


func capture() -> void:
	DirAccess.make_dir_recursive_absolute("res://test-results/arcade-v8")
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.choose_menu(0)
	game.set_physics_process(false)
	game.sim.intro_ticks = 160
	game.paused = false
	await shot("01-round")
	game.sim.intro_ticks = 35
	game.paused = false
	await shot("02-fight")
	game.sim.intro_ticks = 0
	game.paused = true
	await shot("03-marcelo-rafael")
	var marcelo: FighterModel = game.sim.fighters[0]
	marcelo.state = FighterState.Id.ATTACK
	marcelo.move_id = "airPunch:1"
	marcelo.move_tick = marcelo.current_move().startup * 2 + 1
	marcelo.y -= 90 * 256
	game.views[0].sync(true)
	await shot("03a-marcelo-air-punch")
	game.selected = ["adriano", "rafael"]
	game._start_fight(false)
	game.paused = true
	await shot("04-adriano-rafael")
	for name in ["punch", "kick", "airPunch", "airKick", "special"]:
		for i in 2:
			var f: FighterModel = game.sim.fighters[i]
			f.state = FighterState.Id.ATTACK
			f.move_id = name + ":1"
			f.move_tick = f.current_move().startup * 2 + 1
			f.y = f.ground_y - (90 * 256 if name.begins_with("air") else 0)
			game.views[i].sync(true)
		await shot(name)
	for i in 2:
		var f: FighterModel = game.sim.fighters[i]
		f.state = FighterState.Id.IDLE
		f.y = f.ground_y
		game.views[i].sync(true)
	game.sim.projectiles = [
		{
			"x": 640 * 256,
			"y": 400 * 256,
			"facing": 1,
			"vx": 6 * 256,
			"kind": "projectile",
			"drone": false,
			"character": "marcelo",
			"effect": "code",
			"age": 12
		},
		{
			"x": 940 * 256,
			"y": 400 * 256,
			"facing": -1,
			"vx": -6 * 256,
			"kind": "projectile",
			"drone": false,
			"character": "rafael",
			"effect": "scroll",
			"age": 12
		}
	]
	game.impact.particles = [
		{
			"x": 650.0,
			"y": 520.0,
			"life": 0.13,
			"max": 0.2,
			"blocked": false,
			"strong": true,
			"seed": 1,
			"facing": 1
		}
	]
	await shot("05-effects")
	game.sim.projectiles.clear()
	game.impact.clear()
	root.size = Vector2i(1720, 720)
	game._fit_viewport()
	await shot("06-ultrawide")
	root.size = Vector2i(1024, 768)
	game._fit_viewport()
	await shot("07-four-three")
	print("ARCADE_V8_VISUAL_CAPTURE_COMPLETE")
	quit()


func shot(label: String) -> void:
	for i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-results/arcade-v8/%s.png" % label)
