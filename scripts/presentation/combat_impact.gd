class_name CombatImpact
extends Node2D
## Presentation consumes identified events; effects never modify authoritative state.
var particles: Array = []
var seen: Dictionary = {}
var flash: float = 0.0
var super_time: float = 0.0
var super_character: String = "marcelo"
var shake: float = 0.0
var camera_x: float = 0.0
var clock: float = 0.0


func clear() -> void:
	particles.clear()
	seen.clear()
	flash = 0.0
	super_time = 0.0
	shake = 0.0


func consume(events: Array, simulation: FightSimulation) -> void:
	for e in events:
		var id := str(e.id)
		if seen.has(id):
			continue
		seen[id] = true
		if seen.size() > 100:
			seen.erase(seen.keys()[0])
		if e.kind == "voice" and e.move == "super":
			super_time = 0.5
			super_character = e.character
			flash = 0.07
		if e.kind in ["hit", "block"]:
			var strong: bool = (
				str(e.get("move", "")).begins_with("super")
				or str(e.get("move", "")).begins_with("uppercut")
			)
			particles.append(
				{
					"x": float(e.x) / FighterModel.SCALE,
					"y": float(e.y) / FighterModel.SCALE,
					"life": 0.24 if strong else 0.16,
					"max": 0.24 if strong else 0.16,
					"blocked": e.kind == "block",
					"strong": strong,
					"seed": int(e.get("tick", 0)) % 13
				}
			)
			shake = 6.0 if strong else 2.5
			if strong:
				flash = 0.045
	if simulation != null and simulation.freeze_ticks > 0:
		shake = maxf(shake, 1.0)


func _process(delta: float) -> void:
	clock += delta
	flash = maxf(0.0, flash - delta)
	super_time = maxf(0.0, super_time - delta)
	shake = maxf(0.0, shake - delta * 35.0)
	for p in particles:
		p.life -= delta
	particles = particles.filter(func(p: Dictionary) -> bool: return p.life > 0.0)
	queue_redraw()


func offset() -> Vector2:
	return Vector2(sin(clock * 133), cos(clock * 97)) * shake


func _draw() -> void:
	for p in particles:
		var origin := Vector2(float(p.x) - camera_x, float(p.y))
		var phase := 1.0 - float(p.life) / float(p.max)
		var color := Color("80e8ff") if p.blocked else Color("ffe599")
		color.a = 1.0 - phase
		if p.blocked:
			draw_arc(origin, 14 + phase * 30, -1.2, 1.2, 18, color, 4, true)
		else:
			var count := 14 if p.strong else 9
			for i in count:
				var angle := TAU * float(i) / count + float(p.seed) * 0.23
				var ray := Vector2(cos(angle), sin(angle))
				var reach := (70.0 if p.strong else 42.0) * (0.35 + phase)
				draw_line(
					origin + ray * reach * 0.35,
					origin + ray * reach,
					color,
					4.0 * (1.0 - phase) + 1,
					true
				)
			draw_circle(origin, 10 * (1.0 - phase), Color(1, 1, 1, color.a))
	if flash > 0:
		draw_rect(Rect2(0, 112, 1280, 552), Color(0.8, 1, 0.95, flash * 3.0))
