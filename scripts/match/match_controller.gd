extends Node2D
## Controlador local. Não colocar regra de combate no _process ou nos views.
const PROTOTYPE: CharacterData = preload("res://data/characters/prototype.tres")
var sim: FightSimulation
var input_source: LocalCombatInput
var views: Array[FighterView] = []
var hud: FightHUD
var paused: bool = false
var focus_lost: bool = false
var dummy_mode: int = 0
var debug_boxes: bool = false

func _ready() -> void:
	add_child(TrainingStage.new())
	input_source = LocalCombatInput.new()
	add_child(input_source)
	for i in 2:
		var view := FighterView.new()
		add_child(view)
		views.append(view)
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = FightHUD.new()
	layer.add_child(hud)
	_reset()
	get_viewport().size_changed.connect(_fit_viewport)
	_fit_viewport()

func _fit_viewport() -> void:
	# Viewport lógico fixo e letterbox preservam coordenadas de combate em qualquer tela.
	var area := get_viewport_rect().size
	var factor := minf(area.x / 1280.0, area.y / 720.0)
	scale = Vector2.ONE * factor
	position = (area - Vector2(1280, 720) * factor) / 2
	# CanvasLayer não herda o transform do Node2D.
	hud.scale = Vector2.ONE * factor
	hud.position = position

func _reset() -> void:
	sim = FightSimulation.new(PROTOTYPE, PROTOTYPE)
	for i in 2:
		views[i].setup(sim.fighters[i], Color("4fe5cd") if i == 0 else Color("ffad52"))
	hud.sim = sim
	hud.effects.clear()
	paused = false
	focus_lost = false
	hud.paused = false
	input_source.clear()

func _physics_process(_delta: float) -> void:
	if paused or focus_lost:
		return
	var inputs: Array[CombatInput] = [input_source.sample(0), input_source.sample(1)]
	if dummy_mode > 0:
		var held := 0
		if dummy_mode >= 2:
			held |= CombatInput.GUARD
		if dummy_mode == 3:
			held |= CombatInput.DOWN
		inputs[1] = CombatInput.new(held)
	sim.step(inputs)
	for view in views:
		view.sync()
	hud.show_events(sim.events)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("reset_match"):
		_reset()
	elif event.is_action_pressed("debug_boxes"):
		debug_boxes = not debug_boxes
		for view in views:
			view.debug_boxes = debug_boxes
	elif event.is_action_pressed("dummy_mode"):
		dummy_mode = (dummy_mode + 1) % 4
		hud.dummy_mode = dummy_mode
	elif event.is_action_pressed("pause_match"):
		paused = not paused
		focus_lost = false
		hud.paused = paused
		input_source.clear()
	elif event.is_action_pressed("fullscreen"):
		var mode := DisplayServer.window_get_mode()
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if mode == DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_instance_valid(input_source):
		focus_lost = true
		paused = true
		hud.paused = true
		input_source.clear()
