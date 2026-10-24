extends Node2D
## Native Godot shell. The original JavaScript engine is never embedded or executed.
const MENU := [
	"TREINO LIVRE",
	"CIRCUITO VICENTE / CPU",
	"VERSUS / 2 JOGADORES",
	"HISTÓRIA / RESGATE DO NIT",
	"TREINAMENTO",
	"ONLINE / VERSUS E COOP"
]
var screen: String = "menu"
var mode: String = "cpu"
var menu_index: int = 0
var selection_slot: int = 0
var cursor: int = 1
var selected: Array = ["marcelo", "rafael"]
var arcade: ArcadeRun
var progress := PlayerProgress.new()
var route_ticks: int = 0
var save_clock: float = 0.0
var saved_record: int = 0
var story_checkpoint: String = ""
var sim: FightSimulation
var story: StorySimulation
var input_source: LocalCombatInput
var ai := CombatAI.new()
var views: Array[SpriteFighterView] = []
var controls: ControllerPanel
var ui: GameScreen
var audio: GameAudio
var power_view: PowerView
var story_view: StoryView
var paused: bool = false
var dummy_mode: int = 0
var debug_boxes: bool = false
var rooms: Array = []
var room_code: String = ""
var net_status: String = "Conectando ao serviço de salas..."
var net_session: OnlineSession
var directory: RoomDirectory
var online_panel: OnlinePanel
var qa: bool = false
var demo: bool = false
var impact: CombatImpact
var last_contacts: Array = []
var reference_heights: Dictionary = {}
var qa_trace: Array = []
var qa_trace_key: String = ""
var qa_round_calls: Array = []
var stage_id := "patio"
var stage_cursor := 0
var stage_return := "menu"
var stage_view: ArenaView
var stage_audio: StageAudio
var status_view: FighterStatusV11


func _ready() -> void:
	LegacyRoster.load_catalog()
	progress.load_saved()
	saved_record = progress.record
	input_source = LocalCombatInput.new()
	add_child(input_source)
	audio = GameAudio.new()
	add_child(audio)
	stage_view = ArenaView.new()
	stage_view.z_index = -2000
	add_child(stage_view)
	stage_audio = StageAudio.new()
	stage_audio.game = self
	add_child(stage_audio)
	story_view = StoryView.new()
	add_child(story_view)
	impact = CombatImpact.new()
	var backdrop := PowerBackdrop.new()
	backdrop.z_index = -800
	backdrop.impact = impact
	add_child(backdrop)
	for i in 2:
		var view := SpriteFighterView.new()
		add_child(view)
		views.append(view)
	power_view = PowerView.new()
	backdrop.powers = power_view
	add_child(power_view)
	add_child(impact)
	status_view = FighterStatusV11.new()
	add_child(status_view)
	ui = GameScreen.new()
	ui.game = self
	add_child(ui)
	directory = RoomDirectory.new()
	add_child(directory)
	net_session = OnlineSession.new()
	add_child(net_session)
	net_session.setup(directory)
	net_session.changed.connect(_online_changed)
	net_session.prepare_game.connect(_online_prepare)
	net_session.committed.connect(_online_events)
	net_session.reset_presentation.connect(_online_reset)
	online_panel = OnlinePanel.new()
	add_child(online_panel)
	online_panel.setup(self)
	directory.active = false
	controls = ControllerPanel.new()
	controls.game = self
	add_child(controls)
	AppSettings.controllers_changed.connect(_controller_changed)
	AppSettings.menu_action.connect(_pad_navigation)
	_hide_world()
	get_viewport().size_changed.connect(_fit_viewport)
	_fit_viewport()
	if OS.has_feature("web"):
		qa = (
			int(JavaScriptBridge.eval("window.location.search.includes('qa=1') ? 1 : 0", true)) == 1
		)
		print("Web observer enabled: ", qa)


func _fit_viewport() -> void:
	var area := get_viewport_rect().size
	var factor := minf(area.x / 1280.0, area.y / 720.0)
	scale = Vector2.ONE * factor
	position = (area - Vector2(1280, 720) * factor) / 2


func _hide_world() -> void:
	for view in views:
		view.hide()
	power_view.hide()
	story_view.hide()
	if is_instance_valid(impact):
		impact.clear()


func choose_menu(index: int) -> void:
	if net_session != null and net_session.active():
		close_online()
	progress.save()
	arcade = null
	if index == 3 and progress.valid_checkpoint():
		mode = "story"
		screen = "story_resume"
		_hide_world()
		return
	if index == 0:
		mode = "training"
		selected = ["marcelo", "rafael"]
		_start_fight()
		return
	if index == 5:
		directory.start(online_panel.mode)
		net_session.status = ""
		screen = "online"
		_hide_world()
		return
	mode = ["cpu", "local", "story", "training"][index - 1]
	selection_slot = 0
	cursor = LegacyRoster.ids().find(selected[0])
	screen = "selection"
	_hide_world()


func confirm_selection() -> void:
	var id: String = LegacyRoster.ids()[cursor]
	if online_active():
		net_session.choose(id, not net_session.confirmed[net_session.slot])
		audio.select_character(id)
		return
	if selection_slot == 1 and selected[0] == id:
		return
	selected[selection_slot] = id
	audio.select_character(id)
	if mode == "story":
		_start_story()
	elif selection_slot == 0:
		selection_slot = 1
		cursor = LegacyRoster.ids().find(selected[1])
		if selected[0] == selected[1]:
			cursor = (cursor + 1) % LegacyRoster.ids().size()
	else:
		open_stage_selection("selection")


func open_stage_selection(origin: String) -> void:
	stage_return = origin
	stage_cursor = ArenaCatalog.IDS.find(stage_id)
	screen = "stage_selection"
	paused = true
	input_source.clear()
	_hide_world()


func confirm_stage() -> void:
	stage_id = ArenaCatalog.IDS[stage_cursor]
	if stage_return == "menu":
		screen = "menu"
		paused = false
	elif stage_return == "fight":
		screen = "fight"
		paused = false
		for view in views:
			view.show()
		power_view.show()
		input_source.clear()
	else:
		if mode == "cpu":
			arcade = ArcadeRun.new(LegacyRoster.ids(), selected[0], selected[1], progress.record)
		_start_fight()


func cancel_stage() -> void:
	if stage_return == "fight":
		screen = "fight"
		paused = false
		for view in views:
			view.show()
		power_view.show()
	else:
		screen = stage_return
		paused = false


func presentation_stage() -> String:
	if screen == "stage_selection":
		return ArenaCatalog.IDS[stage_cursor]
	if screen in ["story", "story_dialog", "story_resume"] and story != null:
		return ArenaCatalog.STORY[mini(story.act_index, 3)]
	return stage_id


func _start_fight(show_intro: bool = true) -> void:
	qa_trace.clear()
	qa_trace_key = ""
	qa_round_calls.clear()
	if arcade != null:
		selected = [arcade.player_id, arcade.opponents[arcade.index]]
	impact.clear()
	last_contacts.clear()
	ai = CombatAI.new()
	PilotArt.load_data()
	for atlas in PilotArt.data.sheets.values():
		LegacyRoster.texture(atlas.image)
	for id in selected:
		for atlas in LegacyRoster.get_character(id).legacy.atlases.values():
			LegacyRoster.texture(atlas.image)
	sim = FightSimulation.new(
		LegacyRoster.get_character(selected[0]), LegacyRoster.get_character(selected[1])
	)
	if show_intro:
		sim.begin_round_intro()
	if mode == "training":
		for f in sim.fighters:
			f.meter = 100
		dummy_mode = 1
	screen = "fight"
	paused = false
	demo = false
	input_source.clear()
	for i in 2:
		views[i].setup(sim.fighters[i], sim.fighters[i].character.color)
		views[i].camera_x = 0
		views[i].show()
	power_view.setup(sim)
	power_view.show()
	story_view.hide()


func _start_story(resume: bool = false) -> void:
	impact.clear()
	PilotArt.load_data()
	for atlas in PilotArt.data.sheets.values():
		LegacyRoster.texture(atlas.image)
	if resume:
		selected[0] = progress.checkpoint.character
	story = StorySimulation.new(LegacyRoster.get_character(selected[0]))
	if resume:
		story.restore(progress.checkpoint.world)
	story_checkpoint = "%d:%d" % [story.act_index, story.wave_index]
	progress.capture_story(story)
	_bind_story()
	screen = "story_dialog"
	_hide_world()


func _bind_story() -> void:
	screen = "story"
	paused = false
	demo = false
	input_source.clear()
	views[0].setup(story.hero, story.hero.character.color)
	views[0].show()
	views[1].hide()
	story_view.world = story
	story_view.sync(true)
	story_view.show()
	power_view.setup(story)
	power_view.show()


func _physics_process(_delta: float) -> void:
	if online_active() and screen in ["fight", "story"]:
		if not controls.visible:
			net_session.advance(input_source.sample(0))
		_online_views()
		if screen == "story":
			story_view.sync()
		if qa and screen == "fight":
			_capture_qa_trace()
		return
	if paused:
		return
	if screen == "arcade_route":
		route_ticks += 1
		if route_ticks >= ArcadeRun.ROUTE_TICKS:
			_next_arcade()
	elif screen == "fight":
		var inputs: Array[CombatInput] = [input_source.sample(0), input_source.sample(1)]
		if mode == "cpu":
			inputs[1] = ai.sample(sim, 1)
		elif mode == "training" and dummy_mode > 0:
			inputs[1] = CombatInput.new(
				(
					(CombatInput.GUARD if dummy_mode > 1 else 0)
					| (CombatInput.DOWN if dummy_mode == 3 else 0)
				)
			)
		if demo:
			inputs = _demo_inputs()
			sim.fighters[0].meter = 100
			sim.fighters[1].health = 1000
			sim.fighters[0].health = 1000
		sim.step(inputs)
		var contacts := sim.events.filter(
			func(e: Dictionary) -> bool: return e.kind in ["hit", "block"]
		)
		if not contacts.is_empty():
			last_contacts = contacts.duplicate(true)
		impact.consume(sim.events, sim)
		power_view.consume(sim.events)
		if mode == "training" and sim.winner < 0:
			sim.remaining_ticks = 99 * 120
		for i in 2:
			if views[i].model != sim.fighters[i]:
				views[i].setup(sim.fighters[i], sim.fighters[i].character.color)
			views[i].sync()
		audio.consume(sim.events)
		if arcade != null:
			arcade.consume(sim.events)
			progress.record = maxi(progress.record, arcade.record)
			if arcade.state != "fighting" and sim.round_wait >= FightSimulation.ROUND_WAIT_TICKS:
				_show_arcade_outcome()
	elif screen == "story":
		story.step(input_source.sample(0))
		story_view.sync()
		if views[0].model != story.hero:
			views[0].setup(story.hero, story.hero.character.color)
		views[0].camera_x = story.camera_x
		views[0].sync()
		audio.consume(story.events)
		impact.consume(story.events, null)
		power_view.consume(story.events)
		var checkpoint_key := "%d:%d" % [story.act_index, story.wave_index]
		if checkpoint_key != story_checkpoint or story.completed:
			progress.capture_story(story)
			if story.act_index != int(story_checkpoint.get_slice(":", 0)) and not story.completed:
				screen = "story_dialog"
				_hide_world()
			story_checkpoint = checkpoint_key
	if qa and screen == "fight":
		_capture_qa_trace()


func _process(_delta: float) -> void:
	var current_stage := presentation_stage()
	stage_view.stage_id = current_stage
	stage_view.paused = paused
	stage_audio.play_arena(current_stage)
	stage_view.impact_offset = impact.offset() * .25
	status_view.world = story if screen == "story" else sim if screen == "fight" else null
	status_view.camera_x = story_view.render_camera() if screen == "story" else 0.0
	status_view.position = StoryLayout.ORIGIN if screen == "story" else Vector2.ZERO
	status_view.scale = Vector2.ONE * (StoryLayout.SCALE if screen == "story" else 1.0)
	status_view.visible = screen in ["fight", "story"]
	save_clock += _delta
	if save_clock >= 1.0 and progress.record != saved_record:
		progress.save()
		saved_record = progress.record
		save_clock = 0.0
	var campaign := screen == "story" and story != null
	var scene_scale := StoryLayout.SCALE if campaign else 1.0
	var scene_origin := StoryLayout.ORIGIN if campaign else Vector2.ZERO
	story_view.presentation_frozen = paused or (campaign and story.freeze_ticks > 0)
	for i in views.size():
		var view: SpriteFighterView = views[i]
		view.world_scale = scene_scale
		view.world_origin = scene_origin
		view.depth_scale = StoryLayout.depth(float(view.model.ground_y) / FighterModel.SCALE) if campaign and view.model != null else 1.0
		view.z_index = StoryLayout.Z_BASE + roundi(float(view.model.ground_y) / FighterModel.SCALE) if campaign and view.model != null else 0
		view.story_gear = story.object_sets()[i] if campaign and i < story.object_sets().size() else null
		if campaign:
			view.camera_x = story_view.render_camera()
		view.impact_offset = impact.offset()
		view.presentation_paused = paused
		view.presentation_frozen = (
			paused or (screen == "fight" and sim != null and sim.freeze_ticks > 0) or (campaign and story.freeze_ticks > 0)
		)
	power_view.position = scene_origin + impact.offset() * scene_scale
	power_view.scale = Vector2.ONE * scene_scale
	power_view.presentation_paused = paused
	impact.presentation_paused = paused
	impact.position = scene_origin + impact.offset() * scene_scale
	impact.scale = Vector2.ONE * scene_scale
	impact.camera_x = story_view.render_camera() if campaign else 0.0
	power_view.camera_x = impact.camera_x
	queue_redraw()
	if qa:
		_publish_qa()


func _capture_qa_trace() -> void:
	for event in sim.events:
		if event.kind == "announcer":
			qa_round_calls.append({"cue": event.cue, "tick": sim.tick})
			if qa_round_calls.size() > 32:
				qa_round_calls.pop_front()
	# Record transient poses at physics rate, publish once per rendered frame.
	# This is observation only: no browser command or debug hook mutates simulation.
	var f: FighterModel = sim.fighters[0]
	var pose := CharacterArt.frame(f)
	var phase := f.current_move().phase(f.move_tick) if f.state == FighterState.Id.ATTACK else ""
	var key := "%d:%s:%s:%d:%s" % [f.state, f.move_id, pose.key, pose.index, phase]
	if key == qa_trace_key:
		return
	qa_trace_key = key
	qa_trace.append(
		{
			"tick": sim.tick,
			"state": FighterState.NAMES[f.state],
			"move": f.move_id,
			"meter": f.meter,
			"pose": pose.key,
			"pose_index": pose.index,
			"art_sheet": str(pose.sheet.image),
			"art_height": float(pose.frame.rect[3]) * float(pose.frame.get("scale", 1)),
			"art_face_revision": int(pose.frame.get("face_revision", 0)),
			"y": f.y,
			"vy": f.vy,
			"hit_count": f.attack_boxes().size(),
			"x": f.x,
			"roll_phase": f.roll_phase,
			"roll_hits": f.roll_hits
		}
	)
	if qa_trace.size() > 64:
		qa_trace.pop_front()


func _publish_qa() -> void:
	var data := {
		"screen": screen,
		"mode": mode,
		"selected": selected,
		"cursor": cursor,
		"slot": selection_slot,
		"roster": LegacyRoster.ids().size(),
		"roster_ids": LegacyRoster.ids(),
		"paused": paused,
		"record": progress.record,
		"checkpoint": progress.valid_checkpoint(),
		"arena": presentation_stage(),
		"arena_ids": ArenaCatalog.IDS,
		"stage_cursor": stage_cursor,
		"audio": stage_audio.observation()
	}
	if net_session != null:
		data.online = net_session.observation()
		data.rooms = directory.rooms
	if progress.valid_checkpoint():
		data.checkpoint_meta = {
			"character": progress.checkpoint.character,
			"act": progress.checkpoint.act,
			"x": progress.checkpoint.world.hero.x,
			"hp": progress.checkpoint.world.hero.health,
			"score": progress.checkpoint.world.score
		}
	if arcade != null:
		data.arcade = {
			"score": arcade.score,
			"record": arcade.record,
			"index": arcade.index,
			"state": arcade.state,
			"opponents": arcade.opponents,
			"breakdown": arcade.breakdown
		}
	if screen == "fight" and sim != null:
		data.states = sim.fighters.map(
			func(f: FighterModel) -> String: return FighterState.NAMES[f.state]
		)
		data.reactions = sim.fighters.map(
			func(f: FighterModel) -> Dictionary:
				return {
					"duration": f.hit_duration,
					"remaining": f.stun_ticks,
					"dizzy": f.dizzy_ticks,
					"protected": f.dizzy_protection,
					"pose": CharacterArt.frame(f).index,
					"height": _standing_height(f)
				}
		)
		data.tick = sim.tick
		data.intro_ticks = sim.intro_ticks
		data.round_calls = qa_round_calls
		data.trace = qa_trace
		data.hp = [sim.fighters[0].health, sim.fighters[1].health]
		data.x = [sim.fighters[0].x, sim.fighters[1].x]
		data.y = [sim.fighters[0].y, sim.fighters[1].y]
		data.moves = [sim.fighters[0].move_id, sim.fighters[1].move_id]
		data.move_tick = sim.fighters[0].move_tick
		data.vy = sim.fighters[0].vy
		data.meter = [sim.fighters[0].meter, sim.fighters[1].meter]
		data.fx_revision = 11
		data.roster_fx_revision = 20
		data.super_cutin = impact.super_time
		data.power_bursts = power_view.bursts.map(func(b: Dictionary) -> Dictionary:
			return {"character": b.character, "move": b.move, "kind": b.kind,
				"life": b.life, "x": b.x, "y": b.y})
		data.revised_power_ids = PowerFXV20.IDS + ["tais", "luciana", "ruan"]
		data.contact_clips = impact.particles.map(func(p: Dictionary) -> String: return p.clip)
		data.roll = {
			"phase": sim.fighters[0].roll_phase,
			"tick": sim.fighters[0].roll_tick,
			"hits": sim.fighters[0].roll_hits
		}
		data.freeze_ticks = sim.freeze_ticks
		data.round_wait = sim.round_wait
		data.winner = sim.winner
		data.match_over = sim.match_over
		data.wins = sim.wins.duplicate()
		data.shake = impact.shake
		data.last_contacts = last_contacts
		data.hurtboxes = sim.fighters.map(
			func(f: FighterModel) -> Array:
				return f.hurtboxes().map(
					func(r: Rect2i) -> Array:
						return [
							r.position.x / 256.0,
							r.position.y / 256.0,
							r.size.x / 256.0,
							r.size.y / 256.0
						]
				)
		)
		data.hitboxes = sim.fighters.map(
			func(f: FighterModel) -> Array:
				return f.attack_boxes().map(
					func(r: Rect2i) -> Array:
						return [
							r.position.x / 256.0,
							r.position.y / 256.0,
							r.size.x / 256.0,
							r.size.y / 256.0
						]
				)
		)
		data.projectiles = sim.projectiles.size()
		data.emitted_waves = sim.fighters[0].emitted_waves
		data.power_kinds = sim.projectiles.map(func(p: Dictionary) -> String: return str(p.kind))
		data.power_sprites = power_view.visible
		data.power_positions = sim.projectiles.map(
			func(p: Dictionary) -> Dictionary:
				return {
					"x": float(p.x) / 256.0,
					"y": float(p.y) / 256.0,
					"kind": p.kind,
					"age": p.age,
					"radius": p.radius,
					"spawn_x": float(p.spawn_x) / 256.0,
					"spawn_y": float(p.spawn_y) / 256.0,
					"effect": p.effect
				}
		)
		data.pose_index = (
			CharacterArt.frame(sim.fighters[0]).index
			if CharacterArt.has_frame(sim.fighters[0])
			else 0
		)
		data.hash = sim.state_hash()
		data.new_art = views[0].use_new_art
		data.pilot_3d = (
			views[0].pilot_3d.observation()
			if views[0].pilot_3d != null and views[0].pilot_3d.visible
			else {}
		)
		data.pose = (
			CharacterArt.frame(sim.fighters[0]).key
			if CharacterArt.has_frame(sim.fighters[0])
			else "legacy"
		)
		data.state = FighterState.NAMES[sim.fighters[0].state]
	if screen == "story" and story != null:
		data.story = {
			"character": story.hero.character.id,
			"pose": CharacterArt.frame(story.hero).key,
			"art_sheet": CharacterArt.frame(story.hero).sheet.image,
			"art_face_revision": CharacterArt.frame(story.hero).frame.get("face_revision", 0),
			"ground_y": story.hero.ground_y,
			"act": story.act_index,
			"wave": story.wave_index,
			"enemies": story.enemies.size(),
			"hp": story.hero.health,
			"meter": story.hero.meter,
			"state": FighterState.NAMES[story.hero.state],
			"carry": story.objects.carry.duplicate(true),
			"pickup_ticks": story.objects.pickup_ticks,
			"thrown": story.objects.thrown.duplicate(true),
			"props": story.props.duplicate(true),
			"presentation_revision": 23,
			"scene_scale": StoryLayout.SCALE,
			"enemy_states": story.enemies.map(func(e: Dictionary) -> Dictionary:
				var f: FighterModel = e.fighter
				return {"id": e.id, "kind": e.kind, "x": f.x, "lane": f.ground_y, "hp": f.health, "state": FighterState.NAMES[f.state], "cel": StoryEnemyArt.sample(e, story.tick).index}),
			"projectiles": story.projectiles.size(),
			"power_sprites": power_view.visible,
			"power_kinds": story.projectiles.map(func(p: Dictionary) -> String: return str(p.kind)),
			"x": story.hero.x,
			"y": story.hero.y
		}
	data.controls_open = controls.visible
	data.dizzy_indicators = FighterStatusV11.dizzy_actors(status_view.world).size()
	if screen == "fight":
		data.art_sheet = CharacterArt.frame(sim.fighters[0]).sheet.image
		var frame: Dictionary = CharacterArt.frame(sim.fighters[0]).frame
		var scale_factor := float(frame.get("scale", 1))
		data.art_height = float(frame.rect[3]) * scale_factor
		data.art_scale = scale_factor
		data.art_source = str(frame.get("source", "legacy"))
		data.art_face_revision = int(frame.get("face_revision", 0))
		data.gustavo_revision = 12
	data.controller_devices = AppSettings.devices
	if controls.visible:
		data.controller_ui = {
			"device_label": controls.device_list.get_item_text(controls.device_list.selected),
			"device_id": controls.device_list.get_selected_id(),
			"popup_open": controls.device_list.get_popup().visible
		}

	if screen == "story" and story is CoopStorySimulation:
		data.story.players = story.players().map(func(f: FighterModel) -> Dictionary:
			return {"character": f.character.id, "x": f.x, "y": f.y, "lane": f.ground_y,
				"hp": f.health, "meter": f.meter, "pose": CharacterArt.frame(f).key})
		data.story.hash = story.state_hash()
	JavaScriptBridge.eval("window.svfQA = " + JSON.stringify(data), true)


func toggle_fullscreen() -> void:
	DisplayServer.window_set_mode(
		(
			DisplayServer.WINDOW_MODE_WINDOWED
			if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
			else DisplayServer.WINDOW_MODE_FULLSCREEN
		)
	)


func _controller_changed() -> void:
	input_source.clear()
	if online_active():
		net_session.pause_game(true)
	if screen in ["fight", "story"]:
		paused = true
		if controls.visible:
			controls.was_paused = true
		_snap_views()


func _unhandled_input(event: InputEvent) -> void:
	if controls.visible:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var local: Vector2 = (event.position - position) / scale
		if ui.audio_rect().has_point(local):
			stage_audio.toggle()
			get_viewport().set_input_as_handled()
			return
		if ui.stage_rect().has_point(local) and screen in ["menu", "fight"] and not online_active():
			open_stage_selection(screen)
			get_viewport().set_input_as_handled()
			return
		if screen == "stage_selection":
			if ui.music_file_rect().has_point(local):
				stage_audio.choose_music()
				return
			for i in ArenaCatalog.IDS.size():
				if ui.arena_card_rect(i).has_point(local):
					if stage_cursor == i:
						confirm_stage()
					else:
						stage_cursor = i
					return
		if ui.fullscreen_rect().has_point(local):
			toggle_fullscreen()
			get_viewport().set_input_as_handled()
			return
		if ui.controls_rect().has_point(local):
			controls.open()
			get_viewport().set_input_as_handled()
			return
		if screen == "menu":
			for i in MENU.size():
				if ui.menu_rect(i).has_point(local):
					choose_menu(i)
		elif screen in ["arcade_route", "arcade_result"] and ui.action_rect().has_point(local):
			if screen == "arcade_route":
				_next_arcade()
			elif arcade.state == "defeated":
				arcade.continue_run()
				_start_fight(mode != "training")
			else:
				screen = "menu"
		elif screen == "selection":
			for i in LegacyRoster.ids().size():
				if ui.card_rect(i).has_point(local):
					cursor = i
					confirm_selection()
					break
	var key := 0
	if event is InputEventKey and event.pressed and not event.echo:
		key = event.physical_keycode
	else:
		return
	_handle_key(key)


func _pad_navigation(key: int) -> void:
	if controls.visible:
		return
	if screen in ["fight", "story"]:
		if key != KEY_PAUSE:
			return
		key = KEY_ENTER if paused else KEY_ESCAPE
	elif key == KEY_PAUSE:
		key = KEY_ENTER
	_handle_key(key)


func _handle_key(key: int) -> void:
	if online_active() and _online_key(key):
		return
	if key == KEY_F9:
		stage_audio.toggle()
		return
	if key == KEY_F5 and screen in ["menu", "fight"]:
		open_stage_selection(screen)
		return
	if key == KEY_F11:
		toggle_fullscreen()
		get_viewport().set_input_as_handled()
		return
	if key == KEY_F10:
		controls.open()
		return
	if screen == "stage_selection":
		if key in [KEY_A, KEY_LEFT, KEY_W, KEY_UP]:
			stage_cursor = posmod(stage_cursor - 1, ArenaCatalog.IDS.size())
		elif key in [KEY_D, KEY_RIGHT, KEY_S, KEY_DOWN]:
			stage_cursor = (stage_cursor + 1) % ArenaCatalog.IDS.size()
		elif key == KEY_ENTER:
			confirm_stage()
		elif key == KEY_ESCAPE:
			cancel_stage()
		elif key == KEY_F6:
			stage_audio.choose_music()
		elif key == KEY_DELETE:
			stage_audio.remove_music()
		elif key == KEY_MINUS:
			stage_audio.set_level(stage_audio.level - .1)
		elif key in [KEY_EQUAL, KEY_PLUS]:
			stage_audio.set_level(stage_audio.level + .1)
		return
	if screen == "menu":
		if key in [KEY_W, KEY_UP]:
			menu_index = posmod(menu_index - 1, MENU.size())
		elif key in [KEY_S, KEY_DOWN]:
			menu_index = (menu_index + 1) % MENU.size()
		elif key == KEY_ENTER:
			choose_menu(menu_index)
	elif screen == "online":
		if key == KEY_ESCAPE:
			close_online()
	elif screen in ["arcade_route", "arcade_result"]:
		if key == KEY_ENTER:
			if screen == "arcade_route":
				_next_arcade()
			elif arcade.state == "defeated":
				arcade.continue_run()
				_start_fight()
			else:
				screen = "menu"
		elif key == KEY_ESCAPE:
			screen = "menu"
	elif screen == "story_resume":
		if key == KEY_ENTER:
			_start_story(true)
		elif key == KEY_N:
			selection_slot = 0
			cursor = LegacyRoster.ids().find(selected[0])
			screen = "selection"
		elif key == KEY_ESCAPE:
			screen = "menu"
	elif screen == "story_dialog":
		if key == KEY_ENTER:
			_bind_story()
		elif key == KEY_ESCAPE:
			screen = "menu"
	elif screen == "selection":
		if key in [KEY_A, KEY_LEFT]:
			cursor = posmod(cursor - 1, LegacyRoster.ids().size())
		elif key in [KEY_D, KEY_RIGHT]:
			cursor = (cursor + 1) % LegacyRoster.ids().size()
		elif key in [KEY_W, KEY_UP, KEY_S, KEY_DOWN]:
			cursor = ui.vertical_neighbor(cursor, -1 if key in [KEY_W, KEY_UP] else 1)
		elif key == KEY_ENTER:
			confirm_selection()
		elif key == KEY_ESCAPE:
			screen = "menu"
	elif screen in ["fight", "story"]:
		if key == KEY_ESCAPE:
			if paused:
				screen = "menu"
				_hide_world()
				paused = false
			else:
				paused = true
				if screen == "story":
					progress.capture_story(story)
				progress.save()
				input_source.clear()
				_snap_views()
		elif key == KEY_ENTER:
			if paused:
				paused = false
				input_source.clear()
			elif screen == "fight" and sim.match_over:
				if arcade != null:
					_show_arcade_outcome()
				else:
					choose_menu(4 if mode == "training" else 2)
			elif screen == "story" and story.completed:
				screen = "menu"
				_hide_world()
		elif key == KEY_F8:
			if screen == "fight":
				if arcade != null:
					if arcade.state not in ["defeated", "fighting"]:
						_show_arcade_outcome()
						return
					arcade.continue_run()
				_start_fight(mode != "training")
			else:
				story.retry_act()
				_bind_story()
				progress.capture_story(story)
		elif key == KEY_F3 and screen == "fight" and mode == "training":
			demo = not demo
		elif key == KEY_F4:
			for view in views:
				view.use_new_art = not view.use_new_art
		elif key == KEY_F1:
			debug_boxes = not debug_boxes
			for view in views:
				view.debug_boxes = debug_boxes
		elif key == KEY_F2 and mode == "training":
			dummy_mode = (dummy_mode + 1) % 4


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and online_active():
		input_source.clear()
		return
	if (
		what == NOTIFICATION_APPLICATION_FOCUS_OUT
		and is_instance_valid(input_source)
		and screen in ["fight", "story"]
	):
		paused = true
		input_source.clear()
		_snap_views()


func _snap_views() -> void:
	for view in views:
		if view.model != null:
			view.sync(true)


func _demo_inputs() -> Array[CombatInput]:
	var t := sim.tick % 1500
	var held := 0
	var pressed := 0
	var other := 0
	if t < 90 and sim.fighters[1].x - sim.fighters[0].x > 180 * FighterModel.SCALE:
		held = CombatInput.RIGHT
	elif t >= 900 and t < 970:
		held = CombatInput.LEFT
	if t in [100, 150, 210]:
		pressed = CombatInput.PUNCH
	elif t in [310, 390]:
		pressed = CombatInput.KICK
	elif t == 480:
		held = CombatInput.DOWN
		pressed = CombatInput.PUNCH
	elif t == 570:
		held = CombatInput.DOWN
		pressed = CombatInput.KICK
	elif t == 690:
		pressed = CombatInput.UPPERCUT
	elif t == 790:
		pressed = CombatInput.UP
	elif t == 810:
		pressed = CombatInput.KICK
	elif t == 990:
		pressed = CombatInput.SPECIAL
	elif t == 1100:
		pressed = CombatInput.SUPER
	elif t == 1400:
		pressed = CombatInput.UP
	if t > 1000 and t < 1250:
		other = CombatInput.GUARD
	return [CombatInput.new(held, pressed), CombatInput.new(other)]


func _next_arcade() -> void:
	if arcade != null and arcade.state == "route":
		arcade.advance()
		stage_id = ArenaCatalog.opponent_arena(arcade.opponents[arcade.index])
		_start_fight()


func _standing_height(f: FighterModel) -> float:
	if reference_heights.has(f.character.id):
		return reference_heights[f.character.id]
	var standing := FighterModel.new(f.character, f.slot, 0)
	var art := CharacterArt.frame(standing)
	reference_heights[f.character.id] = (
		float(art.frame.rect[3])
		* float(art.frame.get("scale", art.sheet.scale))
		* CharacterMetrics.factor(f.character.id)
	)
	return reference_heights[f.character.id]


func _show_arcade_outcome() -> void:
	route_ticks = 0
	screen = "arcade_route" if arcade.state == "route" else "arcade_result"
	progress.save()
	_hide_world()


func online_active() -> bool:
	return net_session != null and net_session.active()


func close_online() -> void:
	net_session.leave()
	directory.active = false
	screen = "menu"
	paused = false
	input_source.clear()
	_hide_world()


func _online_changed() -> void:
	room_code = net_session.room
	net_status = net_session.status
	if net_session.phase == "lobby":
		selected = net_session.pair.duplicate()
		selection_slot = net_session.slot
		cursor = LegacyRoster.ids().find(net_session.selection_character())
		mode = "story_online" if net_session.game_mode == "story" else "online"
		screen = "selection"
		paused = false
		_hide_world()
	elif net_session.phase == "error":
		screen = "online"
		paused = false
		_hide_world()
	elif net_session.world != null:
		paused = net_session.phase != "playing"


func _online_prepare() -> void:
	selected = net_session.pair.duplicate()
	stage_id = net_session.stage
	mode = "story_online" if net_session.game_mode == "story" else "online"
	if mode == "online":
		_start_fight()
		net_session.attach_world(sim)
	else:
		story = CoopStorySimulation.new(LegacyRoster.get_character(selected[0]),
			LegacyRoster.get_character(selected[1]))
		_bind_story()
		views[1].setup(story.heroes[1], story.heroes[1].character.color)
		views[1].show()
		net_session.attach_world(story)
	paused = true


func _online_events(events: Array) -> void:
	var contacts := events.filter(func(e: Dictionary) -> bool: return e.kind in ["hit", "block"])
	if not contacts.is_empty():
		last_contacts = contacts.duplicate(true)
	impact.consume(events, sim if mode == "online" else null)
	power_view.consume(events)
	audio.consume(events)


func _online_reset() -> void:
	impact.clear()
	power_view.bursts.clear()
	power_view.seen.clear()
	last_contacts.clear()
	input_source.clear()
	_snap_views()


func _online_views() -> void:
	if net_session.world == null:
		return
	paused = net_session.phase != "playing" or (net_session.timeline != null and not net_session.timeline.can_advance())
	var actors: Array = sim.fighters if mode == "online" else story.players()
	for i in 2:
		if views[i].model != actors[i]:
			views[i].setup(actors[i], actors[i].character.color)
		views[i].camera_x = 0 if mode == "online" else story.camera_x
		views[i].sync()
		views[i].show()


func _online_key(key: int) -> bool:
	if screen == "selection":
		if key == KEY_ESCAPE:
			close_online()
		elif key == KEY_ENTER:
			confirm_selection()
		elif key == KEY_F5 and net_session.slot == 0:
			var index := (ArenaCatalog.IDS.find(net_session.stage) + 1) % ArenaCatalog.IDS.size()
			net_session.set_stage(ArenaCatalog.IDS[index])
		elif key in [KEY_A, KEY_LEFT, KEY_D, KEY_RIGHT, KEY_W, KEY_UP, KEY_S, KEY_DOWN]:
			if net_session.confirmed[net_session.slot]:
				return true
			if key in [KEY_A, KEY_LEFT, KEY_D, KEY_RIGHT]:
				cursor = posmod(cursor + (-1 if key in [KEY_A, KEY_LEFT] else 1), LegacyRoster.ids().size())
				if LegacyRoster.ids()[cursor] == net_session.pair[1 - net_session.slot]:
					cursor = posmod(cursor + (-1 if key in [KEY_A, KEY_LEFT] else 1), LegacyRoster.ids().size())
			else:
				cursor = ui.vertical_neighbor(cursor, -1 if key in [KEY_W, KEY_UP] else 1)
				if LegacyRoster.ids()[cursor] == net_session.pair[1 - net_session.slot]:
					cursor = posmod(cursor + 1, LegacyRoster.ids().size())
			net_session.choose(LegacyRoster.ids()[cursor])
		else:
			return false
		return true
	if screen in ["fight", "story"]:
		if key == KEY_ESCAPE:
			if net_session.phase != "playing":
				close_online()
			else:
				net_session.pause_game(true)
			return true
		if key == KEY_ENTER:
			if net_session.phase == "paused":
				net_session.pause_game(false)
			else:
				net_session.finish()
			return true
		if key in [KEY_F2, KEY_F3, KEY_F5, KEY_F8]:
			return true
	return false
