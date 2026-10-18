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
	var super_move := str(p.move).begins_with("super")
	# Only the bright pressure front has collision; the wake conveys velocity.
	PowerFXV10.glow(c, at, diameter, AMBER if super_move else ICE, .17)
	cel(c, "impulse", age / 4, at, Vector2(diameter * 3.7, diameter * 1.8), facing)
	if super_move:
		# After-rings make the five separate impulses readable without hiding them.
		for i in 2:
			var wake := at - Vector2((48 + i * 32) * facing, 0)
			cel(c, "gather", 3, wake, Vector2(33, 59), facing, Color(1, .85, .7, .32 - i * .10))


static func charge(c: CanvasItem, f: FighterModel, camera: float) -> void:
	var move := f.current_move()
	var phase := move.phase(f.move_tick)
	var name := str(move.legacy.name)
	var root := Vector2(f.x / 256.0 - camera, f.y / 256.0)
	var at := PowerFXV10.hand(f, camera)
	var amount := clampf(f.move_tick / float(maxi(1, move.startup * 2)), 0, 1)
	if name == "uppercut":
		if phase == "STARTUP":
			cel(c, "gather", 0, at, Vector2(42, 42), f.facing)
		elif phase == "ACTIVE":
			var age := f.move_tick - move.startup * 2
			# Convex side follows the shared authoritative rising attack bands.
			cel(
				c,
				"rise",
				mini(3, age / 7),
				root + Vector2(102 * f.facing, -197),
				Vector2(170, 270),
				f.facing
			)
			cel(c, "gather", 2, at, Vector2(57, 57), f.facing, Color(1, 1, 1, .8))
		return
	if name not in ["special", "super"]:
		return
	var super_move := name == "super"
	if phase == "STARTUP":
		cel(c, "gather", 0 if amount < .55 else 1, at, Vector2.ONE * (35 + amount * 45), f.facing)
		PowerFXV10.glow(c, at, 45 + amount * 30, ICE, .20)
		if super_move:
			# Two narrow pressure halos converge on the actual palm socket.
			for i in 2:
				var offset := Vector2((30 + i * 18) * f.facing * (1 - amount), 0)
				cel(c, "gather", 3, at - offset, Vector2(45, 80), f.facing, Color(1, .9, .7, .6))
	elif phase == "ACTIVE":
		# Pulse on the same ten-tick cadence as authoritative wave emission.
		var pulse := (f.move_tick - move.startup * 2) % 10
		cel(
			c,
			"gather",
			2,
			at,
			Vector2(112 - pulse * 3, 75 - pulse),
			f.facing,
			Color(1, 1, 1, 1 - pulse * .055)
		)
	else:
		var elapsed := f.move_tick - (move.startup + move.active) * 2
		var alpha := maxf(0, 1 - elapsed / 20.0)
		if alpha > 0:
			cel(c, "gather", 3, at, Vector2(75, 65), f.facing, Color(1, 1, 1, alpha * .5))


static func impact(c: CanvasItem, b: Dictionary, camera: float) -> void:
	var at := Vector2(float(b.x) - camera, float(b.y))
	var t := clampf(1 - float(b.life) / float(b.max), 0, 1)
	var facing := int(b.get("facing", 1))
	if b.kind == "cast":
		cel(c, "gather", 2 if t < .35 else 3, at, Vector2(100, 75), facing, Color(1, 1, 1, 1 - t))
		return
	var blocked: bool = b.kind == "block"
	var size := 128.0 if blocked else 200.0
	if str(b.move).begins_with("super"):
		size *= 1.15
	cel(
		c,
		"impact",
		mini(3, int(t * 4)),
		at,
		Vector2.ONE * size,
		facing,
		Color(.6, .85, 1, 1 - t * .65) if blocked else Color(1, 1, 1, 1 - t * .65)
	)
	if t < .18:
		PowerFXV10.glow(c, at, 32, Color.WHITE, .35 * (1 - t / .18))
