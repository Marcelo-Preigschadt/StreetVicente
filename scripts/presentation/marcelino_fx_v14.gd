class_name MarcelinoFXV14
extends RefCounted
## Kinetic pressure cels. The fixed-step simulation owns contact, speed and waves.
const ICE := Color("8cf1ff")
const AMBER := Color("ffb84f")
static var art: Dictionary = {}


static func load_data() -> void:
	if art.is_empty():
		art = JSON.parse_string(
			FileAccess.get_file_as_string("res://data/characters/marcelino-effects-v14.json")
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
	var speed := absf(float(p.vx)) * 120 / FighterModel.SCALE
	# Visual intensity follows speed squared; simulation damage/radius are unchanged.
	var energy := clampf(pow(speed / 740, 2), 1, 2.2)
	var length := clampf(speed * .19, 130, 220)
	cel(c, "impulse", age / 4, at, Vector2(length + diameter, diameter * 1.75), facing)
	for i in 3:
		var behind := at - Vector2((27 + i * 28 + posmod(age * 4, 18)) * facing, 0)
		c.draw_set_transform(behind, 0, Vector2(.33 * facing, 1))
		c.draw_arc(
			Vector2.ZERO,
			diameter * (.48 + i * .05),
			-1.25,
			1.25,
			24,
			Color(ICE, (.24 - i * .055) * energy),
			2,
			true
		)
		c.draw_set_transform(Vector2.ZERO)
	for i in 3:
		var tail := at - Vector2((length * .75 + i * 15) * facing, 19 * (i - 1))
		c.draw_line(
			tail,
			tail + Vector2((20 + energy * 12) * facing, 0),
			Color(AMBER if i == 1 else ICE, .35 - i * .07),
			2,
			true
		)


static func charge(c: CanvasItem, f: FighterModel, camera: float) -> void:
	var move := f.current_move()
	var phase := move.phase(f.move_tick)
	var name := str(move.legacy.name)
	var root := Vector2(f.x / 256.0 - camera, f.y / 256.0)
	var at := PowerFXV10.hand(f, camera)
	var amount := clampf(f.move_tick / float(maxi(1, move.startup * 2)), 0, 1)
	if name == "uppercut":
		if phase == "STARTUP":
			cel(c, "gather", 0 if amount < .6 else 1, at, Vector2(55, 55), f.facing)
		elif phase == "ACTIVE":
			var age := f.move_tick - move.startup * 2
			cel(
				c,
				"rise",
				mini(3, age / 7),
				root + Vector2(102 * f.facing, -197),
				Vector2(170, 270),
				f.facing
			)
			cel(c, "gather", 2, at, Vector2(78, 61), f.facing, Color(1, 1, 1, .8))
			if age < 18:
				var floor_at := Vector2(root.x - 15 * f.facing, f.ground_y / 256.0)
				cel(
					c,
					"gather",
					3,
					floor_at,
					Vector2(80 + age * 5, 27 + age),
					f.facing,
					Color(1, 1, 1, .7 * (1 - age / 18.0))
				)
		return
	if name not in ["special", "super"]:
		return
	var super_move := name == "super"
	if phase == "STARTUP":
		# Wide pressure rings contract into the actual palm socket before release.
		cel(
			c,
			"gather",
			0 if amount < .55 else 1,
			at,
			Vector2(115 - amount * 57, 90 - amount * 32),
			f.facing
		)
		for i in 2:
			var offset := Vector2((32 + i * 21) * f.facing * (1 - amount), 0)
			cel(
				c,
				"gather",
				3,
				at - offset,
				Vector2(35, 75 - amount * 20),
				f.facing,
				Color(1, 1, 1, .3 + .1 * amount)
			)
	elif phase == "ACTIVE":
		var age := f.move_tick - move.startup * 2
		if not super_move or age < 50:
			var pulse := age % 10
			cel(
				c,
				"gather",
				2,
				at,
				Vector2(132 - pulse * 5, 95 - pulse * 3),
				f.facing,
				Color(1, 1, 1, 1 - pulse * .075)
			)
			if super_move and pulse < 5:
				# Counter-impulse behind the torso accompanies the body's recoil.
				cel(
					c,
					"gather",
					3,
					root + Vector2(-36 * f.facing, -155),
					Vector2(75 + pulse * 5, 60),
					-f.facing,
					Color(1, 1, 1, .45 - pulse * .07)
				)
	else:
		var elapsed := f.move_tick - (move.startup + move.active) * 2
		var alpha := maxf(0, 1 - elapsed / 20.0)
		if alpha > 0:
			cel(c, "gather", 3, at, Vector2(95, 65), f.facing, Color(1, 1, 1, alpha * .5))


static func impact(c: CanvasItem, b: Dictionary, camera: float) -> void:
	var at := Vector2(float(b.x) - camera, float(b.y))
	var t := clampf(1 - float(b.life) / float(b.max), 0, 1)
	var facing := int(b.get("facing", 1))
	if b.kind == "cast":
		cel(c, "gather", 2 if t < .35 else 3, at, Vector2(115, 80), facing, Color(1, 1, 1, 1 - t))
		return
	var blocked: bool = b.kind == "block"
	var size := (100.0 if blocked else 130.0) + t * (55 if blocked else 110)
	if str(b.move).begins_with("super"):
		size *= 1.12
	cel(
		c,
		"impact",
		mini(3, int(t * 4)),
		at,
		Vector2.ONE * size,
		facing,
		Color(.6, .85, 1, 1 - t * .7) if blocked else Color(1, 1, 1, 1 - t * .7)
	)
	var direction := -facing if blocked else facing
	for i in 3:
		var start := at + Vector2((10 + t * 42) * direction, (i - 1) * 18)
		c.draw_line(
			start,
			start + Vector2((20 + t * 35) * direction, (i - 1) * 9),
			Color(ICE if blocked else AMBER, .65 * (1 - t)),
			2.2,
			true
		)
	if t < .15:
		PowerFXV10.glow(c, at, 28, Color.WHITE, .32 * (1 - t / .15))
