class_name GeltonFXV13
extends RefCounted
## Paint drawn frame by frame. Simulation owns all hit areas, ages and damage.
## No random clocks, expanding projectile hitboxes or effects glued to the screen.
const GOLD := Color("ffe561")
const PINK := Color("ff67c8")
const CYAN := Color("66edff")
static var art: Dictionary = {}


static func load_data() -> void:
	if art.is_empty():
		art = JSON.parse_string(
			FileAccess.get_file_as_string("res://data/characters/gelton-effects-v13.json")
		)


static func cel(
	c: CanvasItem,
	clip: String,
	index: int,
	at: Vector2,
	size: Vector2,
	facing: int = 1,
	tint: Color = Color.WHITE
) -> void:
	load_data()
	var sequence: Array = art.clips[clip]
	var f: Dictionary = art.frames[int(sequence[posmod(index, sequence.size())])]
	var r: Array = f.rect
	var pivot := Vector2(float(f.pivot[0]), float(f.pivot[1]))
	c.draw_set_transform(at, 0, Vector2(facing, 1))
	c.draw_texture_rect_region(
		LegacyRoster.texture(art.image),
		Rect2(-pivot * size, size),
		Rect2(r[0], r[1], r[2], r[3]),
		tint
	)
	c.draw_set_transform(Vector2.ZERO)


static func projectile(c: CanvasItem, p: Dictionary, camera: float) -> void:
	var at := Vector2(p.x / 256.0 - camera, p.y / 256.0)
	var diameter := float(p.radius) * 2
	var age := int(p.age)
	var facing := int(p.facing)
	var super_move := str(p.move).begins_with("super")
	# The fan of paint occupies the real diameter; its tail has no collision.
	PowerFXV10.glow(c, at, diameter, PINK if super_move else GOLD, .16)
	cel(
		c,
		"stroke",
		age / 5,
		at,
		Vector2(diameter * 3.4, diameter * 1.7),
		facing,
		Color(1, .85, 1) if super_move else Color.WHITE
	)
	for i in 3:
		var color: Color = [PINK, CYAN, GOLD][i]
		var drop := at + Vector2((-48 - i * 27) * facing, sin(age * .10 + i * 2) * 18)
		c.draw_line(drop - Vector2(9 * facing, 2), drop, Color(color, .65 - i * .13), 3, true)


static func charge(c: CanvasItem, f: FighterModel, camera: float) -> void:
	var move := f.current_move()
	var phase := move.phase(f.move_tick)
	var name := str(move.legacy.name)
	var root := Vector2(f.x / 256.0 - camera, f.y / 256.0)
	var at := PowerFXV10.hand(f, camera)
	var amount := clampf(f.move_tick / float(maxi(1, move.startup * 2)), 0, 1)
	if name == "uppercut":
		if phase == "STARTUP":
			cel(c, "charge", 0, at, Vector2(48, 48), f.facing)
		elif phase == "ACTIVE":
			var age := f.move_tick - move.startup * 2
			# The painted convex edge follows the active cartwheel bands.
			cel(
				c,
				"arc",
				mini(3, age / 7),
				root + Vector2(103 * f.facing, -197),
				Vector2(175, 270),
				f.facing
			)
			PowerFXV10.glow(c, at, 48, GOLD, .20)
		elif not f.grounded():
			cel(
				c,
				"charge",
				3,
				root + Vector2(30 * f.facing, -70),
				Vector2(80, 105),
				f.facing,
				Color(1, 1, 1, .32)
			)
		return
	if name not in ["special", "super"]:
		return
	var super_move := name == "super"
	var color := PINK if super_move else GOLD
	if phase == "STARTUP":
		var radius := 22 + 22 * amount
		PowerFXV10.glow(c, at, radius * 1.9, color, .15 + amount * .15)
		cel(
			c,
			"charge",
			0 if amount < .55 else 1,
			at,
			Vector2.ONE * radius * 2,
			f.facing,
			Color(.93, .85, 1) if super_move else Color.WHITE
		)
		if super_move:
			for i in 2:
				var orbit := Vector2(cos(amount * 4 + i * PI), sin(amount * 4 + i * PI))
				cel(
					c,
					"charge",
					0,
					at + orbit * (52 - amount * 28),
					Vector2(32, 32),
					f.facing,
					Color(color, .65)
				)
	elif phase == "ACTIVE":
		if super_move:
			# The painted leg sweep surrounds the inversion without hiding the face.
			var age := f.move_tick - move.startup * 2
			cel(
				c,
				"arc",
				age / 6,
				root + Vector2(10 * f.facing, -210),
				Vector2(200, 195),
				f.facing,
				Color(1, 1, 1, .82)
			)
		cel(c, "charge", 2, at, Vector2(108, 78), f.facing)
	else:
		var elapsed := f.move_tick - (move.startup + move.active) * 2
		var alpha := maxf(0, 1 - elapsed / 22.0)
		if alpha > 0:
			cel(c, "charge", 3, at, Vector2(92, 70), f.facing, Color(1, 1, 1, alpha * .6))


static func impact(c: CanvasItem, b: Dictionary, camera: float) -> void:
	var at := Vector2(float(b.x) - camera, float(b.y))
	var t := clampf(1 - float(b.life) / float(b.max), 0, 1)
	var facing := int(b.get("facing", 1))
	var blocked: bool = b.kind == "block"
	if b.kind == "cast":
		cel(c, "charge", 2 if t < .4 else 3, at, Vector2(105, 80), facing, Color(1, 1, 1, 1 - t))
		return
	var size := 125.0 if blocked else 205.0
	if str(b.move).begins_with("super"):
		size *= 1.2
	cel(
		c,
		"splash",
		mini(3, int(t * 4)),
		at,
		Vector2.ONE * size,
		facing,
		Color(.65, .82, 1, 1 - t * .7) if blocked else Color(1, 1, 1, 1 - t * .7)
	)
	# A compact contact flash keeps the exact moment of impact readable.
	if t < .20:
		PowerFXV10.glow(c, at, 38, Color.WHITE, .35 * (1 - t / .20))
	c.draw_set_transform(Vector2.ZERO)
