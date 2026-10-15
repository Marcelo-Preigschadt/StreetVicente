extends Node2D
## Native Godot shell. The original JavaScript engine is never embedded or executed.
const MENU := [
	"TESTAR MARCELO / NOVA ARTE",
	"VERSUS / CPU",
	"VERSUS / 2 JOGADORES",
	"MODO HISTÓRIA",
	"TREINAMENTO",
	"ONLINE / EM MIGRAÇÃO"
]
var screen: String = "menu"
var mode: String = "cpu"
var menu_index: int = 0
var selection_slot: int = 0
var cursor: int = 1
var selected: Array = ["marcelo", "rafael"]
var sim: FightSimulation
var story: StorySimulation
var input_source: LocalCombatInput
var ai := CombatAI.new()
var views: Array[SpriteFighterView] = []
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


func _ready() -> void:
	LegacyRoster.load_catalog()
	input_source = LocalCombatInput.new()
	add_child(input_source)
	audio = GameAudio.new()
	add_child(audio)
	story_view = StoryView.new()
	add_child(story_view)
	for i in 2:
		var view := SpriteFighterView.new()
		add_child(view)
		views.append(view)
	power_view = PowerView.new()
	add_child(power_view)
	impact = CombatImpact.new()
	add_child(impact)
	ui = GameScreen.new()
	ui.game = self
	add_child(ui)
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
		_start_fight()


func _start_fight() -> void:
	impact.clear()
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
	audio.play(LegacyRoster.catalog.sounds.get("announcer-fight", ""), "voice")


func _start_story() -> void:
	impact.clear()
	PilotArt.load_data()
	for atlas in PilotArt.data.sheets.values():
		LegacyRoster.texture(atlas.image)
	story = StorySimulation.new(LegacyRoster.get_character(selected[0]))
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
	if screen == "fight":
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
		impact.consume(sim.events, sim)
		power_view.consume(sim.events)
		if mode == "training" and sim.winner < 0:
			sim.remaining_ticks = 99 * 120
		for i in 2:
			if views[i].model != sim.fighters[i]:
				views[i].setup(sim.fighters[i], sim.fighters[i].character.color)
			views[i].sync()
		audio.consume(sim.events)
	elif screen == "story":
		story.step(input_source.sample(0))
		if views[0].model != story.hero:
			views[0].setup(story.hero, story.hero.character.color)
		views[0].camera_x = story.camera_x
		views[0].sync()
		audio.consume(story.events)
		impact.consume(story.events, null)
		power_view.consume(story.events)
	if qa:
		_publish_qa()


func _draw() -> void:
	if screen == "fight":
		draw_texture_rect(
			LegacyRoster.texture(LegacyRoster.catalog.arena), Rect2(0, 0, 1280, 720), false
		)


func _process(_delta: float) -> void:
	for view in views:
		view.impact_offset = impact.offset()
	impact.camera_x = story.camera_x if screen == "story" else 0.0
	power_view.camera_x = impact.camera_x
	queue_redraw()
	if qa and (paused or screen not in ["fight", "story"]):
		_publish_qa()


func _publish_qa() -> void:
	var data := {
		"screen": screen,
		"mode": mode,
		"selected": selected,
		"cursor": cursor,
		"slot": selection_slot,
		"roster": LegacyRoster.ids().size(),
		"roster_ids": LegacyRoster.ids(),
		"paused": paused
	}
	if screen == "fight" and sim != null:
		data.tick = sim.tick
		data.hp = [sim.fighters[0].health, sim.fighters[1].health]
		data.x = [sim.fighters[0].x, sim.fighters[1].x]
		data.y = [sim.fighters[0].y, sim.fighters[1].y]
		data.moves = [sim.fighters[0].move_id, sim.fighters[1].move_id]
		data.meter = [sim.fighters[0].meter, sim.fighters[1].meter]
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
			PilotArt.frame(sim.fighters[0]).index
			if sim.fighters[0].character.id == "marcelo"
			else 0
		)
		data.hash = sim.state_hash()
		data.new_art = views[0].use_new_art
		data.pose = (
			PilotArt.frame(sim.fighters[0]).key
			if sim.fighters[0].character.id == "marcelo"
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
	JavaScriptBridge.eval("window.svfQA = " + JSON.stringify(data), true)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var local: Vector2 = (event.position - position) / scale
		if screen == "menu":
			for i in MENU.size():
				if Rect2(75, 245 + i * 57, 570, 48).has_point(local):
					choose_menu(i)
		elif screen == "selection":
			for i in LegacyRoster.ids().size():
				if ui.card_rect(i).has_point(local):
					cursor = i
					confirm_selection()
					break
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var key: int = event.physical_keycode
	if key == KEY_F11:
		DisplayServer.window_set_mode(
			(
				DisplayServer.WINDOW_MODE_WINDOWED
				if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
				else DisplayServer.WINDOW_MODE_FULLSCREEN
			)
		)
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
	elif screen == "selection":
		if key in [KEY_A, KEY_LEFT]:
			cursor = posmod(cursor - 1, LegacyRoster.ids().size())
		elif key in [KEY_D, KEY_RIGHT]:
			cursor = (cursor + 1) % LegacyRoster.ids().size()
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
				input_source.clear()
				_snap_views()
		elif key == KEY_ENTER:
			if paused:
				paused = false
				input_source.clear()
			elif screen == "fight" and sim.match_over:
				choose_menu(1 if mode == "cpu" else 4 if mode == "training" else 2)
			elif screen == "story" and story.completed:
				screen = "menu"
				_hide_world()
		elif key == KEY_R:
			if screen == "fight":
				_start_fight()
			else:
				_start_story()
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
	elif t == 990:
		pressed = CombatInput.SPECIAL
	elif t == 1100:
		pressed = CombatInput.SUPER
	elif t == 1400:
		pressed = CombatInput.UP
	if t > 1000 and t < 1250:
		other = CombatInput.GUARD
	return [CombatInput.new(held, pressed), CombatInput.new(other)]
