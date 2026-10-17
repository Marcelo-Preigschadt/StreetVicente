extends Node2D
## Native Godot shell. The original JavaScript engine is never embedded or executed.
const MENU := [
	"TREINO LIVRE",
	"CIRCUITO VICENTE / CPU",
	"VERSUS / 2 JOGADORES",
	"HISTÓRIA / RESGATE DO NIT",
	"TREINAMENTO",
	"ONLINE / EM MIGRAÇÃO"
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
var net_session: Node
var qa: bool = false
var demo: bool = false
var impact: CombatImpact
var last_contacts: Array = []
var reference_heights: Dictionary = {}
var qa_trace: Array = []
var qa_trace_key: String = ""
var qa_round_calls: Array = []


func _ready() -> void:
	LegacyRoster.load_catalog()
	progress.load_saved()
	saved_record = progress.record
	input_source = LocalCombatInput.new()
	add_child(input_source)
	audio = GameAudio.new()
	add_child(audio)
	story_view = StoryView.new()
	add_child(story_view)
	impact = CombatImpact.new()
	var backdrop := PowerBackdrop.new()
	backdrop.impact = impact
	add_child(backdrop)
	for i in 2:
		var view := SpriteFighterView.new()
		add_child(view)
		views.append(view)
	power_view = PowerView.new()
	add_child(power_view)
	add_child(impact)
	ui = GameScreen.new()
	ui.game = self
	add_child(ui)
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
		if mode == "cpu":
			arcade = ArcadeRun.new(LegacyRoster.ids(), selected[0], selected[1], progress.record)
		_start_fight()


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
	story_view.show()
	power_view.setup(story)
	power_view.show()


func _physics_process(_delta: float) -> void:
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


func _draw() -> void:
	# Cover the expanded viewport as well as the logical 16:9 playfield. The floor
	# stays at y625 while the camera reveals more scenery on wide/tall windows.
	var area := Rect2(-position / scale, get_viewport_rect().size / scale)
	var texture := LegacyRoster.texture(LegacyRoster.catalog.arena)
	var k := maxf(1.0, maxf(area.size.x / 1280.0, (625.0 - area.position.y) / 625.0))
	var target := Rect2(Vector2(640 - 640 * k, 625 - 625 * k), Vector2(1280, 720) * k)
	draw_texture_rect(texture, target, false)
	if target.end.y < area.end.y:
		draw_texture_rect_region(
			texture,
			Rect2(area.position.x, target.end.y, area.size.x, area.end.y - target.end.y),
			Rect2(0, texture.get_height() - 32, texture.get_width(), 32)
		)


func _process(_delta: float) -> void:
	save_clock += _delta
	if save_clock >= 1.0 and progress.record != saved_record:
		progress.save()
		saved_record = progress.record
		save_clock = 0.0
	for view in views:
		view.impact_offset = impact.offset()
		view.presentation_paused = paused
		view.presentation_frozen = (
			paused or (screen == "fight" and sim != null and sim.freeze_ticks > 0)
		)
	power_view.position = impact.offset()
	power_view.presentation_paused = paused
	impact.presentation_paused = paused
	impact.position = impact.offset()
	impact.camera_x = story.camera_x if screen == "story" else 0.0
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
			"pose": pose.key,
			"pose_index": pose.index,
			"y": f.y,
			"vy": f.vy,
			"hit_count": f.attack_boxes().size()
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
		"checkpoint": progress.valid_checkpoint()
	}
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
		data.fx_revision = 9
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
		data.power_kinds = sim.projectiles.map(func(p: Dictionary) -> String: return str(p.kind))
		data.power_sprites = power_view.visible
		data.power_positions = sim.projectiles.map(
			func(p: Dictionary) -> Dictionary:
				return {
					"x": float(p.x) / 256.0,
					"y": float(p.y) / 256.0,
					"kind": p.kind,
					"age": p.age,
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
			"act": story.act_index,
			"wave": story.wave_index,
			"enemies": story.enemies.size(),
			"hp": story.hero.health,
			"projectiles": story.projectiles.size(),
			"power_sprites": power_view.visible,
			"power_kinds": story.projectiles.map(func(p: Dictionary) -> String: return str(p.kind)),
			"x": story.hero.x,
			"y": story.hero.y
		}
	data.controls_open = controls.visible
	data.controller_devices = AppSettings.devices
	if controls.visible:
		data.controller_ui = {
			"device_label": controls.device_list.get_item_text(controls.device_list.selected),
			"device_id": controls.device_list.get_selected_id()
		}

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
	if key == KEY_F11:
		toggle_fullscreen()
		get_viewport().set_input_as_handled()
		return
	if key == KEY_F10:
		controls.open()
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
			screen = "menu"
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
