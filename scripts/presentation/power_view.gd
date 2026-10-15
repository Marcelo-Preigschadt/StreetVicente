class_name PowerView
extends Node2D
## One presenter for both worlds: windup, release, projectiles, drones, beams and impacts.
var world
var camera_x: float = 0.0
var clock: float = 0.0
var bursts: Array = []
var seen: Dictionary = {}


func setup(value) -> void:
	world = value
	bursts.clear()
	seen.clear()
	PowerArt.load_data()
	LegacyRoster.texture(PowerArt.data.image)


func consume(events: Array) -> void:
	for e in events:
		if seen.has(e.id):
			continue
		seen[e.id] = true
		if seen.size() > 256:
			seen.erase(seen.keys()[0])
		if (
			e.kind in ["cast", "laser"]
			or (e.kind in ["hit", "block"] and e.get("power_kind", "") != "")
		):
			bursts.append(
				{
					"x": float(e.x) / FighterModel.SCALE,
					"y": float(e.y) / FighterModel.SCALE,
					"kind": e.kind,
					"character": e.character,
					"effect": e.get("effect", ""),
					"life": 0.28,
					"max": 0.28
				}
			)


func _process(delta: float) -> void:
	clock += delta
	for b in bursts:
		b.life -= delta
	bursts = bursts.filter(func(b: Dictionary) -> bool: return b.life > 0.0)
	queue_redraw()


func _draw() -> void:
	if world == null:
		return
	for f in world.power_actors():
		_draw_charge(f)
	for p in world.projectiles:
		# Each entity starts in world space. A beam must not inherit the preceding
		# drone's translation or facing transform.
		draw_set_transform(Vector2.ZERO)
		var origin := Vector2(
			float(p.x) / FighterModel.SCALE - camera_x, float(p.y) / FighterModel.SCALE
		)
		var facing := int(p.get("facing", signi(int(p.vx))))
		if p.kind == "laser":
			var start := Vector2(
				float(p.origin_x) / FighterModel.SCALE - camera_x,
				float(p.origin_y) / FighterModel.SCALE
			)
			draw_line(start, origin, Color(0.15, 1, 0.45, 0.12), 20, true)
			draw_line(start, origin, Color(0.3, 1, 0.6, 0.5), 8, true)
			draw_line(start, origin, Color("e8fff3"), 2.5, true)
			draw_circle(origin, 9, Color(0.25, 1, 0.5, 0.5))
			draw_circle(origin, 4, Color.WHITE)
			continue
		draw_set_transform(origin, 0, Vector2(facing, 1))
		if p.drone:
			var frame := int(p.age / 8) % 2
			if p.fired:
				frame = 2 if int(p.age) - int(p.fire_tick) < 12 else 3
			PowerArt.draw(self, "drone", frame, 0.36)
			if not p.fired:
				var progress := 1.0 - float(p.delay) / maxf(1, float(p.warmup))
				draw_arc(
					Vector2(19, 3),
					13,
					-PI / 2,
					-PI / 2 + TAU * progress,
					24,
					Color(0.55, 1, 0.75, 0.8),
					2,
					true
				)
			continue
		var character := str(p.character)
		var theme := PowerArt.theme(character, p.effect)
		_draw_projectile(theme, int(p.age), LegacyRoster.get_character(character).color)
	draw_set_transform(Vector2.ZERO)
	for b in bursts:
		_draw_burst(b)
	draw_set_transform(Vector2.ZERO)


func _draw_projectile(theme: String, age: int, color: Color) -> void:
	var frame := int(age / 6)
	match theme:
		"code":
			PowerArt.draw(self, "code", frame, 0.60)
			for i in 5:
				draw_string(
					ThemeDB.fallback_font,
					Vector2(-90 - i * 14, -30 + (i % 3) * 18),
					["0", "1", "{", "}", "/"][i],
					HORIZONTAL_ALIGNMENT_LEFT,
					-1,
					12,
					Color(0.6, 1, 0.8, 0.7 - i * 0.1)
				)
		"smoke":
			PowerArt.draw(self, "smoke", frame, 0.55)
		"fork":
			PowerArt.draw(self, "fork", frame, 0.34)
		"book":
			PowerArt.draw(self, "book", frame, 0.36)
		"chalk":
			draw_line(Vector2(-60, 0), Vector2(5, 0), Color(1, 0.65, 0.95, 0.25), 9, true)
			draw_rect(Rect2(-12, -5, 26, 10), Color("fff2e7"))
			for i in 5:
				draw_circle(
					Vector2(-22 - i * 11, ((age + i * 7) % 13) - 6),
					2,
					Color(1, 0.85, 0.9, 0.7 - i * 0.1)
				)
		"scroll":
			PowerArt.draw(self, "book", frame, 0.4, Color(1, 0.8, 0.45))
		"lightning":
			_bolt(Vector2(-90, 0), Vector2(20, 0), color, age)
			_bolt(Vector2(-65, 14), Vector2(15, 0), Color("deffff"), age + 7)
		"paint":
			for i in 5:
				var c := Color.from_hsv(float(i) / 5, 0.8, 1)
				draw_line(
					Vector2(-100 + i * 8, -28 + i * 12), Vector2(18, 0), Color(c, 0.6), 9 - i, true
				)
		_:
			_ribbon(color, age)


func _draw_charge(f: FighterModel) -> void:
	if f.state != FighterState.Id.ATTACK or f.character.legacy.is_empty():
		return
	var move := f.current_move()
	var name: String = move.legacy.name
	if name not in ["special", "super", "drone", "uppercut"]:
		return
	var root := Vector2(float(f.x) / FighterModel.SCALE - camera_x, float(f.y) / FighterModel.SCALE)
	var hand := root + Vector2(f.facing * 135, -195)
	var color := f.character.color
	var phase := move.phase(f.move_tick)
	if phase == "STARTUP":
		var progress := float(f.move_tick) / maxf(1, move.startup * 2)
		draw_set_transform(hand, 0, Vector2(f.facing, 1))
		for i in 9:
			var angle := float(i) * TAU / 9 + progress * 2
			var d := 45 * (1.0 - progress) + 12
			var p := Vector2(cos(angle), sin(angle)) * d
			draw_line(p, p * 0.6, Color(color, 0.35 + progress * 0.5), 2, true)
			draw_rect(Rect2(p - Vector2.ONE * 2, Vector2.ONE * 4), Color(color, 0.7))
		draw_set_transform(Vector2.ZERO)
	if (
		phase == "ACTIVE"
		and not move.legacy.get("projectile", false)
		and not move.legacy.get("summon", false)
	):
		draw_set_transform(root + Vector2(0, -155), 0, Vector2(f.facing, 1))
		if f.character.id in ["joao", "ruan"]:
			for i in 4:
				_bolt(
					Vector2(-55, -100 + i * 55),
					Vector2(80, -50 + i * 45),
					color,
					f.move_tick + i * 7
				)
		elif name == "uppercut":
			for i in 3:
				draw_arc(
					Vector2(10 + i * 5, -20),
					65 + i * 9,
					-2.0,
					0.9,
					24,
					Color(color, 0.8 - i * 0.2),
					5 - i,
					true
				)
		else:
			_ribbon(color, f.move_tick)
		draw_set_transform(Vector2.ZERO)


func _draw_burst(b: Dictionary) -> void:
	var phase := 1.0 - float(b.life) / float(b.max)
	var alpha := 1.0 - phase
	var origin := Vector2(float(b.x) - camera_x, float(b.y))
	var c := LegacyRoster.get_character(b.character)
	var color := c.color
	draw_set_transform(origin)
	var theme := PowerArt.theme(b.character, b.effect)
	if theme in ["code", "smoke", "fork", "book"] and b.kind == "hit":
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


func _bolt(start: Vector2, end: Vector2, color: Color, seed_value: int) -> void:
	var points := PackedVector2Array()
	for i in 9:
		var point := start.lerp(end, float(i) / 8)
		if i > 0 and i < 8:
			point.y += float((seed_value * 7 + i * 13) % 23 - 11)
		points.append(point)
	draw_polyline(points, Color(color, 0.25), 12, true)
	draw_polyline(points, color, 5, true)
	draw_polyline(points, Color("f2ffff"), 1.5, true)


func _ribbon(color: Color, age: int) -> void:
	var points := PackedVector2Array()
	for i in 12:
		points.append(Vector2(-100 + i * 11, sin(float(age + i * 6) * 0.15) * (10 + i)))
	draw_polyline(points, Color(color, 0.25), 16, true)
	draw_polyline(points, color, 6, true)
	draw_polyline(points, Color(1, 1, 1, 0.9), 2, true)
