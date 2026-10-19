class_name PowerView
extends Node2D
## One presenter for both worlds: windup, release, projectiles, drones, beams and impacts.
var world
var camera_x: float = 0.0
var clock: float = 0.0
var bursts: Array = []
var seen: Dictionary = {}
var presentation_paused: bool = false


func setup(value) -> void:
	world = value
	bursts.clear()
	seen.clear()
	PowerArt.load_data()
	LegacyRoster.texture(PowerArt.data.image)
	MarceloPowerFX.load_art()
	LegacyRoster.texture(MarceloPowerFX.art.image)
	for actor in world.power_actors():
		if actor.character.id == "marcos":
			MarcosFXV16.load_data()
			LegacyRoster.texture(MarcosFXV16.art.image)


func consume(events: Array) -> void:
	for e in events:
		if seen.has(e.id):
			continue
		seen[e.id] = true
		if seen.size() > 256:
			seen.erase(seen.keys()[0])
		if (
			e.kind in ["cast", "laser", "beam"]
			or (e.kind in ["hit", "block"] and e.get("power_kind", "") != "")
		):
			bursts.append(
				{
					"x": float(e.x) / FighterModel.SCALE,
					"y": float(e.y) / FighterModel.SCALE,
					"kind": e.kind,
					"character": e.character,
					"effect": e.get("effect", ""),
					"move": e.get("move", ""),
					"slot": int(e.get("slot", -1)),
					"facing": int(e.get("facing", 1)),
					"origin_x": float(e.get("origin_x", e.x)) / FighterModel.SCALE,
					"origin_y": float(e.get("origin_y", e.y)) / FighterModel.SCALE,
					"life": 0.14 if e.kind in ["beam", "cast"] else 0.32,
					"max": 0.14 if e.kind in ["beam", "cast"] else 0.32
				}
			)


func _process(delta: float) -> void:
	if presentation_paused:
		queue_redraw()
		return
	clock += delta
	for b in bursts:
		b.life -= delta
	bursts = bursts.filter(func(b: Dictionary) -> bool: return b.life > 0.0)
	queue_redraw()


func _draw() -> void:
	if world == null:
		return
	for f in world.power_actors():
		PowerFXV10.charge(self, f, camera_x, world.power_actors())
	for p in world.projectiles:
		# Each entity starts in world space. A beam must not inherit the preceding
		# drone's translation or facing transform.
		draw_set_transform(Vector2.ZERO)
		var origin := Vector2(
			float(p.x) / FighterModel.SCALE - camera_x, float(p.y) / FighterModel.SCALE
		)
		if p.kind == "laser":
			var start := Vector2(
				float(p.origin_x) / FighterModel.SCALE - camera_x,
				float(p.origin_y) / FighterModel.SCALE
			)
			MarceloPowerFX.beam(self, start, origin, 1.0)
			continue
		if p.drone:
			MarceloPowerFX.drone(self, p, camera_x, clock, world.power_actors())
			continue
		PowerFXV10.projectile(self, p, camera_x)
	draw_set_transform(Vector2.ZERO)
	for b in bursts:
		if b.kind == "beam" or b.effect == "sentinelLaser" or b.kind == "laser":
			_draw_burst(b)
		else:
			PowerFXV10.impact(self, b, world.power_actors(), camera_x)
	draw_set_transform(Vector2.ZERO)


func _draw_burst(b: Dictionary) -> void:
	if b.character == "marcelo":
		MarceloPowerFX.burst(self, b, camera_x)
		return
	var phase := 1.0 - float(b.life) / float(b.max)
	var alpha := 1.0 - phase
	var origin := Vector2(float(b.x) - camera_x, float(b.y))
	var c := LegacyRoster.get_character(b.character)
	var color := c.color
	draw_set_transform(origin)
	var theme := PowerArt.theme(b.character, b.effect)
	if b.effect == "sentinelLaser" and b.kind == "hit":
		# The drone fires light: use a compact hot core and sparks, not the
		# character's separate code-wave drawing on every beam contact.
		draw_circle(Vector2.ZERO, 10 * alpha, Color(0.8, 1, 0.9, alpha))
		draw_circle(Vector2.ZERO, 4 * alpha, Color(1, 1, 1, alpha))
	elif theme in ["code", "smoke", "fork", "book"] and b.kind == "hit":
		PowerArt.draw(self, theme, int(phase * 4), 0.5 + phase * 0.3, Color(1, 1, 1, alpha))
	for i in 10:
		var angle := float(i) * TAU / 10 + phase
		var direction := Vector2(cos(angle), sin(angle))
		var distance := 10 + phase * 65
		draw_line(direction * distance * 0.5, direction * distance, Color(color, alpha), 3, true)
	if b.kind == "laser":
		draw_circle(Vector2.ZERO, 13 * alpha, Color(0.8, 1, 0.85, alpha))
	else:
		draw_arc(Vector2.ZERO, 12 + phase * 36, 0, TAU, 32, Color(color, alpha * 0.6), 2, true)
	draw_set_transform(Vector2.ZERO)
