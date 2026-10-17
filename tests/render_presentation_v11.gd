extends SceneTree
## Real Compatibility captures: authored cels, contact events, environments/status.
var game: Node
var folder := "res://test-results/presentation-v11"


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
	game.open_stage_selection("menu")
	await shot("arena-selection")
	game.cancel_stage()
	for id in ArenaCatalog.IDS:
		start("gustavo")
		game.stage_id = id
		await shot(id)
	start("gustavo")
	game.stage_id = "patio"
	for frame in 64:
		for tick in 2:
			var held := CombatInput.RIGHT if frame >= 12 and frame < 44 else 0
			advance(held)
		await shot("walk-%03d" % frame)
	for name in [
		"punch", "kick", "crouchPunch", "sweep", "airPunch", "airKick", "uppercut", "special"
	]:
		start("gustavo")
		var f: FighterModel = game.sim.fighters[0]
		game.sim.fighters[1].x = f.x + (180 if "Punch" in name or name == "punch" else 260) * 256
		if name.begins_with("air"):
			f.y -= 90 * 256
		f._start_move(f.character.get_move(name, 1))
		for tick in 100:
			advance()
			if (
				f.state == FighterState.Id.ATTACK
				and f.move_tick == f.current_move().startup * 2 + 4
			):
				await shot("gustavo-" + name)
				break
	for guard in [false, true]:
		start("gustavo")
		var f: FighterModel = game.sim.fighters[0]
		game.sim.fighters[1].x = f.x + 180 * 256
		f._start_move(f.character.get_move("punch", 2))
		for tick in 100:
			advance(0, guard)
			if not game.impact.particles.is_empty():
				await shot("contact-" + ("block" if guard else "hit"))
				break
	await dizzy_capture()
	start("joao")
	game.sim.fighters[0]._start_move(game.sim.fighters[0].character.get_move("special", 1))
	for tick in 50:
		advance()
		if tick == 24:
			await shot("joao-H-super-soco")
	start("joao")
	game.sim.fighters[0]._start_move(game.sim.fighters[0].character.get_move("super", 1))
	for tick in 60:
		advance()
		if tick == 8:
			await shot("joao-Q-cut-in")
		if game.sim.fighters[0].roll_phase == RollMotion.TRAVEL:
			await shot("joao-Q-roll")
			break
	game.stage_audio.stop_all()
	game.queue_free()
	await process_frame
	print("V11_VISUAL_CAPTURE_COMPLETE")
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
