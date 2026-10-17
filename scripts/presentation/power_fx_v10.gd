class_name PowerFXV10
extends RefCounted
## Character-specific, layered 2D effects. Clocks never drive damage or movement.
const INK := Color("111323")
const WHITE := Color("f8ffef")
static var radial: GradientTexture2D


static func glow(c: CanvasItem, at: Vector2, radius: float, color: Color, alpha: float) -> void:
	if radial == null:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0, 0.15, 0.45, 1])
		g.colors = PackedColorArray(
			[Color.WHITE, Color(1, 1, 1, 0.65), Color(1, 1, 1, 0.16), Color(1, 1, 1, 0)]
		)
		radial = GradientTexture2D.new()
		radial.gradient = g
		radial.fill = GradientTexture2D.FILL_RADIAL
		radial.width = 128
		radial.height = 128
		radial.fill_from = Vector2(0.5, 0.5)
		radial.fill_to = Vector2(1, 0.5)
	c.draw_texture_rect(
		radial,
		Rect2(at - Vector2.ONE * radius, Vector2.ONE * radius * 2),
		false,
		Color(color, alpha)
	)


static func line(
	c: CanvasItem, points: PackedVector2Array, color: Color, width: float, alpha: float = 1
) -> void:
	c.draw_polyline(points, Color(INK, alpha * 0.7), width + 3, true)
	c.draw_polyline(points, Color(color, alpha * 0.25), width * 3.2, true)
	c.draw_polyline(points, Color(color, alpha), width, true)
	c.draw_polyline(points, Color(WHITE, alpha), maxf(1, width * 0.23), true)


static func bolt(
	c: CanvasItem, a: Vector2, b: Vector2, color: Color, seed_value: int, alpha: float = 1
) -> void:
	var p := PackedVector2Array()
	var normal := (b - a).orthogonal().normalized()
	for i in 9:
		var at := a.lerp(b, float(i) / 8)
		if i > 0 and i < 8:
			at += normal * (((seed_value * 11 + i * 17) % 29) - 14)
		p.append(at)
	line(c, p, color, 4, alpha)


static func stroke(
	c: CanvasItem, color: Color, age: int, length: float = 150, spread: float = 28
) -> void:
	for layer in 3:
		var points := PackedVector2Array()
		for i in 12:
			var t := float(i) / 11
			points.append(
				Vector2(
					-length * t,
					sin(t * PI) * spread * (layer - 1) + sin((age + i * 3) * 0.18) * t * 8
				)
			)
		line(c, points, color, 5 - layer, 0.7 - layer * 0.15)


static func seal(c: CanvasItem, age: int, color: Color) -> void:
	var angle := age * 0.025
	var points := PackedVector2Array()
	for i in 24:
		var a := angle + i * TAU / 24
		points.append(Vector2(cos(a), sin(a)) * (32 if i % 2 == 0 else 26))
	c.draw_colored_polygon(points, INK)
	for i in points.size():
		points[i] *= 0.86
	c.draw_colored_polygon(points, color)
	c.draw_arc(Vector2.ZERO, 19, 0, TAU, 32, WHITE, 2, true)
	for side in [-1, 1]:
		for i in 5:
			var a := -1.0 + i * 0.45
			var at := Vector2(side * (14 + sin(a) * 8), cos(a) * 17)
			c.draw_line(at, at + Vector2(side * 7, -4), INK, 3, true)
	c.draw_line(Vector2(-3, -12), Vector2(-3, 10), INK, 4, true)
	c.draw_line(Vector2(-10, -9), Vector2(7, -9), INK, 3, true)


static func projectile(c: CanvasItem, p: Dictionary, camera: float) -> void:
	if p.character == "gustavo":
		GustavoFXV12.projectile(c, p, camera)
		return
	var origin := Vector2(float(p.x) / 256 - camera, float(p.y) / 256)
	var facing := int(p.get("facing", 1))
	var age := int(p.age)
	var character := str(p.character)
	var color := LegacyRoster.get_character(character).color
	var theme := PowerArt.theme(character, p.effect)
	var frame := age / 5
	c.draw_set_transform(origin, 0, Vector2(facing, 1))
	glow(c, Vector2.ZERO, 65, color, 0.5)
	match character:
		"marcelo":
			stroke(c, Color("9aff65"), age, 170, 20)
			ArcadeEffects.draw_cel(c, "code", frame, 0.45)
			for i in 4:
				var x := -35 - i * 31.0
				c.draw_polyline(
					PackedVector2Array(
						[
							Vector2(x - 18, 20),
							Vector2(x - 8, 20),
							Vector2(x - 8, -12),
							Vector2(x + 5, -12)
						]
					),
					Color("d7ffb3"),
					2,
					true
				)
		"adriano":
			stroke(c, color, age, 135, 22)
			seal(c, age, color)
		"rafael":
			stroke(c, color, age, 165, 26)
			ArcadeEffects.draw_cel(c, "scroll", frame, 0.56)
			for i in 5:
				var x := -25.0 - i * 28
				c.draw_line(
					Vector2(x, -17 - i * 2),
					Vector2(x, 17 + i * 2),
					Color("fff0b9", 0.8 - i * 0.12),
					2,
					true
				)
		"khauany":
			stroke(c, color, age, 175, 18)
			for i in [2, 1]:
				c.draw_set_transform(
					origin - Vector2(i * 32 * facing, i * 5), 0, Vector2(facing, 1)
				)
				PowerArt.draw(c, "fork", frame, 0.38, Color(color, 0.22 / i))
			c.draw_set_transform(origin, 0, Vector2(facing, 1))
			PowerArt.draw(c, "fork", frame, 0.4)
			c.draw_line(Vector2(-12, -7), Vector2(27, -7), WHITE, 2, true)
		"dienes":
			stroke(c, color, age, 150, 22)
			if theme == "chalk":
				c.draw_set_transform(origin, 0.14 * sin(age * 0.2), Vector2(facing, 1))
				c.draw_rect(Rect2(-18, -7, 38, 14), INK)
				c.draw_rect(Rect2(-16, -5, 34, 10), WHITE)
			else:
				PowerArt.draw(c, "book", frame, 0.47)
				for i in 4:
					var at := Vector2(-35 - i * 21, sin(age * 0.15 + i) * 25)
					c.draw_colored_polygon(
						PackedVector2Array([at, at + Vector2(15, -6), at + Vector2(9, 7)]),
						Color(WHITE, 0.8 - i * 0.15)
					)
		"gelton":
			for i in 5:
				var paint := Color.from_hsv(fposmod(i * 0.17 + 0.01 * age, 1), 0.75, 1)
				var points := PackedVector2Array()
				for j in 14:
					var t := float(j) / 13
					points.append(Vector2(-150 * t, sin(t * PI) * (i - 2) * 18))
				line(c, points, paint, 8 - i, 0.9)
			for i in 7:
				var a := age * 0.1 + i * 2.4
				var at := Vector2(cos(a) * 21, sin(a) * 27)
				c.draw_circle(at, 4 + i % 3, Color.from_hsv(i / 7.0, 0.7, 1))
		"ruan":
			for i in 3:
				bolt(
					c,
					Vector2(-155, (-1 + i) * 28),
					Vector2(35, (-1 + i) * 7),
					color,
					age / 3 + i * 7
				)
		"marcos":
			stroke(c, color, age, 160, 23)
			for i in 4:
				var x := 15.0 - i * 34
				line(
					c,
					PackedVector2Array(
						[
							Vector2(x - 22, 22),
							Vector2(x - 22, -18),
							Vector2(x, -18),
							Vector2(x + 14, 0),
							Vector2(x, 18)
						]
					),
					color,
					3,
					1 - i * 0.18
				)
		"marcelino":
			for i in 4:
				var x := 25.0 - i * 34
				line(
					c,
					PackedVector2Array([Vector2(x - 25, -25), Vector2(x, 0), Vector2(x - 25, 25)]),
					color,
					5,
					1 - i * 0.18
				)
			c.draw_arc(Vector2.ZERO, 29, -1.25, 1.25, 20, WHITE, 4, true)
		"tais":
			stroke(c, color, age, 175, 42)
			for i in 3:
				c.draw_arc(
					Vector2(-i * 22, 0),
					28 + i * 6,
					-1.2,
					1.2,
					24,
					Color(WHITE, 0.9 - i * 0.2),
					4 - i,
					true
				)
		"luciana":
			for i in 3:
				var points := PackedVector2Array(
					[
						Vector2(-145, -28 + i * 23),
						Vector2(-86, 35 - i * 26),
						Vector2(-35, -24 + i * 15),
						Vector2(24, -10 + i * 8)
					]
				)
				line(c, points, color, 8 - i * 2, 0.9 - i * 0.15)
			for i in 4:
				c.draw_line(
					Vector2(-80 - i * 15, -25 - i * 2),
					Vector2(-65 - i * 15, -35 - i * 2),
					Color(WHITE, 0.6),
					2,
					true
				)
		_:
			stroke(c, color, age)
	c.draw_set_transform(Vector2.ZERO)


static func hand(f: FighterModel, camera: float) -> Vector2:
	if f.character.id in ["marcelo", "rafael", "adriano", "joao", "gustavo"]:
		return Vector2(CombatGeometry.hand(f)) / 256 - Vector2(camera, 0)
	var source: Dictionary = f.character.legacy.get("projectile", {})
	return Vector2(
		f.x / 256.0 - camera + f.facing * float(source.get("offset", 134)),
		f.y / 256.0 - float(source.get("height", 199))
	)


static func upper(c: CanvasItem, f: FighterModel, camera: float) -> void:
	var move := f.current_move()
	var phase := move.phase(f.move_tick)
	var root := Vector2(f.x / 256.0 - camera, f.y / 256.0)
	var color := f.character.color
	if phase == "STARTUP":
		var p := float(f.move_tick) / maxi(1, move.startup * 2)
		c.draw_set_transform(root + Vector2(22 * f.facing, -70), 0, Vector2(f.facing, 1))
		glow(c, Vector2.ZERO, 35 + p * 65, color, 0.4 + p * 0.3)
		for i in 4:
			var x := -30.0 + i * 27
			line(
				c, PackedVector2Array([Vector2(x, 20), Vector2(x + 20, -18 - p * 35)]), color, 3, p
			)
	elif phase == "ACTIVE":
		c.draw_set_transform(
			root,
			0,
			Vector2(
				f.facing * CharacterMetrics.factor(f.character.id),
				CharacterMetrics.factor(f.character.id)
			)
		)
		var cel := clampi(2 + (f.move_tick - move.startup * 2) / 4, 2, 5)
		PowerCelsV10.draw(
			c,
			"upper",
			cel,
			0.83 * float(PowerMoves.upper_profile(f.character.id)[2]) / 170.0,
			color.lerp(WHITE, 0.38)
		)
		var center := Vector2(90, -195)
		glow(c, center, 95, color, 0.28)
		match f.character.id:
			"adriano":
				for i in 4:
					var at := Vector2(52 + i % 2 * 45, -100 - i * 47)
					c.draw_rect(Rect2(at, Vector2(32, 24)), Color(WHITE, 0.4))
			"rafael":
				for i in 5:
					c.draw_line(
						Vector2(115, -100 - i * 36), Vector2(133, -108 - i * 36), WHITE, 2, true
					)
			"gelton":
				for i in 4:
					c.draw_arc(
						center,
						53 + i * 11,
						-1.6,
						1.1,
						24,
						Color.from_hsv(i * 0.22, 0.7, 1),
						4,
						true
					)
			"khauany":
				for i in 3:
					line(
						c,
						PackedVector2Array(
							[Vector2(85 + i * 13, -130), Vector2(130 + i * 8, -245)]
						),
						WHITE,
						2
					)
			"dienes", "luciana":
				for i in 4:
					var at := Vector2(105 + i * 8, -110 - i * 48)
					c.draw_colored_polygon(
						PackedVector2Array([at, at + Vector2(13, -9), at + Vector2(9, 7)]), WHITE
					)
			"joao", "ruan":
				bolt(c, Vector2(70, -80), Vector2(135, -310), color, f.move_tick / 3)
			"marcos", "marcelo":
				for i in 4:
					c.draw_rect(Rect2(120 - i * 9, -120 - i * 43, 9, 15), WHITE, false, 2)
			_:
				for i in 3:
					c.draw_arc(center, 55 + i * 13, -1.5, 0.5, 24, Color(WHITE, 0.7), 2, true)
	c.draw_set_transform(Vector2.ZERO)


static func roll(c: CanvasItem, f: FighterModel, camera: float, actors: Array) -> void:
	var at := Vector2(f.x / 256.0 - camera, f.y / 256.0 - 130)
	var color := Color("beff50")
	c.draw_set_transform(at, 0, Vector2(f.facing, 1))
	if f.roll_phase in [RollMotion.TRAVEL, RollMotion.SHOCK, RollMotion.REBOUND]:
		var strength := 0.65 if f.roll_phase == RollMotion.REBOUND else 1.0
		glow(c, Vector2.ZERO, 150, color, 0.5 * strength)
		PowerCelsV10.draw(c, "ring", f.move_tick / 4, 0.82, Color(color.lerp(WHITE, 0.4), strength))
		if f.roll_phase == RollMotion.TRAVEL:
			for i in 5:
				var y := -64.0 + i * 31
				line(
					c,
					PackedVector2Array(
						[
							Vector2(-110, y),
							Vector2(-175 - i * 9, y * 0.65),
							Vector2(-230 - i * 9, y * 0.35)
						]
					),
					color,
					3,
					0.7 - i * 0.08
				)
	else:
		var p := clampf(f.move_tick / float(maxi(1, f.current_move().startup * 2)), 0, 1)
		glow(c, Vector2.ZERO, 50 + p * 65, color, 0.5)
		for i in 3:
			bolt(
				c,
				Vector2(-45, -40 + i * 42),
				Vector2(45, -50 + i * 42),
				color,
				f.move_tick / 3 + i * 7,
				p
			)
	c.draw_set_transform(Vector2.ZERO)
	if f.roll_phase == RollMotion.SHOCK:
		for target in actors:
			if target.slot == f.roll_target:
				var end := Vector2(target.x / 256.0 - camera, target.y / 256.0 - 150)
				for i in 3:
					bolt(
						c,
						at + Vector2(0, -35 + i * 35),
						end + Vector2(0, -48 + i * 48),
						color,
						f.roll_tick / 3 + i * 13,
						0.9
					)


static func charge(c: CanvasItem, f: FighterModel, camera: float, actors: Array) -> void:
	if f.state != FighterState.Id.ATTACK or f.current_move().legacy.is_empty():
		return
	var move := f.current_move()
	var name := str(move.legacy.name)
	if name not in ["special", "super", "uppercut", "drone"]:
		return
	if f.character.id == "gustavo":
		GustavoFXV12.charge(c, f, camera)
		return
	if RollMotion.active(f):
		roll(c, f, camera, actors)
		return
	if f.character.id == "joao" and name == "special":
		super_punch(c, f, camera)
		return
	if name == "uppercut":
		upper(c, f, camera)
		return
	if f.character.id == "marcelo":
		MarceloPowerFX.charge(c, f, camera)
	var at := hand(f, camera)
	var color := f.character.color
	var phase := move.phase(f.move_tick)
	c.draw_set_transform(at, 0, Vector2(f.facing, 1))
	if phase == "STARTUP":
		var p := f.move_tick / float(maxi(1, move.startup * 2))
		glow(c, Vector2.ZERO, 40 + p * 65, color, 0.35 + p * 0.5)
		for i in 6:
			var a := i * TAU / 6 + p * 1.2
			var direction := Vector2(cos(a), sin(a))
			line(
				c,
				PackedVector2Array([direction * (65 - 40 * p), direction * (48 - 35 * p)]),
				color,
				2,
				p
			)
		match PowerArt.theme(f.character.id):
			"smoke":
				PowerArt.draw(c, "smoke", f.move_tick / 5, 0.16 + p * 0.22, Color(1, 1, 1, p))
			"fork":
				PowerArt.draw(c, "fork", f.move_tick / 5, 0.10 + p * 0.14, Color(1, 1, 1, p))
			"book":
				PowerArt.draw(c, "book", f.move_tick / 5, 0.11 + p * 0.18, Color(1, 1, 1, p))
			"scroll":
				if f.character.id == "adriano":
					seal(c, f.move_tick, color)
				else:
					ArcadeEffects.draw_cel(
						c, "scroll", f.move_tick / 4, 0.18 + p * 0.09, Color(1, 1, 1, p)
					)
			_:
				for i in 3:
					c.draw_line(
						Vector2(-30, -22 + i * 20),
						Vector2(16, -36 + i * 21),
						Color(WHITE, p),
						2,
						true
					)
	elif (
		phase == "ACTIVE"
		and not move.legacy.get("projectile", false)
		and not move.legacy.get("summon", false)
	):
		var root := Vector2(f.x / 256.0 - camera, f.y / 256.0 - 155)
		c.draw_set_transform(root, 0, Vector2(f.facing, 1))
		if f.character.id in ["joao", "ruan"]:
			glow(c, Vector2.ZERO, 155, color, 0.6)
			for i in 6:
				bolt(
					c,
					Vector2(-75, -135 + i * 45),
					Vector2(95, -125 + i * 44),
					color,
					f.move_tick / 3 + i * 7
				)
		elif f.character.id == "marcos":
			c.draw_set_transform(at, 0, Vector2(f.facing, 1))
			for i in 3:
				var r := Rect2(-27 - i * 10, -39 - i * 8, 54 + i * 20, 78 + i * 16)
				c.draw_rect(r, Color(color, 0.8 - i * 0.2), false, 3, true)
				c.draw_line(r.position, r.end, Color(WHITE, 0.5), 2, true)
		else:
			stroke(c, color, f.move_tick, 135, 60)
	c.draw_set_transform(Vector2.ZERO)


static func super_punch(c: CanvasItem, f: FighterModel, camera: float) -> void:
	# H concentrates electricity on the drawn fist. Q alone wraps the rolling body.
	var move := f.current_move()
	var phase := move.phase(f.move_tick)
	var strength := clampf(f.move_tick / float(maxi(1, move.startup * 2)), 0, 1)
	if phase == "RECOVERY":
		strength = clampf(
			(
				1
				- (
					(f.move_tick - (move.startup + move.active) * 2)
					/ float(maxi(1, move.recovery * 2))
				)
			),
			0,
			1
		)
	var at := hand(f, camera)
	c.draw_set_transform(at, 0, Vector2(f.facing, 1))
	glow(c, Vector2.ZERO, 28 + strength * 48, Color("caff58"), .28 + strength * .4)
	PowerCelsV10.draw(c, "ring", f.move_tick / 4, .20 + strength * .14, Color(1, 1, .6, strength))
	for i in 3:
		var a := i * TAU / 3 + f.move_tick * .13
		bolt(
			c,
			Vector2(cos(a), sin(a)) * 16,
			Vector2(cos(a + .9), sin(a + .9)) * 40,
			Color("c4ff55"),
			f.move_tick / 3 + i * 19,
			strength
		)
	if phase == "ACTIVE":
		stroke(c, Color("caff58"), f.move_tick, 115, 16)
		c.draw_circle(Vector2.ZERO, 8, WHITE)
	c.draw_set_transform(Vector2.ZERO)


static func impact(c: CanvasItem, b: Dictionary, actors: Array, camera: float) -> void:
	if b.character == "gustavo":
		GustavoFXV12.impact(c, b, camera)
		return
	var phase := 1.0 - float(b.life) / float(b.max)
	var alpha := pow(1 - phase, 0.9)
	var origin := Vector2(float(b.x) - camera, float(b.y))
	var character := str(b.character)
	var color := LegacyRoster.get_character(character).color
	if b.effect == "electricRoll":
		for actor in actors:
			if actor.slot == int(b.get("slot", -1)):
				origin = Vector2(actor.x / 256.0 - camera, actor.y / 256.0 - 150)
	c.draw_set_transform(origin, 0, Vector2(int(b.get("facing", 1)), 1))
	if b.kind == "cast":
		PowerCelsV10.draw(
			c, "cast", mini(3, int(phase * 4)), 0.5, Color(color.lerp(WHITE, 0.45), alpha)
		)
		c.draw_set_transform(Vector2.ZERO)
		return
	if b.effect == "electricRoll" and b.kind == "hit":
		glow(c, Vector2.ZERO, 160, Color("d1ff60"), alpha * 0.5)
		for i in 6:
			bolt(
				c,
				Vector2(-70, -118 + i * 43),
				Vector2(80, -105 + i * 44),
				Color("c4ff55"),
				int(phase * 60) + i * 9,
				alpha
			)
	elif b.kind == "block":
		c.draw_set_transform(origin, 0, Vector2(-int(b.get("facing", 1)), 1))
		var points := PackedVector2Array()
		for i in 19:
			var a := -1.45 + i * 2.9 / 18
			points.append(Vector2(cos(a) * 43, sin(a) * 58) * (0.5 + phase))
		line(c, points, Color("b1eeff"), 7, alpha)
	else:
		glow(c, Vector2.ZERO, 65 + phase * 55, color, alpha * 0.45)
		PowerCelsV10.draw(
			c, "cast", mini(3, int(phase * 4)), 0.6, Color(color.lerp(WHITE, 0.4), alpha)
		)
	c.draw_set_transform(Vector2.ZERO)
