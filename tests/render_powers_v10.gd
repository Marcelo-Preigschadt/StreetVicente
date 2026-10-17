extends SceneTree
## Captures real Compatibility rendering from stepped combat, not mocked VFX.
var game: Node
var folder := "res://test-results/powers-v10"


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
	for guard in [false, true]:
		start("joao")
		var f: FighterModel = game.sim.fighters[0]
		f._start_move(f.character.get_move("special", 1))
		var captured := {}
		for tick in 270:
			advance(guard)
			var label := ""
			if tick == 20:
				label = "load"
			elif f.roll_phase == RollMotion.TRAVEL and f.roll_tick == 10:
				label = "travel"
			elif f.roll_phase == RollMotion.SHOCK and f.roll_hits == 2:
				label = "shock-combo"
			elif f.roll_phase == RollMotion.REBOUND and f.roll_tick == 8:
				label = "rebound"
			elif f.roll_phase == RollMotion.RECOVER and f.roll_tick == 7:
				label = "landing"
			if not label.is_empty() and not captured.has(label):
				captured[label] = true
				await shot("joao-%s-%s" % ["block" if guard else "hit", label])
		for view in game.views:
			view.trails.clear()
	for id in LegacyRoster.ids():
		if id != "joao":
			start(id)
			var f: FighterModel = game.sim.fighters[0]
			if id == "marcos":
				game.sim.fighters[1].x = f.x + 190 * 256
			f._start_move(f.character.get_move("special", 1))
			for tick in 110:
				advance()
				if f.move_tick == f.current_move().startup * 2 - 2:
					await shot(id + "-charge")
				if (
					(game.sim.projectiles.size() > 0 and game.sim.projectiles[0].age == 12)
					or (
						id == "marcos"
						and game.sim.events.any(func(e: Dictionary) -> bool: return e.kind == "hit")
					)
				):
					await shot(id + "-special")
					break
		start(id)
		var f: FighterModel = game.sim.fighters[0]
		f._start_move(f.character.get_move("uppercut", 1))
		for tick in 100:
			advance()
			if f.move_tick == f.current_move().startup * 2 + 3:
				await shot(id + "-upper-drive")
			if f.move_tick == f.current_move().startup * 2 + 8:
				await shot(id + "-upper-rise")
				break
	# Lethal contact, then victory after the real final hitstop has expired.
	start("marcelo")
	game.sim.fighters[1].x = game.sim.fighters[0].x + 140 * 256
	game.sim.fighters[1].health = 1
	game.sim.fighters[0]._start_move(game.sim.fighters[0].character.get_move("punch", 2))
	for tick in 160:
		advance()
	await shot("round-end-stable")
	print("V10_VISUAL_CAPTURE_COMPLETE")
	quit()


func start(id: String) -> void:
	game.selected = [id, "rafael"]
	game.mode = "training"
	game._start_fight(false)
	for view in game.views:
		view.presentation_frozen = true


func advance(guard: bool = false) -> void:
	var inputs: Array[CombatInput] = [
		CombatInput.new(), CombatInput.new(CombatInput.GUARD if guard else 0)
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
	game.queue_redraw()


func shot(label: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(folder + "/" + label + ".png")
