class_name FightHUD
extends Control
var sim: FightSimulation
var dummy_mode: int = 0
var paused: bool = false
var debug_boxes: bool = false
var effects: Array = []
const MINT := Color("4fe5cd")
const GOLD := Color("ffad52")

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func show_events(events: Array) -> void:
	for event in events:
		effects.append({"x": event.x / float(FighterModel.SCALE), "y": event.y / float(FighterModel.SCALE),
			"life": 0.2, "kind": event.kind})

func _process(delta: float) -> void:
	for effect in effects:
		effect.life -= delta
	effects = effects.filter(func(e: Dictionary) -> bool: return e.life > 0.0)
	queue_redraw()

func _text(at: Vector2, value: String, size: int, tint: Color = Color.WHITE) -> void:
	draw_string(ThemeDB.fallback_font, at, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, tint)

func _draw() -> void:
	if sim == null:
		return
	draw_rect(Rect2(0, 0, 1280, 143), Color(0.025, 0.045, 0.08, 0.95))
	_text(Vector2(36, 30), "STREET VICENTE FIGHTER", 18, MINT)
	_text(Vector2(859, 30), "GODOT 4  /  BASE LOCAL  /  120 Hz", 16, Color("9bacc1"))
	for i in 2:
		var x := 36 if i == 0 else 704
		var tint := MINT if i == 0 else GOLD
		_text(Vector2(x, 62), "LUTADOR 0%d" % (i + 1), 22, tint)
		draw_rect(Rect2(x, 76, 540, 18), Color("24354a"))
		var health_width := 536.0 * sim.fighters[i].health / sim.fighters[i].character.max_health
		var fill_x := x + 2 if i == 0 else x + 538 - health_width
		draw_rect(Rect2(fill_x, 78, health_width, 14), tint)
		var f := sim.fighters[i]
		var caption: String = FighterState.NAMES[f.state]
		if f.state == FighterState.Id.ATTACK:
			caption = "%s / %s / tick %d" % [f.current_move().display_name, f.current_move().phase(f.move_tick), f.move_tick]
		_text(Vector2(x, 119), caption, 15, Color("a6b7cb"))
	_text(Vector2(606, 85), "%02d" % ceili(sim.remaining_ticks / 120.0), 42)
	_text(Vector2(603, 112), "TEMPO", 12, Color("7b91aa"))
	draw_rect(Rect2(25, 155, 450, 41), Color(0.04, 0.075, 0.12, 0.92))
	_text(Vector2(39, 182), "F2  OPONENTE: " + ["2 JOGADORES", "PARADO", "DEFESA ALTA", "DEFESA BAIXA"][dummy_mode], 17, GOLD)
	_text(Vector2(39, 654), "P1  A/D mover   W pular   S agachar   F soco   G chute   H defender", 16, MINT)
	_text(Vector2(39, 680), "P2  ←/→ mover   ↑ pular   ↓ agachar   J soco   K chute   L defender", 16, GOLD)
	_text(Vector2(39, 708), "F1 caixas   •   F2 treino   •   R reiniciar   •   Esc pausa   •   F11 tela cheia", 15, Color("90a5bb"))
	for effect in effects:
		var origin := Vector2(effect.x, effect.y)
		var radius: float = 12 + (0.2 - effect.life) * 240
		var tint := Color("79bfff") if effect.kind == "block" else Color("ffecb0")
		tint.a = effect.life / 0.2
		for ray in 9:
			var direction := Vector2.from_angle(ray * TAU / 9)
			draw_line(origin + direction * radius * 0.35, origin + direction * radius, tint, 4, true)
	if paused or sim.winner >= 0:
		draw_rect(Rect2(0, 265, 1280, 150), Color(0.015, 0.03, 0.06, 0.9))
		var label := "PAUSA"
		if sim.winner >= 0:
			label = "EMPATE" if sim.winner == 2 else "LUTADOR 0%d VENCEU" % (sim.winner + 1)
		var width := ThemeDB.fallback_font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 38).x
		_text(Vector2((1280 - width) / 2, 327), label, 38, MINT)
		_text(Vector2(492, 372), "Esc continuar  /  R reiniciar", 20, Color("a6b7cb"))
