extends SceneTree
## Captura o renderer real e a passagem guarda → andar → guarda dos dois revisados.
var game: Node


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://test-results/arcade-v9")
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await shot("menu")
	game.controls.open()
	await shot("controls")
	game.controls.close()
	game.selected = ["adriano", "joao"]
	game.mode = "training"
	game._start_fight(false)
	game.set_physics_process(false)
	for frame in 64:
		for tick in 2:
			var held := CombatInput.RIGHT if frame >= 12 and frame < 44 else 0
			var inputs: Array[CombatInput] = [CombatInput.new(held), CombatInput.new(held)]
			game.sim.step(inputs)
		for view in game.views:
			view.sync(true)
		await shot("walk-%03d" % frame, 1)
	game.selected = ["joao", "rafael"]
	game._start_fight(false)
	for name in [
		"punch", "kick", "crouchPunch", "sweep", "airPunch", "airKick", "uppercut", "special"
	]:
		var f: FighterModel = game.sim.fighters[0]
		f.state = FighterState.Id.ATTACK
		f.move_id = name + ":1"
		f.move_tick = f.current_move().startup * 2 + 1
		f.y = f.ground_y - (90 * 256 if name.begins_with("air") else 0)
		f.move_motion_started = name == "uppercut"
		if name == "uppercut":
			f.y -= 80 * 256
		game.views[0].sync(true)
		await shot("joao-" + name)
	print("V9_VISUAL_CAPTURE_COMPLETE")
	quit()


func shot(label: String, frames: int = 3) -> void:
	for i in frames:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-results/arcade-v9/%s.png" % label)
