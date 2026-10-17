extends SceneTree
## Real Compatibility captures: authored cels, contact events, environments/status.
var game: Node
var folder := "res://test-results/gustavo-v12"


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	DirAccess.make_dir_recursive_absolute(folder)
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	game.power_view.set_process(false)
	game.impact.set_process(false)
	if "--status-only" in OS.get_cmdline_user_args():
		await dizzy_capture()
		game.stage_audio.stop_all()
		game.queue_free()
		await process_frame
		quit()
		return
	start("gustavo")
	game.stage_id = "nit"
	await shot("00-guard")
	for tick in 30:
		advance(CombatInput.DOWN)
	await shot("01-crouch")
	for name in [
		"punch",
		"kick",
		"crouchPunch",
		"sweep",
		"airPunch",
		"airKick",
		"uppercut",
		"special",
		"super"
	]:
		if (
			"--smoke-only" in OS.get_cmdline_user_args()
			and name not in ["special", "uppercut", "super"]
		):
			continue
		start("gustavo")
		game.stage_id = "nit"
		var f: FighterModel = game.sim.fighters[0]
		game.sim.fighters[1].x = (
			f.x
			+ (
				(
					180
					if name in ["punch", "crouchPunch"]
					else 290 if name in ["kick", "sweep", "uppercut"] else 460
				)
				* 256
			)
		)
		if name.begins_with("air"):
			f.y -= 100 * 256
			f.vy = -200
		f.meter = 100
		f._start_move(f.character.get_move(name, 1))
		for tick in 160:
			advance(CombatInput.DOWN if name == "crouchPunch" else 0)
			if tick in [3, 10, 18, 28, 38, 52, 72, 105, 145]:
				await shot(name + "-%03d" % tick)
	for guard in [false, true]:
		start("gustavo")
		game.stage_id = "nit"
		var f: FighterModel = game.sim.fighters[0]
		game.sim.fighters[1].x = f.x + 370 * 256
		f._start_move(f.character.get_move("special", 1))
		for tick in 180:
			advance(0, guard)
			if not game.impact.particles.is_empty():
				await shot("smoke-contact-" + ("block" if guard else "hit"))
				for decay in 12:
					advance(0, guard)
				await shot("smoke-contact-late-" + ("block" if guard else "hit"))
				break
	await dizzy_capture()
	game.stage_audio.stop_all()
	game.queue_free()
	await process_frame
	print("GUSTAVO_V12_VISUAL_CAPTURE_COMPLETE")
	quit()


func dizzy_capture() -> void:
	start("gustavo")
	var victim: FighterModel = game.sim.fighters[1]
	victim.stun_gauge = 99
	victim.receive_hit(game.sim.fighters[0].character.get_move("punch", 1), 1, false, 0, 3)
	for tick in 160:
		advance()
		if victim.state == FighterState.Id.DIZZY:
			await shot("dizzy-orbit")
			break


func start(id: String) -> void:
	game.selected = [id, "rafael"]
	game.mode = "training"
	game._start_fight(false)
	for view in game.views:
		view.presentation_frozen = true
		view.sync(true)


func advance(held: int = 0, guard: bool = false) -> void:
	var inputs: Array[CombatInput] = [
		CombatInput.new(held), CombatInput.new(CombatInput.GUARD if guard else 0)
	]
	game.sim.step(inputs)
	game.power_view.consume(game.sim.events)
	game.impact.consume(game.sim.events, game.sim)
	game.power_view._process(1.0 / 120)
	game.impact._process(1.0 / 120)
	for view in game.views:
		view.presentation_frozen = true
		view.sync(true)
		view.position = view.current_position
		view.queue_redraw()
	game.power_view.queue_redraw()
	game.impact.queue_redraw()


func shot(label: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(folder + "/" + label + ".png")
