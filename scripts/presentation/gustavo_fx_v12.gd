class_name GustavoFXV12
extends RefCounted
## Smoke drawn frame by frame. Simulation owns all hit areas, ages and damage.
## No random clocks, expanding projectile hitboxes or effects glued to the screen.
const MINT := Color("a8fff0")
const VIOLET := Color("c7adff")
static var art: Dictionary = {}


static func load_data() -> void:
	if art.is_empty():
		art = JSON.parse_string(
			FileAccess.get_file_as_string("res://data/characters/gustavo-effects-v12.json")
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
	var super_move := str(p.move).begins_with("super")
	var color := VIOLET if super_move else MINT
	var facing := int(p.facing)
	var age := int(p.age)
	# The dense front occupies the real diameter. The long tail is decorative.
	var diameter := float(p.radius) * 2
	var size := Vector2(diameter * 3.3, diameter * 1.65)
	PowerFXV10.glow(c, at, diameter * 1.2, color, .18)
	cel(c, "wave", age / 5, at, size, facing, Color(0.92, .84, 1) if super_move else Color.WHITE)
	# Thin trailing wisps provide speed without a second opaque hit core.
	for i in 2:
		var trail := at - Vector2((62 + i * 32) * facing, -11 + i * 22)
		cel(c, "gather", 3, trail, Vector2(80, 50), facing, Color(color, .16 - i * .05))


static func charge(c: CanvasItem, f: FighterModel, camera: float) -> void:
	var move := f.current_move()
	var phase := move.phase(f.move_tick)
	var name := str(move.legacy.name)
	var root := Vector2(f.x / 256.0 - camera, f.y / 256.0)
	var at := PowerFXV10.hand(f, camera)
	var amount := clampf(f.move_tick / float(maxi(1, move.startup * 2)), 0, 1)
	if name == "uppercut":
		if phase == "STARTUP":
			cel(c, "gather", 0, at, Vector2(48, 48), f.facing)
		elif phase == "ACTIVE":
			var age := f.move_tick - move.startup * 2
			# Mirror the authored open crescent: convex edge follows upper_boxes.
			cel(
				c,
				"rise",
				mini(3, age / 7),
				root + Vector2(94 * f.facing, -197),
				Vector2(170, 265),
				-f.facing
			)
			PowerFXV10.glow(c, at, 48, MINT, .20)
		elif not f.grounded():
			cel(
				c,
				"gather",
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
	var color := VIOLET if super_move else MINT
	if phase == "STARTUP":
		var radius := 22 + 22 * amount
		PowerFXV10.glow(c, at, radius * 1.9, color, .15 + amount * .15)
		cel(
			c,
			"gather",
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
					"gather",
					0,
					at + orbit * (52 - amount * 28),
					Vector2(32, 32),
					f.facing,
					Color(color, .65)
				)
	elif phase == "ACTIVE":
		cel(c, "gather", 2, at, Vector2(108, 78), f.facing)
	else:
		var elapsed := f.move_tick - (move.startup + move.active) * 2
		var alpha := maxf(0, 1 - elapsed / 22.0)
		if alpha > 0:
			cel(c, "gather", 3, at, Vector2(92, 70), f.facing, Color(1, 1, 1, alpha * .6))


static func impact(c: CanvasItem, b: Dictionary, camera: float) -> void:
	var at := Vector2(float(b.x) - camera, float(b.y))
	var t := clampf(1 - float(b.life) / float(b.max), 0, 1)
	var facing := int(b.get("facing", 1))
	var blocked: bool = b.kind == "block"
	if b.kind == "cast":
		cel(c, "gather", 2 if t < .4 else 3, at, Vector2(105, 80), facing, Color(1, 1, 1, 1 - t))
		return
	var size := 125.0 if blocked else 205.0
	if str(b.move).begins_with("super"):
		size *= 1.2
	cel(
		c,
		"impact",
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
