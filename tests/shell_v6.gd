extends SceneTree


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	app.set_physics_process(false)
	app.progress.file_path = "user://test-shell-v6.json"
	app.progress.checkpoint.clear()
	app.progress.record = 0
	app.selected = ["marcelo", "rafael"]
	app.mode = "cpu"
	app.arcade = ArcadeRun.new(LegacyRoster.ids(), "marcelo", "rafael")
	app._start_fight()
	assert(not app.views[0].use_3d and app.views[0].pilot_3d == null)
	var retired_shortcut := InputEventKey.new()
	retired_shortcut.physical_keycode = KEY_F6
	retired_shortcut.pressed = true
	app._unhandled_input(retired_shortcut)
	assert(not app.views[0].use_3d and app.views[0].pilot_3d == null)
	app.sim.wins[0] = 1
	app.sim.fighters[1].health = 0
	for i in FightSimulation.ROUND_WAIT_TICKS + 2 + FightSimulation.INTRO_TICKS:
		app._physics_process(1.0 / 120)
	assert(app.screen == "arcade_route")
	assert(app.arcade.index == 0 and app.arcade.score > 0)
	var score: int = app.arcade.score
	app._next_arcade()
	assert(app.screen == "fight" and app.arcade.index == 1)
	assert(app.sim.fighters[0].health == 1000 and app.sim.fighters[0].meter == 0)
	assert(app.arcade.score == score)
	app.sim.wins[1] = 1
	app.sim.fighters[0].health = 0
	for i in FightSimulation.ROUND_WAIT_TICKS + 2 + FightSimulation.INTRO_TICKS:
		app._physics_process(1.0 / 120)
	assert(app.screen == "arcade_result" and app.arcade.state == "defeated")
	var confirm := InputEventKey.new()
	confirm.physical_keycode = KEY_ENTER
	confirm.pressed = true
	app._unhandled_input(confirm)
	assert(app.screen == "fight" and app.arcade.index == 1 and app.arcade.score == 0)
	app.choose_menu(3)
	assert(app.screen == "selection")
	app.confirm_selection()
	assert(app.screen == "story_dialog")
	app._unhandled_input(confirm)
	assert(app.screen == "story")
	assert(app.views[0].pilot_3d == null)
	assert(app.progress.valid_checkpoint())
	print("SHELL V6: route, next opponent, defeat, continue, story dialog/save passed")
	DirAccess.remove_absolute("user://test-shell-v6.json")
	# Direct stepping runs several seconds of announcer cues in one rendered
	# frame. Stop voices before disposing the fixture/audio server at shutdown.
	app.audio.selection.stop()
	app.audio.voice.stop()
	for player in app.audio.effects:
		player.stop()
	app.audio.streams.clear()
	app.queue_free()
	await process_frame
	await process_frame
	quit(0)
